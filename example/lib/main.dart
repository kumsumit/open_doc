import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_doc/open_doc.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff2563eb);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Open Doc Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff4f7fb),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const _PickerScreen(),
    );
  }
}

class _PickerScreen extends StatefulWidget {
  const _PickerScreen();

  @override
  State<_PickerScreen> createState() => _PickerScreenState();
}

class _PickerScreenState extends State<_PickerScreen> {
  String? _path;
  OpenDocMode _mode = OpenDocMode.view;

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'docx', 'txt', 'md', 'markdown', 'rtf', 'html', 'htm', 'csv', 'odoc',
      ],
    );
    final path = result?.files.single.path;
    if (path != null) {
      setState(() => _path = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_path != null) {
      return OpenDocViewer(filePath: _path!, mode: _mode);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Open Doc Example')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<OpenDocMode>(
              segments: const [
                ButtonSegment(
                  value: OpenDocMode.view,
                  icon: Icon(Icons.visibility_outlined),
                  label: Text('View'),
                ),
                ButtonSegment(
                  value: OpenDocMode.edit,
                  icon: Icon(Icons.edit_outlined),
                  label: Text('Edit'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open a document'),
            ),
          ],
        ),
      ),
    );
  }
}
