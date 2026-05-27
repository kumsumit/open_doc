import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import '../engine/docx.dart' as docx;
import 'package:xml/xml.dart';

import 'document_export_service.dart';
import 'document_models.dart';

class ImportedDocument {
  const ImportedDocument({
    required this.text,
    required this.formatLabel,
    this.title,
    this.selectedFontFamily,
    this.mediaBlocks = const [],
    this.customFonts = const [],
    this.sourcePackageFormat,
    this.sourcePackageBytes,
    this.ooxmlBlocks = const [],
    this.wysiwygBlocks = const [],
    this.quillDeltaJson = const [],
    this.pageSetup,
  });

  final String text;
  final String formatLabel;
  final String? title;
  final String? selectedFontFamily;
  final List<MediaBlock> mediaBlocks;
  final List<CustomFontFile> customFonts;
  final String? sourcePackageFormat;
  final Uint8List? sourcePackageBytes;
  final List<OoxmlVisualBlock> ooxmlBlocks;
  final List<WysiwygBlock> wysiwygBlocks;
  final List<Object?> quillDeltaJson;
  final DocumentPageSetup? pageSetup;
}

class DocumentImportService {
  const DocumentImportService();

  Future<ImportedDocument> parseAsync(Uint8List bytes, String fileName) async {
    if (fileExtension(fileName) != 'docx') {
      return parse(bytes, fileName);
    }

    final base = parse(bytes, fileName);
    final partBlocks = _visualPartTextBlocks(bytes);
    try {
      final document = await docx.DocxReader.loadFromBytes(bytes);
      return ImportedDocument(
        text: base.text,
        formatLabel: base.formatLabel,
        sourcePackageFormat: base.sourcePackageFormat,
        sourcePackageBytes: base.sourcePackageBytes,
        ooxmlBlocks: [..._visualBlocksFromDocx(document), ...partBlocks],
        wysiwygBlocks: WysiwygDocumentCodec.fromMarkdown(base.text),
        quillDeltaJson: _quillDeltaFromDocx(document),
      );
    } on Object {
      return ImportedDocument(
        text: base.text,
        formatLabel: base.formatLabel,
        sourcePackageFormat: base.sourcePackageFormat,
        sourcePackageBytes: base.sourcePackageBytes,
        ooxmlBlocks: partBlocks,
      );
    }
  }

  ImportedDocument parse(Uint8List bytes, String fileName) {
    final extension = fileExtension(fileName);
    return switch (extension) {
      'docx' => ImportedDocument(
        text: _extractDocxText(bytes),
        formatLabel: 'DOCX',
        sourcePackageFormat: 'docx',
        sourcePackageBytes: Uint8List.fromList(bytes),
      ),
      'txt' || 'md' || 'markdown' => ImportedDocument(
        text: _decodeText(bytes),
        formatLabel: extension == 'txt' ? 'text' : 'Markdown',
      ),
      'rtf' => ImportedDocument(
        text: _stripRtf(_decodeText(bytes)),
        formatLabel: 'RTF',
      ),
      'html' || 'htm' => ImportedDocument(
        text: _stripHtml(_decodeText(bytes)),
        formatLabel: 'HTML',
      ),
      'csv' => ImportedDocument(
        text: _csvToReadableText(_decodeText(bytes)),
        formatLabel: 'CSV',
      ),
      'odoc' => _parseOpenDoc(bytes),
      _ => throw FormatException('Unsupported file type: .$extension'),
    };
  }

  String titleFromFileName(String fileName) {
    final baseName = fileName.split(RegExp(r'[/\\]')).last;
    final withoutExtension = baseName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return withoutExtension.trim().isEmpty
        ? 'Imported document'
        : withoutExtension;
  }

