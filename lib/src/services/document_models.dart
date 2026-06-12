import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../engine/docx.dart' as docx;

enum DocumentEditMode {
  openXml('Word-like OpenXML editor', Icons.edit_document),
  wysiwyg('Rich text editor', Icons.edit_document),
  docxVisual('DOCX visual editor', Icons.dashboard_customize_outlined),
  docxRoundTrip('DOCX round-trip', Icons.description_outlined),
  docxView('DOCX viewer', Icons.visibility_outlined);

  const DocumentEditMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum OoxmlVisualBlockType { paragraph, table, partText }

enum OoxmlTextAlign { left, center, right, justify }

enum OpenXmlBlockType { paragraph, table, reviewMarker, bibliography }

enum OpenXmlTextStyle {
  normal('Normal', null),
  title('Title', 'Title'),
  subtitle('Subtitle', 'Subtitle'),
  heading1('Heading 1', 'Heading1'),
  heading2('Heading 2', 'Heading2'),
  heading3('Heading 3', 'Heading3'),
  heading4('Heading 4', 'Heading4'),
  heading5('Heading 5', 'Heading5'),
  heading6('Heading 6', 'Heading6'),
  quote('Quote', 'Quote'),
  code('Code', 'Code'),
  caption('Caption', 'Caption');

  const OpenXmlTextStyle(this.label, this.styleId);

  final String label;
  final String? styleId;
}

class OpenXmlDocument {
  const OpenXmlDocument({
    required this.blocks,
    this.sourcePackageFormat,
    this.sourcePackageBytes,
  });

  factory OpenXmlDocument.plain(String text) {
    final blocks = _openXmlBlocksFromReadableText(text);
    return OpenXmlDocument(
      blocks: blocks.isEmpty
          ? const [
              OpenXmlParagraphBlock(runs: [OpenXmlRun('')]),
            ]
          : blocks,
    );
  }

  factory OpenXmlDocument.fromJson(Map<String, Object?> json) {
    final rawBlocks = json['blocks'];
    return OpenXmlDocument(
      blocks: rawBlocks is List
          ? rawBlocks
                .whereType<Map<String, Object?>>()
                .map(OpenXmlBlockFactory.fromJson)
                .whereType<OpenXmlBlock>()
                .toList()
          : OpenXmlDocument.plain('').blocks,
      sourcePackageFormat: json['sourcePackageFormat'] is String
          ? json['sourcePackageFormat'] as String
          : null,
      sourcePackageBytes: _decodeOpenXmlBase64(json['sourcePackageBase64']),
    );
  }

  final List<OpenXmlBlock> blocks;
  final String? sourcePackageFormat;
  final Uint8List? sourcePackageBytes;

  String get plainText {
    return blocks.map((block) => block.plainText).join('\n\n').trimRight();
  }

  List<docx.DocxNode> toDocxNodes() {
    return blocks.map((block) => block.toDocxNode()).toList();
  }

  OpenXmlDocument copyWith({
    List<OpenXmlBlock>? blocks,
    String? sourcePackageFormat,
    Uint8List? sourcePackageBytes,
  }) {
    return OpenXmlDocument(
      blocks: blocks ?? this.blocks,
      sourcePackageFormat: sourcePackageFormat ?? this.sourcePackageFormat,
      sourcePackageBytes: sourcePackageBytes ?? this.sourcePackageBytes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': 1,
      'blocks': [for (final block in blocks) block.toJson()],
      if (sourcePackageFormat != null)
        'sourcePackageFormat': sourcePackageFormat,
      if (sourcePackageBytes != null)
        'sourcePackageBase64': base64Encode(sourcePackageBytes!),
    };
  }
}

class OpenXmlBlockFactory {
  const OpenXmlBlockFactory._();

  static OpenXmlBlock? fromJson(Map<String, Object?> json) {
    return switch (json['type']) {
      'paragraph' => OpenXmlParagraphBlock(
        style: _enumByName(
          OpenXmlTextStyle.values,
          json['style'],
          OpenXmlTextStyle.normal,
        ),
        align: _enumByName(
          OoxmlTextAlign.values,
          json['align'],
          OoxmlTextAlign.left,
        ),
        pageBreakBefore: json['pageBreakBefore'] == true,
        runs: _openXmlRunsFromJson(json['runs']),
      ),
      'table' => OpenXmlTableBlock(
        rows: _openXmlRowsFromJson(json['rows']),
        hasHeader: json['hasHeader'] != false,
        columnWidths: _intListFromJson(json['columnWidths']),
        rowHeights: _intListFromJson(json['rowHeights']),
      ),
      _ => null,
    };
  }
}

abstract class OpenXmlBlock {
  const OpenXmlBlock(this.type);

  final OpenXmlBlockType type;

  String get plainText;

  docx.DocxNode toDocxNode();

