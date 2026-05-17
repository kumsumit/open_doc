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
  });

  final String title;
  final String markdown;
  final List<ExportMediaBlock> mediaBlocks;
}

class DocumentExportService {
  const DocumentExportService();

  Future<docx.DocxBuiltDocument> buildDocument(
    DocumentExportPayload payload,
  ) async {
    final nodes = await docx.MarkdownParser.parse(buildMarkdown(payload));
    return docx.DocxBuiltDocument(
      elements: nodes,
      section: docx.DocxSectionDef(
        pageSize: docx.DocxPageSize.a4,
        orientation: docx.DocxPageOrientation.portrait,
        header: docx.DocxHeader.styled('Open Doc', bold: true),
        footer: docx.DocxFooter.pageNumbers(),
      ),
    );
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
