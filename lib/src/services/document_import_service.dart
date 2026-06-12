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
    this.openXmlDocument,
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
  final OpenXmlDocument? openXmlDocument;
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
        openXmlDocument: _openXmlDocumentFromDocx(
          document,
          sourcePackageFormat: base.sourcePackageFormat,
          sourcePackageBytes: base.sourcePackageBytes,
        ),
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
        openXmlDocument: OpenXmlDocument.plain(base.text).copyWith(
          sourcePackageFormat: base.sourcePackageFormat,
          sourcePackageBytes: base.sourcePackageBytes,
        ),
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
        openXmlDocument: OpenXmlDocument.plain(_extractDocxText(bytes))
            .copyWith(
              sourcePackageFormat: 'docx',
              sourcePackageBytes: Uint8List.fromList(bytes),
            ),
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
      'odt' || 'ott' => _parseOdt(bytes),
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
    final archive = _decodeDocxArchive(bytes);
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
      openXmlDocument: _parseOpenDocOpenXmlDocument(decoded['openXmlDocument']),
    );
  }

  OpenXmlDocument _openXmlDocumentFromDocx(
    docx.DocxBuiltDocument document, {
    String? sourcePackageFormat,
    Uint8List? sourcePackageBytes,
  }) {
    final blocks = <OpenXmlBlock>[];
    for (final node in document.elements) {
      if (node is docx.DocxParagraph) {
        blocks.add(
          OpenXmlParagraphBlock(
            runs: [
              for (final child in node.children.whereType<docx.DocxText>())
                OpenXmlRun(
                  child.content,
                  bold: child.isBold,
                  italic: child.isItalic,
                  underline: child.isUnderline,
                  strike: child.isStrike,
                  colorHex: child.color?.hex,
                  href: child.href,
                ),
            ],
            style: _openXmlStyleFor(node.styleId),
            align: _visualAlignFor(node.align),
            pageBreakBefore: node.pageBreakBefore,
          ),
        );
      } else if (node is docx.DocxTable) {
        blocks.add(
          OpenXmlTableBlock(
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
    return OpenXmlDocument(
      blocks: blocks.isEmpty ? OpenXmlDocument.plain('').blocks : blocks,
      sourcePackageFormat: sourcePackageFormat,
      sourcePackageBytes: sourcePackageBytes,
    );
  }

  OpenXmlTextStyle _openXmlStyleFor(String? styleId) {
    if (styleId == null) return OpenXmlTextStyle.normal;
    // Normalize: lowercase, collapse spaces/underscores, strip unicode escapes.
    // Handles "Heading 1", "Heading1", "heading_1", "Heading_20_1" (ODT), etc.
    final normalized = styleId
        .toLowerCase()
        .replaceAll(RegExp(r'_[0-9a-f]{2}_'), ' ') // ODT hex escapes like _20_
        .replaceAll(RegExp(r'[\s_\-]+'), '');
    return switch (normalized) {
      'title' => OpenXmlTextStyle.title,
      'subtitle' => OpenXmlTextStyle.subtitle,
      'heading1' || 'h1' || '1' => OpenXmlTextStyle.heading1,
      'heading2' || 'h2' || '2' => OpenXmlTextStyle.heading2,
      'heading3' || 'h3' || '3' => OpenXmlTextStyle.heading3,
      'heading4' || 'h4' || '4' => OpenXmlTextStyle.heading4,
      'heading5' || 'h5' || '5' => OpenXmlTextStyle.heading5,
      'heading6' || 'h6' || '6' => OpenXmlTextStyle.heading6,
      'quote' || 'quotations' || 'blockquote' => OpenXmlTextStyle.quote,
      'code' || 'codechar' || 'codeparagraph' || 'preformatted' =>
        OpenXmlTextStyle.code,
      'caption' || 'figurecaption' || 'tablecaption' => OpenXmlTextStyle.caption,
      _ => OpenXmlTextStyle.normal,
    };
  }

  // ── ODT / OpenDocument Text parser ────────────────────────────────────────

  ImportedDocument _parseOdt(Uint8List bytes) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const FormatException('This file is not a readable ODT package.');
    }

    // Load and merge named styles + automatic styles.
    final namedStyles = _odtNamedStyles(archive);
    final autoStyles = _odtAutoStyles(archive);
    final allStyles = {...namedStyles, ...autoStyles};

    final contentFile = archive.files
        .where((f) => f.name == 'content.xml')
        .firstOrNull;
    if (contentFile == null) {
      throw const FormatException('This ODT file has no content.xml.');
    }

    final doc = XmlDocument.parse(utf8.decode(contentFile.content as List<int>));
    // Also pick up automatic styles defined inside content.xml itself.
    for (final entry in _odtAutoStylesFromDoc(doc).entries) {
      allStyles[entry.key] = entry.value;
    }

    final textBody = doc.descendants.whereType<XmlElement>().firstWhere(
      (e) => e.name.local == 'text' && e.name.prefix == 'office',
      orElse: () => doc.rootElement,
    );

    final blocks = <OpenXmlBlock>[];
    final plainLines = <String>[];

    for (final child in textBody.childElements) {
      final local = child.name.local;
      final ns = child.name.prefix;

      if (local == 'h' && ns == 'text') {
        final level = int.tryParse(
              child.getAttribute('text:outline-level') ?? '',
            ) ??
            int.tryParse(
              child.getAttribute('outline-level') ?? '',
            ) ??
            1;
        final text = _odtParagraphPlainText(child);
        if (text.trim().isEmpty) continue;
        final style = _odtHeadingStyle(level);
        final runs = _odtRuns(child, allStyles);
        blocks.add(OpenXmlParagraphBlock(runs: runs, style: style));
        plainLines.add(text);
      } else if (local == 'p' && ns == 'text') {
        final styleName =
            child.getAttribute('text:style-name') ??
            child.getAttribute('style-name') ??
            '';
        final resolvedStyle = _odtResolveParaStyle(styleName, allStyles);
        final text = _odtParagraphPlainText(child);
        if (text.trim().isEmpty) {
          blocks.add(const OpenXmlParagraphBlock(runs: [OpenXmlRun('')]));
          continue;
        }
        final runs = _odtRuns(child, allStyles);
        blocks.add(OpenXmlParagraphBlock(runs: runs, style: resolvedStyle));
        plainLines.add(text);
      } else if (local == 'list' && ns == 'text') {
        final listBlocks = _odtList(child, allStyles);
        blocks.addAll(listBlocks);
        for (final b in listBlocks) {
          if (b is OpenXmlParagraphBlock) plainLines.add(b.plainText);
        }
      } else if (local == 'table' && ns == 'table') {
        final tableBlock = _odtTable(child, allStyles);
        if (tableBlock != null) {
          blocks.add(tableBlock);
        }
      }
    }

    final plainText = plainLines.join('\n\n');
    final openXmlDoc = OpenXmlDocument(
      blocks: blocks.isEmpty
          ? [const OpenXmlParagraphBlock(runs: [OpenXmlRun('')])]
          : blocks,
    );

    return ImportedDocument(
      text: plainText.trim(),
      formatLabel: 'ODT',
      openXmlDocument: openXmlDoc,
      wysiwygBlocks: WysiwygDocumentCodec.fromMarkdown(plainText),
      quillDeltaJson: WysiwygDocumentCodec.toQuillDeltaJson(
        WysiwygDocumentCodec.fromMarkdown(plainText),
      ),
    );
  }

  // ── ODT helpers ─────────────────────────────────────────────────────────────

  /// Named styles from styles.xml (Heading 1, Title, etc.).
  Map<String, _OdtStyle> _odtNamedStyles(Archive archive) {
    final stylesFile = archive.files
        .where((f) => f.name == 'styles.xml')
        .firstOrNull;
    if (stylesFile == null) return {};
    try {
      final doc = XmlDocument.parse(
        utf8.decode(stylesFile.content as List<int>),
      );
      return _odtParseStyleElements(doc);
    } on Object {
      return {};
    }
  }

  /// Automatic styles declared in content.xml's own automatic-styles section.
  Map<String, _OdtStyle> _odtAutoStyles(Archive archive) {
    // Nothing extra in the archive itself; content.xml is parsed separately.
    return {};
  }

  Map<String, _OdtStyle> _odtAutoStylesFromDoc(XmlDocument doc) {
    return _odtParseStyleElements(doc);
  }

  Map<String, _OdtStyle> _odtParseStyleElements(XmlDocument doc) {
    final result = <String, _OdtStyle>{};
    for (final style in doc.descendants.whereType<XmlElement>()) {
      if (style.name.local != 'style') continue;
      final name = style.getAttribute('style:name') ??
          style.getAttribute('name');
      if (name == null || name.isEmpty) continue;
      final displayName = style.getAttribute('style:display-name') ??
          style.getAttribute('display-name');
      final parentName = style.getAttribute('style:parent-style-name') ??
          style.getAttribute('parent-style-name');

      // Text properties (inline formatting).
      final textProps = style.childElements
          .where((e) => e.name.local == 'text-properties')
          .firstOrNull;
      final paraProps = style.childElements
          .where((e) => e.name.local == 'paragraph-properties')
          .firstOrNull;

      bool bold = false;
      bool italic = false;
      bool underline = false;
      bool strike = false;
      String? colorHex;

      if (textProps != null) {
        final fw = textProps.getAttribute('fo:font-weight') ??
            textProps.getAttribute('font-weight') ?? '';
        final fs = textProps.getAttribute('fo:font-style') ??
            textProps.getAttribute('font-style') ?? '';
        final ul = textProps.getAttribute('style:text-underline-style') ??
            textProps.getAttribute('text-underline-style') ?? '';
        final st = textProps.getAttribute('style:text-line-through-style') ??
            textProps.getAttribute('text-line-through-style') ?? '';
        final col = textProps.getAttribute('fo:color') ??
            textProps.getAttribute('color') ?? '';
        bold = fw == 'bold';
        italic = fs == 'italic';
        underline = ul.isNotEmpty && ul != 'none';
        strike = st.isNotEmpty && st != 'none';
        if (col.startsWith('#')) colorHex = col.substring(1).toUpperCase();
      }

      OoxmlTextAlign align = OoxmlTextAlign.left;
      if (paraProps != null) {
        final fo = paraProps.getAttribute('fo:text-align') ??
            paraProps.getAttribute('text-align') ?? '';
        align = switch (fo) {
          'center' => OoxmlTextAlign.center,
          'right' || 'end' => OoxmlTextAlign.right,
          'justify' => OoxmlTextAlign.justify,
          _ => OoxmlTextAlign.left,
        };
      }

      result[name] = _OdtStyle(
        name: name,
        displayName: displayName,
        parentName: parentName,
        bold: bold,
        italic: italic,
        underline: underline,
        strike: strike,
        colorHex: colorHex,
        align: align,
      );
    }
    return result;
  }

  OpenXmlTextStyle _odtHeadingStyle(int level) {
    return switch (level) {
      1 => OpenXmlTextStyle.heading1,
      2 => OpenXmlTextStyle.heading2,
      3 => OpenXmlTextStyle.heading3,
      4 => OpenXmlTextStyle.heading4,
      5 => OpenXmlTextStyle.heading5,
      _ => OpenXmlTextStyle.heading6,
    };
  }

  OpenXmlTextStyle _odtResolveParaStyle(
    String styleName,
    Map<String, _OdtStyle> styles,
  ) {
    // Walk the parent chain looking for a heading/title match.
    var current = styleName;
    final seen = <String>{};
    while (current.isNotEmpty && !seen.contains(current)) {
      seen.add(current);
      final mapped = _openXmlStyleFor(current);
      if (mapped != OpenXmlTextStyle.normal) return mapped;
      // Also check the display name.
      final display = styles[current]?.displayName;
      if (display != null) {
        final dm = _openXmlStyleFor(display);
        if (dm != OpenXmlTextStyle.normal) return dm;
      }
      current = styles[current]?.parentName ?? '';
    }
    return OpenXmlTextStyle.normal;
  }

  String _odtParagraphPlainText(XmlElement para) {
    final buffer = StringBuffer();
    for (final node in para.descendants) {
      if (node is XmlText) {
        buffer.write(node.value);
      } else if (node is XmlElement) {
        switch (node.name.local) {
          case 's':
            final count = int.tryParse(
                  node.getAttribute('text:c') ??
                      node.getAttribute('c') ??
                      '1',
                ) ??
                1;
            buffer.write(' ' * count);
          case 'tab':
            buffer.write('\t');
          case 'line-break':
            buffer.write('\n');
        }
      }
    }
    return buffer.toString();
  }

  List<OpenXmlRun> _odtRuns(
    XmlElement para,
    Map<String, _OdtStyle> styles,
  ) {
    final runs = <OpenXmlRun>[];

    void addText(
      String text, {
      bool bold = false,
      bool italic = false,
      bool underline = false,
      bool strike = false,
      String? colorHex,
    }) {
      if (text.isEmpty) return;
      runs.add(OpenXmlRun(
        text,
        bold: bold,
        italic: italic,
        underline: underline,
        strike: strike,
        colorHex: colorHex,
      ));
    }

    _OdtStyle? resolveStyle(String? name) {
      if (name == null) return null;
      _OdtStyle? merged;
      var current = name;
      final seen = <String>{};
      // Walk parent chain and merge (child overrides parent).
      final chain = <_OdtStyle>[];
      while (current.isNotEmpty && !seen.contains(current)) {
        seen.add(current);
        final s = styles[current];
        if (s != null) chain.add(s);
        current = s?.parentName ?? '';
      }
      // Apply parent-to-child order so child wins.
      for (final s in chain.reversed) {
        if (merged == null) {
          merged = s;
        } else {
          merged = _OdtStyle(
            name: s.name,
            displayName: s.displayName,
            parentName: s.parentName,
            bold: s.bold || merged.bold,
            italic: s.italic || merged.italic,
            underline: s.underline || merged.underline,
            strike: s.strike || merged.strike,
            colorHex: s.colorHex ?? merged.colorHex,
            align: s.align,
          );
        }
      }
      return merged;
    }

    void processNode(XmlNode node, _OdtStyle? parentStyle) {
      if (node is XmlText) {
        addText(
          node.value,
          bold: parentStyle?.bold ?? false,
          italic: parentStyle?.italic ?? false,
          underline: parentStyle?.underline ?? false,
          strike: parentStyle?.strike ?? false,
          colorHex: parentStyle?.colorHex,
        );
      } else if (node is XmlElement) {
        switch (node.name.local) {
          case 'span':
            final styleName = node.getAttribute('text:style-name') ??
                node.getAttribute('style-name');
            final spanStyle = resolveStyle(styleName);
            final merged = spanStyle == null
                ? parentStyle
                : _OdtStyle(
                    name: spanStyle.name,
                    displayName: spanStyle.displayName,
                    parentName: spanStyle.parentName,
                    bold: spanStyle.bold || (parentStyle?.bold ?? false),
                    italic: spanStyle.italic || (parentStyle?.italic ?? false),
                    underline: spanStyle.underline ||
                        (parentStyle?.underline ?? false),
                    strike:
                        spanStyle.strike || (parentStyle?.strike ?? false),
                    colorHex: spanStyle.colorHex ?? parentStyle?.colorHex,
                    align: spanStyle.align,
                  );
            for (final child in node.children) {
              processNode(child, merged);
            }
          case 's':
            final count = int.tryParse(
                  node.getAttribute('text:c') ??
                      node.getAttribute('c') ??
                      '1',
                ) ??
                1;
            addText(
              ' ' * count,
              bold: parentStyle?.bold ?? false,
              italic: parentStyle?.italic ?? false,
              colorHex: parentStyle?.colorHex,
            );
          case 'tab':
            addText(
              '\t',
              bold: parentStyle?.bold ?? false,
              italic: parentStyle?.italic ?? false,
            );
          case 'line-break':
            addText('\n');
          case 'a':
            final href = node.getAttribute('xlink:href') ??
                node.getAttribute('href');
            final text = _odtParagraphPlainText(node);
            if (text.isNotEmpty) {
              runs.add(OpenXmlRun(text, href: href));
            }
          default:
            for (final child in node.children) {
              processNode(child, parentStyle);
            }
        }
      }
    }

    for (final child in para.children) {
      processNode(child, null);
    }

    return runs.isEmpty ? const [OpenXmlRun('')] : runs;
  }

  List<OpenXmlBlock> _odtList(
    XmlElement listEl,
    Map<String, _OdtStyle> styles,
  ) {
    final blocks = <OpenXmlBlock>[];
    for (final item in listEl.childElements) {
      if (item.name.local != 'list-item') continue;
      for (final child in item.childElements) {
        if (child.name.local == 'p') {
          final text = _odtParagraphPlainText(child);
          if (text.trim().isEmpty) continue;
          final runs = _odtRuns(child, styles);
          blocks.add(OpenXmlParagraphBlock(runs: runs));
        } else if (child.name.local == 'list') {
          blocks.addAll(_odtList(child, styles));
        }
      }
    }
    return blocks;
  }

  OpenXmlTableBlock? _odtTable(
    XmlElement tableEl,
    Map<String, _OdtStyle> styles,
  ) {
    final rows = <List<String>>[];
    for (final row in tableEl.descendants.whereType<XmlElement>()) {
      if (row.name.local != 'table-row') continue;
      final cells = row.childElements
          .where((e) => e.name.local == 'table-cell' ||
              e.name.local == 'covered-table-cell')
          .map((cell) {
            return cell.descendants
                .whereType<XmlElement>()
                .where((e) => e.name.local == 'p')
                .map(_odtParagraphPlainText)
                .where((t) => t.trim().isNotEmpty)
                .join(' ');
          })
          .toList();
      if (cells.any((c) => c.trim().isNotEmpty)) {
        rows.add(cells);
      }
    }
    if (rows.isEmpty) return null;
    return OpenXmlTableBlock(rows: rows, hasHeader: rows.length > 1);
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

  OpenXmlDocument? _parseOpenDocOpenXmlDocument(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }
    return OpenXmlDocument.fromJson(value);
  }

  List<OoxmlVisualBlock> _visualPartTextBlocks(Uint8List bytes) {
    final archive = _decodeDocxArchive(bytes);
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

  Archive _decodeDocxArchive(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException(
        'This DOCX file is empty. Choose a downloaded, non-empty Word document.',
      );
    }

    try {
      return ZipDecoder().decodeBytes(bytes);
    } on Object {
      throw const FormatException(
        'This file is not a readable DOCX/OpenXML package.',
      );
    }
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

class _OdtStyle {
  const _OdtStyle({
    required this.name,
    this.displayName,
    this.parentName,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.colorHex,
    this.align = OoxmlTextAlign.left,
  });

  final String name;
  final String? displayName;
  final String? parentName;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String? colorHex;
  final OoxmlTextAlign align;
}