  Map<String, Object?> toJson();
}

class OpenXmlRun {
  const OpenXmlRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.superscript = false,
    this.subscript = false,
    this.smallCaps = false,
    this.allCaps = false,
    this.doubleUnderline = false,
    this.doubleStrike = false,
    this.hidden = false,
    this.colorHex,
    this.highlightHex,
    this.letterSpacing,
    this.href,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool superscript;
  final bool subscript;
  final bool smallCaps;
  final bool allCaps;
  final bool doubleUnderline;
  final bool doubleStrike;
  final bool hidden;
  final String? colorHex;
  final String? highlightHex;
  final double? letterSpacing;
  final String? href;

  docx.DocxText toDocxText() {
    return docx.DocxText(
      text,
      fontWeight: bold ? docx.DocxFontWeight.bold : docx.DocxFontWeight.normal,
      fontStyle: italic ? docx.DocxFontStyle.italic : docx.DocxFontStyle.normal,
      decorations: [
        if (underline || doubleUnderline) docx.DocxTextDecoration.underline,
        if (strike || doubleStrike) docx.DocxTextDecoration.strikethrough,
      ],
      isSuperscript: superscript,
      isSubscript: subscript,
      isSmallCaps: smallCaps,
      isAllCaps: allCaps,
      isDoubleStrike: doubleStrike,
      characterSpacing: letterSpacing,
      color: colorHex == null ? null : docx.DocxColor(colorHex!),
      shadingFill: highlightHex,
      href: href,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'text': text,
      if (bold) 'bold': true,
      if (italic) 'italic': true,
      if (underline) 'underline': true,
      if (strike) 'strike': true,
      if (superscript) 'superscript': true,
      if (subscript) 'subscript': true,
      if (smallCaps) 'smallCaps': true,
      if (allCaps) 'allCaps': true,
      if (doubleUnderline) 'doubleUnderline': true,
      if (doubleStrike) 'doubleStrike': true,
      if (hidden) 'hidden': true,
      if (colorHex != null) 'colorHex': colorHex,
      if (highlightHex != null) 'highlightHex': highlightHex,
      if (letterSpacing != null) 'letterSpacing': letterSpacing,
      if (href != null) 'href': href,
    };
  }
}

class OpenXmlParagraphBlock extends OpenXmlBlock {
  const OpenXmlParagraphBlock({
    required this.runs,
    this.style = OpenXmlTextStyle.normal,
    this.align = OoxmlTextAlign.left,
    this.pageBreakBefore = false,
    this.indentLeft = 0,
    this.hangingIndent = 0,
    this.keepWithNext = false,
    this.widowOrphanControl = true,
  }) : super(OpenXmlBlockType.paragraph);

  final List<OpenXmlRun> runs;
  final OpenXmlTextStyle style;
  final OoxmlTextAlign align;
  final bool pageBreakBefore;
  /// Left indent in twips (720 = 0.5 inch, matching Word's Tab key increment).
  final int indentLeft;
  /// Hanging indent in twips (first line pulled left by this amount).
  final int hangingIndent;
  /// Keep this paragraph on the same page as the next.
  final bool keepWithNext;
  /// Prevent orphaned/widowed lines at page breaks.
  final bool widowOrphanControl;

  OpenXmlParagraphBlock copyWith({
    List<OpenXmlRun>? runs,
    OpenXmlTextStyle? style,
    OoxmlTextAlign? align,
    bool? pageBreakBefore,
    int? indentLeft,
    int? hangingIndent,
    bool? keepWithNext,
    bool? widowOrphanControl,
  }) {
    return OpenXmlParagraphBlock(
      runs: runs ?? this.runs,
      style: style ?? this.style,
      align: align ?? this.align,
      pageBreakBefore: pageBreakBefore ?? this.pageBreakBefore,
      indentLeft: indentLeft ?? this.indentLeft,
      hangingIndent: hangingIndent ?? this.hangingIndent,
      keepWithNext: keepWithNext ?? this.keepWithNext,
      widowOrphanControl: widowOrphanControl ?? this.widowOrphanControl,
    );
  }

  @override
  String get plainText => runs.map((run) => run.text).join();

  @override
  docx.DocxNode toDocxNode() {
    return docx.DocxParagraph(
      styleId: style.styleId,
      align: switch (align) {
        OoxmlTextAlign.center => docx.DocxAlign.center,
        OoxmlTextAlign.right => docx.DocxAlign.right,
        OoxmlTextAlign.justify => docx.DocxAlign.justify,
        OoxmlTextAlign.left => docx.DocxAlign.left,
      },
      pageBreakBefore: pageBreakBefore,
      indentLeft: indentLeft > 0
          ? indentLeft
          : (style == OpenXmlTextStyle.quote ? 720 : null),
      indentFirstLine: hangingIndent > 0 ? -hangingIndent : null,
      children: [for (final run in runs) run.toDocxText()],
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'style': style.name,
      'align': align.name,
      'pageBreakBefore': pageBreakBefore,
      if (indentLeft > 0) 'indentLeft': indentLeft,
      'runs': [for (final run in runs) run.toJson()],
    };
  }
}

class OpenXmlTableBlock extends OpenXmlBlock {
  const OpenXmlTableBlock({
    required this.rows,
    this.hasHeader = true,
    this.columnWidths = const [],
    this.rowHeights = const [],
  }) : super(OpenXmlBlockType.table);

