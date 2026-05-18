import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_doc/app.dart';
import 'package:open_doc/src/services/document_export_service.dart';
import 'package:open_doc/src/services/document_import_service.dart';
import 'package:open_doc/src/services/language_support_service.dart';
import 'package:open_doc/src/services/document_models.dart';

void main() {
  const exportService = DocumentExportService();
  const importService = DocumentImportService();

  test('DOCX import extracts readable paragraphs', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('word/document.xml', '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Executive summary</w:t></w:r></w:p>
    <w:p><w:r><w:t>Open Doc reads DOCX content.</w:t></w:r></w:p>
  </w:body>
</w:document>
'''),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

    final imported = importService.parse(bytes, 'sample.docx');

    expect(imported.formatLabel, 'DOCX');
    expect(imported.text, contains('Executive summary'));
    expect(imported.text, contains('Open Doc reads DOCX content.'));
  });

  test('DOCX import preserves tables as markdown rows', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('word/document.xml', '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Budget</w:t></w:r></w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Item</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>Amount</w:t></w:r></w:p></w:tc>
      </w:tr>
      <w:tr>
        <w:tc><w:p><w:r><w:t>Design</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>1200</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>
'''),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

    final imported = importService.parse(bytes, 'budget.docx');

    expect(imported.text, contains('Budget'));
    expect(imported.text, contains('| Item | Amount |'));
    expect(imported.text, contains('| --- | --- |'));
    expect(imported.text, contains('| Design | 1200 |'));
    expect(imported.sourcePackageFormat, 'docx');
    expect(imported.sourcePackageBytes, bytes);
  });

  test('DOCX import converts Word structure to editor markdown', () {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('word/document.xml', '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:t>Launch plan</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr>
        <w:numPr><w:ilvl w:val="0"/><w:numId w:val="7"/></w:numPr>
      </w:pPr>
      <w:r><w:t>Approve scope</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:pageBreakBefore/></w:pPr>
      <w:r><w:t>Next page has </w:t></w:r>
      <w:r><w:rPr><w:b/></w:rPr><w:t>bold</w:t></w:r>
      <w:r><w:t> and </w:t></w:r>
      <w:r><w:rPr><w:i/></w:rPr><w:t>italic</w:t></w:r>
      <w:hyperlink r:id="rId5"><w:r><w:t>details</w:t></w:r></w:hyperlink>
    </w:p>
  </w:body>
</w:document>
'''),
      )
      ..addFile(
        ArchiveFile.string('word/_rels/document.xml.rels', '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId5"
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink"
    Target="https://example.com/details" TargetMode="External"/>
</Relationships>
'''),
      )
      ..addFile(
        ArchiveFile.string('word/numbering.xml', '''
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="3">
    <w:lvl w:ilvl="0"><w:numFmt w:val="bullet"/></w:lvl>
  </w:abstractNum>
  <w:num w:numId="7"><w:abstractNumId w:val="3"/></w:num>
</w:numbering>
'''),
      );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

    final imported = importService.parse(bytes, 'structured.docx');

    expect(imported.text, contains('# Launch plan'));
    expect(imported.text, contains('- Approve scope'));
    expect(imported.text, contains('[[PAGE_BREAK]]'));
    expect(imported.text, contains('Next page has **bold** and *italic*'));
    expect(imported.text, contains('[details](https://example.com/details)'));
  });

  test('CSV import creates markdown tables and handles quoted cells', () {
    final imported = importService.parse(
      Uint8List.fromList(
        utf8.encode('Name,Notes\nAsha,"Needs review, legal"\nMina,Ready'),
      ),
      'status.csv',
    );

    expect(imported.formatLabel, 'CSV');
    expect(imported.text, contains('| Name | Notes |'));
    expect(imported.text, contains('| Asha | Needs review, legal |'));
    expect(imported.text, contains('| Mina | Ready |'));
  });

  test('HTML import preserves table rows', () {
    final imported = importService.parse(
      Uint8List.fromList(
        utf8.encode('''
<h1>Plan</h1>
<table>
  <tr><th>Milestone</th><th>Owner</th></tr>
  <tr><td>Import</td><td>Asha</td></tr>
</table>
'''),
      ),
      'plan.html',
    );

    expect(imported.formatLabel, 'HTML');
    expect(imported.text, contains('Plan'));
    expect(imported.text, contains('| Milestone | Owner |'));
    expect(imported.text, contains('| Import | Asha |'));
  });

  test('plain import supports text-like files', () {
    final imported = importService.parse(
      Uint8List.fromList(utf8.encode('# Notes\nHello')),
      'notes.md',
    );

    expect(imported.formatLabel, 'Markdown');
    expect(imported.text, contains('Hello'));
  });

  test('DOCX export creates a valid Word package from markdown', () async {
    final bytes = await exportService.exportDocx(
      const DocumentExportPayload(
        title: 'Export check',
        markdown: '''
Open Doc writes real DOCX files now.

| Feature | Status |
| --- | --- |
| DOCX export | Ready |
''',
      ),
    );
    final archive = ZipDecoder().decodeBytes(bytes);

    expect(archive.findFile('[Content_Types].xml'), isNotNull);
    final documentXml = archive.findFile('word/document.xml');
    expect(documentXml, isNotNull);
    expect(
      utf8.decode(documentXml!.content as List<int>),
      contains('Open Doc writes real DOCX files now.'),
    );
  });

  test(
    'visual OOXML export writes editable paragraph and table blocks',
    () async {
      final bytes = await exportService.exportVisualDocx(
        const DocumentExportPayload(
          title: 'Visual OOXML check',
          markdown: 'Fallback text',
          ooxmlBlocks: [
            OoxmlParagraphBlock(
              text: 'Styled visual paragraph',
              styleId: 'Heading1',
              align: OoxmlTextAlign.center,
            ),
            OoxmlTableBlock(
              rows: [
                ['Name', 'Status'],
                ['Open Doc', 'Ready'],
              ],
            ),
          ],
        ),
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXml = archive.findFile('word/document.xml');

      expect(documentXml, isNotNull);
      final xml = utf8.decode(documentXml!.content as List<int>);
      expect(xml, contains('Styled visual paragraph'));
      expect(xml, contains('Heading1'));
      expect(xml, contains('Open Doc'));
      expect(xml, contains('Ready'));
    },
  );

  test(
    'visual OOXML patches source package and preserves unknown parts',
    () async {
      final source = Archive()
        ..addFile(
          ArchiveFile.string('word/document.xml', '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
  <w:body>
    <w:p><w:r><w:t>Old body</w:t></w:r></w:p>
    <w:p><w:r><w:drawing><wp:inline/></w:drawing></w:r></w:p>
    <w:sdt><w:sdtContent><w:p><w:r><w:t>Original control</w:t></w:r></w:p></w:sdtContent></w:sdt>
  </w:body>
</w:document>
'''),
        )
        ..addFile(
          ArchiveFile.string('word/header1.xml', '''
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p><w:r><w:t>Old header</w:t></w:r></w:p>
</w:hdr>
'''),
        );
      final sourceBytes = Uint8List.fromList(ZipEncoder().encode(source));

      final bytes = await exportService.exportVisualDocx(
        DocumentExportPayload(
          title: 'Patch check',
          markdown: '',
          sourcePackageFormat: 'docx',
          sourcePackageBytes: sourceBytes,
          ooxmlBlocks: const [
            OoxmlParagraphBlock(text: 'New body'),
            OoxmlPartTextBlock(
              partPath: 'word/header1.xml',
              paragraphIndex: 0,
              label: 'Header 1',
              text: 'New header',
            ),
          ],
        ),
      );
      final patched = ZipDecoder().decodeBytes(bytes);
      final documentXml = utf8.decode(
        patched.findFile('word/document.xml')!.content as List<int>,
      );
      final headerXml = utf8.decode(
        patched.findFile('word/header1.xml')!.content as List<int>,
      );

      expect(documentXml, contains('New body'));
      expect(documentXml, contains('<w:drawing>'));
      expect(documentXml, contains('<w:sdt>'));
      expect(documentXml, contains('Original control'));
      expect(headerXml, contains('New header'));
    },
  );

  test('PDF and HTML exporters produce real document output', () async {
    const payload = DocumentExportPayload(
      title: 'Multi-format check',
      markdown: 'Open Doc can publish through the shared document engine.',
    );

    final pdfBytes = await exportService.exportPdf(payload);
    final html = utf8.decode(await exportService.exportHtml(payload));

    expect(utf8.decode(pdfBytes.take(5).toList()), '%PDF-');
    expect(html, contains('<h1>Multi-format check</h1>'));
    expect(
      html,
      contains('Open Doc can publish through the shared document engine.'),
    );
  });

  test('export blocks multilingual text without a covering embedded font', () {
    const payload = DocumentExportPayload(
      title: 'Hindi check',
      markdown: 'नमस्ते दुनिया',
    );

    expect(
      exportService.exportPdf(payload),
      throwsA(isA<LanguageSupportException>()),
    );
  });

  test('Open Doc export and import preserve native project data', () async {
    final bytes = await exportService.exportOpenDoc(
      DocumentExportPayload(
        title: 'Native package',
        markdown: '# Brief\n\nKeep the rich state.',
        wysiwygBlocks: WysiwygDocumentCodec.fromMarkdown(
          '# Brief\n\nKeep the rich state.',
        ),
        quillDeltaJson: WysiwygDocumentCodec.toQuillDeltaJson(
          WysiwygDocumentCodec.fromMarkdown('# Brief\n\nKeep the rich state.'),
        ),
        selectedFontFamily: 'Brand Sans',
        pageSetup: const DocumentPageSetup(
          pageSize: DocumentPageSize.legal,
          orientation: DocumentPageOrientation.landscape,
          marginPreset: DocumentMarginPreset.narrow,
        ),
        mediaBlocks: [
          ExportMediaBlock(
            type: ExportMediaType.image,
            source: 'diagram.png',
            caption: 'Architecture diagram',
            hasBytes: true,
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ],
        customFonts: [
          CustomFontFile(
            family: 'Brand Sans',
            source: 'brand-sans.ttf',
            bytes: Uint8List.fromList([4, 5, 6]),
          ),
        ],
        sourcePackageFormat: 'docx',
        sourcePackageBytes: Uint8List.fromList([7, 8, 9]),
      ),
    );

    final imported = importService.parse(bytes, 'native.odoc');

    expect(imported.formatLabel, 'Open Doc');
    expect(imported.title, 'Native package');
    expect(imported.selectedFontFamily, 'Brand Sans');
    expect(imported.text, contains('# Brief'));
    expect(imported.pageSetup?.pageSize, DocumentPageSize.legal);
    expect(imported.pageSetup?.orientation, DocumentPageOrientation.landscape);
    expect(imported.pageSetup?.marginPreset, DocumentMarginPreset.narrow);
    expect(imported.mediaBlocks.single.type, MediaType.image);
    expect(imported.mediaBlocks.single.caption, 'Architecture diagram');
    expect(imported.mediaBlocks.single.bytes, Uint8List.fromList([1, 2, 3]));
    expect(imported.customFonts.single.family, 'Brand Sans');
    expect(imported.customFonts.single.source, 'brand-sans.ttf');
    expect(imported.customFonts.single.bytes, Uint8List.fromList([4, 5, 6]));
    expect(imported.sourcePackageFormat, 'docx');
    expect(imported.sourcePackageBytes, Uint8List.fromList([7, 8, 9]));
    expect(imported.wysiwygBlocks, isNotEmpty);
    expect(imported.wysiwygBlocks.first.type, WysiwygBlockType.title);
    expect(imported.quillDeltaJson, isNotEmpty);
  });

  test('WYSIWYG document codec bridges visual blocks to markdown', () {
    final blocks = WysiwygDocumentCodec.fromMarkdown(
      '# Title\n\n## Heading\n\n- First\n\n1. Step\n\n- [x] Done',
    );

    expect(blocks.map((block) => block.type), contains(WysiwygBlockType.title));
    expect(
      blocks.map((block) => block.type),
      contains(WysiwygBlockType.checklist),
    );
    expect(WysiwygDocumentCodec.toMarkdown(blocks), contains('# Title'));
    expect(WysiwygDocumentCodec.toMarkdown(blocks), contains('- [x] Done'));
  });

  test('WYSIWYG document codec bridges Quill delta to blocks', () {
    final delta = WysiwygDocumentCodec.toQuillDeltaJson(
      WysiwygDocumentCodec.fromMarkdown('# Title\n\n- [x] Done'),
    );
    final blocks = WysiwygDocumentCodec.fromQuillDeltaJson(delta);

    expect(blocks.first.type, WysiwygBlockType.title);
    expect(blocks.last.type, WysiwygBlockType.checklist);
    expect(blocks.last.checked, isTrue);
    expect(WysiwygDocumentCodec.toMarkdown(blocks), contains('- [x] Done'));
  });

  test('DOCX export preserves Quill Delta rich text formatting', () async {
    final bytes = await exportService.exportDocx(
      const DocumentExportPayload(
        title: 'Quill fidelity',
        markdown: 'Fallback',
        quillDeltaJson: [
          {
            'insert': 'Styled Heading',
            'attributes': {'bold': true},
          },
          {
            'insert': '\n',
            'attributes': {'header': 1, 'align': 'center'},
          },
          {'insert': 'Rich '},
          {
            'insert': 'italic underline',
            'attributes': {
              'italic': true,
              'underline': true,
              'color': '#FF0000',
              'background': '#FFFF00',
              'link': 'https://example.com',
            },
          },
          {'insert': '\n'},
          {'insert': 'First item'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
        ],
      ),
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.content as List<int>,
    );

    expect(documentXml, contains('Heading1'));
    expect(documentXml, contains('<w:jc w:val="center"'));
    expect(documentXml, contains('<w:b/>'));
    expect(documentXml, contains('<w:i/>'));
    expect(documentXml, contains('<w:u'));
    expect(documentXml, contains('w:color w:val="FF0000"'));
    expect(documentXml, contains('w:fill="FFFF00"'));
    expect(documentXml, contains('<w:hyperlink r:id="rIdHyperlink1"'));
    expect(documentXml, contains('<w:numPr>'));
    final relsXml = utf8.decode(
      archive.findFile('word/_rels/document.xml.rels')!.content as List<int>,
    );
    expect(relsXml, contains('rIdHyperlink1'));
    expect(relsXml, contains('https://example.com'));
    expect(relsXml, contains('TargetMode="External"'));
  });

  test('DOCX import preserves hyperlinks in Quill Delta', () async {
    final bytes = await exportService.exportDocx(
      const DocumentExportPayload(
        title: 'Quill hyperlink import',
        markdown: 'Fallback',
        quillDeltaJson: [
          {'insert': 'Read '},
          {
            'insert': 'details',
            'attributes': {'link': 'https://example.com/details'},
          },
          {'insert': '\n'},
        ],
      ),
    );

    final imported = await importService.parseAsync(bytes, 'links.docx');
    final deltaText = jsonEncode(imported.quillDeltaJson);

    expect(imported.quillDeltaJson, isNotEmpty);
    expect(deltaText, contains('"link":"https://example.com/details"'));
    expect(imported.text, contains('[details](https://example.com/details)'));
  });

  test('export service supports page setup and references', () async {
    final bytes = await exportService.exportDocx(
      const DocumentExportPayload(
        title: 'Layout check',
        pageSetup: DocumentPageSetup(
          pageSize: DocumentPageSize.legal,
          orientation: DocumentPageOrientation.landscape,
          marginPreset: DocumentMarginPreset.narrow,
        ),
        markdown: '''
[[TOC]]

# First section

Text before the break.

[[PAGE_BREAK]]

Second page content.

[[FOOTNOTE:Reference note generated by Open Doc.]]

[[ENDNOTE:Closing note generated by Open Doc.]]

[[HR]]

[[DROP_CAP:Once upon a time in Open Doc.]]

[[SHAPE:ellipse:Milestone]]

[[SHAPE:actionButtonHome:Home]]

[[ADV_TABLE:rows=3;cols=3;mergeHeader=true;shadeHeader=true;perCellBorders=true;border=double]]

[[LINK:Open Doc|https://open-doc.local]]
''',
      ),
    );
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentXml = utf8.decode(
      archive.findFile('word/document.xml')!.content as List<int>,
    );
    final footnotesXml = utf8.decode(
      archive.findFile('word/footnotes.xml')!.content as List<int>,
    );
    final endnotesXml = utf8.decode(
      archive.findFile('word/endnotes.xml')!.content as List<int>,
    );

    expect(documentXml, contains('Table of Contents'));
    expect(documentXml, contains('w:pageBreakBefore'));
    expect(documentXml, contains('w:footnoteReference'));
    expect(documentXml, contains('w:endnoteReference'));
    expect(documentXml, contains('w:framePr'));
    expect(documentXml, contains('Milestone'));
    expect(documentXml, contains('Home'));
    expect(documentXml, contains('w:gridSpan'));
    expect(documentXml, contains('w:tcBorders'));
    expect(documentXml, contains('w:val="double"'));
    expect(documentXml, contains('Open Doc'));
    expect(documentXml, contains('w:orient="landscape"'));
    expect(documentXml, contains('w:left="720"'));
    expect(footnotesXml, contains('Reference note generated by Open Doc.'));
    expect(endnotesXml, contains('Closing note generated by Open Doc.'));
  });

  testWidgets('Open Doc editor loads and inserts content', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OpenDocApp());

    expect(find.text('Project proposal'), findsOneWidget);
    expect(find.byKey(const ValueKey('document-editor')), findsOneWidget);
    expect(find.text('Navigation'), findsWidgets);
    expect(find.text('Inspector'), findsWidgets);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byTooltip('Versions'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Import'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Export'), findsOneWidget);
    expect(find.byTooltip('Image'), findsOneWidget);
    expect(find.byTooltip('Video'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.checklist_outlined));
    await tester.pump();

    expect(find.textContaining('Action item'), findsWidgets);
    expect(find.text('Unsaved'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.image_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Insert image'), findsOneWidget);
    expect(find.text('Choose device image'), findsOneWidget);

    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace reference image'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.drag(find.byType(ListView).first, const Offset(-1800, 0));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Brief'), findsWidgets);
    expect(find.byTooltip('Social'), findsOneWidget);
    expect(find.byTooltip('Source'), findsOneWidget);
    expect(find.byTooltip('Actions'), findsWidgets);
    expect(find.text('Millennial'), findsWidgets);
    expect(find.text('Clear'), findsWidgets);

    await tester.tap(find.byIcon(Icons.auto_awesome_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Smart brief'), findsOneWidget);
    expect(find.textContaining('Clarity:'), findsOneWidget);

    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Smart brief for Millennial readers'),
      findsWidgets,
    );

    await tester.tap(find.byIcon(Icons.save_outlined).first);
    await tester.pump();

    expect(find.text('Saved'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dashboard_customize_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Contract'), findsOneWidget);
  });

  testWidgets('Open Doc adapts to phone and landscape sizes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OpenDocApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('document-editor')), findsOneWidget);

    await tester.tap(find.byTooltip('Navigation'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Outline'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpWidget(const OpenDocApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('document-editor')), findsOneWidget);
  });
}
