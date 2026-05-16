import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:open_doc/main.dart';

void main() {
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

    final imported = parseImportedDocument(bytes, 'sample.docx');

    expect(imported.formatLabel, 'DOCX');
    expect(imported.text, contains('Executive summary'));
    expect(imported.text, contains('Open Doc reads DOCX content.'));
  });

  test('plain import supports text-like files', () {
    final imported = parseImportedDocument(
      Uint8List.fromList(utf8.encode('# Notes\nHello')),
      'notes.md',
    );

    expect(imported.formatLabel, 'Markdown');
    expect(imported.text, contains('Hello'));
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
    expect(find.byTooltip('Image'), findsOneWidget);
    expect(find.byTooltip('Video'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.checklist_outlined));
    await tester.pump();

    expect(find.textContaining('[ ] Action item'), findsWidgets);
    expect(find.text('Unsaved'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.image_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Insert image'), findsOneWidget);
    expect(find.text('Choose device image'), findsOneWidget);

    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace reference image'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.drag(find.byType(ListView).first, const Offset(-900, 0));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Brief'), findsWidgets);
    expect(find.byTooltip('Social'), findsOneWidget);
    expect(find.byTooltip('Source'), findsOneWidget);
    expect(find.byTooltip('Actions'), findsWidgets);
    expect(find.text('Millennial'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);

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