  final List<List<String>> rows;
  final bool hasHeader;
  final List<int> columnWidths;
  final List<int> rowHeights;

  OpenXmlTableBlock copyWith({
    List<List<String>>? rows,
    bool? hasHeader,
    List<int>? columnWidths,
    List<int>? rowHeights,
  }) {
    return OpenXmlTableBlock(
      rows: rows ?? this.rows,
      hasHeader: hasHeader ?? this.hasHeader,
      columnWidths: columnWidths ?? this.columnWidths,
      rowHeights: rowHeights ?? this.rowHeights,
    );
  }

  @override
  String get plainText => rows.map((row) => row.join('\t')).join('\n');

  @override
  docx.DocxNode toDocxNode() {
    return docx.DocxTable(
      hasHeader: hasHeader,
      gridColumns: columnWidths.isEmpty ? null : columnWidths,
      rows: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1)
          docx.DocxTableRow(
            height: rowIndex < rowHeights.length && rowHeights[rowIndex] > 0
                ? rowHeights[rowIndex]
                : null,
            cells: [
              for (
                var columnIndex = 0;
                columnIndex < rows[rowIndex].length;
                columnIndex += 1
              )
                docx.DocxTableCell.text(
                  rows[rowIndex][columnIndex],
                  isBold: hasHeader && rowIndex == 0,
                  shadingFill: hasHeader && rowIndex == 0 ? 'DBEAFE' : null,
                ).copyWith(
                  width: columnIndex < columnWidths.length
                      ? columnWidths[columnIndex]
                      : null,
                ),
            ],
          ),
      ],
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'rows': rows,
      'hasHeader': hasHeader,
      if (columnWidths.isNotEmpty) 'columnWidths': columnWidths,
      if (rowHeights.isNotEmpty) 'rowHeights': rowHeights,
    };
  }
}

OpenXmlTextStyle _styleFromPlainText(String text) {
  if (text.length <= 80 && !text.contains('.')) {
    return OpenXmlTextStyle.heading1;
  }
  return OpenXmlTextStyle.normal;
}

List<OpenXmlBlock> _openXmlBlocksFromReadableText(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final blocks = <OpenXmlBlock>[];
  final paragraph = StringBuffer();

  void flushParagraph() {
    final value = paragraph.toString().trim();
    if (value.isNotEmpty) {
      blocks.add(
        OpenXmlParagraphBlock(
          runs: [OpenXmlRun(_cleanInlineMarkdown(value))],
          style: _styleFromPlainText(value),
        ),
      );
    }
    paragraph.clear();
  }

  var index = 0;
  while (index < lines.length) {
    final rawLine = lines[index].trimRight();
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      flushParagraph();
      index += 1;
      continue;
    }

    if (_looksLikeMarkdownTableStart(lines, index)) {
      flushParagraph();
      final tableLines = <String>[];
      while (index < lines.length && _isMarkdownTableLine(lines[index])) {
        tableLines.add(lines[index].trim());
        index += 1;
      }
      final rows = _openXmlRowsFromMarkdownTable(tableLines);
      if (rows.isNotEmpty) {
        blocks.add(OpenXmlTableBlock(rows: rows));
      }
      continue;
    }

    final specialBlock = _openXmlSpecialBlockFromLine(trimmed);
    if (specialBlock != null) {
      flushParagraph();
      blocks.add(specialBlock);
      index += 1;
      continue;
    }

    final heading = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      blocks.add(
        OpenXmlParagraphBlock(
          runs: [OpenXmlRun(_cleanInlineMarkdown(heading.group(2) ?? ''))],
          style: switch ((heading.group(1) ?? '').length) {
            1 => OpenXmlTextStyle.title,
            2 => OpenXmlTextStyle.heading1,
            3 => OpenXmlTextStyle.heading2,
            4 => OpenXmlTextStyle.heading3,
            5 => OpenXmlTextStyle.heading4,
            _ => OpenXmlTextStyle.heading5,
          },
        ),
      );
      index += 1;
      continue;
    }

    final checklist = RegExp(r'^[-*]\s+\[[ xX]\]\s+(.+)$').firstMatch(trimmed);
    if (checklist != null) {
      flushParagraph();
      blocks.add(
        OpenXmlParagraphBlock(
          runs: [OpenXmlRun(_cleanInlineMarkdown(checklist.group(1) ?? ''))],
        ),
      );
      index += 1;
      continue;
    }

    final bullet = RegExp(r'^[-*]\s+(.+)$').firstMatch(trimmed);
    if (bullet != null) {
      flushParagraph();
      blocks.add(
        OpenXmlParagraphBlock(
          runs: [OpenXmlRun(_cleanInlineMarkdown(bullet.group(1) ?? ''))],
        ),
      );
      index += 1;
      continue;
    }

    final ordered = RegExp(r'^\d+\.\s+(.+)$').firstMatch(trimmed);
    if (ordered != null) {
      flushParagraph();
      blocks.add(
        OpenXmlParagraphBlock(
          runs: [OpenXmlRun(_cleanInlineMarkdown(ordered.group(1) ?? ''))],
        ),
      );
      index += 1;
      continue;
    }

    final quote = RegExp(r'^>\s+(.+)$').firstMatch(trimmed);
    if (quote != null) {
      flushParagraph();
      blocks.add(
        OpenXmlParagraphBlock(
          runs: [OpenXmlRun(_cleanInlineMarkdown(quote.group(1) ?? ''))],
          style: OpenXmlTextStyle.quote,
        ),
      );
      index += 1;
      continue;
    }

    if (paragraph.isNotEmpty) {
      paragraph.write(' ');
    }
    paragraph.write(trimmed);
    index += 1;
  }

  flushParagraph();
  return blocks;
}

