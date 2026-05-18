// ignore_for_file: implementation_imports

import '../docx/exporters/pdf/ttf_parser.dart';

import 'document_models.dart';

class LanguageSupportException implements Exception {
  const LanguageSupportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LanguageSupportService {
  const LanguageSupportService();

  void ensureExportable({
    required String text,
    required List<CustomFontFile> customFonts,
    String? selectedFontFamily,
  }) {
    final requiredCodePoints = _significantCodePoints(text);
    if (requiredCodePoints.isEmpty) {
      return;
    }

    final selectedFont = customFonts
        .where((font) => font.family == selectedFontFamily)
        .firstOrNull;
    if (selectedFont == null) {
      throw const LanguageSupportException(
        'This document contains non-Latin characters. Import and select a TTF font that covers those characters before exporting.',
      );
    }

    final parser = TtfParser(selectedFont.bytes);
    try {
      parser.parse();
    } on Object {
      throw LanguageSupportException(
        'The selected font "${selectedFont.family}" could not be inspected. Use a Unicode TTF font for guaranteed multilingual export.',
      );
    }

    final missing = requiredCodePoints
        .where((codePoint) => parser.getGlyphId(codePoint) == 0)
        .toList();
    if (missing.isEmpty) {
      return;
    }

    final preview = missing
        .take(8)
        .map((codePoint) => 'U+${codePoint.toRadixString(16).toUpperCase()}')
        .join(', ');
    throw LanguageSupportException(
      'The selected font "${selectedFont.family}" does not cover every character in this document. Missing: $preview.',
    );
  }

  Set<int> _significantCodePoints(String text) {
    return text.runes
        .where((codePoint) => !_isCoveredByBasePdfFonts(codePoint))
        .toSet();
  }

  bool _isCoveredByBasePdfFonts(int codePoint) {
    if (codePoint == 0x09 || codePoint == 0x0A || codePoint == 0x0D) {
      return true;
    }
    return codePoint >= 0x20 && codePoint <= 0x7E;
  }
}
