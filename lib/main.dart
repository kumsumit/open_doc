import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_rich_text_quill/smart_rich_text_quill.dart';

import 'src/document/document_export_service.dart';
import 'src/document/document_import_service.dart';
import 'src/document/document_models.dart';
import 'src/data/document_templates.dart';
import 'src/ui/editor_intents.dart';
import 'src/ui/editor_workspace.dart';
import 'src/ui/ribbon.dart';
import 'src/ui/side_panels.dart';
import 'src/ui/common_controls.dart';
import 'src/ui/top_bar.dart';

void main() {
  runApp(const OpenDocApp());
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class OpenDocApp extends StatelessWidget {
  const OpenDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff2563eb);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Open Doc',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff4f7fb),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const DocumentStudio(),
    );
  }
}

class DocumentStudio extends StatefulWidget {
  const DocumentStudio({super.key});

  @override
  State<DocumentStudio> createState() => _DocumentStudioState();
}

class _DocumentStudioState extends State<DocumentStudio> {
  final TextEditingController _titleController = TextEditingController(
    text: 'Project proposal',
  );
  late SrqController _srqController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();
  final DocumentExportService _exportService = const DocumentExportService();
  final DocumentImportService _importService = const DocumentImportService();
  int _currentMatchIndex = -1;

  bool _showRuler = true;
  bool _showNavigation = true;
  bool _showInspector = true;
  bool _trackChanges = true;
  bool _commentsMode = true;
  bool _focusMode = false;
  bool _saved = true;
  double _fontSize = 16;
  double _zoom = 1;
  String _fontFamily = 'Aptos';
  String _style = 'Body';
  String _alignment = 'Left';
  String _permission = 'Can comment';
  String _template = 'Proposal';
  String _activeVersion = 'v1';
  String _audienceProfile = 'Millennial';
  String _toneMode = 'Clear';
  DocumentPageSize _pageSize = DocumentPageSize.a4;
  DocumentPageOrientation _pageOrientation = DocumentPageOrientation.portrait;
  DocumentMarginPreset _marginPreset = DocumentMarginPreset.normal;
  Color _inkColor = const Color(0xff111827);
  Color _pageColor = Colors.white;
  DateTime _savedAt = DateTime.now();
  final List<MediaBlock> _mediaBlocks = [];
  final List<CustomFontFile> _customFonts = [];
  String? _sourcePackageFormat;
  Uint8List? _sourcePackageBytes;
  DocumentEditMode _editMode = DocumentEditMode.markdown;
  final List<DocumentVersion> _versions = [];
  final List<Collaborator> _collaborators = const [
    Collaborator('Asha', 'Editing', Color(0xff2563eb)),
    Collaborator('Legal', 'Commenting', Color(0xff047857)),
    Collaborator('Mina', 'Viewing', Color(0xffb45309)),
  ];

  @override
  void initState() {
    super.initState();
    _srqController = SrqControllerFactory.create(
      initialMarkdown: starterDocument,
    );
    _srqController.addListener(_refresh);
    _titleController.addListener(_refresh);
    _searchController.addListener(_refresh);
    _captureVersion('Created first draft');
  }

