// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart' as docx;
import 'package:docx_creator/src/core/font_manager.dart' as docx_fonts;

import 'document_models.dart';
import 'language_support_service.dart';

enum ExportMediaType {
  image('Image'),
  video('Video');

  const ExportMediaType(this.label);

  final String label;
}

class ExportMediaBlock {
  const ExportMediaBlock({
    required this.type,
    required this.source,
    required this.caption,
    required this.hasBytes,
    this.bytes,
  });

  final ExportMediaType type;
  final String source;
  final String caption;
  final bool hasBytes;
  final Uint8List? bytes;
}

class DocumentExportPayload {
  const DocumentExportPayload({
    required this.title,
    required this.markdown,
    this.mediaBlocks = const [],
    this.customFonts = const [],
    this.selectedFontFamily,
    this.sourcePackageFormat,
    this.sourcePackageBytes,
    this.pageSetup = const DocumentPageSetup(),
  });

  final String title;
  final String markdown;
  final List<ExportMediaBlock> mediaBlocks;
  final List<CustomFontFile> customFonts;
  final String? selectedFontFamily;
  final String? sourcePackageFormat;
  final Uint8List? sourcePackageBytes;
  final DocumentPageSetup pageSetup;
}

enum DocumentPageSize {
  a4('A4'),
  letter('Letter'),
  legal('Legal');

  const DocumentPageSize(this.label);

  final String label;
}

enum DocumentPageOrientation {
  portrait('Portrait'),
  landscape('Landscape');

  const DocumentPageOrientation(this.label);

  final String label;
}

enum DocumentMarginPreset {
  normal('Normal', 1440),
  narrow('Narrow', 720),
  wide('Wide', 2160);

  const DocumentMarginPreset(this.label, this.twips);

  final String label;
  final int twips;
}

class DocumentPageSetup {
  const DocumentPageSetup({
    this.pageSize = DocumentPageSize.a4,
    this.orientation = DocumentPageOrientation.portrait,
    this.marginPreset = DocumentMarginPreset.normal,
  });

  final DocumentPageSize pageSize;
  final DocumentPageOrientation orientation;
  final DocumentMarginPreset marginPreset;

  DocumentPageSetup copyWith({
    DocumentPageSize? pageSize,
    DocumentPageOrientation? orientation,
    DocumentMarginPreset? marginPreset,
  }) {
    return DocumentPageSetup(
      pageSize: pageSize ?? this.pageSize,
      orientation: orientation ?? this.orientation,
      marginPreset: marginPreset ?? this.marginPreset,
    );
  }
}

class DocumentExportService {
  const DocumentExportService();

  static const LanguageSupportService _languageSupport =
      LanguageSupportService();

  Future<docx.DocxBuiltDocument> buildDocument(
    DocumentExportPayload payload,
  ) async {
    final built = await _buildNodes(buildMarkdown(payload));
    final selectedFont = _selectedFont(payload);
    final nodes = selectedFont == null
        ? built.nodes
        : built.nodes.map((node) => _applyFont(node, selectedFont)).toList();
    final footnotes = selectedFont == null
        ? built.footnotes
        : built.footnotes
              .map(
                (note) => note.copyWith(
                  content: note.content
                      .map((block) => _applyFont(block, selectedFont))
                      .whereType<docx.DocxBlock>()
                      .toList(),
                ),
              )
              .toList();
    final endnotes = selectedFont == null
        ? built.endnotes
        : built.endnotes
              .map(
                (note) => note.copyWith(
                  content: note.content
                      .map((block) => _applyFont(block, selectedFont))
                      .whereType<docx.DocxBlock>()
                      .toList(),
                ),
              )
              .toList();
    return docx.DocxBuiltDocument(
      elements: nodes,
      footnotes: footnotes.isEmpty ? null : footnotes,
      endnotes: endnotes.isEmpty ? null : endnotes,
      section: _sectionFor(payload.pageSetup),
      fonts: _embeddedFonts(payload.customFonts),
    );
  }