OpenXmlBlock? _openXmlSpecialBlockFromLine(String line) {
  if (line == '[[TOC]]') {
    return const OpenXmlParagraphBlock(
      runs: [OpenXmlRun('Table of contents')],
      style: OpenXmlTextStyle.heading1,
    );
  }
  if (line == '[[PAGE_BREAK]]') {
    return const OpenXmlParagraphBlock(
      runs: [OpenXmlRun('')],
      pageBreakBefore: true,
    );
  }
  if (line == '[[HR]]') {
    return const OpenXmlParagraphBlock(runs: [OpenXmlRun('')]);
  }
  final tagged = RegExp(r'^\[\[([A-Z_]+):(.+)\]\]$').firstMatch(line);
  if (tagged == null) {
    return null;
  }
  final tag = tagged.group(1) ?? '';
  final body = tagged.group(2) ?? '';
  return switch (tag) {
    'SUBTITLE' => OpenXmlParagraphBlock(
      runs: [OpenXmlRun(body)],
      style: OpenXmlTextStyle.subtitle,
    ),
    'CAPTION' => OpenXmlParagraphBlock(
      runs: [OpenXmlRun(body)],
      style: OpenXmlTextStyle.caption,
    ),
    'FOOTNOTE' => OpenXmlParagraphBlock(
      runs: [OpenXmlRun('Footnote: $body')],
      style: OpenXmlTextStyle.caption,
    ),
    'ENDNOTE' => OpenXmlParagraphBlock(
      runs: [OpenXmlRun('Endnote: $body')],
      style: OpenXmlTextStyle.caption,
    ),
    'DROP_CAP' => OpenXmlParagraphBlock(runs: [OpenXmlRun(body)]),
    'LINK' => _openXmlLinkBlock(body),
    'CITATION' => OpenXmlParagraphBlock(
      runs: [OpenXmlRun(body.replaceAll('|', ': '))],
      style: OpenXmlTextStyle.caption,
    ),
    'SHAPE' => OpenXmlParagraphBlock(
      runs: [OpenXmlRun('Shape: ${body.split(':').last}')],
      style: OpenXmlTextStyle.caption,
    ),
    _ => null,
  };
}

OpenXmlParagraphBlock _openXmlLinkBlock(String body) {
  final parts = body.split('|');
  final label = parts.isEmpty ? body : parts.first;
  final href = parts.length > 1 ? parts.sublist(1).join('|') : null;
  return OpenXmlParagraphBlock(runs: [OpenXmlRun(label, href: href)]);
}

bool _looksLikeMarkdownTableStart(List<String> lines, int index) {
  if (index + 1 >= lines.length) {
    return false;
  }
  return _isMarkdownTableLine(lines[index]) &&
      RegExp(r'^\s*\|?[\s:\-|]+\|[\s:\-|]*$').hasMatch(lines[index + 1]);
}

bool _isMarkdownTableLine(String line) {
  final trimmed = line.trim();
  return trimmed.contains('|') && trimmed.replaceAll('|', '').trim().isNotEmpty;
}

List<List<String>> _openXmlRowsFromMarkdownTable(List<String> lines) {
  final rows = <List<String>>[];
  for (var index = 0; index < lines.length; index += 1) {
    if (index == 1 &&
        RegExp(r'^\s*\|?[\s:\-|]+\|[\s:\-|]*$').hasMatch(lines[index])) {
      continue;
    }
    final cells = lines[index]
        .trim()
        .replaceFirst(RegExp(r'^\|'), '')
        .replaceFirst(RegExp(r'\|$'), '')
        .split('|')
        .map((cell) => _cleanInlineMarkdown(cell.trim()))
        .toList();
    if (cells.isNotEmpty) {
      rows.add(cells);
    }
  }
  return rows;
}

