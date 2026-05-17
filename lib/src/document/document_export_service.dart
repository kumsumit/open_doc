import 'dart:convert';
import 'dart:typed_data';

import 'package:docx_creator/docx_creator.dart' as docx;

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
  });

  final ExportMediaType type;
  final String source;
  final String caption;
  final bool hasBytes;
}

class DocumentExportPayload {
  const DocumentExportPayload({
    required this.title,
    required this.markdown,
    this.mediaBlocks = const [],
    this.pageSetup = const DocumentPageSetup(),
  });

  final String title;
  final String markdown;
  final List<ExportMediaBlock> mediaBlocks;
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

  Future<docx.DocxBuiltDocument> buildDocument(
    DocumentExportPayload payload,
  ) async {
    final built = await _buildNodes(buildMarkdown(payload));
    return docx.DocxBuiltDocument(
      elements: built.nodes,
      footnotes: built.footnotes.isEmpty ? null : built.footnotes,
      section: _sectionFor(payload.pageSetup),
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
        default:
          final footnoteMatch = RegExp(
            r'^\[\[FOOTNOTE:(.*)\]\]$',
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
          } else {
            chunk.writeln(rawLine);
          }
      }
    }
    await flushChunk();

    return _BuiltExportNodes(nodes: nodes, footnotes: footnotes);
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
    final document = await buildDocument(payload);
    return docx.DocxExporter().exportToBytes(document);
  }

  Future<Uint8List> exportPdf(DocumentExportPayload payload) async {
    final document = await buildDocument(payload);
    return docx.PdfExporter().exportToBytes(document);
  }

  Future<Uint8List> exportHtml(DocumentExportPayload payload) async {
    final document = await buildDocument(payload);
    final html = docx.HtmlExporter().export(document);
    return Uint8List.fromList(utf8.encode(html));
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
  const _BuiltExportNodes({required this.nodes, required this.footnotes});

  final List<docx.DocxNode> nodes;
  final List<docx.DocxFootnote> footnotes;
}