  @override
  void dispose() {
    _srqController
      ..removeListener(_refresh)
      ..dispose();
    _titleController
      ..removeListener(_refresh)
      ..dispose();
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    _replaceController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() => _saved = false);
  }

  // ─── Selection-aware format state (computed from SrqController) ──────────────

  bool get _bold => _srqController.selectionBoldActive;
  bool get _italic => _srqController.selectionItalicActive;
  bool get _underline => _srqController.selectionUnderlineActive;
  bool get _strikethrough => _srqController.selectionStrikethroughActive;

  // ─── Document text helpers ────────────────────────────────────────────────────

  String get _markdownText => _srqController.markdown;

  String get _plainText {
    return _markdownText
        .replaceAll(RegExp(r'\*\*|~~|\*|<u>|</u>|`'), '')
        .replaceAll(RegExp(r'^#{1,3} ', multiLine: true), '')
        .replaceAll(
          RegExp(r'^\* \[ \] |^\* |^- |\d+\. |^> ', multiLine: true),
          '',
        );
  }

  // ─── Document statistics ──────────────────────────────────────────────────────

  int get _wordCount {
    final matches = RegExp(r"\b[\w'-]+\b").allMatches(_plainText);
    return matches.length;
  }

  int get _characterCount => _plainText.length;

  int get _readingMinutes => math.max(1, (_wordCount / 220).ceil());

  int get _sentenceCount {
    final matches = RegExp(r'[^.!?]+[.!?]').allMatches(_plainText);
    return math.max(1, matches.length);
  }

  int get _averageSentenceLength =>
      math.max(1, (_wordCount / _sentenceCount).round());

  int get _clarityScore {
    final sentencePenalty = math.max(0, _averageSentenceLength - 18) * 2;
    final lengthPenalty = _wordCount > 900 ? 8 : 0;
    final score = 96 - sentencePenalty - lengthPenalty + (_headings.length * 2);
    return score.clamp(42, 100);
  }

  int get _attentionScore {
    final mediaBoost = math.min(12, _mediaBlocks.length * 4);
    final listBoost = RegExp(
      r'(^|\n)(\*\s|\-\s|[0-9]+\.|\*\s\[)',
    ).allMatches(_markdownText).length.clamp(0, 8);
    final score = 58 + mediaBoost + listBoost + (_headings.length * 3);
    return score.clamp(35, 100);
  }

  int get _sourceCount {
    return RegExp(
      r'https?://|doi:|Source:',
      caseSensitive: false,
    ).allMatches(_markdownText).length;
  }

  int get _citationNudgeCount {
    final numberClaims = RegExp(
      r'\b\d{2,}(%|x|k|m| billion| million)?\b',
      caseSensitive: false,
    ).allMatches(_plainText).length;
    return math.max(0, numberClaims - _sourceCount);
  }

  List<String> get _actionItems {
    final lines = _markdownText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines
        .where(
          (line) =>
              line.startsWith('* [ ]') ||
              line.startsWith('- [ ]') ||
              line.toLowerCase().startsWith('todo') ||
              line.toLowerCase().contains('follow up') ||
              line.toLowerCase().contains('owner:'),
        )
        .take(5)
        .toList();
  }

  int get _searchMatches {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return 0;
    return RegExp(
      RegExp.escape(query),
    ).allMatches(_markdownText.toLowerCase()).length;
  }

  List<(int, int)> get _allMatchPositions {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return [];
    return RegExp(RegExp.escape(query))
        .allMatches(_markdownText.toLowerCase())
        .map((m) => (m.start, m.end))
        .toList();
  }

  void _findNext() {
    final positions = _allMatchPositions;
    if (positions.isEmpty) return;
    final next = (_currentMatchIndex + 1) % positions.length;
    setState(() => _currentMatchIndex = next);
    final (start, end) = positions[next];
    _srqController.textController.selection = TextSelection(
      baseOffset: start,
      extentOffset: end,
    );
    _editorFocusNode.requestFocus();
  }

  void _findPrev() {
    final positions = _allMatchPositions;
    if (positions.isEmpty) return;
    final idx = _currentMatchIndex <= 0
        ? positions.length - 1
        : _currentMatchIndex - 1;
    setState(() => _currentMatchIndex = idx);
    final (start, end) = positions[idx];
    _srqController.textController.selection = TextSelection(
      baseOffset: start,
      extentOffset: end,
    );
    _editorFocusNode.requestFocus();
  }

  void _replaceOne() {
    final positions = _allMatchPositions;
    if (positions.isEmpty) return;
    final idx = _currentMatchIndex.clamp(0, positions.length - 1);
    final (start, end) = positions[idx];
    final replacement = _replaceController.text;
    final newText = _markdownText.replaceRange(start, end, replacement);
    _srqController.setMarkdown(newText);
    setState(
      () => _currentMatchIndex = idx.clamp(0, _allMatchPositions.length - 1),
    );
  }

  void _replaceAll() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final replacement = _replaceController.text;
    final newText = _markdownText.replaceAll(
      RegExp(RegExp.escape(query), caseSensitive: false),
      replacement,
    );
    _srqController.setMarkdown(newText);
    setState(() => _currentMatchIndex = -1);
  }

  Future<void> _exportToFile(String format) async {
    final title = _titleController.text
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    if (format == 'docx') {
      await _exportToDocx(title.isEmpty ? 'Untitled document' : title);
      return;
    }
    if (format == 'pdf') {
      await _exportToPdf(title.isEmpty ? 'Untitled document' : title);
      return;
    }
    if (format == 'html') {
      await _exportToHtml(title.isEmpty ? 'Untitled document' : title);
      return;
    }
    if (format == 'odoc') {
      await _exportToOpenDoc(title.isEmpty ? 'Untitled document' : title);
      return;
    }

    String content;
    String ext;
    if (format == 'markdown') {
      content = _markdownText;
      ext = 'md';
    } else {
      content = '${_titleController.text}\n\n$_plainText';
      ext = 'txt';
    }
    try {
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save $ext file',
        fileName: '$title.$ext',
        bytes: Uint8List.fromList(content.codeUnits),
      );
      if (savePath != null) {
        await File(savePath).writeAsString(content);
        _showSnack('Saved to $savePath');
      }
    } catch (e) {
      _showSnack('Export failed: $e');
    }
  }

  Future<void> _exportToDocx(String title) async {
    try {
      if (_editMode == DocumentEditMode.docxRoundTrip &&
          _sourcePackageFormat == 'docx' &&
          _sourcePackageBytes != null) {
        final savePath = await FilePicker.saveFile(
          dialogTitle: 'Save DOCX file',
          fileName: '$title.docx',
          bytes: _sourcePackageBytes!,
        );
        if (savePath != null) {
          await File(savePath).writeAsBytes(_sourcePackageBytes!);
          _showSnack('Saved original styled DOCX to $savePath');
        }
        return;
      }
      final bytes = await _exportService.exportDocx(_exportPayload);
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save DOCX file',
        fileName: '$title.docx',
        bytes: bytes,
      );
      if (savePath != null) {
        await File(savePath).writeAsBytes(bytes);
        _showSnack('Saved DOCX to $savePath');
      }
    } catch (e) {
      _showSnack('DOCX export failed: $e');
    }
  }

  Future<void> _exportToPdf(String title) async {
    try {
      final bytes = await _exportService.exportPdf(_exportPayload);
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save PDF file',
        fileName: '$title.pdf',
        bytes: bytes,
      );
      if (savePath != null) {
        await File(savePath).writeAsBytes(bytes);
        _showSnack('Saved PDF to $savePath');
      }
    } catch (e) {
      _showSnack('PDF export failed: $e');
    }
  }

  Future<void> _exportToHtml(String title) async {
    try {
      final bytes = await _exportService.exportHtml(_exportPayload);
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save HTML file',
        fileName: '$title.html',
        bytes: bytes,
      );
      if (savePath != null) {
        await File(savePath).writeAsBytes(bytes);
        _showSnack('Saved HTML to $savePath');
      }
    } catch (e) {
      _showSnack('HTML export failed: $e');
    }
  }

  Future<void> _exportToOpenDoc(String title) async {
    try {
      final bytes = await _exportService.exportOpenDoc(_exportPayload);
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save Open Doc file',
        fileName: '$title.odoc',
        bytes: bytes,
      );
      if (savePath != null) {
        await File(savePath).writeAsBytes(bytes);
        _showSnack('Saved Open Doc to $savePath');
      }
    } catch (e) {
      _showSnack('Open Doc export failed: $e');
    }
  }

  DocumentExportPayload get _exportPayload {
    return DocumentExportPayload(
      title: _titleController.text,
      markdown: _markdownText,
      pageSetup: DocumentPageSetup(
        pageSize: _pageSize,
        orientation: _pageOrientation,
        marginPreset: _marginPreset,
      ),
      mediaBlocks: _mediaBlocks
          .map(
            (block) => ExportMediaBlock(
              type: block.type == MediaType.image
                  ? ExportMediaType.image
                  : ExportMediaType.video,
              source: block.source,
              caption: block.caption,
              hasBytes: block.bytes != null,
              bytes: block.bytes,
            ),
          )
          .toList(),
      customFonts: List<CustomFontFile>.of(_customFonts),
      selectedFontFamily: _fontFamily,
      sourcePackageFormat: _sourcePackageFormat,
      sourcePackageBytes: _sourcePackageBytes,
    );
  }

  List<String> get _fontFamilies => [
    'Aptos',
    'Arial',
    'Georgia',
    'Times',
    for (final font in _customFonts) font.family,
  ];

  List<String> get _headings {
    return _markdownText
        .split('\n')
        .where((line) => RegExp(r'^#{1,3} .+').hasMatch(line.trim()))
        .map((line) => line.replaceAll(RegExp(r'^#+\s*'), '').trim())
        .take(8)
        .toList();
  }

  TextAlign get _textAlign {
    switch (_alignment) {
      case 'Center':
        return TextAlign.center;
      case 'Right':
        return TextAlign.right;
      case 'Justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  TextStyle get _editorStyle => TextStyle(
    color: _inkColor,
    fontFamily: _fontFamily == 'Aptos' ? null : _fontFamily,
    fontSize: _fontSize,
    height: 1.55,
  );

  void _insertText(String value) {
    final selection = _srqController.textController.selection;
    if (selection.isValid) {
      _srqController.insertAtCursor(value);
    } else {
      _srqController.setMarkdown('$_markdownText$value');
    }
    _editorFocusNode.requestFocus();
  }

  void _captureVersion(String label) {
    final nextVersion = 'v${_versions.length + 1}';
    _activeVersion = nextVersion;
    _versions.insert(
      0,
      DocumentVersion(
        nextVersion,
        label,
        _titleController.text,
        _markdownText,
        List<MediaBlock>.of(_mediaBlocks),
        DateTime.now(),
        _wordCount,
      ),
    );
    _savedAt = DateTime.now();
    _saved = true;
  }

  void _saveDocument() {
    setState(() => _captureVersion('Saved ${_titleController.text}'));
    _showSnack('Saved locally as $_activeVersion.');
  }

  void _newDocument() {
    _srqController.setMarkdownSilently('');
    setState(() {
      _titleController.text = 'Untitled document';
      _style = 'Body';
      _fontSize = 16;
      _zoom = 1;
      _template = 'Blank';
      _mediaBlocks.clear();
      _customFonts.clear();
      _sourcePackageFormat = null;
      _sourcePackageBytes = null;
      _editMode = DocumentEditMode.markdown;
      _captureVersion('Started blank document');
    });
    _editorFocusNode.requestFocus();
  }

  void _duplicateDocument() {
    setState(() {
      _titleController.text = '${_titleController.text} copy';
    });
    _showSnack('A working copy is ready.');
  }

  Future<void> _pickAndInsertMedia(MediaType type) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: type.allowedExtensions,
        withData: true,
      );
      final picked = result?.files.single;
      final bytes = picked?.bytes;
      if (picked == null || bytes == null) {
        return;
      }

      setState(() {
        _mediaBlocks.add(
          MediaBlock(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: type,
            source: picked.name,
            caption: _importService.titleFromFileName(picked.name),
            bytes: bytes,
          ),
        );
        _saved = false;
      });
      _showSnack(
        type == MediaType.image
            ? 'Device image inserted.'
            : 'Device video inserted.',
      );
    } catch (_) {
      _showSnack(
        type == MediaType.image
            ? 'Could not insert that image.'
            : 'Could not insert that video.',
      );
    }
  }

  Future<void> _pickAndImportFont() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['ttf', 'otf'],
        withData: true,
      );
      final picked = result?.files.single;
      final bytes = picked?.bytes;
      if (picked == null || bytes == null) {
        return;
      }

      final font = CustomFontFile(
        family: _fontFamilyFromFileName(picked.name),
        source: picked.name,
        bytes: bytes,
      );
      await _registerCustomFont(font);
      setState(() {
        _customFonts.removeWhere((existing) => existing.family == font.family);
        _customFonts.add(font);
        _fontFamily = font.family;
        _saved = false;
      });
      _showSnack('Imported font ${font.family}.');
    } catch (e) {
      _showSnack('Could not import that font: $e');
    }
  }

  Future<void> _registerCustomFont(CustomFontFile font) async {
    final loader = FontLoader(font.family)
      ..addFont(Future.value(ByteData.sublistView(font.bytes)));
    await loader.load();
  }

  String _fontFamilyFromFileName(String fileName) {
    final baseName = fileName.split(RegExp(r'[/\\]')).last;
    final withoutExtension = baseName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final cleaned = withoutExtension
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'Custom Font' : cleaned;
  }

  void _showMediaSheet(MediaType type) {
    final urlController = TextEditingController(
      text: type == MediaType.image
          ? 'https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=1200'
          : 'https://videos.open-doc.local/project-overview.mp4',
    );
    final captionController = TextEditingController(
      text: type == MediaType.image
          ? 'Workspace reference image'
          : 'Project overview video',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final title = type == MediaType.image ? 'Insert image' : 'Insert video';
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _pickAndInsertMedia(type);
                  },
                  icon: Icon(
                    type == MediaType.image
                        ? Icons.add_photo_alternate_outlined
                        : Icons.video_library_outlined,
                  ),
                  label: Text(
                    type == MediaType.image
                        ? 'Choose device image'
                        : 'Choose device video',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    type == MediaType.image
                        ? Icons.image_outlined
                        : Icons.smart_display_outlined,
                  ),
                  labelText: type == MediaType.image
                      ? 'Image URL'
                      : 'Video URL or embed link',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: captionController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.closed_caption_outlined),
                  labelText: 'Caption',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.getData(Clipboard.kTextPlain).then((data) {
                        urlController.text = data?.text ?? urlController.text;
                      });
                    },
                    icon: const Icon(Icons.content_paste_outlined),
                    label: const Text('Paste URL'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      final source = urlController.text.trim();
                      if (source.isEmpty) {
                        _showSnack('Add a media URL first.');
                        return;
                      }
                      Navigator.of(context).pop();
                      setState(() {
                        _mediaBlocks.add(
                          MediaBlock(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            type: type,
                            source: source,
                            caption: captionController.text.trim(),
                            bytes: null,
                          ),
                        );
                        _saved = false;
                      });
                      _showSnack(
                        type == MediaType.image
                            ? 'Image inserted.'
                            : 'Video embed inserted.',
                      );
                    },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Insert'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeMediaBlock(String id) {
    setState(() {
      _mediaBlocks.removeWhere((block) => block.id == id);
      _saved = false;
    });
    _showSnack('Media removed from document.');
  }

  Future<void> _applyImportedDocument({
    required String name,
    required String text,
    required String format,
    String? title,
    String? selectedFontFamily,
    List<MediaBlock> mediaBlocks = const [],
    List<CustomFontFile> customFonts = const [],
    String? sourcePackageFormat,
    Uint8List? sourcePackageBytes,
    DocumentPageSetup? pageSetup,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      _showSnack('No readable text found in $name.');
      return;
    }

    _srqController.setMarkdownSilently(cleanText);
    for (final font in customFonts) {
      await _registerCustomFont(font);
    }
    setState(() {
      _titleController.text = title?.trim().isNotEmpty == true
          ? title!.trim()
          : _importService.titleFromFileName(name);
      _template = 'Imported $format';
      _mediaBlocks
        ..clear()
        ..addAll(mediaBlocks);
      _customFonts
        ..clear()
        ..addAll(customFonts);
      _sourcePackageFormat = sourcePackageFormat;
      _sourcePackageBytes = sourcePackageBytes;
      _editMode = sourcePackageBytes != null && sourcePackageFormat == 'docx'
          ? DocumentEditMode.docxRoundTrip
          : DocumentEditMode.markdown;
      final importedFamily = selectedFontFamily?.trim();
      if (importedFamily != null &&
          importedFamily.isNotEmpty &&
          _fontFamilies.contains(importedFamily)) {
        _fontFamily = importedFamily;
      } else if (_customFonts.isNotEmpty) {
        _fontFamily = _customFonts.first.family;
      }
      if (pageSetup != null) {
        _pageSize = pageSetup.pageSize;
        _pageOrientation = pageSetup.orientation;
        _marginPreset = pageSetup.marginPreset;
      }
      _captureVersion('Imported $format file');
    });
    _editorFocusNode.requestFocus();
    _showSnack('Imported $name.');
  }

  Future<void> _pickAndImportFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'docx',
          'txt',
          'md',
          'markdown',
          'rtf',
          'html',
          'htm',
          'csv',
          'odoc',
        ],
        withData: true,
      );
      final picked = result?.files.single;
      final bytes = picked?.bytes;
      if (picked == null || bytes == null) {
        return;
      }

      final imported = _importService.parse(bytes, picked.name);
      await _applyImportedDocument(
        name: picked.name,
        text: imported.text,
        format: imported.formatLabel,
        title: imported.title,
        selectedFontFamily: imported.selectedFontFamily,
        mediaBlocks: imported.mediaBlocks,
        pageSetup: imported.pageSetup,
        customFonts: imported.customFonts,
        sourcePackageFormat: imported.sourcePackageFormat,
        sourcePackageBytes: imported.sourcePackageBytes,
      );
    } on FormatException catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Could not import that file yet.');
    }
  }

  void _showImportSheet() {
    final importController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import document',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                'Supports DOCX, TXT, Markdown, RTF, HTML, and CSV.',
                style: TextStyle(color: Color(0xff64748b)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _pickAndImportFile();
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Choose file'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: importController,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'Paste text, markdown, or copied DOCX content...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.getData(Clipboard.kTextPlain).then((data) {
                        importController.text = data?.text ?? '';
                      });
                    },
                    icon: const Icon(Icons.content_paste_outlined),
                    label: const Text('Paste'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      final text = importController.text.trim();
                      if (text.isEmpty) {
                        _showSnack('Paste content before importing.');
                        return;
                      }
                      Navigator.of(context).pop();
                      _applyImportedDocument(
                        name: 'Pasted text',
                        text: text,
                        format: 'text',
                      );
                    },
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTemplateSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Templates', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in templateLibrary.entries)
                    TemplateTile(
                      label: entry.key,
                      selected: entry.key == _template,
                      onTap: () {
                        Navigator.of(context).pop();
                        _srqController.setMarkdownSilently(entry.value);
                        setState(() {
                          _template = entry.key;
                          _titleController.text = entry.key;
                          _mediaBlocks.clear();
                          _sourcePackageFormat = null;
                          _sourcePackageBytes = null;
                          _editMode = DocumentEditMode.markdown;
                          _style = 'Body';
                          _captureVersion('Applied ${entry.key} template');
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share document',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  for (final collaborator in _collaborators)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: collaborator.color,
                        child: Text(
                          collaborator.name.substring(0, 1),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(collaborator.name),
                      subtitle: Text(collaborator.status),
                    ),
                  const Divider(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'Can view',
                        icon: Icon(Icons.visibility_outlined),
                        label: Text('View'),
                      ),
                      ButtonSegment(
                        value: 'Can comment',
                        icon: Icon(Icons.rate_review_outlined),
                        label: Text('Comment'),
                      ),
                      ButtonSegment(
                        value: 'Can edit',
                        icon: Icon(Icons.edit_outlined),
                        label: Text('Edit'),
                      ),
                    ],
                    selected: {_permission},
                    onSelectionChanged: (value) {
                      setState(() => _permission = value.first);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text:
                              'https://open-doc.local/${Uri.encodeComponent(_titleController.text)}',
                        ),
                      );
                      Navigator.of(context).pop();
                      _showSnack('Share link copied with $_permission access.');
                    },
                    icon: const Icon(Icons.link_outlined),
                    label: const Text('Copy share link'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showVersionHistorySheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version history',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _versions.length,
                  itemBuilder: (context, index) {
                    final version = _versions[index];
                    return ListTile(
                      leading: Icon(
                        version.id == _activeVersion
                            ? Icons.radio_button_checked
                            : Icons.history_outlined,
                      ),
                      title: Text(version.label),
                      subtitle: Text(
                        '${version.id} • ${version.wordCount} words • ${_formatTime(version.createdAt)}',
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _srqController.setMarkdownSilently(version.body);
                          setState(() {
                            _activeVersion = version.id;
                            _titleController.text = version.title;
                            _mediaBlocks
                              ..clear()
                              ..addAll(version.mediaBlocks);
                            _saved = true;
                          });
                          _showSnack('Restored ${version.id}.');
                        },
                        child: const Text('Restore'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _acceptAllChanges() {
    setState(() {
      _trackChanges = false;
      _captureVersion('Accepted review changes');
    });
    _showSnack('Changes accepted and versioned.');
  }

  void _rejectAllChanges() {
    if (_versions.isEmpty) return;
    final previous = _versions.last;
    _srqController.setMarkdownSilently(previous.body);
    setState(() {
      _titleController.text = previous.title;
      _mediaBlocks
        ..clear()
        ..addAll(previous.mediaBlocks);
      _trackChanges = false;
      _saved = true;
    });
    _showSnack('Draft reset to the original version.');
  }

  String _smartBriefText() {
    final firstParagraph = _plainText
        .split('\n')
        .map((line) => line.trim())
        .firstWhere(
          (line) => line.length > 80,
          orElse: () => _plainText.trim(),
        );
    final clean = firstParagraph.replaceAll(RegExp(r'\s+'), ' ');
    final summary = clean.length > 190
        ? '${clean.substring(0, 190)}...'
        : clean;
    return 'Smart brief for $_audienceProfile readers\n\n'
        'Tone: $_toneMode\n'
        'Read time: $_readingMinutes min\n'
        'Clarity: $_clarityScore/100\n'
        'Attention: $_attentionScore/100\n\n'
        '$summary';
  }

  void _showSmartBriefSheet() {
    final brief = _smartBriefText();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart brief',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SelectableText(brief),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: brief));
                      Navigator.of(context).pop();
                      _showSnack('Smart brief copied.');
                    },
                    icon: const Icon(Icons.content_copy_outlined),
                    label: const Text('Copy'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _insertText('\n\n$brief\n');
                    },
                    icon: const Icon(Icons.add_outlined),
                    label: const Text('Insert'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _copySocialSummary() {
    final text =
        '${_titleController.text}: ${_smartBriefText().split('\n').last}\n\nRead time: $_readingMinutes min • Clarity $_clarityScore/100';
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Share-ready summary copied.');
  }

  void _insertCitationNudge() {
    _insertText(
      '\nSource: paste link, DOI, dataset, or interview note here.\n',
    );
    _showSnack('Source placeholder inserted.');
  }

  void _insertActionDigest() {
    final actions = _actionItems.isEmpty
        ? ['[ ] Add owner, due date, and next step.']
        : _actionItems;
    _insertText('\n\nAction digest\n${actions.join('\n')}\n');
  }

  void _insertPageBreak() {
    _insertText('\n\n[[PAGE_BREAK]]\n\n');
    _showSnack('Page break inserted.');
  }

  void _insertTableOfContents() {
    _insertText('\n\n[[TOC]]\n\n');
    _showSnack('Table of contents inserted.');
  }

  void _insertFootnote() {
    _insertText(
      '\n\n[[FOOTNOTE:Add source, citation, or explanatory note.]]\n\n',
    );
    _showSnack('Footnote placeholder inserted.');
  }

  void _insertEndnote() {
    _insertText('\n\n[[ENDNOTE:Add appendix note or closing reference.]]\n\n');
    _showSnack('Endnote placeholder inserted.');
  }

  void _insertHorizontalRule() {
    _insertText('\n\n[[HR]]\n\n');
    _showSnack('Horizontal rule inserted.');
  }

  void _insertDropCap() {
    _insertText('\n\n[[DROP_CAP:Once upon a time, start this section.]]\n\n');
    _showSnack('Drop cap block inserted.');
  }

  void _insertShape() {
    _showShapePaletteSheet();
  }

  void _insertLink() {
    _insertText('\n\n[[LINK:Reference|https://example.com]]\n\n');
    _showSnack('Link placeholder inserted.');
  }

  void _switchRoundTripToMarkdown() {
    setState(() {
      _editMode = DocumentEditMode.markdown;
      _sourcePackageFormat = null;
      _sourcePackageBytes = null;
      _saved = false;
    });
    _editorFocusNode.requestFocus();
    _showSnack(
      'Switched to Markdown editing. Future exports use the edited content.',
    );
  }

  void _showAdvancedTableSheet() {
    var rows = 4;
    var columns = 4;
    var mergeHeader = true;
    var shadeHeader = true;
    var perCellBorders = true;
    var borderStyle = 'single';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget stepper({
              required String label,
              required int value,
              required ValueChanged<int> onChanged,
              required int min,
              required int max,
            }) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  IconButton(
                    tooltip: 'Decrease $label',
                    onPressed: value <= min ? null : () => onChanged(value - 1),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(width: 28, child: Center(child: Text('$value'))),
                  IconButton(
                    tooltip: 'Increase $label',
                    onPressed: value >= max ? null : () => onChanged(value + 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Advanced table',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      stepper(
                        label: 'Rows',
                        value: rows,
                        min: 1,
                        max: 12,
                        onChanged: (value) => setSheetState(() => rows = value),
                      ),
                      stepper(
                        label: 'Columns',
                        value: columns,
                        min: 1,
                        max: 8,
                        onChanged: (value) =>
                            setSheetState(() => columns = value),
                      ),
                      DropdownChip(
                        value: borderStyle,
                        values: const ['single', 'double', 'dashed', 'dotted'],
                        width: 120,
                        onChanged: (value) =>
                            setSheetState(() => borderStyle = value),
                      ),
                      FilterChip(
                        label: const Text('Merged header'),
                        selected: mergeHeader,
                        onSelected: (value) =>
                            setSheetState(() => mergeHeader = value),
                      ),
                      FilterChip(
                        label: const Text('Header fill'),
                        selected: shadeHeader,
                        onSelected: (value) =>
                            setSheetState(() => shadeHeader = value),
                      ),
                      FilterChip(
                        label: const Text('Per-cell borders'),
                        selected: perCellBorders,
                        onSelected: (value) =>
                            setSheetState(() => perCellBorders = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _insertText(
                          '\n\n[[ADV_TABLE:rows=$rows;cols=$columns;mergeHeader=$mergeHeader;shadeHeader=$shadeHeader;perCellBorders=$perCellBorders;border=$borderStyle]]\n\n',
                        );
                        _showSnack('Advanced table inserted.');
                      },
                      icon: const Icon(Icons.table_chart_outlined),
                      label: const Text('Insert'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showShapePaletteSheet() {
    const presets = [
      'rect',
      'roundRect',
      'ellipse',
      'triangle',
      'rtTriangle',
      'parallelogram',
      'trapezoid',
      'diamond',
      'pentagon',
      'hexagon',
      'heptagon',
      'octagon',
      'star4',
      'star5',
      'star6',
      'heart',
      'cloud',
      'lightning',
      'arrow',
      'leftArrow',
      'rightArrow',
      'upArrow',
      'downArrow',
      'leftRightArrow',
      'upDownArrow',
      'line',
      'straightConnector1',
      'bentConnector2',
      'bentConnector3',
      'curvedConnector2',
      'curvedConnector3',
      'callout1',
      'callout2',
      'callout3',
      'borderCallout1',
      'borderCallout2',
      'borderCallout3',
      'ribbon',
      'ribbon2',
      'chevron',
      'plus',
      'minus',
      'cross',
      'cube',
      'can',
      'donut',
      'noSmoking',
      'blockArc',
      'wedgeRectCallout',
      'wedgeRoundRectCallout',
      'wedgeEllipseCallout',
      'flowChartProcess',
      'flowChartAlternateProcess',
      'flowChartDecision',
      'flowChartInputOutput',
      'flowChartPredefinedProcess',
      'flowChartDocument',
      'flowChartMultidocument',
      'flowChartTerminator',
      'flowChartConnector',
      'flowChartExtract',
      'flowChartMerge',
      'bevel',
      'foldedCorner',
      'smileyFace',
      'sun',
      'moon',
      'bracePair',
      'bracketPair',
      'actionButtonHome',
      'actionButtonHelp',
      'actionButtonInformation',
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * .72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shape palette',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 48,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: presets.length,
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      return OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _insertText('\n\n[[SHAPE:$preset:$preset]]\n\n');
                          _showSnack('Shape inserted.');
                        },
                        icon: const Icon(Icons.category_outlined, size: 18),
                        label: Text(preset, overflow: TextOverflow.ellipsis),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationPanel({required VoidCallback onClose}) {
    return NavigationRailPanel(
      headings: _headings,
      searchController: _searchController,
      replaceController: _replaceController,
      searchMatches: _searchMatches,
      currentMatchIndex: _currentMatchIndex,
      onFindNext: _findNext,
      onFindPrev: _findPrev,
      onReplaceOne: _replaceOne,
      onReplaceAll: _replaceAll,
      onClose: onClose,
    );
  }

  Widget _buildInspectorPanel({required VoidCallback onClose}) {
    return InspectorPanel(
      wordCount: _wordCount,
      characterCount: _characterCount,
      readingMinutes: _readingMinutes,
      commentsMode: _commentsMode,
      trackChanges: _trackChanges,
      permission: _permission,
      template: _template,
      savedAt: _savedAt,
      activeVersion: _activeVersion,
      collaborators: _collaborators,
      versions: _versions,
      mediaCount: _mediaBlocks.length,
      imageCount: _mediaBlocks
          .where((block) => block.type == MediaType.image)
          .length,
      videoCount: _mediaBlocks
          .where((block) => block.type == MediaType.video)
          .length,
      audienceProfile: _audienceProfile,
      toneMode: _toneMode,
      clarityScore: _clarityScore,
      attentionScore: _attentionScore,
      averageSentenceLength: _averageSentenceLength,
      sourceCount: _sourceCount,
      citationNudgeCount: _citationNudgeCount,
      actionItems: _actionItems,
      onSave: _saveDocument,
      onShare: _showShareSheet,
      onHistory: _showVersionHistorySheet,
      onSmartBrief: _showSmartBriefSheet,
      onActionDigest: _insertActionDigest,
      onCommentsToggle: () => setState(() => _commentsMode = !_commentsMode),
      onTrackChangesToggle: () =>
          setState(() => _trackChanges = !_trackChanges),
      onPermissionChange: (v) => setState(() => _permission = v),
      onAudienceProfileChange: (v) => setState(() => _audienceProfile = v),
      onToneModeChange: (v) => setState(() => _toneMode = v),
      onClose: onClose,
    );
  }

  void _showNavigationSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * .76,
          child: _buildNavigationPanel(
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  void _showInspectorSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * .82,
          child: _buildInspectorPanel(
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showExportSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export document',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ExportTile(
                    icon: Icons.description_outlined,
                    label: 'DOCX',
                    onTap: () => _finishExport(context, 'DOCX'),
                  ),
                  ExportTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Open Doc',
                    onTap: () => _finishExport(context, 'Open Doc'),
                  ),
                  ExportTile(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF',
                    onTap: () => _finishExport(context, 'PDF'),
                  ),
                  ExportTile(
                    icon: Icons.html_outlined,
                    label: 'HTML',
                    onTap: () => _finishExport(context, 'HTML'),
                  ),
                  ExportTile(
                    icon: Icons.text_snippet_outlined,
                    label: 'Plain text',
                    onTap: () => _finishExport(context, 'Plain text'),
                  ),
                  ExportTile(
                    icon: Icons.code_outlined,
                    label: 'Markdown',
                    onTap: () => _finishExport(context, 'Markdown'),
                  ),
                  ExportTile(
                    icon: Icons.link_outlined,
                    label: 'Share link',
                    onTap: () => _finishExport(context, 'share link'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _finishExport(BuildContext sheetContext, String type) {
    Navigator.of(sheetContext).pop();
    if (type == 'DOCX') {
      _exportToFile('docx');
    } else if (type == 'Open Doc') {
      _exportToFile('odoc');
    } else if (type == 'PDF') {
      _exportToFile('pdf');
    } else if (type == 'HTML') {
      _exportToFile('html');
    } else if (type == 'Markdown') {
      _exportToFile('markdown');
    } else if (type == 'Plain text') {
      _exportToFile('text');
    } else {
      final mediaNote = _mediaBlocks.isEmpty
          ? ''
          : ' with ${_mediaBlocks.length} media block${_mediaBlocks.length == 1 ? '' : 's'}';
      _showSnack('$type export queued$mediaNote.');
    }
  }

  void _copyPlainText() {
    final mediaText = _mediaBlocks
        .map(
          (block) =>
              '[${block.type.label}: ${block.caption.isEmpty ? block.source : block.caption}] ${block.source}',
        )
        .join('\n');
    Clipboard.setData(
      ClipboardData(
        text:
            '${_titleController.text}\n\n$_plainText'
            '${mediaText.isEmpty ? '' : '\n\nMedia\n$mediaText'}',
      ),
    );
    _showSnack('Document copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyB, control: true):
            ToggleBoldIntent(),
        SingleActivator(LogicalKeyboardKey.keyI, control: true):
            ToggleItalicIntent(),
        SingleActivator(LogicalKeyboardKey.keyU, control: true):
            ToggleUnderlineIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
            ToggleStrikethroughIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): RedoIntent(),
      },
      child: Actions(
        actions: {
          ToggleBoldIntent: CallbackAction<ToggleBoldIntent>(
            onInvoke: (_) {
              _srqController.toggleBold();
              setState(() {});
              return null;
            },
          ),
          ToggleItalicIntent: CallbackAction<ToggleItalicIntent>(
            onInvoke: (_) {
              _srqController.toggleItalic();
              setState(() {});
              return null;
            },
          ),
          ToggleUnderlineIntent: CallbackAction<ToggleUnderlineIntent>(
            onInvoke: (_) {
              _srqController.toggleUnderline();
              setState(() {});
              return null;
            },
          ),
          ToggleStrikethroughIntent: CallbackAction<ToggleStrikethroughIntent>(
            onInvoke: (_) {
              _srqController.toggleStrikethrough();
              setState(() {});
              return null;
            },
          ),
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              _srqController.undo();
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              _srqController.redo();
              return null;
            },
          ),
        },
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 900;
                final showLeft = _showNavigation && !compact && !_focusMode;
                final showRight = _showInspector && !compact && !_focusMode;

                return Column(
                  children: [
                    TopBar(
                      titleController: _titleController,
                      focusMode: _focusMode,
                      saved: _saved,
                      onNew: _newDocument,
                      onSave: _saveDocument,
                      onImport: _showImportSheet,
                      onTemplates: _showTemplateSheet,
                      onDuplicate: _duplicateDocument,
                      onCopy: _copyPlainText,
                      onShare: _showShareSheet,
                      onHistory: _showVersionHistorySheet,
                      onExport: _showExportSheet,
                      onToggleFocus: () =>
                          setState(() => _focusMode = !_focusMode),
                    ),
                    if (!_focusMode)
                      Ribbon(
                        bold: _bold,
                        italic: _italic,
                        underline: _underline,
                        strikethrough: _strikethrough,
                        showRuler: _showRuler,
                        trackChanges: _trackChanges,
                        commentsMode: _commentsMode,
                        fontSize: _fontSize,
                        zoom: _zoom,
                        fontFamily: _fontFamily,
                        fontFamilies: _fontFamilies,
                        style: _style,
                        alignment: _alignment,
                        audienceProfile: _audienceProfile,
                        toneMode: _toneMode,
                        pageSize: _pageSize,
                        pageOrientation: _pageOrientation,
                        marginPreset: _marginPreset,
                        inkColor: _inkColor,
                        pageColor: _pageColor,
                        onBold: () {
                          _srqController.toggleBold();
                          setState(() {});
                        },
                        onItalic: () {
                          _srqController.toggleItalic();
                          setState(() {});
                        },
                        onUnderline: () {
                          _srqController.toggleUnderline();
                          setState(() {});
                        },
                        onStrikethrough: () {
                          _srqController.toggleStrikethrough();
                          setState(() {});
                        },
                        onRuler: () => setState(() => _showRuler = !_showRuler),
                        onTrackChanges: () =>
                            setState(() => _trackChanges = !_trackChanges),
                        onCommentsMode: () =>
                            setState(() => _commentsMode = !_commentsMode),
                        onFontSize: (value) =>
                            setState(() => _fontSize = value),
                        onZoom: (value) => setState(() => _zoom = value),
                        onFontFamily: (value) =>
                            setState(() => _fontFamily = value),
                        onImportFont: _pickAndImportFont,
                        onStyle: (value) {
                          setState(() {
                            _style = value;
                            _fontSize = value == 'Title'
                                ? 28
                                : value == 'Heading'
                                ? 22
                                : 16;
                          });
                          switch (value) {
                            case 'Title':
                              _srqController.setHeading(1);
                            case 'Heading':
                              _srqController.setHeading(2);
                            case 'Quote':
                              _srqController.toggleBlockquote();
                            default:
                              _srqController.clearBlockFormat();
                          }
                        },
                        onAlignment: (value) =>
                            setState(() => _alignment = value),
                        onAudienceProfile: (value) =>
                            setState(() => _audienceProfile = value),
                        onToneMode: (value) =>
                            setState(() => _toneMode = value),
                        onPageSize: (value) =>
                            setState(() => _pageSize = value),
                        onPageOrientation: (value) =>
                            setState(() => _pageOrientation = value),
                        onMarginPreset: (value) =>
                            setState(() => _marginPreset = value),
                        onInkColor: (value) =>
                            setState(() => _inkColor = value),
                        onPageColor: (value) =>
                            setState(() => _pageColor = value),
                        onInsertTable: _showAdvancedTableSheet,
                        onInsertImage: () => _showMediaSheet(MediaType.image),
                        onInsertVideo: () => _showMediaSheet(MediaType.video),
                        onInsertChecklist: () =>
                            _insertText('\n* [ ] Action item\n'),
                        onInsertBulletList: () =>
                            _srqController.toggleBulletList(),
                        onInsertOrderedList: () =>
                            _srqController.toggleOrderedList(),
                        onInsertPageBreak: _insertPageBreak,
                        onInsertToc: _insertTableOfContents,
                        onInsertFootnote: _insertFootnote,
                        onInsertEndnote: _insertEndnote,
                        onInsertHorizontalRule: _insertHorizontalRule,
                        onInsertDropCap: _insertDropCap,
                        onInsertShape: _insertShape,
                        onInsertLink: _insertLink,
                        onInsertSignature: () => _insertText(
                          '\n\nRegards,\n${_titleController.text.split(' ').first}\n',
                        ),
                        onUndo: _srqController.undo,
                        onRedo: _srqController.redo,
                        onAcceptChanges: _acceptAllChanges,
                        onRejectChanges: _rejectAllChanges,
                        onSmartBrief: _showSmartBriefSheet,
                        onSocialSummary: _copySocialSummary,
                        onCitationNudge: _insertCitationNudge,
                        onActionDigest: _insertActionDigest,
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          if (showLeft)
                            SizedBox(
                              width: constraints.maxWidth < 1180 ? 236 : 268,
                              child: _buildNavigationPanel(
                                onClose: () =>
                                    setState(() => _showNavigation = false),
                              ),
                            ),
                          Expanded(
                            child: EditorWorkspace(
                              srqController: _srqController,
                              editorFocusNode: _editorFocusNode,
                              editorStyle: _editorStyle,
                              textAlign: _textAlign,
                              showRuler: _showRuler && !_focusMode,
                              pageColor: _pageColor,
                              zoom: _zoom,
                              focusMode: _focusMode,
                              wordCount: _wordCount,
                              readingMinutes: _readingMinutes,
                              characterCount: _characterCount,
                              editMode: _editMode,
                              sourcePackageFormat: _sourcePackageFormat,
                              onSwitchToMarkdown: _switchRoundTripToMarkdown,
                              mediaBlocks: _mediaBlocks,
                              onRemoveMedia: _removeMediaBlock,
                              onToggleNavigation: compact
                                  ? _showNavigationSheet
                                  : () => setState(
                                      () => _showNavigation = !_showNavigation,
                                    ),
                              onToggleInspector: compact
                                  ? _showInspectorSheet
                                  : () => setState(
                                      () => _showInspector = !_showInspector,
                                    ),
                            ),
                          ),
                          if (showRight)
                            SizedBox(
                              width: constraints.maxWidth < 1180 ? 264 : 292,
                              child: _buildInspectorPanel(
                                onClose: () =>
                                    setState(() => _showInspector = false),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