String _cleanInlineMarkdown(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'\*\*(.*?)\*\*|__(.*?)__'),
        (match) => match.group(1) ?? match.group(2) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'\*(.*?)\*|_(.*?)_'),
        (match) => match.group(1) ?? match.group(2) ?? '',
      )
      .replaceAllMapped(RegExp(r'~~(.*?)~~'), (match) => match.group(1) ?? '')
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1) ?? '')
      .replaceAll('<u>', '')
      .replaceAll('</u>', '')
      .trim();
}

List<OpenXmlRun> _openXmlRunsFromJson(Object? value) {
  if (value is! List) {
    return const [OpenXmlRun('')];
  }
  return [
    for (final item in value)
      if (item is Map<String, Object?>)
        OpenXmlRun(
          item['text'] is String ? item['text'] as String : '',
          bold: item['bold'] == true,
          italic: item['italic'] == true,
          underline: item['underline'] == true,
          strike: item['strike'] == true,
          colorHex: item['colorHex'] is String
              ? _normalizeOpenXmlColor(item['colorHex'] as String)
              : null,
          href: item['href'] is String ? item['href'] as String : null,
        ),
  ];
}

String? _normalizeOpenXmlColor(String value) {
  final cleaned = value
      .trim()
      .replaceFirst('#', '')
      .replaceFirst('0x', '')
      .toUpperCase();
  return RegExp(r'^[0-9A-F]{6}$').hasMatch(cleaned) ? cleaned : null;
}

List<List<String>> _openXmlRowsFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final row in value)
      if (row is List)
        [for (final cell in row) cell is String ? cell : cell.toString()],
  ];
}

Uint8List? _decodeOpenXmlBase64(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  try {
    return base64Decode(value);
  } on Object {
    return null;
  }
}

enum WysiwygBlockType {
  title('Title'),
  subtitle('Subtitle'),
  heading1('Heading 1'),
  heading2('Heading 2'),
  heading3('Heading 3'),
  heading4('Heading 4'),
  heading5('Heading 5'),
  heading6('Heading 6'),
  paragraph('Paragraph'),
  quote('Quote'),
  code('Code'),
  caption('Caption'),
  bulletList('Bullet'),
  orderedList('Numbered'),
  checklist('Checklist');

  const WysiwygBlockType(this.label);

  final String label;
}

class WysiwygBlock {
  const WysiwygBlock({
    required this.id,
    required this.type,
    required this.text,
    this.checked = false,
  });

  factory WysiwygBlock.fromJson(Map<String, Object?> json) {
    return WysiwygBlock(
      id: json['id'] is String ? json['id'] as String : _newWysiwygBlockId(),
      type: _enumByName(
        WysiwygBlockType.values,
        json['type'],
        WysiwygBlockType.paragraph,
      ),
      text: json['text'] is String ? json['text'] as String : '',
      checked: json['checked'] == true,
    );
  }

  final String id;
  final WysiwygBlockType type;
  final String text;
  final bool checked;

  WysiwygBlock copyWith({WysiwygBlockType? type, String? text, bool? checked}) {
    return WysiwygBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      checked: checked ?? this.checked,
    );
  }

  Map<String, Object?> toJson() {
    return {'id': id, 'type': type.name, 'text': text, 'checked': checked};
  }
}

class WysiwygDocumentCodec {
  const WysiwygDocumentCodec._();

