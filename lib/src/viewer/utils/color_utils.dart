import 'package:flutter/material.dart';

import '../../engine/reader/docx_reader/models/docx_theme.dart';

/// Parses an OOXML hex color string to a Flutter [Color].
///
/// Returns `null` for `'auto'`, empty strings, or unparseable values.
/// When [themeBackground] is dark, near-black colors are inverted to white
/// so text remains legible in dark-mode viewers.
Color? parseDocxHexColor(String hex, {Color? themeBackground}) {
  if (hex == 'auto' || hex.isEmpty) return null;
  try {
    final clean = hex.replaceAll('#', '').replaceAll('0x', '');
    if (clean.length == 6 || clean.length == 8) {
      final argb = clean.length == 6 ? 'ff$clean' : clean;
      final color = Color(int.parse(argb, radix: 16));
      if (themeBackground != null && themeBackground.computeLuminance() < 0.5) {
        if (color.computeLuminance() < 0.179) return Colors.white;
      }
      return color;
    }
  } catch (_) {}
  return null;
}

/// Resolves a DOCX color from hex, theme color name, tint, and shade values.
///
/// Priority: theme color → direct hex. Tint/shade are applied on top.
/// Returns `null` if no color can be resolved.
Color? resolveDocxColor({
  String? hex,
  String? themeColor,
  String? themeTint,
  String? themeShade,
  DocxTheme? docxTheme,
  Color? themeBackground,
}) {
  Color? baseColor;

  if (themeColor != null && docxTheme != null) {
    final themeHex = docxTheme.colors.getColor(themeColor);
    if (themeHex != null) {
      baseColor = parseDocxHexColor(themeHex, themeBackground: themeBackground);
    }
  }

  if (baseColor == null && hex != null && hex != 'auto') {
    baseColor = parseDocxHexColor(hex, themeBackground: themeBackground);
  }

  if (baseColor == null) return null;

  if (themeTint != null) {
    final tintVal = int.tryParse(themeTint, radix: 16);
    if (tintVal != null) {
      final factor = tintVal / 255.0;
      baseColor = Color.alphaBlend(
        Colors.white.withValues(alpha: 1 - factor),
        baseColor,
      );
    }
  }

  if (themeShade != null) {
    final shadeVal = int.tryParse(themeShade, radix: 16);
    if (shadeVal != null) {
      final factor = shadeVal / 255.0;
      baseColor = Color.alphaBlend(
        Colors.black.withValues(alpha: 1 - factor),
        baseColor,
      );
    }
  }

  return baseColor;
}
