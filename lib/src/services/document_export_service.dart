// ignore_for_file: implementation_imports

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../engine/docx.dart' as docx;
import '../engine/core/font_manager.dart' as docx_fonts;

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
    this.ooxmlBlocks = const [],
    this.wysiwygBlocks = const [],
    this.quillDeltaJson = const [],
    this.pageSetup = const DocumentPageSetup(),
  });

  final String title;
  final String markdown;
  final List<ExportMediaBlock> mediaBlocks;
  final List<CustomFontFile> customFonts;
  final String? selectedFontFamily;
  final String? sourcePackageFormat;
  final Uint8List? sourcePackageBytes;
  final List<OoxmlVisualBlock> ooxmlBlocks;
  final List<WysiwygBlock> wysiwygBlocks;
  final List<Object?> quillDeltaJson;
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
    final built = payload.quillDeltaJson.isNotEmpty
        ? _buildNodesFromQuillDelta(payload.quillDeltaJson)
        : await _buildNodes(buildMarkdown(payload));
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

  _BuiltExportNodes _buildNodesFromQuillDelta(List<Object?> deltaJson) {
    final nodes = <docx.DocxNode>[];
    final lines = _quillLines(deltaJson);
    var orderedStart = 1;
    var pendingListItems = <docx.DocxListItem>[];
    var pendingListOrdered = false;

    void flushList() {
      if (pendingListItems.isEmpty) {
        return;
      }
      nodes.add(
        docx.DocxList.items(
          pendingListItems,
          ordered: pendingListOrdered,
          start: pendingListOrdered ? orderedStart : 1,
        ),
      );
      if (pendingListOrdered) {
        orderedStart += pendingListItems.length;
      }
      pendingListItems = [];
    }

    for (final line in lines) {
      final listKind = line.attributes['list'];
      if (listKind == 'bullet' ||
          listKind == 'ordered' ||
          listKind == 'checked' ||
          listKind == 'unchecked') {
        final ordered = listKind == 'ordered';
        if (pendingListItems.isNotEmpty && pendingListOrdered != ordered) {
          flushList();
        }
        pendingListOrdered = ordered;
        final prefix = listKind == 'checked'
            ? '[x] '
            : listKind == 'unchecked'
            ? '[ ] '
            : '';
        pendingListItems.add(
          docx.DocxListItem.rich([
            if (prefix.isNotEmpty) docx.DocxText(prefix),
            ..._quillInlines(line.runs),
          ]),
        );
        continue;
      }

      flushList();
      orderedStart = 1;
      if (line.runs.isEmpty ||
          line.runs.every((run) => run.text.trim().isEmpty)) {
        continue;
      }
      nodes.add(
        docx.DocxParagraph(
          children: _quillInlines(line.runs),
          align: _quillAlign(line.attributes['align']),
          styleId: _quillStyleId(line.attributes),
          indentLeft: line.attributes['blockquote'] == true ? 720 : null,
        ),
      );
    }
    flushList();
    return _BuiltExportNodes(
      nodes: nodes,
      footnotes: const [],
      endnotes: const [],
    );
  }

  List<_QuillLine> _quillLines(List<Object?> deltaJson) {
    final lines = <_QuillLine>[];
    var runs = <_QuillRun>[];

    void flush(Map<String, Object?> attributes) {
      lines.add(_QuillLine(runs: runs, attributes: attributes));
      runs = [];
    }

    for (final rawOp in deltaJson) {
      if (rawOp is! Map) {
        continue;
      }
      final attributes = _quillAttributes(rawOp['attributes']);
      final insert = rawOp['insert'];
      if (insert is String) {
        final parts = insert.split('\n');
        for (var index = 0; index < parts.length; index += 1) {
          if (parts[index].isNotEmpty) {
            runs.add(_QuillRun(parts[index], attributes));
          }
          if (index != parts.length - 1) {
            flush(attributes);
          }
        }
      } else if (insert != null) {
        runs.add(_QuillRun('[Object]', attributes));
      }
    }
    if (runs.isNotEmpty) {
      flush(const {});
    }
    return lines;
  }

  List<docx.DocxInline> _quillInlines(List<_QuillRun> runs) {
    return [
      for (final run in runs)
        if (run.text.isNotEmpty) _quillText(run.text, run.attributes),
    ];
  }

  docx.DocxText _quillText(String text, Map<String, Object?> attributes) {
    final decorations = <docx.DocxTextDecoration>[
      if (attributes['underline'] == true) docx.DocxTextDecoration.underline,
      if (attributes['strike'] == true) docx.DocxTextDecoration.strikethrough,
    ];
    final code = attributes['code'] == true;
    return docx.DocxText(
      text,
      fontWeight: attributes['bold'] == true
          ? docx.DocxFontWeight.bold
          : docx.DocxFontWeight.normal,
      fontStyle: attributes['italic'] == true
          ? docx.DocxFontStyle.italic
          : docx.DocxFontStyle.normal,
      decorations: decorations,
      color: _quillColor(attributes['color']),
      shadingFill:
          _quillHex(attributes['background']) ?? (code ? 'E5E7EB' : null),
      fontSize: _quillFontSize(attributes['size']),
      fontFamily: code ? 'Courier New' : null,
      href: attributes['link'] is String ? attributes['link'] as String : null,
      isSuperscript: attributes['script'] == 'super',
      isSubscript: attributes['script'] == 'sub',
    );
  }

  Map<String, Object?> _quillAttributes(Object? value) {
    if (value is! Map) {
      return const {};
    }
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  String? _quillStyleId(Map<String, Object?> attributes) {
    return switch (attributes['header']) {
      1 => 'Heading1',
      2 => 'Heading2',
      3 => 'Heading3',
      _ => attributes['blockquote'] == true ? 'Quote' : null,
    };
  }

  docx.DocxAlign _quillAlign(Object? value) {
    return switch (value) {
      'center' => docx.DocxAlign.center,
      'right' => docx.DocxAlign.right,
      'justify' => docx.DocxAlign.justify,
      _ => docx.DocxAlign.left,
    };
  }

  docx.DocxColor? _quillColor(Object? value) {
    final hex = _quillHex(value);
    return hex == null ? null : docx.DocxColor(hex);
  }

  String? _quillHex(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    final cleaned = value
        .trim()
        .replaceFirst('#', '')
        .replaceFirst('0x', '')
        .toUpperCase();
    if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }

  double? _quillFontSize(Object? value) {
    return switch (value) {
      'small' => 10,
      'large' => 18,
      'huge' => 24,
      num() => value.toDouble(),
      String() => double.tryParse(value),
      _ => null,
    };
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
      if (payload.ooxmlBlocks.isNotEmpty)
        'ooxmlBlocks': [
          for (final block in payload.ooxmlBlocks) block.toJson(),
        ],
      if (payload.wysiwygBlocks.isNotEmpty)
        'wysiwygBlocks': [
          for (final block in payload.wysiwygBlocks) block.toJson(),
        ],
      if (payload.quillDeltaJson.isNotEmpty)
        'quillDeltaJson': payload.quillDeltaJson,
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

  Future<Uint8List> exportVisualDocx(DocumentExportPayload payload) async {
    ensureLanguageSupport(payload);
    if (payload.sourcePackageFormat == 'docx' &&
        payload.sourcePackageBytes != null) {
      return _exportPatchedVisualDocx(payload);
    }
    final selectedFont = _selectedFont(payload);
    final elements = payload.ooxmlBlocks
        .map((block) => _visualNodeFor(block, selectedFont))
        .whereType<docx.DocxNode>()
        .toList();
    final document = docx.DocxBuiltDocument(
      elements: elements,
      section: _sectionFor(payload.pageSetup),
      fonts: _embeddedFonts(payload.customFonts),
    );
    return docx.DocxExporter().exportToBytes(document);
  }

  docx.DocxNode? _visualNodeFor(OoxmlVisualBlock block, String? fontFamily) {
    if (block is OoxmlParagraphBlock) {
      final inline = docx.DocxText(block.text);
      return docx.DocxParagraph(
        styleId: block.styleId,
        align: _docxAlignFor(block.align),
        pageBreakBefore: block.pageBreakBefore,
        children: [
          fontFamily == null ? inline : _applyFontToInline(inline, fontFamily),
        ],
      );
    }
    if (block is OoxmlTableBlock) {
      return docx.DocxTable(
        hasHeader: block.hasHeader,
        rows: [
          for (var rowIndex = 0; rowIndex < block.rows.length; rowIndex += 1)
            docx.DocxTableRow(
              cells: [
                for (final cell in block.rows[rowIndex])
                  docx.DocxTableCell.text(
                    cell,
                    isBold: block.hasHeader && rowIndex == 0,
                    shadingFill: block.hasHeader && rowIndex == 0
                        ? 'DBEAFE'
                        : null,
                  ),
              ],
            ),
        ],
      );
    }
    return null;
  }

  docx.DocxAlign _docxAlignFor(OoxmlTextAlign align) {
    return switch (align) {
      OoxmlTextAlign.center => docx.DocxAlign.center,
      OoxmlTextAlign.right => docx.DocxAlign.right,
      OoxmlTextAlign.justify => docx.DocxAlign.justify,
      OoxmlTextAlign.left => docx.DocxAlign.left,
    };
  }

  Uint8List _exportPatchedVisualDocx(DocumentExportPayload payload) {
    final source = ZipDecoder().decodeBytes(payload.sourcePackageBytes!);
    final replacements = <String, String>{};
    final documentFile = source.findFile('word/document.xml');
    if (documentFile != null) {
      replacements['word/document.xml'] = _patchDocumentBodyXml(
        utf8.decode(documentFile.content as List<int>),
        payload.ooxmlBlocks,
      );
    }

    final partTextBlocks = payload.ooxmlBlocks.whereType<OoxmlPartTextBlock>();
    final blocksByPart = <String, List<OoxmlPartTextBlock>>{};
    for (final block in partTextBlocks) {
      blocksByPart.putIfAbsent(block.partPath, () => []).add(block);
    }
    for (final entry in blocksByPart.entries) {
      final file = source.findFile(entry.key);
      if (file == null) {
        continue;
      }
      replacements[entry.key] = _patchPartParagraphTextXml(
        replacements[entry.key] ?? utf8.decode(file.content as List<int>),
        entry.value,
      );
    }

    final output = Archive();
    for (final file in source.files) {
      final replacement = replacements[file.name];
      if (replacement != null) {
        output.addFile(ArchiveFile.string(file.name, replacement));
      } else {
        output.addFile(
          ArchiveFile(file.name, file.size, file.content)..mode = file.mode,
        );
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(output));
  }

  String _patchDocumentBodyXml(String xml, List<OoxmlVisualBlock> blocks) {
    final document = XmlDocument.parse(xml);
    final body = document.descendants.whereType<XmlElement>().firstWhere(
      (element) => element.name.local == 'body',
      orElse: () => document.rootElement,
    );
    var blockIndex = 0;
    for (final child in body.childElements) {
      if (blockIndex >= blocks.length) {
        break;
      }
      final block = blocks[blockIndex];
      if (child.name.local == 'p' && block is OoxmlParagraphBlock) {
        _replaceParagraphText(child, block.text);
        blockIndex += 1;
      } else if (child.name.local == 'tbl' && block is OoxmlTableBlock) {
        _replaceTableText(child, block);
        blockIndex += 1;
      }
    }
    return document.toXmlString();
  }

  String _patchPartParagraphTextXml(
    String xml,
    List<OoxmlPartTextBlock> blocks,
  ) {
    final document = XmlDocument.parse(xml);
    final byIndex = {
      for (final block in blocks) block.paragraphIndex: block.text,
    };
    var index = 0;
    for (final paragraph in document.descendants.whereType<XmlElement>()) {
      if (paragraph.name.local != 'p') {
        continue;
      }
      final text = byIndex[index];
      if (text != null) {
        _replaceParagraphText(paragraph, text);
      }
      index += 1;
    }
    return document.toXmlString();
  }

  void _replaceTableText(XmlElement table, OoxmlTableBlock block) {
    final rows = table.childElements
        .where((element) => element.name.local == 'tr')
        .toList();
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
      if (rowIndex >= block.rows.length) {
        break;
      }
      final cells = rows[rowIndex].childElements
          .where((element) => element.name.local == 'tc')
          .toList();
      for (var cellIndex = 0; cellIndex < cells.length; cellIndex += 1) {
        if (cellIndex >= block.rows[rowIndex].length) {
          break;
        }
        final paragraph = cells[cellIndex].descendants
            .whereType<XmlElement>()
            .firstWhere(
              (element) => element.name.local == 'p',
              orElse: () => cells[cellIndex],
            );
        _replaceParagraphText(paragraph, block.rows[rowIndex][cellIndex]);
      }
    }
  }

  void _replaceParagraphText(XmlElement paragraph, String text) {
    final textNodes = paragraph.descendants
        .whereType<XmlElement>()
        .where((element) => element.name.local == 't')
        .toList();
    if (textNodes.isEmpty) {
      return;
    }
    for (var index = 0; index < textNodes.length; index += 1) {
      textNodes[index].children
        ..clear()
        ..add(XmlText(index == 0 ? text : ''));
    }
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

class _QuillLine {
  const _QuillLine({required this.runs, required this.attributes});

  final List<_QuillRun> runs;
  final Map<String, Object?> attributes;
}

class _QuillRun {
  const _QuillRun(this.text, this.attributes);

  final String text;
  final Map<String, Object?> attributes;
}