  void ensureLanguageSupport(DocumentExportPayload payload) {
    _languageSupport.ensureExportable(
      text: buildMarkdown(payload),
      customFonts: payload.customFonts,
      selectedFontFamily: payload.selectedFontFamily,
    );
  }

  docx.DocxSectionDef _sectionFor(DocumentPageSetup setup) {
    final margin = setup.marginPreset.twips;
    return docx.DocxSectionDef(
      pageSize: switch (setup.pageSize) {
        DocumentPageSize.a4 => docx.DocxPageSize.a4,
        DocumentPageSize.letter => docx.DocxPageSize.letter,
        DocumentPageSize.legal => docx.DocxPageSize.legal,
      },
      orientation: setup.orientation == DocumentPageOrientation.landscape
          ? docx.DocxPageOrientation.landscape
          : docx.DocxPageOrientation.portrait,
      marginTop: margin,
      marginBottom: margin,
      marginLeft: margin,
      marginRight: margin,
      header: docx.DocxHeader.styled('Open Doc', bold: true),
      footer: docx.DocxFooter.pageNumbers(),
    );
  }

  Future<_BuiltExportNodes> _buildNodes(String markdown) async {
    final nodes = <docx.DocxNode>[];
    final footnotes = <docx.DocxFootnote>[];
    final endnotes = <docx.DocxEndnote>[];
    final chunk = StringBuffer();

    Future<void> flushChunk() async {
      final text = chunk.toString().trim();
      if (text.isNotEmpty) {
        nodes.addAll(await docx.MarkdownParser.parse(text));
      }
      chunk.clear();
    }

    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trim();
      switch (line) {
        case '[[TOC]]':
          await flushChunk();
          nodes
            ..add(docx.DocxParagraph.heading1('Table of Contents'))
            ..add(
              docx.DocxTableOfContents(
                cachedContent: _cachedTocContent(markdown),
              ),
            );
        case '[[PAGE_BREAK]]':
          await flushChunk();
          nodes.add(const docx.DocxParagraph(pageBreakBefore: true));
        case '[[HR]]':
          await flushChunk();
          nodes.add(
            const docx.DocxParagraph(
              borderBottomSide: docx.DocxBorderSide(
                style: docx.DocxBorder.single,
              ),
            ),
          );
        default:
          final footnoteMatch = RegExp(
            r'^\[\[FOOTNOTE:(.*)\]\]$',
            caseSensitive: false,
          ).firstMatch(line);
          final endnoteMatch = RegExp(
            r'^\[\[ENDNOTE:(.*)\]\]$',
            caseSensitive: false,
          ).firstMatch(line);
          final dropCapMatch = RegExp(
            r'^\[\[DROP_CAP:(.*)\]\]$',
            caseSensitive: false,
          ).firstMatch(line);
          final shapeMatch = RegExp(
            r'^\[\[SHAPE:([^:]+):?(.*)\]\]$',
            caseSensitive: false,
          ).firstMatch(line);
          final advancedTableMatch = RegExp(
            r'^\[\[ADV_TABLE:(.*)\]\]$',
            caseSensitive: false,
          ).firstMatch(line);
          final linkMatch = RegExp(
            r'^\[\[LINK:([^|]+)\|(.+)\]\]$',
            caseSensitive: false,
          ).firstMatch(line);
          if (footnoteMatch != null) {
            await flushChunk();
            final id = footnotes.length + 1;
            final note = footnoteMatch.group(1)?.trim() ?? 'Footnote';
            nodes.add(
              docx.DocxParagraph(
                children: [
                  docx.DocxText('Footnote reference'),
                  docx.DocxFootnoteRef(footnoteId: id),
                ],
              ),
            );
            footnotes.add(
              docx.DocxFootnote(
                footnoteId: id,
                content: [docx.DocxParagraph.text(note)],
              ),
            );
          } else if (endnoteMatch != null) {
            await flushChunk();
            final id = endnotes.length + 1;
            final note = endnoteMatch.group(1)?.trim() ?? 'Endnote';
            nodes.add(
              docx.DocxParagraph(
                children: [
                  docx.DocxText('Endnote reference'),
                  docx.DocxEndnoteRef(endnoteId: id),
                ],
              ),
            );
            endnotes.add(
              docx.DocxEndnote(
                endnoteId: id,
                content: [docx.DocxParagraph.text(note)],
              ),
            );
          } else if (dropCapMatch != null) {
            await flushChunk();
            final text = dropCapMatch.group(1)?.trim() ?? '';
            if (text.isNotEmpty) {
              final runes = text.runes.toList();
              nodes.add(
                docx.DocxDropCap(
                  letter: String.fromCharCode(runes.first),
                  restOfParagraph: [
                    docx.DocxText(String.fromCharCodes(runes.skip(1))),
                  ],
                ),
              );
            }
          } else if (shapeMatch != null) {
            await flushChunk();
            final kind = shapeMatch.group(1)?.trim().toLowerCase() ?? 'rect';
            final label = shapeMatch.group(2)?.trim();
            nodes.add(_shapeFor(kind, label?.isEmpty == true ? null : label));
          } else if (advancedTableMatch != null) {
            await flushChunk();
            nodes.add(_advancedTableFor(advancedTableMatch.group(1) ?? ''));
          } else if (linkMatch != null) {
            await flushChunk();
            final label = linkMatch.group(1)?.trim() ?? 'Link';
            final url = linkMatch.group(2)?.trim() ?? '';
            nodes.add(
              docx.DocxParagraph(
                children: [docx.DocxText.link(label, href: url)],
              ),
            );
          } else {
            chunk.writeln(rawLine);
          }
      }
    }
    await flushChunk();