  String fileExtension(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index == -1 || index == fileName.length - 1) {
      return '';
    }
    return fileName.substring(index + 1).toLowerCase();
  }

  String _extractDocxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentFile = archive.files
        .where((file) => file.name == 'word/document.xml')
        .firstOrNull;
    if (documentFile == null) {
      throw const FormatException(
        'This DOCX file has no readable document body.',
      );
    }

    final relationships = _extractDocxRelationships(archive);
    final numbering = _extractDocxNumbering(archive);
    final document = XmlDocument.parse(utf8.decode(documentFile.content));
    final body = document.descendants.whereType<XmlElement>().firstWhere(
      (element) => element.name.local == 'body',
      orElse: () => document.rootElement,
    );
    final blocks = <String>[];

    for (final child in body.childElements) {
      switch (child.name.local) {
        case 'p':
          final text = _extractDocxParagraphText(
            child,
            relationships: relationships,
            numbering: numbering,
          );
          if (text.trim().isNotEmpty) {
            blocks.add(text);
          }
        case 'tbl':
          final table = _extractDocxTableText(
            child,
            relationships: relationships,
            numbering: numbering,
          );
          if (table.trim().isNotEmpty) {
            blocks.add(table);
          }
      }
    }

    return blocks.join('\n\n');
  }

  ImportedDocument _parseOpenDoc(Uint8List bytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(_decodeText(bytes));
    } on Object {
      throw const FormatException('This Open Doc file is not valid JSON.');
    }

    if (decoded is! Map<String, Object?> || decoded['format'] != 'open_doc') {
      throw const FormatException('This is not a readable Open Doc file.');
    }

    final markdown = decoded['markdown'];
    if (markdown is! String) {
      throw const FormatException('This Open Doc file has no document body.');
    }

    return ImportedDocument(
      text: markdown,
      title: decoded['title'] is String ? decoded['title'] as String : null,
      selectedFontFamily: decoded['selectedFontFamily'] is String
          ? decoded['selectedFontFamily'] as String
          : null,
      formatLabel: 'Open Doc',
      pageSetup: _parseOpenDocPageSetup(decoded['pageSetup']),
      mediaBlocks: _parseOpenDocMediaBlocks(decoded['mediaBlocks']),
      customFonts: _parseOpenDocCustomFonts(decoded['customFonts']),
      sourcePackageFormat: decoded['sourcePackageFormat'] is String
          ? decoded['sourcePackageFormat'] as String
          : null,
      sourcePackageBytes: _decodeNullableBase64(decoded['sourcePackageBase64']),
      ooxmlBlocks: _parseOpenDocVisualBlocks(decoded['ooxmlBlocks']),
      wysiwygBlocks: _parseOpenDocWysiwygBlocks(decoded['wysiwygBlocks']),
      quillDeltaJson: _parseOpenDocQuillDelta(decoded['quillDeltaJson']),
    );
  }

  List<OoxmlVisualBlock> _visualBlocksFromDocx(
    docx.DocxBuiltDocument document,
  ) {
    final blocks = <OoxmlVisualBlock>[];
    for (final node in document.elements) {
      if (node is docx.DocxParagraph) {
        final text = node.children
            .whereType<docx.DocxText>()
            .map((text) => text.content)
            .join();
        if (text.trim().isNotEmpty || node.styleId != null) {
          blocks.add(
            OoxmlParagraphBlock(
              text: text,
              styleId: node.styleId,
              align: _visualAlignFor(node.align),
              pageBreakBefore: node.pageBreakBefore,
            ),
          );
        }
      } else if (node is docx.DocxTable) {
        blocks.add(
          OoxmlTableBlock(
            hasHeader: node.hasHeader,
            columnWidths: node.resolvedGridColumns,
            rowHeights: [for (final row in node.rows) row.height ?? 0],
            rows: [
              for (final row in node.rows)
                [
                  for (final cell in row.cells)
                    cell.children
                        .whereType<docx.DocxParagraph>()
                        .expand((paragraph) => paragraph.children)
                        .whereType<docx.DocxText>()
                        .map((text) => text.content)
                        .join(),
                ],
            ],
          ),
        );
      }
    }
    return blocks;
  }

  List<Object?> _quillDeltaFromDocx(docx.DocxBuiltDocument document) {
    final ops = <Object?>[];
    for (final node in document.elements) {
      if (node is docx.DocxParagraph) {
        for (final child in node.children) {
          if (child is docx.DocxText) {
            final attributes = _quillTextAttributes(child);
            ops.add(
              attributes.isEmpty
                  ? {'insert': child.content}
                  : {'insert': child.content, 'attributes': attributes},
            );
          }
        }
        final lineAttributes = _quillParagraphAttributes(node);
        ops.add(
          lineAttributes.isEmpty
              ? {'insert': '\n'}
              : {'insert': '\n', 'attributes': lineAttributes},
        );
      } else if (node is docx.DocxList) {
        for (final item in node.items) {
          for (final child in item.children) {
            if (child is docx.DocxText) {
              final attributes = _quillTextAttributes(child);
              ops.add(
                attributes.isEmpty
                    ? {'insert': child.content}
                    : {'insert': child.content, 'attributes': attributes},
              );
            }
          }
          ops.add({
            'insert': '\n',
            'attributes': {'list': node.isOrdered ? 'ordered' : 'bullet'},
          });
        }
      } else if (node is docx.DocxTable) {
        for (final row in node.rows) {
          final cells = <String>[];
          for (final cell in row.cells) {
            cells.add(
              cell.children
                  .whereType<docx.DocxParagraph>()
                  .expand((paragraph) => paragraph.children)
                  .whereType<docx.DocxText>()
                  .map((text) => text.content)
                  .join(),
            );
          }
          ops
            ..add({'insert': cells.join(' | ')})
            ..add({'insert': '\n'});
        }
      }
    }
    if (ops.isEmpty) {
      return const [];
    }
    final last = ops.last;
    if (last is Map && last['insert'] != '\n') {
      ops.add({'insert': '\n'});
    }
    return ops;
  }

  Map<String, Object?> _quillTextAttributes(docx.DocxText text) {
    final attributes = <String, Object?>{};
    if (text.isBold) {
      attributes['bold'] = true;
    }
    if (text.isItalic) {
      attributes['italic'] = true;
    }
    if (text.isUnderline) {
      attributes['underline'] = true;
    }
    if (text.isStrike) {
      attributes['strike'] = true;
    }
    if (text.color != null) {
      attributes['color'] = '#${text.color!.hex}';
    }
    if (text.shadingFill != null) {
      attributes['background'] = '#${text.shadingFill}';
    }
    if (text.fontSize != null) {
      attributes['size'] = text.fontSize!.toString();
    }
    if (text.href != null && text.href!.isNotEmpty) {
      attributes['link'] = text.href;
    }
    if (text.isSuperscript) {
      attributes['script'] = 'super';
    } else if (text.isSubscript) {
      attributes['script'] = 'sub';
    }
    return attributes;
  }

  Map<String, Object?> _quillParagraphAttributes(docx.DocxParagraph paragraph) {
    final attributes = <String, Object?>{};
    final styleId = paragraph.styleId?.toLowerCase();
    if (styleId == 'heading1' || styleId == 'title') {
      attributes['header'] = 1;
    } else if (styleId == 'heading2') {
      attributes['header'] = 2;
    } else if (styleId == 'heading3') {
      attributes['header'] = 3;
    } else if (styleId == 'quote' || paragraph.indentLeft == 720) {
      attributes['blockquote'] = true;
    }
    switch (paragraph.align) {
      case docx.DocxAlign.center:
        attributes['align'] = 'center';
      case docx.DocxAlign.right:
        attributes['align'] = 'right';
      case docx.DocxAlign.justify:
        attributes['align'] = 'justify';
      case docx.DocxAlign.left:
        break;
    }
    return attributes;
  }

  OoxmlTextAlign _visualAlignFor(docx.DocxAlign align) {
    return switch (align) {
      docx.DocxAlign.center => OoxmlTextAlign.center,
      docx.DocxAlign.right => OoxmlTextAlign.right,
      docx.DocxAlign.justify => OoxmlTextAlign.justify,
      docx.DocxAlign.left => OoxmlTextAlign.left,
    };
  }

  List<OoxmlVisualBlock> _parseOpenDocVisualBlocks(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, Object?>>()
        .map((json) {
          return switch (json['type']) {
            'paragraph' => OoxmlParagraphBlock.fromJson(json),
            'table' => OoxmlTableBlock.fromJson(json),
            'partText' => OoxmlPartTextBlock.fromJson(json),
            _ => null,
          };
        })
        .nonNulls
        .toList();
  }

  List<WysiwygBlock> _parseOpenDocWysiwygBlocks(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, Object?>>()
        .map(WysiwygBlock.fromJson)
        .toList();
  }

  List<Object?> _parseOpenDocQuillDelta(Object? value) {
    if (value is! List) {
      return const [];
    }
    return List<Object?>.of(value);
  }

  List<OoxmlVisualBlock> _visualPartTextBlocks(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final blocks = <OoxmlVisualBlock>[];
    for (final file in archive.files) {
      if (!file.isFile || !_isEditableOoxmlPart(file.name)) {
        continue;
      }
      final content = utf8.decode(file.content as List<int>);
      XmlDocument document;
      try {
        document = XmlDocument.parse(content);
      } on Object {
        continue;
      }
      var index = 0;
      for (final paragraph in document.descendants.whereType<XmlElement>()) {
        if (paragraph.name.local != 'p') {
          continue;
        }
        final text = _plainParagraphText(paragraph);
        if (text.trim().isEmpty) {
          index += 1;
          continue;
        }
        blocks.add(
          OoxmlPartTextBlock(
            partPath: file.name,
            paragraphIndex: index,
            label: _partLabel(file.name),
            text: text,
          ),
        );
        index += 1;
      }
    }
    return blocks;
  }

  bool _isEditableOoxmlPart(String path) {
    return RegExp(
      r'^word/(header\d+|footer\d+|comments|footnotes|endnotes)\.xml$',
    ).hasMatch(path);
  }

  String _partLabel(String path) {
    final name = path.split('/').last.replaceAll('.xml', '');
    if (name.startsWith('header')) {
      return 'Header ${name.replaceFirst('header', '')}';
    }
    if (name.startsWith('footer')) {
      return 'Footer ${name.replaceFirst('footer', '')}';
    }
    return switch (name) {
      'comments' => 'Comment',
      'footnotes' => 'Footnote',
      'endnotes' => 'Endnote',
      _ => 'OOXML part',
    };
  }

  String _plainParagraphText(XmlElement paragraph) {
    return paragraph.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 't')
        .map((element) => element.innerText)
        .join();
  }

  Uint8List? _decodeNullableBase64(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    try {
      return base64Decode(value);
    } on Object {
      return null;
    }
  }

  DocumentPageSetup _parseOpenDocPageSetup(Object? value) {
    if (value is! Map<String, Object?>) {
      return const DocumentPageSetup();
    }
    return DocumentPageSetup(
      pageSize: _enumByName(
        DocumentPageSize.values,
        value['pageSize'],
        DocumentPageSize.a4,
      ),
      orientation: _enumByName(
        DocumentPageOrientation.values,
        value['orientation'],
        DocumentPageOrientation.portrait,
      ),
      marginPreset: _enumByName(
        DocumentMarginPreset.values,
        value['marginPreset'],
        DocumentMarginPreset.normal,
      ),
    );
  }

  List<MediaBlock> _parseOpenDocMediaBlocks(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<Map<String, Object?>>().map((item) {
      Uint8List? bytes;
      final encodedBytes = item['bytesBase64'];
      if (encodedBytes is String && encodedBytes.isNotEmpty) {
        try {
          bytes = base64Decode(encodedBytes);
        } on Object {
          bytes = null;
        }
      }

      return MediaBlock(
        id: item['id'] is String
            ? item['id'] as String
            : DateTime.now().microsecondsSinceEpoch.toString(),
        type: _enumByName(MediaType.values, item['type'], MediaType.image),
        source: item['source'] is String ? item['source'] as String : '',
        caption: item['caption'] is String ? item['caption'] as String : '',
        bytes: bytes,
      );
    }).toList();
  }

  List<CustomFontFile> _parseOpenDocCustomFonts(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map<String, Object?>>()
        .map((item) {
          final family = item['family'];
          final source = item['source'];
          final encodedBytes = item['bytesBase64'];
          if (family is! String ||
              family.trim().isEmpty ||
              encodedBytes is! String ||
              encodedBytes.isEmpty) {
            return null;
          }

          try {
            return CustomFontFile(
              family: family.trim(),
              source: source is String && source.trim().isNotEmpty
                  ? source.trim()
                  : '${family.trim()}.ttf',
              bytes: base64Decode(encodedBytes),
            );
          } on Object {
            return null;
          }
        })
        .nonNulls
        .toList();
  }

  T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
    if (name is! String) {
      return fallback;
    }
    return values.where((value) => value.name == name).firstOrNull ?? fallback;
  }

  Map<String, String> _extractDocxRelationships(Archive archive) {
    final relsFile = archive.files
        .where((file) => file.name == 'word/_rels/document.xml.rels')
        .firstOrNull;
    if (relsFile == null) {
      return const {};
    }

    try {
      final rels = XmlDocument.parse(utf8.decode(relsFile.content));
      return {
        for (final element in rels.descendants.whereType<XmlElement>())
          if (element.name.local == 'Relationship' &&
              element.getAttribute('Id') != null &&
              element.getAttribute('Target') != null)
            element.getAttribute('Id')!: element.getAttribute('Target')!,
      };
    } on Object {
      return const {};
    }
  }

  Map<String, _DocxNumberingDef> _extractDocxNumbering(Archive archive) {
    final numberingFile = archive.files
        .where((file) => file.name == 'word/numbering.xml')
        .firstOrNull;
    if (numberingFile == null) {
      return const {};
    }

    try {
      final document = XmlDocument.parse(utf8.decode(numberingFile.content));
      final abstractFormats = <String, Map<int, String>>{};
      for (final abstractNum in document.descendants.whereType<XmlElement>()) {
        if (abstractNum.name.local != 'abstractNum') {
          continue;
        }
        final abstractId =
            abstractNum.getAttribute('w:abstractNumId') ??
            abstractNum.getAttribute('abstractNumId');
        if (abstractId == null) {
          continue;
        }
        final levels = <int, String>{};
        for (final level in abstractNum.childElements.where(
          (element) => element.name.local == 'lvl',
        )) {
          final levelIndex =
              int.tryParse(
                level.getAttribute('w:ilvl') ??
                    level.getAttribute('ilvl') ??
                    '',
              ) ??
              0;
          final format =
              _firstChild(level, 'numFmt')?.getAttribute('w:val') ??
              _firstChild(level, 'numFmt')?.getAttribute('val') ??
              'decimal';
          levels[levelIndex] = format;
        }
        abstractFormats[abstractId] = levels;
      }

      final numbering = <String, _DocxNumberingDef>{};
      for (final num in document.descendants.whereType<XmlElement>()) {
        if (num.name.local != 'num') {
          continue;
        }
        final numId = num.getAttribute('w:numId') ?? num.getAttribute('numId');
        final abstractId =
            _firstChild(num, 'abstractNumId')?.getAttribute('w:val') ??
            _firstChild(num, 'abstractNumId')?.getAttribute('val');
        if (numId != null && abstractId != null) {
          numbering[numId] = _DocxNumberingDef(
            formatsByLevel: abstractFormats[abstractId] ?? const {},
          );
        }
      }
      return numbering;
    } on Object {
      return const {};
    }
  }

  String _extractDocxParagraphText(
    XmlElement paragraph, {
    Map<String, String> relationships = const {},
    Map<String, _DocxNumberingDef> numbering = const {},
  }) {
    final properties = _firstChild(paragraph, 'pPr');
    final styleId =
        _firstChild(properties, 'pStyle')?.getAttribute('w:val') ??
        _firstChild(properties, 'pStyle')?.getAttribute('val');
    final headingLevel = _headingLevelForStyle(styleId);
    final listInfo = _listInfoForParagraph(properties, numbering);
    final hasPageBreak = paragraph.descendants.whereType<XmlElement>().any(
      (element) => element.name.local == 'pageBreakBefore',
    );

    final text = paragraph.childElements
        .where((element) => element.name.local != 'pPr')
        .map((element) => _extractDocxInlineText(element, relationships))
        .join()
        .trimRight();

    final buffer = StringBuffer();
    if (hasPageBreak) {
      buffer.writeln('[[PAGE_BREAK]]');
      if (text.trim().isNotEmpty) {
        buffer.writeln();
      }
    }

    if (text.trim().isEmpty) {
      return buffer.toString().trimRight();
    }

    if (headingLevel != null) {
      buffer.write('${'#' * headingLevel} $text');
    } else if (listInfo != null) {
      final indent = '  ' * listInfo.level;
      final marker = listInfo.isOrdered ? '1.' : '-';
      buffer.write('$indent$marker $text');
    } else {
      buffer.write(text);
    }

    return buffer.toString().trimRight();
  }

  String _extractDocxInlineText(
    XmlElement node,
    Map<String, String> relationships,
  ) {
    if (node.name.local == 'hyperlink') {
      final relationshipId =
          node.getAttribute('r:id') ?? node.getAttribute('id');
      final text = node.childElements
          .map((child) => _extractDocxInlineText(child, relationships))
          .join();
      final target = relationshipId == null
          ? null
          : relationships[relationshipId];
      return target == null || text.trim().isEmpty
          ? text
          : '[${_escapeMarkdownLinkText(text)}]($target)';
    }

    if (node.name.local == 'r') {
      return _extractDocxRunText(node);
    }

    final buffer = StringBuffer();
    for (final child in node.childElements) {
      buffer.write(_extractDocxInlineText(child, relationships));
    }
    return buffer.toString();
  }

  String _extractDocxRunText(XmlElement run) {
    final buffer = StringBuffer();
    var hasBold = false;
    var hasItalic = false;
    var hasCodeStyle = false;

    final runProperties = _firstChild(run, 'rPr');
    if (runProperties != null) {
      hasBold = _firstChild(runProperties, 'b') != null;
      hasItalic = _firstChild(runProperties, 'i') != null;
      final style =
          _firstChild(runProperties, 'rStyle')?.getAttribute('w:val') ??
          _firstChild(runProperties, 'rStyle')?.getAttribute('val');
      hasCodeStyle = style?.toLowerCase().contains('code') ?? false;
    }

    for (final child in run.childElements) {
      switch (child.name.local) {
        case 't':
        case 'instrText':
          buffer.write(child.innerText);
        case 'tab':
          buffer.write('\t');
        case 'br':
        case 'cr':
          buffer.write('\n');
      }
    }

    final value = buffer.toString();
    if (value.trim().isEmpty) {
      return value;
    }
    if (hasCodeStyle) {
      return '`${value.replaceAll('`', r'\`')}`';
    }
    if (hasBold && hasItalic) {
      return '***$value***';
    }
    if (hasBold) {
      return '**$value**';
    }
    if (hasItalic) {
      return '*$value*';
    }
    return value;
  }

  String _extractDocxTableText(
    XmlElement table, {
    Map<String, String> relationships = const {},
    Map<String, _DocxNumberingDef> numbering = const {},
  }) {
    final rows = <List<String>>[];
    for (final row in table.childElements.where(
      (element) => element.name.local == 'tr',
    )) {
      final cells = row.childElements
          .where((element) => element.name.local == 'tc')
          .map((cell) {
            final paragraphs = cell.childElements
                .where((element) => element.name.local == 'p')
                .map(
                  (paragraph) => _extractDocxParagraphText(
                    paragraph,
                    relationships: relationships,
                    numbering: numbering,
                  ),
                )
                .where((text) => text.trim().isNotEmpty)
                .map((text) => text.trim())
                .toList();
            return paragraphs.join(' ');
          })
          .toList();
      if (cells.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(cells);
      }
    }
    return _rowsToMarkdownTable(rows);
  }

  XmlElement? _firstChild(XmlElement? element, String localName) {
    return element?.childElements
        .where((child) => child.name.local == localName)
        .firstOrNull;
  }

  int? _headingLevelForStyle(String? styleId) {
    final normalized = styleId?.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized == null) {
      return null;
    }
    final match = RegExp(r'^heading([1-6])$').firstMatch(normalized);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  _DocxListInfo? _listInfoForParagraph(
    XmlElement? paragraphProperties,
    Map<String, _DocxNumberingDef> numbering,
  ) {
    final numPr = _firstChild(paragraphProperties, 'numPr');
    if (numPr == null) {
      return null;
    }

    final numId =
        _firstChild(numPr, 'numId')?.getAttribute('w:val') ??
        _firstChild(numPr, 'numId')?.getAttribute('val');
    final level =
        int.tryParse(
          _firstChild(numPr, 'ilvl')?.getAttribute('w:val') ??
              _firstChild(numPr, 'ilvl')?.getAttribute('val') ??
              '',
        ) ??
        0;
    final format = numId == null
        ? null
        : numbering[numId]?.formatsByLevel[level] ??
              numbering[numId]?.formatsByLevel[0];
    return _DocxListInfo(
      level: level,
      isOrdered: format == null ? true : format != 'bullet',
    );
  }

  String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  String _stripHtml(String value) {
    return value
        .replaceAllMapped(
          RegExp(
            r'<\s*table\b[^>]*>.*?</\s*table\s*>',
            caseSensitive: false,
            dotAll: true,
          ),
          (match) => '\n${_extractHtmlTableText(match.group(0) ?? '')}\n',
        )
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</\s*(p|div|h[1-6]|li|tr)\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _extractHtmlTableText(String table) {
    final rows =
        RegExp(
              r'<\s*tr\b[^>]*>(.*?)</\s*tr\s*>',
              caseSensitive: false,
              dotAll: true,
            )
            .allMatches(table)
            .map((rowMatch) {
              final rowHtml = rowMatch.group(1) ?? '';
              return RegExp(
                    r'<\s*(td|th)\b[^>]*>(.*?)</\s*\1\s*>',
                    caseSensitive: false,
                    dotAll: true,
                  )
                  .allMatches(rowHtml)
                  .map((cellMatch) => _stripHtml(cellMatch.group(2) ?? ''))
                  .toList();
            })
            .where((row) => row.any((cell) => cell.trim().isNotEmpty))
            .toList();
    return _rowsToMarkdownTable(rows);
  }

  String _stripRtf(String value) {
    return value
        .replaceAll(RegExp(r'\\par[d]?'), '\n')
        .replaceAll(RegExp(r'\\tab'), '\t')
        .replaceAll(RegExp(r"\\'[0-9a-fA-F]{2}"), '')
        .replaceAll(RegExp(r'\\[a-zA-Z]+\d* ?'), '')
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _csvToReadableText(String value) {
    final rows = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_parseCsvLine)
        .toList();
    return _rowsToMarkdownTable(rows);
  }

  List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var quoted = false;

    for (var index = 0; index < line.length; index += 1) {
      final char = line[index];
      if (char == '"') {
        final isEscapedQuote =
            quoted && index + 1 < line.length && line[index + 1] == '"';
        if (isEscapedQuote) {
          buffer.write('"');
          index += 1;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        cells.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    cells.add(buffer.toString().trim());
    return cells;
  }

  String _rowsToMarkdownTable(List<List<String>> rows) {
    if (rows.isEmpty) {
      return '';
    }

    final columnCount = rows.fold<int>(
      0,
      (count, row) => math.max(count, row.length),
    );
    if (columnCount == 0) {
      return '';
    }

    final normalizedRows = rows
        .map(
          (row) => List<String>.generate(
            columnCount,
            (index) =>
                index < row.length ? _escapeMarkdownTableCell(row[index]) : '',
          ),
        )
        .toList();
    final header = normalizedRows.first;
    final bodyRows = normalizedRows.length == 1
        ? <List<String>>[List.filled(columnCount, '')]
        : normalizedRows.skip(1);

    return [
      _formatMarkdownTableRow(header),
      _formatMarkdownTableRow(List.filled(columnCount, '---')),
      for (final row in bodyRows) _formatMarkdownTableRow(row),
    ].join('\n');
  }

  String _formatMarkdownTableRow(Iterable<String> cells) {
    return '| ${cells.join(' | ')} |';
  }

  String _escapeMarkdownTableCell(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').replaceAll('|', r'\|').trim();
  }

  String _escapeMarkdownLinkText(String value) {
    return value.replaceAll('[', r'\[').replaceAll(']', r'\]');
  }
}

class _DocxNumberingDef {
  const _DocxNumberingDef({required this.formatsByLevel});

  final Map<int, String> formatsByLevel;
}

class _DocxListInfo {
  const _DocxListInfo({required this.level, required this.isOrdered});

  final int level;
  final bool isOrdered;
}
