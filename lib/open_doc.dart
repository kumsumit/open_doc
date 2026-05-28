/// Public entry point for the `open_doc` Flutter package.
///
/// Host apps pass a file path and choose a [OpenDocMode]. The package
/// loads the file and presents it in either a read-only viewer (with an
/// "Edit" button to flip into editing) or the full document editor.
///
/// ```dart
/// import 'package:open_doc/open_doc.dart';
///
/// OpenDocViewer(
///   filePath: '/path/to/file.docx',
///   mode: OpenDocMode.view,
/// );
/// ```
library;

export 'src/studio/document_studio.dart'
    show DocumentStudio, OpenDocViewer, OpenDocTabsHost, OpenDocMode;
