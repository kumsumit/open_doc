import '../../docx/docx.dart';
import '../docx_view_config.dart';
import '../theme/docx_view_theme.dart';
import '../utils/block_index_counter.dart';
import '../utils/color_utils.dart';
import 'package:flutter/material.dart';

import 'paragraph_builder.dart';

/// Builds Flutter widgets from [DocxList] elements.
///
/// Supports [DocxListStyle] and all [DocxNumberFormat] types from docx_creator.
class ListBuilder {
  final DocxViewTheme theme;
  final DocxViewConfig config;
  final ParagraphBuilder paragraphBuilder;
  final DocxTheme? docxTheme;

  /// Default bullet characters for different indent levels when no style specified.
  static const _defaultBullets = ['•', '◦', '▪', '▸', '◦', '▪', '▸', '◦', '▪'];

  ListBuilder({
    required this.theme,
    required this.config,
    required this.paragraphBuilder,
    this.docxTheme,
  });

  /// Build a widget from a [DocxList].
  Widget build(DocxList list, {BlockIndexCounter? counter}) {
    final itemWidgets = <Widget>[];

    // Track numbering per level for nested lists
    final numberingByLevel = <int, int>{};

    for (final item in list.items) {
      final level = item.level;

      // Initialize or increment numbering for this level
      numberingByLevel[level] = (numberingByLevel[level] ?? 0) + 1;

      // Reset numbering for deeper levels when we go back up
      for (var i = level + 1; i <= 8; i++) {
        numberingByLevel.remove(i);
      }

      final widget = _buildListItem(
        item,
        list: list,
        number: numberingByLevel[level]!,
        counter: counter,
      );
      itemWidgets.add(widget);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: itemWidgets,
      ),
    );
  }

  Widget _buildListItem(
    DocxListItem item, {
    required DocxList list,
    required int number,
    BlockIndexCounter? counter,
  }) {
    final level = item.level.clamp(0, 8);
    // Use override style if available, otherwise fall back to list style
    final style = item.overrideStyle ?? list.style;

    // Calculate indent from list style or default
    final indentPerLevel =
        style.indentPerLevel / 15.0; // Convert twips to pixels
    // Calculate initial indent based on level
    double indent = 16.0 + (level * indentPerLevel.clamp(16.0, 48.0));

    // Apply hanging indent if specified
    if (style.hangingIndent > 0) {
      // Hanging indent shifts the first line (marker) left
      // But in this Row layout, 'indent' is the stored left padding.
      // If we increase stored padding to accommodate hanging, we might just shift marker.
      // Standard logic: Indent Left - Hanging Indent.
      // Here we just accept that 'indent' is the start of content.
    }

    // Build content from all inline children with search support
    List<InlineSpan> spans;
    Key? key;
    if (counter != null && paragraphBuilder.searchController != null) {
      final blockIndex = counter.value;
      final matches = paragraphBuilder.searchController!.matches
          .where((m) => m.blockIndex == blockIndex)
          .toList();

      if (matches.isNotEmpty) {
        key = counter.registerKey(blockIndex);
      }
      counter.increment();

      spans =
          paragraphBuilder.buildInlineSpans(item.children, matches: matches);
    } else {
      spans = paragraphBuilder.buildInlineSpans(item.children);
    }

    // ... (rest of method)

    // Apply style properties from DocxListStyle to the marker

    // Resolve theme color for marker
    final markerColor = resolveDocxColor(
      hex: style.color.hex,
      themeColor: style.themeColor,
      themeTint: style.themeTint,
      themeShade: style.themeShade,
      docxTheme: docxTheme,
      themeBackground: theme.backgroundColor,
    );

    // Resolve theme font for marker
    final markerFont = docxTheme != null && style.themeFont != null
        ? docxTheme!.fonts.getFont(style.themeFont!)
        : null;

    final markerStyle = TextStyle(
      color: markerColor,
      fontSize: style.fontSize != null
          ? style.fontSize! * 1.333
          : theme.defaultTextStyle.fontSize,
      fontWeight: style.fontWeight == DocxFontWeight.bold
          ? FontWeight.bold
          : FontWeight.normal,
      fontFamily:
          markerFont ?? style.fontFamily ?? theme.defaultTextStyle.fontFamily,
    );

    // Build marker widget
    Widget markerWidget;
    if (style.imageBulletBytes != null) {
      markerWidget = Image.memory(
        style.imageBulletBytes!,
        width: 12,
        height: 12,
        fit: BoxFit.contain,
      );
    } else {
      String markerText;
      if (list.isOrdered) {
        // For mixed ordered/unordered in one list, this is simplified.
        // Ideally isOrdered should be per level too if complex.
        // But typically the whole list block shares order type or splits.
        // If overrideStyle provides numberFormat.bullet, we should treat as unordered bullet.
        if (style.numberFormat == DocxNumberFormat.bullet) {
          markerText = _getBulletMarker(level, style);
        } else {
          markerText = _getOrderedMarker(number, level, style.numberFormat);
        }
      } else {
        markerText = _getBulletMarker(level, style);
      }
      markerWidget = Text(markerText, style: markerStyle);
    }

    return Padding(
      key: key,
      padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: markerWidget,
          ),
          Expanded(
            child: config.enableSelection
                ? SelectableText.rich(TextSpan(children: spans))
                : RichText(text: TextSpan(children: spans)),
          ),
        ],
      ),
    );
  }

  /// Get bullet marker based on level and style.
  String _getBulletMarker(int level, DocxListStyle style) {
    // If style has a custom bullet, use it
    if (style.bullet.isNotEmpty && style.bullet != '•') {
      return style.bullet;
    }
    // Otherwise use level-based default bullets
    return _defaultBullets[level];
  }

  /// Get ordered marker based on number format.
  String _getOrderedMarker(int number, int level, DocxNumberFormat format) {
    switch (format) {
      case DocxNumberFormat.decimal:
        return '$number.';
      case DocxNumberFormat.lowerAlpha:
        return '${_toLowerAlpha(number)}.';
      case DocxNumberFormat.upperAlpha:
        return '${_toUpperAlpha(number)}.';
      case DocxNumberFormat.lowerRoman:
        return '${_toRoman(number).toLowerCase()}.';
      case DocxNumberFormat.upperRoman:
        return '${_toRoman(number)}.';
      case DocxNumberFormat.bullet:
        return _defaultBullets[level];
    }
  }

  String _toLowerAlpha(int n) {
    if (n <= 0) return '';
    final code = ((n - 1) % 26) + 97; // 'a' = 97
    return String.fromCharCode(code);
  }

  String _toUpperAlpha(int n) {
    if (n <= 0) return '';
    final code = ((n - 1) % 26) + 65; // 'A' = 65
    return String.fromCharCode(code);
  }

  String _toRoman(int n) {
    if (n <= 0 || n > 3999) return n.toString();
    const romanNumerals = [
      ['M', 1000],
      ['CM', 900],
      ['D', 500],
      ['CD', 400],
      ['C', 100],
      ['XC', 90],
      ['L', 50],
      ['XL', 40],
      ['X', 10],
      ['IX', 9],
      ['V', 5],
      ['IV', 4],
      ['I', 1],
    ];
    final buffer = StringBuffer();
    int remaining = n;
    for (final entry in romanNumerals) {
      final numeral = entry[0] as String;
      final value = entry[1] as int;
      while (remaining >= value) {
        buffer.write(numeral);
        remaining -= value;
      }
    }
    return buffer.toString();
  }

}