    return _BuiltExportNodes(
      nodes: nodes,
      footnotes: footnotes,
      endnotes: endnotes,
    );
  }

  docx.DocxShapeBlock _shapeFor(String kind, String? label) {
    final normalized = kind.trim();
    final preset = docx.DocxShapePreset.values
        .where((value) => value.name.toLowerCase() == normalized.toLowerCase())
        .firstOrNull;
    return docx.DocxShapeBlock(
      shape: docx.DocxShape(
        width: 160,
        height: 76,
        preset: preset ?? docx.DocxShapePreset.rect,
        fillColor: docx.DocxColor('#E0F2FE'),
        outlineColor: docx.DocxColor('#0369A1'),
        outlineWidth: 1.2,
        text: label ?? _shapeLabel(preset?.name ?? 'rect'),
      ),
    );
  }

  String _shapeLabel(String value) {
    return value
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .trim();
  }

  docx.DocxTable _advancedTableFor(String spec) {
    final options = _parseOptions(spec);
    final rows = (int.tryParse(options['rows'] ?? '') ?? 4).clamp(1, 12);
    final cols = (int.tryParse(options['cols'] ?? '') ?? 4).clamp(1, 8);
    final mergeHeader = options['mergeHeader'] == 'true';
    final shadeHeader = options['shadeHeader'] != 'false';
    final perCellBorders = options['perCellBorders'] != 'false';
    final borderStyle = _borderStyleFor(options['border'] ?? 'single');
    final border = docx.DocxBorderSide(
      style: borderStyle,
      color: docx.DocxColor(options['borderColor'] ?? '#2563EB'),
      size: int.tryParse(options['borderSize'] ?? '') ?? 8,
    );

    return docx.DocxTable(
      hasHeader: true,
      style: const docx.DocxTableStyle(
        border: docx.DocxBorder.single,
        headerFill: 'DBEAFE',
        evenRowFill: 'F8FAFC',
      ),
      rows: [
        for (var rowIndex = 0; rowIndex < rows; rowIndex += 1)
          docx.DocxTableRow(
            cells: [
              for (
                var colIndex = 0;
                colIndex < (mergeHeader && rowIndex == 0 ? 1 : cols);
                colIndex += 1
              )
                docx.DocxTableCell.text(
                  mergeHeader && rowIndex == 0
                      ? 'Merged header'
                      : rowIndex == 0
                      ? 'Header ${colIndex + 1}'
                      : 'Cell $rowIndex.${colIndex + 1}',
                  isBold: rowIndex == 0,
                  shadingFill: rowIndex == 0 && shadeHeader ? 'DBEAFE' : null,
                ).copyWith(
                  colSpan: mergeHeader && rowIndex == 0 ? cols : 1,
                  borderTop: perCellBorders ? border : null,
                  borderBottom: perCellBorders ? border : null,
                  borderLeft: perCellBorders ? border : null,
                  borderRight: perCellBorders ? border : null,
                ),
            ],
          ),
      ],
    );
  }

  Map<String, String> _parseOptions(String spec) {
    final options = <String, String>{};
    for (final part in spec.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      options[part.substring(0, separator).trim()] = part
          .substring(separator + 1)
          .trim();
    }
    return options;
  }

  docx.DocxBorder _borderStyleFor(String value) {
    return docx.DocxBorder.values
            .where((style) => style.name == value)
            .firstOrNull ??
        docx.DocxBorder.single;
  }

  List<docx.DocxBlock> _cachedTocContent(String markdown) {
    return markdown
        .split('\n')
        .where((line) => RegExp(r'^#{1,3} .+').hasMatch(line.trim()))
        .map((line) {
          final title = line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
          return docx.DocxParagraph.text(title);
        })
        .toList();
  }

  Future<Uint8List> exportDocx(DocumentExportPayload payload) async {
    ensureLanguageSupport(payload);
    final document = await buildDocument(payload);
    return docx.DocxExporter().exportToBytes(document);
  }

  Future<Uint8List> exportPdf(DocumentExportPayload payload) async {
    ensureLanguageSupport(payload);
    final document = await buildDocument(payload);
    final exporter = docx.PdfExporter();
    for (final font in payload.customFonts) {
      exporter.registerFont(font.family, font.bytes);
    }
    return exporter.exportToBytes(document);
  }

  Future<Uint8List> exportHtml(DocumentExportPayload payload) async {
    ensureLanguageSupport(payload);
    final document = await buildDocument(payload);
    final html = docx.HtmlExporter().export(document);
    return Uint8List.fromList(
      utf8.encode(_withEmbeddedHtmlFonts(html, payload)),
    );
  }

  Future<Uint8List> exportOpenDoc(DocumentExportPayload payload) async {
    final data = {
      'format': 'open_doc',
      'version': 1,
      'title': payload.title,
      'markdown': payload.markdown,
      if (payload.selectedFontFamily != null)
        'selectedFontFamily': payload.selectedFontFamily,
      if (payload.sourcePackageFormat != null)
        'sourcePackageFormat': payload.sourcePackageFormat,
      if (payload.sourcePackageBytes != null)
        'sourcePackageBase64': base64Encode(payload.sourcePackageBytes!),
      'pageSetup': {
        'pageSize': payload.pageSetup.pageSize.name,
        'orientation': payload.pageSetup.orientation.name,
        'marginPreset': payload.pageSetup.marginPreset.name,
      },
      'mediaBlocks': [
        for (final block in payload.mediaBlocks)
          {
            'type': block.type.name,
            'source': block.source,
            'caption': block.caption,
            if (block.bytes != null) 'bytesBase64': base64Encode(block.bytes!),
          },
      ],
      'customFonts': [
        for (final font in payload.customFonts)
          {
            'family': font.family,
            'source': font.source,
            'bytesBase64': base64Encode(font.bytes),
          },
      ],
    };
    const encoder = JsonEncoder.withIndent('  ');
    return Uint8List.fromList(utf8.encode(encoder.convert(data)));
  }

  String buildMarkdown(DocumentExportPayload payload) {
    final buffer = StringBuffer();
    final title = payload.title.trim();
    final body = payload.markdown.trim();

    if (title.isNotEmpty && !body.startsWith('# $title')) {
      buffer.writeln('# $title');
      buffer.writeln();
    }
    buffer.writeln(body.isEmpty ? ' ' : body);

    if (payload.mediaBlocks.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Media');
      for (final block in payload.mediaBlocks) {
        final label = block.caption.isEmpty ? block.source : block.caption;
        if (block.type == ExportMediaType.image && !block.hasBytes) {
          buffer.writeln('![${_escapeMarkdown(label)}](${block.source})');
        } else {
          buffer.writeln('- ${block.type.label}: [$label](${block.source})');
        }
      }
    }

    return buffer.toString();
  }

  String? _selectedFont(DocumentExportPayload payload) {
    final selected = payload.selectedFontFamily;
    if (selected == null || selected == 'Aptos') {
      return null;
    }
    return selected;
  }

  List<docx_fonts.EmbeddedFont> _embeddedFonts(List<CustomFontFile> fonts) {
    return [
      for (var index = 0; index < fonts.length; index += 1)
        docx_fonts.EmbeddedFont(
          familyName: fonts[index].family,
          bytes: fonts[index].bytes,
          obfuscationKey:
              '00000000-0000-0000-0000-${(index + 1).toRadixString(16).padLeft(12, '0')}',
        ),
    ];
  }

  docx.DocxNode _applyFont(docx.DocxNode node, String fontFamily) {
    if (node is docx.DocxParagraph) {
      return node.copyWith(
        children: node.children
            .map((child) => _applyFontToInline(child, fontFamily))
            .toList(),
      );
    }
    if (node is docx.DocxList) {
      return node.copyWith(
        items: node.items
            .map(
              (item) => item.copyWith(
                children: item.children
                    .map((child) => _applyFontToInline(child, fontFamily))
                    .toList(),
              ),
            )
            .toList(),
      );
    }
    if (node is docx.DocxTable) {
      return node.copyWith(
        rows: node.rows
            .map(
              (row) => row.copyWith(
                cells: row.cells
                    .map(
                      (cell) => cell.copyWith(
                        children: cell.children
                            .map((child) => _applyFont(child, fontFamily))
                            .whereType<docx.DocxBlock>()
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      );
    }
    if (node is docx.DocxTableOfContents) {
      return docx.DocxTableOfContents(
        instruction: node.instruction,
        updateOnOpen: node.updateOnOpen,
        cachedContent: node.cachedContent
            .map((block) => _applyFont(block, fontFamily))
            .whereType<docx.DocxBlock>()
            .toList(),
      );
    }
    return node;
  }

  docx.DocxInline _applyFontToInline(
    docx.DocxInline inline,
    String fontFamily,
  ) {
    if (inline is docx.DocxText) {
      return inline.copyWith(
        fontFamily: fontFamily,
        fonts: docx.DocxFont.family(fontFamily),
      );
    }
    return inline;
  }

  String _withEmbeddedHtmlFonts(String html, DocumentExportPayload payload) {
    final selectedFont = _selectedFont(payload);
    final selectedFontFile = payload.customFonts
        .where((font) => font.family == selectedFont)
        .firstOrNull;
    if (selectedFontFile == null) {
      return html;
    }

    final format = selectedFontFile.source.toLowerCase().endsWith('.otf')
        ? 'opentype'
        : 'truetype';
    final css =
        "@font-face { font-family: '${_escapeCss(selectedFontFile.family)}'; src: url(data:font/${format == 'opentype' ? 'otf' : 'ttf'};base64,${base64Encode(selectedFontFile.bytes)}) format('$format'); }\n"
        "body { font-family: '${_escapeCss(selectedFontFile.family)}', sans-serif; }";

    if (html.contains('</style>')) {
      return html.replaceFirst('</style>', '$css\n</style>');
    }
    return html.replaceFirst('</head>', '<style>$css</style></head>');
  }

  String _escapeCss(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  }

  String _escapeMarkdown(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }
}

class _BuiltExportNodes {
  const _BuiltExportNodes({
    required this.nodes,
    required this.footnotes,
    required this.endnotes,
  });

  final List<docx.DocxNode> nodes;
  final List<docx.DocxFootnote> footnotes;
  final List<docx.DocxEndnote> endnotes;
}