  static List<WysiwygBlock> fromMarkdown(String markdown) {
    final lines = markdown.split('\n');
    final blocks = <WysiwygBlock>[];
    final paragraph = StringBuffer();

    void flushParagraph() {
      final text = paragraph.toString().trim();
      if (text.isNotEmpty) {
        blocks.add(_block(WysiwygBlockType.paragraph, text));
      }
      paragraph.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('# ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.title, trimmed.substring(2)));
      } else if (trimmed.startsWith('## ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.heading1, trimmed.substring(3)));
      } else if (trimmed.startsWith('### ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.heading2, trimmed.substring(4)));
      } else if (trimmed.startsWith('#### ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.heading3, trimmed.substring(5)));
      } else if (trimmed.startsWith('##### ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.heading4, trimmed.substring(6)));
      } else if (trimmed.startsWith('###### ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.heading5, trimmed.substring(7)));
      } else if (trimmed.startsWith('[[SUBTITLE:') && trimmed.endsWith(']]')) {
        flushParagraph();
        blocks.add(
          _block(
            WysiwygBlockType.subtitle,
            trimmed.substring(11, trimmed.length - 2),
          ),
        );
      } else if (trimmed.startsWith('[[CAPTION:') && trimmed.endsWith(']]')) {
        flushParagraph();
        blocks.add(
          _block(
            WysiwygBlockType.caption,
            trimmed.substring(10, trimmed.length - 2),
          ),
        );
      } else if (trimmed.startsWith('```')) {
        flushParagraph();
        blocks.add(
          _block(WysiwygBlockType.code, trimmed.replaceAll('`', '').trim()),
        );
      } else if (trimmed.startsWith('> ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.quote, trimmed.substring(2)));
      } else if (trimmed.startsWith('- [x] ') ||
          trimmed.startsWith('* [x] ') ||
          trimmed.startsWith('- [ ] ') ||
          trimmed.startsWith('* [ ] ')) {
        flushParagraph();
        blocks.add(
          _block(
            WysiwygBlockType.checklist,
            trimmed.substring(6),
            checked: trimmed.substring(2, 5).toLowerCase() == '[x]',
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.bulletList, trimmed.substring(2)));
      } else {
        final ordered = RegExp(r'^\d+\.\s+').firstMatch(trimmed);
        if (ordered != null) {
          flushParagraph();
          blocks.add(
            _block(
              WysiwygBlockType.orderedList,
              trimmed.substring(ordered.end),
            ),
          );
        } else {
          if (paragraph.isNotEmpty) {
            paragraph.write(' ');
          }
          paragraph.write(trimmed);
        }
      }
    }
    flushParagraph();
    return blocks.isEmpty ? [_block(WysiwygBlockType.paragraph, '')] : blocks;
  }

  static String toMarkdown(List<WysiwygBlock> blocks) {
    final orderedIndex = <int>[1];
    return blocks
        .map((block) {
          final text = block.text.trimRight();
          return switch (block.type) {
            WysiwygBlockType.title => '# $text',
            WysiwygBlockType.subtitle => '[[SUBTITLE:$text]]',
            WysiwygBlockType.heading1 => '## $text',
            WysiwygBlockType.heading2 => '### $text',
            WysiwygBlockType.heading3 => '#### $text',
            WysiwygBlockType.heading4 => '##### $text',
            WysiwygBlockType.heading5 => '###### $text',
            WysiwygBlockType.heading6 => '###### $text',
            WysiwygBlockType.quote => '> $text',
            WysiwygBlockType.code => '```\n$text\n```',
            WysiwygBlockType.caption => '[[CAPTION:$text]]',
            WysiwygBlockType.bulletList => '- $text',
            WysiwygBlockType.orderedList => '${orderedIndex[0]++}. $text',
            WysiwygBlockType.checklist =>
              '- [${block.checked ? 'x' : ' '}] $text',
            WysiwygBlockType.paragraph => text,
          };
        })
        .join('\n\n');
  }

  static List<Object?> toQuillDeltaJson(List<WysiwygBlock> blocks) {
    final ops = <Object?>[];
    for (final block in blocks) {
      final text = block.text.isEmpty ? ' ' : block.text;
      ops.add({'insert': text});
      final attrs = <String, Object?>{};
      switch (block.type) {
        case WysiwygBlockType.title:
          attrs['header'] = 1;
        case WysiwygBlockType.subtitle:
          attrs['subtitle'] = true;
        case WysiwygBlockType.heading1:
          attrs['header'] = 2;
        case WysiwygBlockType.heading2:
          attrs['header'] = 3;
        case WysiwygBlockType.heading3:
          attrs['header'] = 4;
        case WysiwygBlockType.heading4:
          attrs['header'] = 5;
        case WysiwygBlockType.heading5:
        case WysiwygBlockType.heading6:
          attrs['header'] = 6;
        case WysiwygBlockType.quote:
          attrs['blockquote'] = true;
        case WysiwygBlockType.code:
          attrs['code-block'] = true;
        case WysiwygBlockType.caption:
          attrs['caption'] = true;
        case WysiwygBlockType.bulletList:
          attrs['list'] = 'bullet';
        case WysiwygBlockType.orderedList:
          attrs['list'] = 'ordered';
        case WysiwygBlockType.checklist:
          attrs['list'] = block.checked ? 'checked' : 'unchecked';
        case WysiwygBlockType.paragraph:
          break;
      }
      ops.add(
        attrs.isEmpty
            ? {'insert': '\n'}
            : {'insert': '\n', 'attributes': attrs},
      );
    }
    return ops;
  }

  static List<WysiwygBlock> fromQuillDeltaJson(List<Object?> deltaJson) {
    final blocks = <WysiwygBlock>[];
    final buffer = StringBuffer();
    Map<String, Object?> lineAttributes = const {};

    void flush() {
      final text = buffer.toString();
      buffer.clear();
      if (text.isEmpty && lineAttributes.isEmpty) {
        return;
      }
      blocks.add(
        _block(
          _typeFromQuillAttributes(lineAttributes),
          text.trimRight(),
          checked: lineAttributes['list'] == 'checked',
        ),
      );
      lineAttributes = const {};
    }

    for (final rawOp in deltaJson) {
      if (rawOp is! Map) {
        continue;
      }
      final attributes = rawOp['attributes'];
      if (attributes is Map) {
        lineAttributes = attributes.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      final insert = rawOp['insert'];
      if (insert is! String) {
        continue;
      }
      final parts = insert.split('\n');
      for (var index = 0; index < parts.length; index += 1) {
        if (index > 0) {
          flush();
        }
        buffer.write(parts[index]);
      }
    }
    flush();
    return blocks.isEmpty ? [_block(WysiwygBlockType.paragraph, '')] : blocks;
  }

  static WysiwygBlock _block(
    WysiwygBlockType type,
    String text, {
    bool checked = false,
  }) {
    return WysiwygBlock(
      id: _newWysiwygBlockId(),
      type: type,
      text: text,
      checked: checked,
    );
  }

  static WysiwygBlockType _typeFromQuillAttributes(
    Map<String, Object?> attributes,
  ) {
    if (attributes['header'] == 1) {
      return WysiwygBlockType.title;
    }
    if (attributes['header'] == 2) {
      return WysiwygBlockType.heading1;
    }
    if (attributes['header'] == 3) {
      return WysiwygBlockType.heading2;
    }
    if (attributes['header'] == 4) {
      return WysiwygBlockType.heading3;
    }
    if (attributes['header'] == 5) {
      return WysiwygBlockType.heading4;
    }
    if (attributes['header'] == 6) {
      return WysiwygBlockType.heading5;
    }
    if (attributes['subtitle'] == true) {
      return WysiwygBlockType.subtitle;
    }
    if (attributes['blockquote'] == true) {
      return WysiwygBlockType.quote;
    }
    if (attributes['code-block'] == true) {
      return WysiwygBlockType.code;
    }
    if (attributes['caption'] == true) {
      return WysiwygBlockType.caption;
    }
    return switch (attributes['list']) {
      'bullet' => WysiwygBlockType.bulletList,
      'ordered' => WysiwygBlockType.orderedList,
      'checked' || 'unchecked' => WysiwygBlockType.checklist,
      _ => WysiwygBlockType.paragraph,
    };
  }
}

abstract class OoxmlVisualBlock {
  const OoxmlVisualBlock(this.type);

  final OoxmlVisualBlockType type;

  Map<String, Object?> toJson();
}

class OoxmlParagraphBlock extends OoxmlVisualBlock {
  const OoxmlParagraphBlock({
    required this.text,
    this.styleId,
    this.align = OoxmlTextAlign.left,
    this.pageBreakBefore = false,
  }) : super(OoxmlVisualBlockType.paragraph);

  factory OoxmlParagraphBlock.fromJson(Map<String, Object?> json) {
    return OoxmlParagraphBlock(
      text: json['text'] is String ? json['text'] as String : '',
      styleId: json['styleId'] is String ? json['styleId'] as String : null,
      align: _enumByName(
        OoxmlTextAlign.values,
        json['align'],
        OoxmlTextAlign.left,
      ),
      pageBreakBefore: json['pageBreakBefore'] == true,
    );
  }

  final String text;
  final String? styleId;
  final OoxmlTextAlign align;
  final bool pageBreakBefore;

  OoxmlParagraphBlock copyWith({
    String? text,
    String? styleId,
    OoxmlTextAlign? align,
    bool? pageBreakBefore,
  }) {
    return OoxmlParagraphBlock(
      text: text ?? this.text,
      styleId: styleId ?? this.styleId,
      align: align ?? this.align,
      pageBreakBefore: pageBreakBefore ?? this.pageBreakBefore,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'text': text,
      'styleId': styleId,
      'align': align.name,
      'pageBreakBefore': pageBreakBefore,
    };
  }
}

class OoxmlTableBlock extends OoxmlVisualBlock {
  const OoxmlTableBlock({
    required this.rows,
    this.hasHeader = true,
    this.columnWidths = const [],
    this.rowHeights = const [],
  }) : super(OoxmlVisualBlockType.table);

  factory OoxmlTableBlock.fromJson(Map<String, Object?> json) {
    final rawRows = json['rows'];
    return OoxmlTableBlock(
      rows: rawRows is List
          ? rawRows
                .whereType<List>()
                .map(
                  (row) => row
                      .map((cell) => cell is String ? cell : cell.toString())
                      .toList(),
                )
                .toList()
          : const [],
      hasHeader: json['hasHeader'] != false,
      columnWidths: _intListFromJson(json['columnWidths']),
      rowHeights: _intListFromJson(json['rowHeights']),
    );
  }

  final List<List<String>> rows;
  final bool hasHeader;
  final List<int> columnWidths;
  final List<int> rowHeights;

  OoxmlTableBlock copyWith({
    List<List<String>>? rows,
    bool? hasHeader,
    List<int>? columnWidths,
    List<int>? rowHeights,
  }) {
    return OoxmlTableBlock(
      rows: rows ?? this.rows,
      hasHeader: hasHeader ?? this.hasHeader,
      columnWidths: columnWidths ?? this.columnWidths,
      rowHeights: rowHeights ?? this.rowHeights,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'rows': rows,
      'hasHeader': hasHeader,
      if (columnWidths.isNotEmpty) 'columnWidths': columnWidths,
      if (rowHeights.isNotEmpty) 'rowHeights': rowHeights,
    };
  }
}

class OoxmlPartTextBlock extends OoxmlVisualBlock {
  const OoxmlPartTextBlock({
    required this.partPath,
    required this.paragraphIndex,
    required this.label,
    required this.text,
  }) : super(OoxmlVisualBlockType.partText);

  factory OoxmlPartTextBlock.fromJson(Map<String, Object?> json) {
    return OoxmlPartTextBlock(
      partPath: json['partPath'] is String ? json['partPath'] as String : '',
      paragraphIndex: json['paragraphIndex'] is int
          ? json['paragraphIndex'] as int
          : 0,
      label: json['label'] is String ? json['label'] as String : 'OOXML part',
      text: json['text'] is String ? json['text'] as String : '',
    );
  }

  final String partPath;
  final int paragraphIndex;
  final String label;
  final String text;

  OoxmlPartTextBlock copyWith({String? text}) {
    return OoxmlPartTextBlock(
      partPath: partPath,
      paragraphIndex: paragraphIndex,
      label: label,
      text: text ?? this.text,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'partPath': partPath,
      'paragraphIndex': paragraphIndex,
      'label': label,
      'text': text,
    };
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) {
    return fallback;
  }
  return values.where((value) => value.name == name).firstOrNull ?? fallback;
}

List<int> _intListFromJson(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final item in value)
      if (item is num) item.round() else if (item is String) int.tryParse(item),
  ].whereType<int>().toList();
}

String _newWysiwygBlockId() => DateTime.now().microsecondsSinceEpoch.toString();

class DocumentVersion {
  const DocumentVersion(
    this.id,
    this.label,
    this.title,
    this.body,
    this.mediaBlocks,
    this.createdAt,
    this.wordCount,
  );

  final String id;
  final String label;
  final String title;
  final String body;
  final List<MediaBlock> mediaBlocks;
  final DateTime createdAt;
  final int wordCount;
}

enum MediaType {
  image('Image', Icons.image_outlined),
  video('Video', Icons.smart_display_outlined);

  const MediaType(this.label, this.icon);

  final String label;
  final IconData icon;

  List<String> get allowedExtensions {
    return switch (this) {
      MediaType.image => const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
      MediaType.video => const ['mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi'],
    };
  }
}

class MediaBlock {
  const MediaBlock({
    required this.id,
    required this.type,
    required this.source,
    required this.caption,
    required this.bytes,
    this.altText = '',
  });

  final String id;
  final MediaType type;
  final String source;
  final String caption;
  final Uint8List? bytes;
  final String altText;

  MediaBlock copyWith({
    String? id,
    MediaType? type,
    String? source,
    String? caption,
    Uint8List? bytes,
    String? altText,
  }) {
    return MediaBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      source: source ?? this.source,
      caption: caption ?? this.caption,
      bytes: bytes ?? this.bytes,
      altText: altText ?? this.altText,
    );
  }
}

class CustomFontFile {
  const CustomFontFile({
    required this.family,
    required this.source,
    required this.bytes,
  });

  final String family;
  final String source;
  final Uint8List bytes;
}

class Collaborator {
  const Collaborator(this.name, this.status, this.color);

  final String name;
  final String status;
  final Color color;
}

class DocumentCommentReply {
  const DocumentCommentReply({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String body;
  final DateTime createdAt;

  DocumentCommentReply copyWith({String? body}) => DocumentCommentReply(
    id: id,
    author: author,
    body: body ?? this.body,
    createdAt: createdAt,
  );
}

class DocumentComment {
  DocumentComment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    List<DocumentCommentReply>? replies,
    this.resolved = false,
  }) : replies = replies ?? [];

  final String id;
  final String author;
  final String body;
  final DateTime createdAt;
  final List<DocumentCommentReply> replies;
  bool resolved;

  DocumentComment copyWith({
    String? body,
    List<DocumentCommentReply>? replies,
    bool? resolved,
  }) {
    return DocumentComment(
      id: id,
      author: author,
      body: body ?? this.body,
      createdAt: createdAt,
      replies: replies ?? List.from(this.replies),
      resolved: resolved ?? this.resolved,
    );
  }
}
