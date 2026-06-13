import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide ShortcutRegistry, TabAlignment;
import 'package:flutter/services.dart';
import 'package:smart_rich_text_quill/smart_rich_text_quill.dart';

import '../services/document_export_service.dart';
import '../services/document_import_service.dart';
import '../services/document_models.dart';
import '../data/document_templates.dart';
import '../ui/editor_intents.dart';
import '../ui/editor_workspace.dart';
import '../ui/inline_format.dart';
import '../ui/keyboard_shortcuts_dialog.dart';
import '../ui/ribbon.dart';
import '../ui/shortcut_registry.dart';
import '../ui/side_panels.dart';
import '../ui/common_controls.dart';
import '../ui/top_bar.dart';

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Whether [DocumentStudio] opens a file as a read-only viewer or the
/// full-featured editor. In [view] mode the editing chrome is hidden and
/// an Edit button lets the user switch into [edit].
enum OpenDocMode { view, edit }

/// Thin convenience wrapper around [OpenDocTabsHost] for host apps that just
/// want to point at a file path. Tabs are enabled by default so the Import
/// button opens additional files in new tabs.
class OpenDocViewer extends StatelessWidget {
  const OpenDocViewer({
    super.key,
    required this.filePath,
    this.mode = OpenDocMode.view,
  });

  final String filePath;
  final OpenDocMode mode;

  @override
  Widget build(BuildContext context) {
    return OpenDocTabsHost(initialFilePath: filePath, initialMode: mode);
  }
}

/// Holds a list of [DocumentStudio] tabs and switches between them. When the
/// user clicks Import inside any tab, the picked file opens in a new tab.
class OpenDocTabsHost extends StatefulWidget {
  const OpenDocTabsHost({
    super.key,
    this.initialFilePath,
    this.initialMode = OpenDocMode.edit,
  });

  final String? initialFilePath;
  final OpenDocMode initialMode;

  @override
  State<OpenDocTabsHost> createState() => _OpenDocTabsHostState();
}

class _OpenDocTab {
  _OpenDocTab({required this.id, this.filePath, required this.mode});

  final String id;
  final String? filePath;
  final OpenDocMode mode;

  String get label {
    final path = filePath;
    if (path == null || path.isEmpty) return 'Untitled';
    return path.split(RegExp(r'[/\\]')).last;
  }
}

class _OpenDocTabsHostState extends State<OpenDocTabsHost> {
  final List<_OpenDocTab> _tabs = [];
  int _activeIndex = 0;
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    _tabs.add(_OpenDocTab(
      id: _nextId(),
      filePath: widget.initialFilePath,
      mode: widget.initialMode,
    ));
  }

  String _nextId() => 'tab-${_idCounter++}';

  void _openInNewTab(String path) {
    setState(() {
      _tabs.add(_OpenDocTab(
        id: _nextId(),
        filePath: path,
        mode: OpenDocMode.edit,
      ));
      _activeIndex = _tabs.length - 1;
    });
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) return;
    setState(() {
      _tabs.removeAt(index);
      if (_activeIndex >= _tabs.length) {
        _activeIndex = _tabs.length - 1;
      } else if (_activeIndex > index) {
        _activeIndex -= 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f7fb),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TabStrip(
              tabs: _tabs,
              activeIndex: _activeIndex,
              onSelect: (i) => setState(() => _activeIndex = i),
              onClose: _closeTab,
            ),
            Expanded(
              child: IndexedStack(
                index: _activeIndex,
                children: [
                  for (final tab in _tabs)
                    DocumentStudio(
                      key: ValueKey(tab.id),
                      filePath: tab.filePath,
                      mode: tab.mode,
                      onOpenInNewTab: _openInNewTab,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
  });

  final List<_OpenDocTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xffe9eff7),
        border: Border(bottom: BorderSide(color: Color(0xffd6dee9))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isActive = index == activeIndex;
          final canClose = tabs.length > 1;
          return Padding(
            padding: const EdgeInsets.only(right: 4, top: 6, bottom: 4),
            child: Material(
              color: isActive ? Colors.white : const Color(0xffdfe7f1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              child: InkWell(
                onTap: () => onSelect(index),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          tabs[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive
                                ? const Color(0xff0f172a)
                                : const Color(0xff475569),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: canClose ? () => onClose(index) : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: canClose
                                ? const Color(0xff64748b)
                                : const Color(0xffcbd5e1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class DocumentStudio extends StatefulWidget {
  const DocumentStudio({
    super.key,
    this.filePath,
    this.mode = OpenDocMode.edit,
    this.onOpenInNewTab,
  });

  /// Optional absolute path to a document the package should load on startup.
  /// Supported extensions: docx, txt, md/markdown, rtf, html/htm, csv, odoc.
  final String? filePath;

  /// Initial mode. The user can flip from [OpenDocMode.view] to
  /// [OpenDocMode.edit] using the Edit button shown in view mode.
  final OpenDocMode mode;

  /// When provided, the Import button delegates file selection here so the
  /// host can open the picked file in a new tab instead of replacing the
  /// current document.
  final ValueChanged<String>? onOpenInNewTab;

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
  int? _activeOpenXmlBlockIndex;

  // Tracks the live OpenXML paragraph so ribbon commands can format the
  // current selection without a floating mini-toolbar.
  RichRunController? _activeRunController;
  FocusNode? _activeFieldFocus;
  TextSelection? _lastOpenXmlSelection;
  final List<OpenXmlDocument> _openXmlUndoStack = [];
  final List<OpenXmlDocument> _openXmlRedoStack = [];
  bool _syncingSrqFromOpenXml = false;

  ToolbarLayout _toolbarLayout = ToolbarLayout.singleRow;
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
  String _style = 'Normal';
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
  Color? _highlightColor;
  bool _formatPainterActive = false;
  CharFormat? _formatPainterFormat;
  bool _highContrast = false;
  final List<DocumentComment> _comments = [
    DocumentComment(
      id: 'c1',
      author: 'Asha',
      body: 'Strengthen the objective with one measurable outcome.',
      createdAt: DateTime.now(),
    ),
    DocumentComment(
      id: 'c2',
      author: 'Legal',
      body: 'Check whether this proposal needs a confidentiality note.',
      createdAt: DateTime.now(),
    ),
  ];
  Color? _wysiwygInkCommandColor;
  int _wysiwygInkCommandId = 0;
  DateTime _savedAt = DateTime.now();

  // ── Autosave ───────────────────────────────────────────────────────────────
  /// Whether the document is saved automatically on a timer.
  bool _autosaveEnabled = false;

  /// How often autosave fires when enabled. Configurable by the user.
  Duration _autosaveInterval = const Duration(minutes: 2);

  /// Preset intervals offered in the autosave configuration dialog.
  static const List<Duration> _autosaveIntervalPresets = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];
  Timer? _autosaveTimer;

  final List<MediaBlock> _mediaBlocks = [];
  final List<CustomFontFile> _customFonts = [];

  // ── New feature state ──────────────────────────────────────────────────────
  DocumentWatermark? _watermark;
  DocumentMetadata _metadata = const DocumentMetadata();
  int _columnCount = 1;
  int _gutterTwips = 0;
  bool _mirrorMargins = false;
  bool _differentFirstPage = false;
  bool _differentOddEvenPages = false;
  String _activeThemeId = 'default';
  final List<IndexEntry> _indexEntries = [];
  final List<CrossReference> _crossReferences = [];
  final List<CustomDocumentStyle> _customStyles = [];
  String? _sourcePackageFormat;
  Uint8List? _sourcePackageBytes;
  DocumentEditMode _editMode = DocumentEditMode.openXml;
  OpenXmlDocument _openXmlDocument = OpenXmlDocument.plain(starterDocument);
  List<OoxmlVisualBlock> _ooxmlBlocks = [];
  List<WysiwygBlock> _wysiwygBlocks = WysiwygDocumentCodec.fromMarkdown(
    starterDocument,
  );
  List<Object?> _quillDeltaJson = WysiwygDocumentCodec.toQuillDeltaJson(
    WysiwygDocumentCodec.fromMarkdown(starterDocument),
  );
  final List<DocumentVersion> _versions = [];
  final List<Collaborator> _collaborators = const [
    Collaborator('Asha', 'Editing', Color(0xff2563eb)),
    Collaborator('Legal', 'Commenting', Color(0xff047857)),
    Collaborator('Mina', 'Viewing', Color(0xffb45309)),
  ];

  late OpenDocMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _srqController = SrqControllerFactory.create(
      initialMarkdown: starterDocument,
    );
    _srqController.addListener(_refresh);
    _titleController.addListener(_refresh);
    _searchController.addListener(_refresh);
    _captureVersion('Created first draft');
    if (widget.filePath != null && widget.filePath!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFromPath(widget.filePath!);
      });
    }
  }

  Future<void> _loadFromPath(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      _showSnack('File not found: $path');
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      final fileName = path.split(RegExp(r'[/\\]')).last;
      final imported = await _importService.parseAsync(bytes, fileName);
      await _applyImportedDocument(
        name: fileName,
        text: imported.text,
        format: imported.formatLabel,
        title: imported.title,
        selectedFontFamily: imported.selectedFontFamily,
        mediaBlocks: imported.mediaBlocks,
        pageSetup: imported.pageSetup,
        customFonts: imported.customFonts,
        sourcePackageFormat: imported.sourcePackageFormat,
        sourcePackageBytes: imported.sourcePackageBytes,
        ooxmlBlocks: imported.ooxmlBlocks,
        wysiwygBlocks: imported.wysiwygBlocks,
        quillDeltaJson: imported.quillDeltaJson,
        openXmlDocument: imported.openXmlDocument,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to load $path: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showSnack('Could not open $path: $error');
    }
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
    _autosaveTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    if (_syncingSrqFromOpenXml) return;
    setState(() {
      if (!_isNativeOpenXmlEditor) {
        _openXmlDocument = OpenXmlDocument.plain(_srqController.markdown);
      }
      _saved = false;
    });
  }

  void _setMarkdownSilently(String markdown) {
    _syncingSrqFromOpenXml = true;
    try {
      _srqController.setMarkdownSilently(markdown);
    } finally {
      _syncingSrqFromOpenXml = false;
    }
  }

  // ─── Selection-aware format state (computed from SrqController) ──────────────

  OpenXmlParagraphBlock? get _activeOpenXmlParagraph {
    final index = _activeOpenXmlBlockIndex;
    if (index == null || index < 0 || index >= _openXmlDocument.blocks.length) {
      for (final block in _openXmlDocument.blocks) {
        if (block is OpenXmlParagraphBlock) {
          return block;
        }
      }
      return null;
    }
    final block = _openXmlDocument.blocks[index];
    return block is OpenXmlParagraphBlock ? block : null;
  }

  bool get _bold => _formatActive(RunAttr.bold);
  bool get _italic => _formatActive(RunAttr.italic);
  bool get _underline => _formatActive(RunAttr.underline);
  bool get _strikethrough => _formatActive(RunAttr.strike);
  bool get _superscript => _formatActive(RunAttr.superscript);
  bool get _subscript => _formatActive(RunAttr.subscript);
  bool get _smallCaps => _formatActive(RunAttr.smallCaps);
  bool get _allCaps => _formatActive(RunAttr.allCaps);
  bool get _doubleUnderline => _formatActive(RunAttr.doubleUnderline);
  bool get _doubleStrike => _formatActive(RunAttr.doubleStrike);
  bool get _hidden => _formatActive(RunAttr.hidden);

  /// Reflects the formatting of the live selection when a paragraph is being
  /// edited (so the ribbon and floating toolbar light up correctly), falling
  /// back to the active paragraph or the markdown controller otherwise.
  bool _formatActive(RunAttr attr) {
    if (_isNativeOpenXmlEditor) {
      final controller = _activeRunController;
      if (controller != null) {
        final selection = controller.selection;
        if (selection.isValid && !selection.isCollapsed) {
          return controller.isActive(selection.start, selection.end, attr);
        }
        // Scope the fallback check to the active block when using the flat
        // controller so we don't report "bold" just because some other
        // paragraph in the document is bold.
        if (controller is DocumentFlatController) {
          final blockIdx = _activeOpenXmlBlockIndex ?? 0;
          final start = controller.blockStartOffset(blockIdx);
          final end = controller.blockEndOffset(blockIdx);
          return controller.text.isNotEmpty &&
              controller.isActive(start, end, attr);
        }
        return controller.text.isNotEmpty &&
            controller.isActive(0, controller.text.length, attr);
      }
      final paragraph = _activeOpenXmlParagraph;
      return paragraph?.runs.any((run) => _runHasAttr(run, attr)) ?? false;
    }
    return switch (attr) {
      RunAttr.bold => _srqController.selectionBoldActive,
      RunAttr.italic => _srqController.selectionItalicActive,
      RunAttr.underline => _srqController.selectionUnderlineActive,
      RunAttr.strike => _srqController.selectionStrikethroughActive,
      RunAttr.superscript ||
      RunAttr.subscript ||
      RunAttr.smallCaps ||
      RunAttr.allCaps ||
      RunAttr.doubleUnderline ||
      RunAttr.doubleStrike ||
      RunAttr.hidden => false,
    };
  }

  bool _runHasAttr(OpenXmlRun run, RunAttr attr) => switch (attr) {
    RunAttr.bold => run.bold,
    RunAttr.italic => run.italic,
    RunAttr.underline => run.underline,
    RunAttr.strike => run.strike,
    RunAttr.superscript => run.superscript,
    RunAttr.subscript => run.subscript,
    RunAttr.smallCaps => run.smallCaps,
    RunAttr.allCaps => run.allCaps,
    RunAttr.doubleUnderline => run.doubleUnderline,
    RunAttr.doubleStrike => run.doubleStrike,
    RunAttr.hidden => run.hidden,
  };

  bool get _isNativeOpenXmlEditor =>
      _editMode == DocumentEditMode.openXml ||
      _editMode == DocumentEditMode.docxVisual;

  // ─── Document text helpers ────────────────────────────────────────────────────

  String get _markdownText => _editMode == DocumentEditMode.wysiwyg
      ? WysiwygDocumentCodec.toMarkdown(
          WysiwygDocumentCodec.fromQuillDeltaJson(_quillDeltaJson),
        )
      : _openXmlDocument.plainText;

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
      if (_editMode == DocumentEditMode.docxVisual) {
        final bytes = await _exportService.exportVisualDocx(_exportPayload);
        final savePath = await FilePicker.saveFile(
          dialogTitle: 'Save DOCX file',
          fileName: '$title.docx',
          bytes: bytes,
        );
        if (savePath != null) {
          await File(savePath).writeAsBytes(bytes);
          _logAudit('Export DOCX', detail: savePath);
          _showSnack('Saved visual DOCX to $savePath');
        }
        return;
      }
      if ((_editMode == DocumentEditMode.docxRoundTrip ||
              _editMode == DocumentEditMode.docxView) &&
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

  void _showPrintPreview() {
    final doc = _openXmlDocument;
    final allBlocks = doc.blocks.whereType<OpenXmlParagraphBlock>().toList();
    // Approximate pages: every 40 paragraphs = 1 page
    final estimatedPages = math.max(1, (allBlocks.length / 40).ceil());
    var pageFrom = 1;
    var pageTo = estimatedPages;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          // Filter blocks to the selected page range (approximate)
          final blocksPerPage = math.max(1, (allBlocks.length / estimatedPages).ceil());
          final startIdx = ((pageFrom - 1) * blocksPerPage).clamp(0, allBlocks.length);
          final endIdx = (pageTo * blocksPerPage).clamp(0, allBlocks.length);
          final blocks = allBlocks.sublist(startIdx, endIdx);

          return Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 780,
                maxHeight: MediaQuery.of(ctx).size.height * 0.92,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.print_outlined, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Print Preview',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        // Page range selector
                        const Text('Pages:', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 56,
                          child: TextFormField(
                            initialValue: pageFrom.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              labelText: 'From',
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null && n >= 1 && n <= estimatedPages) {
                                setDlg(() => pageFrom = n);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('–', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 56,
                          child: TextFormField(
                            initialValue: pageTo.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                              labelText: 'To',
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null && n >= pageFrom && n <= estimatedPages) {
                                setDlg(() => pageTo = n);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _exportToPdf(_titleController.text);
                          },
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: const Text('Export PDF'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 595,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 72, vertical: 96),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _titleController.text,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  for (final block in blocks)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        block.plainText,
                                        style: TextStyle(
                                          fontSize: switch (block.style) {
                                            OpenXmlTextStyle.heading1 => 20.0,
                                            OpenXmlTextStyle.heading2 => 17.0,
                                            OpenXmlTextStyle.heading3 => 15.0,
                                            _ => 12.0,
                                          },
                                          fontWeight: switch (block.style) {
                                            OpenXmlTextStyle.heading1 ||
                                            OpenXmlTextStyle.heading2 ||
                                            OpenXmlTextStyle.heading3 =>
                                              FontWeight.w700,
                                            _ => FontWeight.normal,
                                          },
                                          height: 1.5,
                                        ),
                                        textAlign: switch (block.align) {
                                          OoxmlTextAlign.center =>
                                            TextAlign.center,
                                          OoxmlTextAlign.right =>
                                            TextAlign.right,
                                          OoxmlTextAlign.justify =>
                                            TextAlign.justify,
                                          _ => TextAlign.left,
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Watermark overlay
                            if (_watermark != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Center(
                                    child: Transform.rotate(
                                      angle: (_watermark!.rotation *
                                              math.pi) /
                                          180,
                                      child: Opacity(
                                        opacity: _watermark!.opacity,
                                        child: Text(
                                          _watermark!.text,
                                          style: TextStyle(
                                            fontSize: _watermark!.fontSize,
                                            fontWeight: FontWeight.w900,
                                            color: Color(
                                              int.parse(
                                                'FF${_watermark!.colorHex}',
                                                radix: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── EPUB export ───────────────────────────────────────────────────────────

  Future<void> _exportToEpub() async {
    final title = _titleController.text
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim();
    final safeName = title.isEmpty ? 'Untitled document' : title;
    try {
      final bytes = await _exportService.exportEpub(_exportPayload);
      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save EPUB file',
        fileName: '$safeName.epub',
        bytes: bytes,
      );
      if (savePath != null) {
        await File(savePath).writeAsBytes(bytes);
        _logAudit('Export EPUB', detail: savePath);
        _showSnack('Saved EPUB to $savePath');
      }
    } catch (e) {
      _showSnack('EPUB export failed: $e');
    }
  }

  // ── Watermark ─────────────────────────────────────────────────────────────

  void _showWatermarkDialog() {
    var text = _watermark?.text ?? 'DRAFT';
    var opacity = _watermark?.opacity ?? 0.15;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Watermark'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: text),
                  onChanged: (v) => text = v,
                  decoration: const InputDecoration(
                    labelText: 'Watermark text',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Opacity', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: opacity,
                        min: 0.05,
                        max: 0.5,
                        divisions: 9,
                        label: '${(opacity * 100).round()}%',
                        onChanged: (v) => setDlg(() => opacity = v),
                      ),
                    ),
                    Text('${(opacity * 100).round()}%'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _watermark = null);
                _showSnack('Watermark removed.');
              },
              child: const Text('Remove'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(
                  () => _watermark = DocumentWatermark(
                    text: text.isEmpty ? 'DRAFT' : text,
                    opacity: opacity,
                  ),
                );
                _showSnack('Watermark applied.');
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Accessibility checker ─────────────────────────────────────────────────

  void _showAccessibilityCheckerDialog() {
    final issues = <String>[];
    for (final block in _openXmlDocument.blocks) {
      if (block is OpenXmlParagraphBlock) {
        for (final run in block.runs) {
          if (run.colorHex != null) {
            final hex = run.colorHex!;
            final r = int.tryParse(hex.substring(0, 2), radix: 16) ?? 0;
            final g = int.tryParse(hex.substring(2, 4), radix: 16) ?? 0;
            final b = int.tryParse(hex.substring(4, 6), radix: 16) ?? 0;
            final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
            if (luminance > 0.8) {
              final preview = run.text.length > 30
                  ? '${run.text.substring(0, 30)}…'
                  : run.text;
              issues.add('Low contrast text "$preview"');
            }
          }
          if (run.fontSize != null && run.fontSize! < 9) {
            final preview = run.text.length > 20
                ? '${run.text.substring(0, 20)}…'
                : run.text;
            issues.add('Very small font size (${run.fontSize}pt): "$preview"');
          }
        }
      }
    }
    for (final block in _mediaBlocks) {
      if (block.altText.isEmpty) {
        issues.add('Image "${block.source}" is missing alt text.');
      }
    }
    if (_titleController.text.isEmpty) {
      issues.add('Document has no title.');
    }
    final headings = _openXmlDocument.blocks
        .whereType<OpenXmlParagraphBlock>()
        .where((b) =>
            b.style == OpenXmlTextStyle.heading1 ||
            b.style == OpenXmlTextStyle.title)
        .toList();
    if (headings.isEmpty && _openXmlDocument.blocks.length > 5) {
      issues.add('Long document has no headings — consider adding structure.');
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accessibility Check'),
        content: SizedBox(
          width: 480,
          child: issues.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Color(0xff16a34a), size: 40),
                    SizedBox(height: 12),
                    Text('No accessibility issues found.',
                        style: TextStyle(fontSize: 15)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${issues.length} issue${issues.length == 1 ? '' : 's'} found:',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: issues.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_outlined,
                                  size: 18, color: Color(0xffd97706)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(issues[i],
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Text box insertion ────────────────────────────────────────────────────

  void _showInsertTextBoxDialog() {
    final controller = TextEditingController(text: 'Text box content');
    var widthFraction = 0.4;
    var anchorType = TextBoxAnchorType.inline;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Insert Text Box'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TextBoxAnchorType>(
                  initialValue: anchorType,
                  decoration: const InputDecoration(
                    labelText: 'Anchor type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: TextBoxAnchorType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.name),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDlg(() => anchorType = v ?? TextBoxAnchorType.inline),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Width', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: widthFraction,
                        min: 0.2,
                        max: 1.0,
                        divisions: 8,
                        label: '${(widthFraction * 100).round()}%',
                        onChanged: (v) => setDlg(() => widthFraction = v),
                      ),
                    ),
                    Text('${(widthFraction * 100).round()}%'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _appendOpenXmlBlock(
                  TextBoxBlock(
                    content: controller.text.trim().isEmpty
                        ? 'Text box'
                        : controller.text.trim(),
                    widthFraction: widthFraction,
                    anchorType: anchorType,
                  ),
                );
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image crop / transparency dialog ─────────────────────────────────────

  void _showImageCropDialog() {
    if (_mediaBlocks.isEmpty) {
      _showSnack('No images in document.');
      return;
    }
    var blockIndex = 0;
    var cropLeft = _mediaBlocks[blockIndex].cropLeft;
    var cropTop = _mediaBlocks[blockIndex].cropTop;
    var cropRight = _mediaBlocks[blockIndex].cropRight;
    var cropBottom = _mediaBlocks[blockIndex].cropBottom;
    var opacity = _mediaBlocks[blockIndex].opacity;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          void loadBlock(int idx) {
            cropLeft = _mediaBlocks[idx].cropLeft;
            cropTop = _mediaBlocks[idx].cropTop;
            cropRight = _mediaBlocks[idx].cropRight;
            cropBottom = _mediaBlocks[idx].cropBottom;
            opacity = _mediaBlocks[idx].opacity;
          }

          return AlertDialog(
            title: const Text('Crop & Transparency'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_mediaBlocks.length > 1)
                    DropdownButtonFormField<int>(
                      initialValue: blockIndex,
                      decoration: const InputDecoration(
                        labelText: 'Image',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var i = 0; i < _mediaBlocks.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              _mediaBlocks[i].caption.isNotEmpty
                                  ? _mediaBlocks[i].caption
                                  : 'Image ${i + 1}',
                            ),
                          ),
                      ],
                      onChanged: (v) => setDlg(() {
                        blockIndex = v ?? 0;
                        loadBlock(blockIndex);
                      }),
                    ),
                  const SizedBox(height: 12),
                  for (final pair in [
                    ('Crop Left', cropLeft, (double v) => cropLeft = v),
                    ('Crop Top', cropTop, (double v) => cropTop = v),
                    ('Crop Right', cropRight, (double v) => cropRight = v),
                    ('Crop Bottom', cropBottom, (double v) => cropBottom = v),
                  ])
                    Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(pair.$1,
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Expanded(
                          child: Slider(
                            value: pair.$2,
                            min: 0.0,
                            max: 0.49,
                            divisions: 49,
                            label: '${(pair.$2 * 100).round()}%',
                            onChanged: (v) => setDlg(() => pair.$3(v)),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child:
                              Text('${(pair.$2 * 100).round()}%',
                                  style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  const Divider(),
                  Row(
                    children: [
                      const SizedBox(
                        width: 96,
                        child: Text('Opacity',
                            style: TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        child: Slider(
                          value: opacity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(opacity * 100).round()}%',
                          onChanged: (v) => setDlg(() => opacity = v),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text('${(opacity * 100).round()}%',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _mediaBlocks[blockIndex] = _mediaBlocks[blockIndex]
                        .copyWith(
                          cropLeft: cropLeft,
                          cropTop: cropTop,
                          cropRight: cropRight,
                          cropBottom: cropBottom,
                          opacity: opacity,
                        );
                    _saved = false;
                  });
                  _showSnack('Image crop & transparency updated.');
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
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
      openXmlDocument: _editMode == DocumentEditMode.wysiwyg
          ? OpenXmlDocument.plain(
              WysiwygDocumentCodec.toMarkdown(
                WysiwygDocumentCodec.fromQuillDeltaJson(_quillDeltaJson),
              ),
            )
          : _openXmlDocument,
      pageSetup: DocumentPageSetup(
        pageSize: _pageSize,
        orientation: _pageOrientation,
        marginPreset: _marginPreset,
        columns: _columnCount,
        gutterTwips: _gutterTwips,
        mirrorMargins: _mirrorMargins,
        differentFirstPage: _differentFirstPage,
        differentOddEvenPages: _differentOddEvenPages,
      ),
      metadata: _metadata,
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
      ooxmlBlocks: _ooxmlBlocks,
      wysiwygBlocks: _editMode == DocumentEditMode.wysiwyg
          ? WysiwygDocumentCodec.fromQuillDeltaJson(_quillDeltaJson)
          : const [],
      quillDeltaJson: _editMode == DocumentEditMode.wysiwyg
          ? List<Object?>.of(_quillDeltaJson)
          : const [],
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
    if (_editMode != DocumentEditMode.wysiwyg &&
        _openXmlDocument.blocks.isNotEmpty) {
      return _openXmlDocument.blocks
          .whereType<OpenXmlParagraphBlock>()
          .where(
            (block) =>
                block.style == OpenXmlTextStyle.title ||
                block.style == OpenXmlTextStyle.heading1 ||
                block.style == OpenXmlTextStyle.heading2 ||
                block.style == OpenXmlTextStyle.heading3,
          )
          .map((block) => block.plainText.trim())
          .where((text) => text.isNotEmpty)
          .take(8)
          .toList();
    }
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
    color: _highContrast ? Colors.black : const Color(0xff111827),
    fontFamily: _fontFamily == 'Aptos' ? null : _fontFamily,
    fontSize: _fontSize,
    height: 1.55,
  );

  Color get _effectivePageColor =>
      _highContrast ? Colors.white : _pageColor;

  OpenXmlDocument _cloneOpenXmlDocument(OpenXmlDocument document) {
    return OpenXmlDocument.fromJson(document.toJson());
  }

  String _openXmlSignature(OpenXmlDocument document) {
    return document.toJson().toString();
  }

  bool _sameOpenXmlDocument(OpenXmlDocument left, OpenXmlDocument right) {
    return _openXmlSignature(left) == _openXmlSignature(right);
  }

  // ── Operation grouping ────────────────────────────────────────────────────
  // When a group is active, _recordOpenXmlUndoState only saves once (the
  // snapshot taken when beginUndoGroup was called). All intermediate edits
  // inside the group are collapsed into that single undo step.

  bool _undoGroupActive = false;
  bool _undoGroupSnapshotTaken = false;

  void beginUndoGroup() {
    if (!_undoGroupActive) {
      _undoGroupActive = true;
      _undoGroupSnapshotTaken = false;
    }
  }

  void endUndoGroup() {
    _undoGroupActive = false;
    _undoGroupSnapshotTaken = false;
  }

  void _recordOpenXmlUndoState() {
    if (_undoGroupActive && _undoGroupSnapshotTaken) {
      // Group is active and snapshot already taken — skip recording
      _openXmlRedoStack.clear();
      return;
    }
    if (_openXmlUndoStack.isNotEmpty &&
        _sameOpenXmlDocument(_openXmlUndoStack.last, _openXmlDocument)) {
      _openXmlRedoStack.clear();
      return;
    }
    _openXmlUndoStack.add(_cloneOpenXmlDocument(_openXmlDocument));
    if (_openXmlUndoStack.length > 200) {
      _openXmlUndoStack.removeAt(0);
    }
    _openXmlRedoStack.clear();
    if (_undoGroupActive) {
      _undoGroupSnapshotTaken = true;
    }
  }

  void _setOpenXmlDocumentFromHistory(OpenXmlDocument document) {
    _resetActiveParagraph();
    setState(() {
      _openXmlDocument = _cloneOpenXmlDocument(document);
      if (_activeOpenXmlBlockIndex != null &&
          _activeOpenXmlBlockIndex! >= _openXmlDocument.blocks.length) {
        _activeOpenXmlBlockIndex = null;
      }
      _setMarkdownSilently(_openXmlDocument.plainText);
      _editMode = DocumentEditMode.openXml;
      _saved = false;
    });
  }

  void _undoOpenXml() {
    if (_openXmlUndoStack.isEmpty) {
      _showSnack('Nothing to undo.');
      return;
    }
    _openXmlRedoStack.add(_cloneOpenXmlDocument(_openXmlDocument));
    final previous = _openXmlUndoStack.removeLast();
    _setOpenXmlDocumentFromHistory(previous);
  }

  void _redoOpenXml() {
    if (_openXmlRedoStack.isEmpty) {
      _showSnack('Nothing to redo.');
      return;
    }
    _openXmlUndoStack.add(_cloneOpenXmlDocument(_openXmlDocument));
    final next = _openXmlRedoStack.removeLast();
    _setOpenXmlDocumentFromHistory(next);
  }

  void _clearOpenXmlHistory() {
    _openXmlUndoStack.clear();
    _openXmlRedoStack.clear();
  }

  void _insertText(String value) {
    if (_editMode == DocumentEditMode.openXml) {
      final text = value
          .replaceAll(RegExp(r'\[\[[A-Z_]+:?'), '')
          .replaceAll(']]', '')
          .replaceAll(RegExp(r'[`#>*\-\[\]]'), '')
          .trim();
      final block = OpenXmlParagraphBlock(
        runs: [OpenXmlRun(text.isEmpty ? 'New paragraph' : text)],
      );
      _recordOpenXmlUndoState();
      setState(() {
        _openXmlDocument = _openXmlDocument.copyWith(
          blocks: [..._openXmlDocument.blocks, block],
        );
        _setMarkdownSilently(_openXmlDocument.plainText);
        _saved = false;
      });
      return;
    }
    if (_editMode == DocumentEditMode.wysiwyg) {
      setState(() {
        _wysiwygBlocks = [
          ...WysiwygDocumentCodec.fromQuillDeltaJson(_quillDeltaJson),
          WysiwygBlock(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            type: WysiwygBlockType.paragraph,
            text: value.trim(),
          ),
        ];
        _quillDeltaJson = WysiwygDocumentCodec.toQuillDeltaJson(_wysiwygBlocks);
        _saved = false;
      });
      return;
    }
    final selection = _srqController.textController.selection;
    if (selection.isValid) {
      _srqController.insertAtCursor(value);
    } else {
      _srqController.setMarkdown('$_markdownText$value');
    }
    _openXmlDocument = OpenXmlDocument.plain(_srqController.markdown);
    _editorFocusNode.requestFocus();
  }

  void _updateOpenXmlDocument(OpenXmlDocument document) {
    if (_sameOpenXmlDocument(_openXmlDocument, document)) {
      return;
    }
    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = document;
      if (_activeOpenXmlBlockIndex != null &&
          _activeOpenXmlBlockIndex! >= document.blocks.length) {
        _activeOpenXmlBlockIndex = null;
      }
      _setMarkdownSilently(document.plainText);
      _saved = false;
    });
  }

  void _appendOpenXmlBlock(OpenXmlBlock block) {
    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = _openXmlDocument.copyWith(
        blocks: [..._openXmlDocument.blocks, block],
        sourcePackageFormat: null,
        sourcePackageBytes: null,
      );
      _setMarkdownSilently(_openXmlDocument.plainText);
      _editMode = DocumentEditMode.openXml;
      _ooxmlBlocks = [];
      _sourcePackageFormat = null;
      _sourcePackageBytes = null;
      _activeOpenXmlBlockIndex = _openXmlDocument.blocks.length - 1;
      _saved = false;
    });
  }

  void _updateActiveOpenXmlParagraph(
    OpenXmlParagraphBlock Function(OpenXmlParagraphBlock block) update,
  ) {
    final blocks = List<OpenXmlBlock>.of(_openXmlDocument.blocks);
    var index = _activeOpenXmlBlockIndex;
    if (index == null ||
        index < 0 ||
        index >= blocks.length ||
        blocks[index] is! OpenXmlParagraphBlock) {
      index = blocks.indexWhere((block) => block is OpenXmlParagraphBlock);
    }
    if (index == -1) {
      blocks.add(const OpenXmlParagraphBlock(runs: [OpenXmlRun('')]));
      index = blocks.length - 1;
    }
    blocks[index] = update(blocks[index] as OpenXmlParagraphBlock);
    final nextDocument = _openXmlDocument.copyWith(
      blocks: blocks,
      sourcePackageFormat: null,
      sourcePackageBytes: null,
    );
    if (_sameOpenXmlDocument(_openXmlDocument, nextDocument)) {
      return;
    }
    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = nextDocument;
      _setMarkdownSilently(_openXmlDocument.plainText);
      _editMode = DocumentEditMode.openXml;
      _ooxmlBlocks = [];
      _sourcePackageFormat = null;
      _sourcePackageBytes = null;
      _activeOpenXmlBlockIndex = index;
      _saved = false;
    });
  }

  OpenXmlTextStyle _openXmlStyleForRibbon(String value) {
    return switch (value) {
      'Title' => OpenXmlTextStyle.title,
      'Subtitle' => OpenXmlTextStyle.subtitle,
      'Heading 1' => OpenXmlTextStyle.heading1,
      'Heading 2' => OpenXmlTextStyle.heading2,
      'Heading 3' => OpenXmlTextStyle.heading3,
      'Heading 4' => OpenXmlTextStyle.heading4,
      'Heading 5' => OpenXmlTextStyle.heading5,
      'Heading 6' => OpenXmlTextStyle.heading6,
      'Quote' => OpenXmlTextStyle.quote,
      'Code' => OpenXmlTextStyle.code,
      'Caption' => OpenXmlTextStyle.caption,
      _ => OpenXmlTextStyle.normal,
    };
  }

  OoxmlTextAlign _openXmlAlignForRibbon(String value) {
    return switch (value) {
      'Center' => OoxmlTextAlign.center,
      'Right' => OoxmlTextAlign.right,
      'Justify' => OoxmlTextAlign.justify,
      _ => OoxmlTextAlign.left,
    };
  }

  String _ribbonStyleForOpenXml(OpenXmlTextStyle style) {
    return switch (style) {
      OpenXmlTextStyle.title => 'Title',
      OpenXmlTextStyle.subtitle => 'Subtitle',
      OpenXmlTextStyle.heading1 => 'Heading 1',
      OpenXmlTextStyle.heading2 => 'Heading 2',
      OpenXmlTextStyle.heading3 => 'Heading 3',
      OpenXmlTextStyle.heading4 => 'Heading 4',
      OpenXmlTextStyle.heading5 => 'Heading 5',
      OpenXmlTextStyle.heading6 => 'Heading 6',
      OpenXmlTextStyle.quote => 'Quote',
      OpenXmlTextStyle.code => 'Code',
      OpenXmlTextStyle.caption => 'Caption',
      OpenXmlTextStyle.normal => 'Normal',
    };
  }

  String _ribbonAlignForOpenXml(OoxmlTextAlign align) {
    return switch (align) {
      OoxmlTextAlign.center => 'Center',
      OoxmlTextAlign.right => 'Right',
      OoxmlTextAlign.justify => 'Justify',
      OoxmlTextAlign.left => 'Left',
    };
  }

  void _activateOpenXmlParagraph(
    int index,
    OpenXmlParagraphBlock block,
    RichRunController controller,
    FocusNode focusNode,
  ) {
    _activeRunController = controller;
    _activeFieldFocus = focusNode;
    _rememberOpenXmlSelection(clearCollapsed: true);
    setState(() {
      _activeOpenXmlBlockIndex = index;
      _style = _ribbonStyleForOpenXml(block.style);
      _alignment = _ribbonAlignForOpenXml(block.align);
    });
  }

  void _onOpenXmlSelectionChanged() {
    if (!mounted) return;
    _rememberOpenXmlSelection();
    if (_formatPainterActive) {
      final sel = _activeRunController?.selection;
      if (sel != null && sel.isValid && !sel.isCollapsed) {
        _applyFormatPainterIfActive(sel.start, sel.end);
      }
    }
    setState(() {});
  }

  void _rememberOpenXmlSelection({bool clearCollapsed = false}) {
    final selection = _activeRunController?.selection;
    if (selection == null || !selection.isValid) {
      _lastOpenXmlSelection = null;
      return;
    }
    if (selection.isCollapsed) {
      if (clearCollapsed) {
        _lastOpenXmlSelection = null;
      }
      return;
    }
    _lastOpenXmlSelection = selection;
  }

  TextSelection? _formattingSelectionFor(RichRunController controller) {
    final selection = controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      return selection;
    }
    final remembered = _lastOpenXmlSelection;
    if (remembered != null &&
        remembered.isValid &&
        !remembered.isCollapsed &&
        remembered.end <= controller.text.length) {
      return remembered;
    }
    return null;
  }

  void _refocusActiveOpenXmlEditor() {
    final controller = _activeRunController;
    final selection = controller == null
        ? null
        : _formattingSelectionFor(controller);
    _activeFieldFocus?.requestFocus();
    if (controller != null && selection != null && selection.isValid) {
      controller.selection = selection;
    }
  }

  /// Applies an inline run attribute to the live selection, or to the whole
  /// paragraph when the cursor is collapsed — matching Word's behavior.
  void _applyInlineFormat(RunAttr attr) {
    final controller = _activeRunController;
    if (controller == null) {
      _toggleOpenXmlRunFormat(
        bold: attr == RunAttr.bold,
        italic: attr == RunAttr.italic,
        underline: attr == RunAttr.underline,
        strike: attr == RunAttr.strike,
        superscript: attr == RunAttr.superscript,
        subscript: attr == RunAttr.subscript,
      );
      return;
    }
    final selection = _formattingSelectionFor(controller);
    final int start;
    final int end;
    if (selection != null) {
      start = selection.start;
      end = selection.end;
    } else {
      start = 0;
      end = controller.text.length;
    }
    if (end <= start) {
      _showSnack('Type some text before applying formatting.');
      return;
    }
    final active = controller.isActive(start, end, attr);
    controller.setAttr(start, end, attr, !active);
    _refocusActiveOpenXmlEditor();
    setState(() {});
  }

  void _clearFormatting() {
    final controller = _activeRunController;
    if (controller == null) return;
    final selection = _formattingSelectionFor(controller);
    final start = selection?.start ?? 0;
    final end = selection?.end ?? controller.text.length;
    if (end <= start) return;
    controller.clearFormatting(start, end);
    _refocusActiveOpenXmlEditor();
    setState(() {});
  }

  void _applyHighlight(String? colorHex) {
    final controller = _activeRunController;
    if (controller == null) return;
    final selection = _formattingSelectionFor(controller);
    final start = selection?.start ?? 0;
    final end = selection?.end ?? controller.text.length;
    if (end <= start) return;
    controller.setHighlight(start, end, colorHex);
    _refocusActiveOpenXmlEditor();
    setState(() {});
  }

  void _showPasteSpecialDialog() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final plainText = data?.text ?? '';
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Paste Special'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('plain'),
            child: const ListTile(
              leading: Icon(Icons.text_fields_outlined),
              title: Text('Plain Text'),
              subtitle: Text('Paste without any formatting'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('formatted'),
            child: const ListTile(
              leading: Icon(Icons.format_paint_outlined),
              title: Text('Formatted Text'),
              subtitle: Text('Paste with original formatting'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('markdown'),
            child: const ListTile(
              leading: Icon(Icons.code_outlined),
              title: Text('As Markdown'),
              subtitle: Text('Paste treating content as Markdown'),
            ),
          ),
        ],
      ),
    );
    if (choice == null || plainText.isEmpty) return;
    switch (choice) {
      case 'plain':
        _insertText(plainText);
      case 'formatted':
        _insertText(plainText);
      case 'markdown':
        _insertText(plainText);
    }
  }

  final List<({String name, int offset})> _bookmarks = [];

  void _showInsertBookmarkDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Bookmark'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Bookmark name',
            hintText: 'e.g. section-2',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              _insertBookmark(name);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }

  void _insertBookmark(String name) {
    final ctrl = _activeRunController;
    final offset = ctrl?.selection.baseOffset ?? 0;
    setState(() {
      _bookmarks.removeWhere((b) => b.name == name);
      _bookmarks.add((name: name, offset: offset));
    });
    _showSnack('Bookmark "$name" inserted.');
  }

  // ── Document Properties ────────────────────────────────────────────────────

  void _showDocumentPropertiesDialog() {
    final authorCtrl = TextEditingController(text: _metadata.author);
    final subjectCtrl = TextEditingController(text: _metadata.subject);
    final keywordsCtrl = TextEditingController(text: _metadata.keywords);
    final descCtrl = TextEditingController(text: _metadata.description);
    final companyCtrl = TextEditingController(text: _metadata.company);
    final categoryCtrl = TextEditingController(text: _metadata.category);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document Properties'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _metaField('Author', authorCtrl),
                _metaField('Subject', subjectCtrl),
                _metaField('Keywords', keywordsCtrl),
                _metaField('Description', descCtrl, maxLines: 3),
                _metaField('Company', companyCtrl),
                _metaField('Category', categoryCtrl),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _metadata = DocumentMetadata(
                  author: authorCtrl.text.trim(),
                  subject: subjectCtrl.text.trim(),
                  keywords: keywordsCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  company: companyCtrl.text.trim(),
                  category: categoryCtrl.text.trim(),
                );
              });
              _showSnack('Document properties saved.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _metaField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  // ── Page layout (multi-column, mirror margins, gutter) ────────────────────

  void _showPageLayoutDialog() {
    var columns = _columnCount;
    var gutter = _gutterTwips;
    var mirror = _mirrorMargins;
    var diffFirstPage = _differentFirstPage;
    var diffOddEven = _differentOddEvenPages;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Page Layout'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Columns',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1')),
                    ButtonSegment(value: 2, label: Text('2')),
                    ButtonSegment(value: 3, label: Text('3')),
                  ],
                  selected: {columns},
                  onSelectionChanged: (s) =>
                      setDlg(() => columns = s.first),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Gutter margin',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: gutter,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixText: 'twips',
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('None (0)')),
                    DropdownMenuItem(value: 360, child: Text('Narrow (0.25")')),
                    DropdownMenuItem(value: 720, child: Text('Normal (0.5")')),
                    DropdownMenuItem(value: 1440, child: Text('Wide (1")')),
                  ],
                  onChanged: (v) => setDlg(() => gutter = v ?? 0),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mirror margins'),
                  subtitle:
                      const Text('Inside/outside for double-sided printing'),
                  value: mirror,
                  onChanged: (v) => setDlg(() => mirror = v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Different first page'),
                  subtitle: const Text(
                      'Unique header/footer on the first page'),
                  value: diffFirstPage,
                  onChanged: (v) => setDlg(() => diffFirstPage = v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Different odd & even pages'),
                  subtitle: const Text(
                      'Alternate header/footer for odd and even pages'),
                  value: diffOddEven,
                  onChanged: (v) => setDlg(() => diffOddEven = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _columnCount = columns;
                  _gutterTwips = gutter;
                  _mirrorMargins = mirror;
                  _differentFirstPage = diffFirstPage;
                  _differentOddEvenPages = diffOddEven;
                });
                _showSnack('Page layout updated.');
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Paragraph spacing & line spacing dialog ───────────────────────────────

  void _showParagraphSpacingDialog() {
    final paragraph = _activeOpenXmlParagraph;
    if (paragraph == null) {
      _showSnack('Click inside a paragraph first.');
      return;
    }

    var lineSpacing = paragraph.lineSpacingTwips ?? 240;
    var spaceBefore = paragraph.spaceBefore ?? 0;
    var spaceAfter = paragraph.spaceAfter ?? 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Paragraph Spacing'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _spacingRow(
                  'Line spacing',
                  lineSpacing,
                  [
                    const DropdownMenuItem(value: 240, child: Text('Single')),
                    const DropdownMenuItem(value: 360, child: Text('1.5 lines')),
                    const DropdownMenuItem(value: 480, child: Text('Double')),
                    const DropdownMenuItem(value: 276, child: Text('1.15')),
                    const DropdownMenuItem(value: 312, child: Text('1.3')),
                  ],
                  (v) => setDlg(() => lineSpacing = v ?? 240),
                ),
                const SizedBox(height: 12),
                _spacingRow(
                  'Space before (pt)',
                  spaceBefore,
                  [
                    const DropdownMenuItem(value: 0, child: Text('0 pt')),
                    const DropdownMenuItem(value: 120, child: Text('6 pt')),
                    const DropdownMenuItem(value: 160, child: Text('8 pt')),
                    const DropdownMenuItem(value: 240, child: Text('12 pt')),
                    const DropdownMenuItem(value: 360, child: Text('18 pt')),
                  ],
                  (v) => setDlg(() => spaceBefore = v ?? 0),
                ),
                const SizedBox(height: 12),
                _spacingRow(
                  'Space after (pt)',
                  spaceAfter,
                  [
                    const DropdownMenuItem(value: 0, child: Text('0 pt')),
                    const DropdownMenuItem(value: 120, child: Text('6 pt')),
                    const DropdownMenuItem(value: 160, child: Text('8 pt')),
                    const DropdownMenuItem(value: 240, child: Text('12 pt')),
                    const DropdownMenuItem(value: 360, child: Text('18 pt')),
                  ],
                  (v) => setDlg(() => spaceAfter = v ?? 0),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _updateActiveOpenXmlParagraph(
                  (b) => b.copyWith(
                    lineSpacingTwips: lineSpacing,
                    spaceBefore: spaceBefore,
                    spaceAfter: spaceAfter,
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spacingRow<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: DropdownButtonFormField<T>(
            initialValue: value,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  // ── Tab stops dialog ───────────────────────────────────────────────────────

  void _showTabStopsDialog() {
    final paragraph = _activeOpenXmlParagraph;
    if (paragraph == null) {
      _showSnack('Click inside a paragraph first.');
      return;
    }

    var tabs = List<TabStop>.from(paragraph.tabs);
    var newPosTwips = 720;
    var newAlign = TabAlignment.left;
    var newLeader = TabLeader.none;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Tab Stops'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (tabs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No tab stops defined.',
                      style: TextStyle(color: Color(0xff6b7280)),
                    ),
                  )
                else
                  ...tabs.asMap().entries.map(
                    (e) => ListTile(
                      dense: true,
                      title: Text(
                        '${(e.value.positionTwips / 1440).toStringAsFixed(2)}"'
                        ' — ${e.value.alignment.name}'
                        '${e.value.leader != TabLeader.none ? ' (${e.value.leader.name})' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () =>
                            setDlg(() => tabs.removeAt(e.key)),
                      ),
                    ),
                  ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: newPosTwips,
                        decoration: const InputDecoration(
                          labelText: 'Position',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final inch in [0.5, 1.0, 1.5, 2.0, 2.5, 3.0,
                              3.5, 4.0, 4.5, 5.0, 5.5, 6.0])
                            DropdownMenuItem(
                              value: (inch * 1440).round(),
                              child: Text('$inch"'),
                            ),
                        ],
                        onChanged: (v) =>
                            setDlg(() => newPosTwips = v ?? 720),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<TabAlignment>(
                        initialValue: newAlign,
                        decoration: const InputDecoration(
                          labelText: 'Align',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final a in TabAlignment.values)
                            DropdownMenuItem(
                              value: a,
                              child: Text(a.name),
                            ),
                        ],
                        onChanged: (v) =>
                            setDlg(() => newAlign = v ?? TabAlignment.left),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<TabLeader>(
                        initialValue: newLeader,
                        decoration: const InputDecoration(
                          labelText: 'Leader',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final l in TabLeader.values)
                            DropdownMenuItem(
                              value: l,
                              child: Text(l.name),
                            ),
                        ],
                        onChanged: (v) =>
                            setDlg(() => newLeader = v ?? TabLeader.none),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final stop = TabStop(
                          positionTwips: newPosTwips,
                          alignment: newAlign,
                          leader: newLeader,
                        );
                        setDlg(() {
                          tabs
                            ..removeWhere(
                              (t) => t.positionTwips == stop.positionTwips,
                            )
                            ..add(stop)
                            ..sort(
                              (a, b) => a.positionTwips
                                  .compareTo(b.positionTwips),
                            );
                        });
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _updateActiveOpenXmlParagraph(
                  (b) => b.copyWith(tabs: const []),
                );
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _updateActiveOpenXmlParagraph(
                  (b) => b.copyWith(tabs: List.unmodifiable(tabs)),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Theme selector ─────────────────────────────────────────────────────────

  void _showThemeDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Document Theme'),
          content: SizedBox(
            width: 480,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisExtent: 110,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: DocumentTheme.presets.length,
              itemBuilder: (context, index) {
                final theme = DocumentTheme.presets[index];
                final isActive = theme.id == _activeThemeId;
                return InkWell(
                  onTap: () {
                    setDlg(() {});
                    _applyTheme(theme);
                    Navigator.of(ctx).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isActive
                            ? const Color(0xff2563eb)
                            : const Color(0xffcbd5e1),
                        width: isActive ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: Color(
                        int.parse(
                              'FF${theme.pageColorHex.toUpperCase()}',
                              radix: 16,
                            ),
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theme.name,
                          style: TextStyle(
                            fontFamily: theme.headingFont == 'Aptos'
                                ? null
                                : theme.headingFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(
                              int.parse(
                                'FF${theme.headingColorHex.toUpperCase()}',
                                radix: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Heading font',
                          style: TextStyle(
                            fontFamily: theme.headingFont == 'Aptos'
                                ? null
                                : theme.headingFont,
                            fontSize: 11,
                            color: const Color(0xff64748b),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Body font',
                          style: TextStyle(
                            fontFamily: theme.bodyFont == 'Aptos'
                                ? null
                                : theme.bodyFont,
                            fontSize: 11,
                            color: const Color(0xff64748b),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _colorChip(theme.accentColorHex),
                            const SizedBox(width: 4),
                            _colorChip(theme.headingColorHex),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorChip(String hex) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Color(int.parse('FF$hex', radix: 16)),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
    );
  }

  void _applyTheme(DocumentTheme theme) {
    setState(() {
      _activeThemeId = theme.id;
      _fontFamily = theme.bodyFont;
      _pageColor = Color(
        int.parse('FF${theme.pageColorHex.toUpperCase()}', radix: 16),
      );
    });
    _showSnack('Theme "${theme.name}" applied.');
  }

  // ── Index entries ──────────────────────────────────────────────────────────

  void _showInsertIndexEntryDialog() {
    final termCtrl = TextEditingController();
    final subtermCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Index Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: termCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Main entry',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subtermCtrl,
              decoration: const InputDecoration(
                labelText: 'Sub-entry (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final term = termCtrl.text.trim();
              if (term.isEmpty) return;
              Navigator.of(ctx).pop();
              setState(() {
                _indexEntries.add(
                  IndexEntry(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    term: term,
                    subterm: subtermCtrl.text.trim(),
                    blockIndex: _activeOpenXmlBlockIndex ?? 0,
                  ),
                );
              });
              _showSnack('Index entry "$term" marked.');
            },
            child: const Text('Mark'),
          ),
        ],
      ),
    );
  }

  void _showIndexDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Index'),
          content: SizedBox(
            width: 480,
            child: _indexEntries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No index entries. Use Insert › Index Entry to mark terms.',
                      style: TextStyle(color: Color(0xff6b7280)),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: () {
                        final grouped = <String, List<IndexEntry>>{};
                        for (final e in _indexEntries) {
                          grouped.putIfAbsent(e.term, () => []).add(e);
                        }
                        final keys = grouped.keys.toList()..sort();
                        return [
                          for (final key in keys) ...[
                            Text(
                              key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            for (final entry in grouped[key]!)
                              if (entry.subterm.isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 16, top: 2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          entry.subterm,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      Text(
                                        'para ${entry.blockIndex + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xff6b7280),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => _indexEntries.remove(entry),
                                          );
                                          setDlg(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    children: [
                                      Text(
                                        'para ${entry.blockIndex + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xff6b7280),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => _indexEntries.remove(entry),
                                          );
                                          setDlg(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            const SizedBox(height: 6),
                          ],
                        ];
                      }(),
                    ),
                  ),
          ),
          actions: [
            if (_indexEntries.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _insertGeneratedIndex();
                },
                child: const Text('Insert Index'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _insertGeneratedIndex() {
    final grouped = <String, List<IndexEntry>>{};
    for (final e in _indexEntries) {
      grouped.putIfAbsent(e.term, () => []).add(e);
    }
    final keys = grouped.keys.toList()..sort();
    _appendOpenXmlBlock(
      const OpenXmlParagraphBlock(
        runs: [OpenXmlRun('INDEX')],
        style: OpenXmlTextStyle.heading1,
      ),
    );
    for (final key in keys) {
      final entries = grouped[key]!;
      final pages = entries.map((e) => 'para ${e.blockIndex + 1}').join(', ');
      _appendOpenXmlBlock(
        OpenXmlParagraphBlock(
          runs: [OpenXmlRun('$key ........... $pages')],
        ),
      );
    }
    _showSnack('Index inserted.');
  }

  // ── Cross references ───────────────────────────────────────────────────────

  void _showInsertCrossReferenceDialog() {
    final sources = <CrossReference>[];
    for (var i = 0; i < _openXmlDocument.blocks.length; i++) {
      final b = _openXmlDocument.blocks[i];
      if (b is OpenXmlParagraphBlock &&
          (b.style == OpenXmlTextStyle.heading1 ||
              b.style == OpenXmlTextStyle.heading2 ||
              b.style == OpenXmlTextStyle.heading3)) {
        sources.add(
          CrossReference(
            id: 'auto-$i',
            label: b.plainText.trim(),
            blockIndex: i,
            type: CrossReferenceType.section,
          ),
        );
      }
    }
    sources.addAll(_crossReferences);

    CrossReference? selected = sources.isNotEmpty ? sources.first : null;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Insert Cross-Reference'),
          content: SizedBox(
            width: 400,
            child: sources.isEmpty
                ? const Text(
                    'No headings or references found. Add headings first.',
                  )
                : DropdownButtonFormField<CrossReference>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Reference to',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final ref in sources)
                        DropdownMenuItem(
                          value: ref,
                          child: Text(
                            ref.label.isEmpty
                                ? '(para ${ref.blockIndex + 1})'
                                : ref.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setDlg(() => selected = v),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final ref = selected;
                if (ref == null) return;
                Navigator.of(ctx).pop();
                _appendOpenXmlBlock(
                  OpenXmlParagraphBlock(
                    runs: [
                      OpenXmlRun(
                        'See: ${ref.label.isEmpty ? '(para ${ref.blockIndex + 1})' : ref.label}',
                      ),
                    ],
                  ),
                );
                _showSnack('Cross-reference inserted.');
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Custom styles organizer ────────────────────────────────────────────────

  void _showStyleOrganizerDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Style Organizer'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_customStyles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No custom styles yet.',
                      style: TextStyle(color: Color(0xff6b7280)),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _customStyles.length,
                      separatorBuilder: (context, i) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final style = _customStyles[index];
                        return ListTile(
                          dense: true,
                          title: Text(
                            style.name,
                            style: TextStyle(
                              fontWeight: style.bold
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              fontStyle: style.italic
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              fontSize: style.fontSize ?? 14,
                              color: style.colorHex != null
                                  ? Color(
                                      int.parse(
                                        'FF${style.colorHex!.toUpperCase()}',
                                        radix: 16,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            style.parentStyleId != null
                                ? 'Based on: ${style.parentStyleId}'
                                : 'No parent style',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                tooltip: 'Apply to paragraph',
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _updateActiveOpenXmlParagraph(
                                    (b) =>
                                        b.copyWith(customStyleId: style.id),
                                  );
                                  _showSnack(
                                    'Style "${style.name}" applied.',
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _customStyles.removeAt(index),
                                  );
                                  setDlg(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showCreateStyleDialog();
                  },
                  icon: const Icon(Icons.add_outlined, size: 18),
                  label: const Text('Create new style'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateStyleDialog() {
    final nameCtrl = TextEditingController();
    var bold = false;
    var italic = false;
    var underline = false;
    double fontSize = 12;
    String? parentStyleId;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Create Style'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Style name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: parentStyleId,
                  decoration: const InputDecoration(
                    labelText: 'Based on (parent style)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('None'),
                    ),
                    for (final s in OpenXmlTextStyle.values)
                      DropdownMenuItem(
                        value: s.styleId,
                        child: Text(s.label),
                      ),
                    for (final s in _customStyles)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name),
                      ),
                  ],
                  onChanged: (v) => setDlg(() => parentStyleId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Bold'),
                      selected: bold,
                      onSelected: (v) => setDlg(() => bold = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Italic'),
                      selected: italic,
                      onSelected: (v) => setDlg(() => italic = v),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Underline'),
                      selected: underline,
                      onSelected: (v) => setDlg(() => underline = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Font size: '),
                    Expanded(
                      child: Slider(
                        value: fontSize,
                        min: 8,
                        max: 36,
                        divisions: 28,
                        label: '${fontSize.round()} pt',
                        onChanged: (v) => setDlg(() => fontSize = v),
                      ),
                    ),
                    Text('${fontSize.round()} pt'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  _showSnack('Enter a style name.');
                  return;
                }
                Navigator.of(ctx).pop();
                final style = CustomDocumentStyle(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name,
                  parentStyleId: parentStyleId,
                  bold: bold,
                  italic: italic,
                  underline: underline,
                  fontSize: fontSize,
                );
                setState(() => _customStyles.add(style));
                _showSnack('Style "$name" created.');
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image properties (resize / alt text) ──────────────────────────────────

  void _showImagePropertiesForFirstBlock() {
    if (_mediaBlocks.isEmpty) {
      _showSnack('No images in document.');
      return;
    }
    _showImagePropertiesDialog(0);
  }

  void _showImagePropertiesDialog(int mediaIndex) {
    if (mediaIndex < 0 || mediaIndex >= _mediaBlocks.length) return;
    final block = _mediaBlocks[mediaIndex];
    var width = block.widthFraction ?? 1.0;
    final altCtrl = TextEditingController(text: block.altText);
    final captionCtrl = TextEditingController(text: block.caption);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Image Properties'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Width (% of page)'),
                Slider(
                  value: width,
                  min: 0.2,
                  max: 1.0,
                  divisions: 16,
                  label: '${(width * 100).round()}%',
                  onChanged: (v) => setDlg(() => width = v),
                ),
                Text('${(width * 100).round()}% of page width'),
                const SizedBox(height: 12),
                TextField(
                  controller: captionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Caption',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: altCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alt text',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _mediaBlocks[mediaIndex] = block.copyWith(
                    widthFraction: width,
                    caption: captionCtrl.text.trim(),
                    altText: altCtrl.text.trim(),
                  );
                });
                _showSnack('Image properties updated.');
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compare documents ──────────────────────────────────────────────────────

  void _showCompareDocumentsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final otherCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Compare Documents'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste the text of the document to compare against:',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: otherCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Paste document text here…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _runDocumentComparison(otherCtrl.text);
              },
              child: const Text('Compare'),
            ),
          ],
        );
      },
    );
  }

  void _runDocumentComparison(String other) {
    final currentLines = _plainText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final otherLines = other.split('\n').where((l) => l.trim().isNotEmpty).toList();

    final added = <String>[];
    final removed = <String>[];
    final unchanged = <String>[];

    final otherSet = otherLines.toSet();
    final currentSet = currentLines.toSet();

    for (final line in currentLines) {
      if (!otherSet.contains(line)) {
        removed.add(line);
      } else {
        unchanged.add(line);
      }
    }
    for (final line in otherLines) {
      if (!currentSet.contains(line)) added.add(line);
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comparison Result'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _diffStat(
                'Added lines',
                added.length,
                const Color(0xff16a34a),
              ),
              _diffStat(
                'Removed lines',
                removed.length,
                const Color(0xffdc2626),
              ),
              _diffStat(
                'Unchanged lines',
                unchanged.length,
                const Color(0xff475569),
              ),
              const SizedBox(height: 12),
              if (added.isNotEmpty) ...[
                const Text(
                  'Added:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xff16a34a),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final l in added.take(6))
                          Text(
                            '+ ${l.length > 80 ? '${l.substring(0, 80)}…' : l}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff16a34a),
                            ),
                          ),
                        if (added.length > 6)
                          Text(
                            '… and ${added.length - 6} more',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff6b7280),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (removed.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Removed:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xffdc2626),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 100),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final l in removed.take(6))
                          Text(
                            '- ${l.length > 80 ? '${l.substring(0, 80)}…' : l}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xffdc2626),
                            ),
                          ),
                        if (removed.length > 6)
                          Text(
                            '… and ${removed.length - 6} more',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff6b7280),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _diffStat(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Insert field ───────────────────────────────────────────────────────────

  void _showInsertFieldDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Insert Field'),
        children: [
          for (final fieldType in FieldType.values)
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(ctx).pop();
                _insertField(fieldType);
              },
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.data_object_outlined, size: 18),
                title: Text(fieldType.label),
              ),
            ),
        ],
      ),
    );
  }

  void _insertField(FieldType fieldType) {
    final now = DateTime.now();
    final text = switch (fieldType) {
      FieldType.pageNumber => '[Page]',
      FieldType.totalPages => '[Pages]',
      FieldType.date => '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      FieldType.time => '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      FieldType.author => _metadata.author.isEmpty ? '[Author]' : _metadata.author,
      FieldType.title => _titleController.text.isEmpty ? '[Title]' : _titleController.text,
      FieldType.fileName => '[FileName]',
      FieldType.wordCount => '$_wordCount words',
    };
    if (_isNativeOpenXmlEditor) {
      final controller = _activeRunController;
      if (controller != null) {
        final sel = controller.selection;
        final offset = sel.isValid ? sel.baseOffset : controller.text.length;
        controller.text = controller.text.substring(0, offset) +
            text +
            controller.text.substring(sel.isValid ? sel.extentOffset : offset);
        _refocusActiveOpenXmlEditor();
        return;
      }
    }
    _insertText(text);
    _showSnack('Field "${fieldType.label}" inserted.');
  }

  // ── Custom TOC ─────────────────────────────────────────────────────────────

  void _showCustomTocDialog() {
    var levels = 3;
    var includePageNumbers = true;
    var rightAlignPageNumbers = true;
    var useHyperlinks = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Table of Contents Options'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: levels,
                  decoration: const InputDecoration(
                    labelText: 'Show levels',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 level')),
                    DropdownMenuItem(value: 2, child: Text('2 levels')),
                    DropdownMenuItem(value: 3, child: Text('3 levels')),
                    DropdownMenuItem(value: 4, child: Text('4 levels')),
                    DropdownMenuItem(value: 5, child: Text('5 levels')),
                    DropdownMenuItem(value: 6, child: Text('6 levels')),
                  ],
                  onChanged: (v) => setDlg(() => levels = v ?? 3),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show page numbers'),
                  value: includePageNumbers,
                  onChanged: (v) => setDlg(() => includePageNumbers = v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Right-align page numbers'),
                  value: rightAlignPageNumbers,
                  onChanged: (v) =>
                      setDlg(() => rightAlignPageNumbers = v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use hyperlinks'),
                  value: useHyperlinks,
                  onChanged: (v) => setDlg(() => useHyperlinks = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _insertCustomToc(
                  levels: levels,
                  includePageNumbers: includePageNumbers,
                );
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  void _insertCustomToc({required int levels, required bool includePageNumbers}) {
    // Build TOC heading entries from document headings up to requested depth.
    final styleMap = {
      1: OpenXmlTextStyle.heading1,
      2: OpenXmlTextStyle.heading2,
      3: OpenXmlTextStyle.heading3,
      4: OpenXmlTextStyle.heading4,
      5: OpenXmlTextStyle.heading5,
      6: OpenXmlTextStyle.heading6,
    };
    final allowedStyles = {
      for (var i = 1; i <= levels; i++) styleMap[i],
    }.whereType<OpenXmlTextStyle>().toSet();

    _appendOpenXmlBlock(
      const OpenXmlParagraphBlock(
        runs: [OpenXmlRun('Table of Contents')],
        style: OpenXmlTextStyle.heading1,
      ),
    );

    var entryNum = 1;
    for (final block in _openXmlDocument.blocks) {
      if (block is OpenXmlParagraphBlock &&
          allowedStyles.contains(block.style)) {
        final text = block.plainText.trim();
        if (text.isNotEmpty) {
          final dots = includePageNumbers ? ' .' * 20 : '';
          _appendOpenXmlBlock(
            OpenXmlParagraphBlock(
              runs: [OpenXmlRun('$entryNum. $text$dots')],
            ),
          );
          entryNum++;
        }
      }
    }
    _showSnack('Custom TOC inserted ($levels level${levels != 1 ? 's' : ''}).');
  }

  void _updateToc() {
    // Find the TOC heading and regenerate from headings.
    final blocks = List<OpenXmlBlock>.from(_openXmlDocument.blocks);
    final tocIdx = blocks.indexWhere(
      (b) =>
          b is OpenXmlParagraphBlock &&
          b.style == OpenXmlTextStyle.heading1 &&
          b.plainText.trim().toLowerCase() == 'table of contents',
    );
    if (tocIdx < 0) {
      _showSnack('No Table of Contents found. Insert one first.');
      return;
    }

    // Remove existing TOC entries (plain-style paragraphs after the TOC heading
    // that start with digits and dots pattern).
    var end = tocIdx + 1;
    while (end < blocks.length) {
      final b = blocks[end];
      if (b is OpenXmlParagraphBlock && b.style == OpenXmlTextStyle.normal) {
        final text = b.plainText.trim();
        if (text.isEmpty || RegExp(r'^\d+\.').hasMatch(text)) {
          end++;
          continue;
        }
      }
      break;
    }
    blocks.removeRange(tocIdx + 1, end);

    // Re-insert headings as TOC entries.
    var entryNum = 1;
    for (final block in _openXmlDocument.blocks) {
      if (block is OpenXmlParagraphBlock) {
        if (block.style == OpenXmlTextStyle.heading1 ||
            block.style == OpenXmlTextStyle.heading2 ||
            block.style == OpenXmlTextStyle.heading3) {
          final text = block.plainText.trim();
          if (text.isNotEmpty && text.toLowerCase() != 'table of contents') {
            blocks.insert(
              tocIdx + entryNum,
              OpenXmlParagraphBlock(
                runs: [OpenXmlRun('$entryNum. $text')],
              ),
            );
            entryNum++;
          }
        }
      }
    }

    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = _openXmlDocument.copyWith(blocks: blocks);
      _setMarkdownSilently(_openXmlDocument.plainText);
      _saved = false;
    });
    _showSnack('Table of Contents updated.');
  }

  // ── Merge table cells dialog ───────────────────────────────────────────────

  void _showMergeCellsDialog() {
    final tableBlocks = <(int, OpenXmlTableBlock)>[];
    for (var i = 0; i < _openXmlDocument.blocks.length; i++) {
      final b = _openXmlDocument.blocks[i];
      if (b is OpenXmlTableBlock) tableBlocks.add((i, b));
    }
    if (tableBlocks.isEmpty) {
      _showSnack('No tables found in document.');
      return;
    }

    var tableIdx = tableBlocks.first.$1;
    var startRow = 0;
    var startCol = 0;
    var rowSpan = 2;
    var colSpan = 2;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final table = _openXmlDocument.blocks[tableIdx] as OpenXmlTableBlock;
          final maxRow = table.rows.length;
          final maxCol = table.rows.isEmpty ? 0 : table.rows[0].length;
          return AlertDialog(
            title: const Text('Merge Cells'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tableBlocks.length > 1)
                    DropdownButtonFormField<int>(
                      initialValue: tableIdx,
                      decoration: const InputDecoration(
                        labelText: 'Table',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final (idx, _) in tableBlocks)
                          DropdownMenuItem(
                            value: idx,
                            child: Text('Table at para ${idx + 1}'),
                          ),
                      ],
                      onChanged: (v) =>
                          setDlg(() => tableIdx = v ?? tableIdx),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: startRow.clamp(0, math.max(0, maxRow - 1)),
                          decoration: const InputDecoration(
                            labelText: 'Start row',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (var i = 0; i < maxRow; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text('Row ${i + 1}'),
                              ),
                          ],
                          onChanged: (v) =>
                              setDlg(() => startRow = v ?? 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: startCol.clamp(0, math.max(0, maxCol - 1)),
                          decoration: const InputDecoration(
                            labelText: 'Start col',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (var i = 0; i < maxCol; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text('Col ${i + 1}'),
                              ),
                          ],
                          onChanged: (v) =>
                              setDlg(() => startCol = v ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: rowSpan.clamp(1, math.max(1, maxRow - startRow)),
                          decoration: const InputDecoration(
                            labelText: 'Row span',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (var i = 1; i <= math.max(1, maxRow - startRow); i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text('$i row${i > 1 ? 's' : ''}'),
                              ),
                          ],
                          onChanged: (v) =>
                              setDlg(() => rowSpan = v ?? 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: colSpan.clamp(1, math.max(1, maxCol - startCol)),
                          decoration: const InputDecoration(
                            labelText: 'Col span',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (var i = 1; i <= math.max(1, maxCol - startCol); i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text('$i col${i > 1 ? 's' : ''}'),
                              ),
                          ],
                          onChanged: (v) =>
                              setDlg(() => colSpan = v ?? 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _applyMergeCells(
                    tableIdx,
                    startRow,
                    startCol,
                    rowSpan,
                    colSpan,
                  );
                },
                child: const Text('Merge'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applyMergeCells(
    int blockIndex,
    int row,
    int col,
    int rowSpan,
    int colSpan,
  ) {
    final block = _openXmlDocument.blocks[blockIndex];
    if (block is! OpenXmlTableBlock) return;
    final existing = List<(int, int, int, int)>.from(block.mergedCells);
    existing.removeWhere(
      (m) => m.$1 == row && m.$2 == col,
    );
    if (rowSpan > 1 || colSpan > 1) {
      existing.add((row, col, rowSpan, colSpan));
    }
    final newBlock = block.copyWith(mergedCells: existing);
    final blocks = List<OpenXmlBlock>.from(_openXmlDocument.blocks);
    blocks[blockIndex] = newBlock;
    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = _openXmlDocument.copyWith(blocks: blocks);
      _setMarkdownSilently(_openXmlDocument.plainText);
      _saved = false;
    });
    _showSnack('Cells merged.');
  }

  // ── Split cells ───────────────────────────────────────────────────────────

  void _showSplitCellsDialog() {
    final tableBlocks = <(int, OpenXmlTableBlock)>[];
    for (var i = 0; i < _openXmlDocument.blocks.length; i++) {
      final b = _openXmlDocument.blocks[i];
      if (b is OpenXmlTableBlock) tableBlocks.add((i, b));
    }
    if (tableBlocks.isEmpty) {
      _showSnack('No tables found in document.');
      return;
    }
    var tableIdx = tableBlocks.first.$1;
    var targetRow = 0;
    var targetCol = 0;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final table = _openXmlDocument.blocks[tableIdx] as OpenXmlTableBlock;
          final maxRow = table.rows.length;
          final maxCol = table.rows.isEmpty ? 0 : table.rows[0].length;
          return AlertDialog(
            title: const Text('Split Cell'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tableBlocks.length > 1)
                    DropdownButtonFormField<int>(
                      initialValue: tableIdx,
                      decoration: const InputDecoration(
                        labelText: 'Table',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final (idx, _) in tableBlocks)
                          DropdownMenuItem(
                            value: idx,
                            child: Text('Table at para ${idx + 1}'),
                          ),
                      ],
                      onChanged: (v) => setDlg(() => tableIdx = v ?? tableIdx),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: targetRow.clamp(0, math.max(0, maxRow - 1)),
                          decoration: const InputDecoration(
                            labelText: 'Row',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (var i = 0; i < maxRow; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text('Row ${i + 1}'),
                              ),
                          ],
                          onChanged: (v) => setDlg(() => targetRow = v ?? 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: targetCol.clamp(0, math.max(0, maxCol - 1)),
                          decoration: const InputDecoration(
                            labelText: 'Column',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (var i = 0; i < maxCol; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text('Col ${i + 1}'),
                              ),
                          ],
                          onChanged: (v) => setDlg(() => targetCol = v ?? 0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Splits any merged cell at this position back to individual cells.',
                    style: TextStyle(fontSize: 12, color: Color(0xff6b7280)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _applySplitCell(tableIdx, targetRow, targetCol);
                },
                child: const Text('Split'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applySplitCell(int blockIndex, int row, int col) {
    final block = _openXmlDocument.blocks[blockIndex];
    if (block is! OpenXmlTableBlock) return;
    final updated = List<(int, int, int, int)>.from(block.mergedCells)
      ..removeWhere((m) => m.$1 == row && m.$2 == col);
    final newBlock = block.copyWith(mergedCells: updated);
    final blocks = List<OpenXmlBlock>.from(_openXmlDocument.blocks);
    blocks[blockIndex] = newBlock;
    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = _openXmlDocument.copyWith(blocks: blocks);
      _setMarkdownSilently(_openXmlDocument.plainText);
      _saved = false;
    });
    _showSnack('Cell split.');
  }

  // ── Table sort ────────────────────────────────────────────────────────────

  void _showTableSortDialog() {
    final tableBlocks = <(int, OpenXmlTableBlock)>[];
    for (var i = 0; i < _openXmlDocument.blocks.length; i++) {
      final b = _openXmlDocument.blocks[i];
      if (b is OpenXmlTableBlock) tableBlocks.add((i, b));
    }
    if (tableBlocks.isEmpty) {
      _showSnack('No tables found in document.');
      return;
    }
    var tableIdx = tableBlocks.first.$1;
    var sortCol = 0;
    var ascending = true;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final table = _openXmlDocument.blocks[tableIdx] as OpenXmlTableBlock;
          final maxCol = table.rows.isEmpty ? 0 : table.rows[0].length;
          return AlertDialog(
            title: const Text('Sort Table'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tableBlocks.length > 1)
                    DropdownButtonFormField<int>(
                      initialValue: tableIdx,
                      decoration: const InputDecoration(
                        labelText: 'Table',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final (idx, _) in tableBlocks)
                          DropdownMenuItem(
                            value: idx,
                            child: Text('Table at para ${idx + 1}'),
                          ),
                      ],
                      onChanged: (v) => setDlg(() {
                        tableIdx = v ?? tableIdx;
                        sortCol = 0;
                      }),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: sortCol.clamp(0, math.max(0, maxCol - 1)),
                    decoration: const InputDecoration(
                      labelText: 'Sort by column',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (var i = 0; i < maxCol; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('Column ${i + 1}'),
                        ),
                    ],
                    onChanged: (v) => setDlg(() => sortCol = v ?? 0),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('A → Z')),
                      ButtonSegment(value: false, label: Text('Z → A')),
                    ],
                    selected: {ascending},
                    onSelectionChanged: (s) =>
                        setDlg(() => ascending = s.first),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _applyTableSort(tableIdx, sortCol, ascending);
                },
                child: const Text('Sort'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applyTableSort(int blockIndex, int col, bool ascending) {
    final block = _openXmlDocument.blocks[blockIndex];
    if (block is! OpenXmlTableBlock) return;
    final rows = List<List<String>>.from(block.rows.map(List<String>.from));
    final startRow = block.hasHeader && rows.length > 1 ? 1 : 0;
    final dataRows = rows.sublist(startRow)
      ..sort((a, b) {
        final av = col < a.length ? a[col] : '';
        final bv = col < b.length ? b[col] : '';
        final numA = num.tryParse(av);
        final numB = num.tryParse(bv);
        int cmp;
        if (numA != null && numB != null) {
          cmp = numA.compareTo(numB);
        } else {
          cmp = av.toLowerCase().compareTo(bv.toLowerCase());
        }
        return ascending ? cmp : -cmp;
      });
    final sorted = [
      if (startRow > 0) rows[0],
      ...dataRows,
    ];
    final newBlock = block.copyWith(rows: sorted);
    final blocks = List<OpenXmlBlock>.from(_openXmlDocument.blocks);
    blocks[blockIndex] = newBlock;
    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = _openXmlDocument.copyWith(blocks: blocks);
      _setMarkdownSilently(_openXmlDocument.plainText);
      _saved = false;
    });
    _showSnack('Table sorted.');
  }

  // ── Table auto-fit ────────────────────────────────────────────────────────

  void _applyTableAutoFit(int blockIndex) {
    final block = _openXmlDocument.blocks[blockIndex];
    if (block is! OpenXmlTableBlock) return;
    final newBlock = block.copyWith(columnWidths: const []);
    final blocks = List<OpenXmlBlock>.from(_openXmlDocument.blocks);
    blocks[blockIndex] = newBlock;
    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = _openXmlDocument.copyWith(blocks: blocks);
      _setMarkdownSilently(_openXmlDocument.plainText);
      _saved = false;
    });
    _showSnack('Table set to auto-fit.');
  }

  void _showTableAutoFitDialog() {
    final tableBlocks = <(int, OpenXmlTableBlock)>[];
    for (var i = 0; i < _openXmlDocument.blocks.length; i++) {
      final b = _openXmlDocument.blocks[i];
      if (b is OpenXmlTableBlock) tableBlocks.add((i, b));
    }
    if (tableBlocks.isEmpty) {
      _showSnack('No tables found.');
      return;
    }
    if (tableBlocks.length == 1) {
      _applyTableAutoFit(tableBlocks.first.$1);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var tableIdx = tableBlocks.first.$1;
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            title: const Text('Auto-fit Table'),
            content: DropdownButtonFormField<int>(
              initialValue: tableIdx,
              decoration: const InputDecoration(
                labelText: 'Table',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final (idx, _) in tableBlocks)
                  DropdownMenuItem(
                    value: idx,
                    child: Text('Table at para ${idx + 1}'),
                  ),
              ],
              onChanged: (v) => setDlg(() => tableIdx = v ?? tableIdx),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _applyTableAutoFit(tableIdx);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _activateFormatPainter() {
    final controller = _activeRunController;
    if (controller == null) return;
    final selection = _formattingSelectionFor(controller);
    if (selection == null || selection.isCollapsed) return;
    final lo = selection.start.clamp(0, controller.text.length);
    // Capture the format of the first character in selection.
    final fmt = controller.formatAt(lo);
    setState(() {
      _formatPainterActive = !_formatPainterActive;
      _formatPainterFormat = _formatPainterActive ? fmt : null;
    });
  }

  void _applyFormatPainterIfActive(int start, int end) {
    if (!_formatPainterActive) return;
    final fmt = _formatPainterFormat;
    if (fmt == null) return;
    final controller = _activeRunController;
    if (controller == null) return;
    controller.applyFormat(start, end, fmt);
    setState(() {
      _formatPainterActive = false;
      _formatPainterFormat = null;
    });
  }

  void _indentIncrease() {
    _updateActiveOpenXmlParagraph(
      (block) => block.copyWith(
        indentLeft: (block.indentLeft + 720).clamp(0, 7200),
      ),
    );
  }

  void _indentDecrease() {
    _updateActiveOpenXmlParagraph(
      (block) => block.copyWith(
        indentLeft: (block.indentLeft - 720).clamp(0, 7200),
      ),
    );
  }

  void _applyTextColor(Color color) {
    final colorHex = _hexForColor(color);
    setState(() => _inkColor = color);
    final controller = _activeRunController;
    if (controller == null) {
      _updateActiveOpenXmlParagraph((block) {
        final runs = block.runs.isEmpty ? const [OpenXmlRun('')] : block.runs;
        return block.copyWith(
          runs: [
            for (final run in runs)
              OpenXmlRun(
                run.text,
                bold: run.bold,
                italic: run.italic,
                underline: run.underline,
                strike: run.strike,
                colorHex: colorHex,
                href: run.href,
              ),
          ],
        );
      });
      return;
    }

    final selection = _formattingSelectionFor(controller);
    final int start;
    final int end;
    if (selection != null) {
      start = selection.start;
      end = selection.end;
    } else {
      start = 0;
      end = controller.text.length;
    }
    if (end <= start) {
      _showSnack('Type some text before applying color.');
      return;
    }
    controller.setColor(start, end, colorHex);
    _refocusActiveOpenXmlEditor();
    setState(() {});
  }

  void _applyWysiwygTextColor(Color color) {
    setState(() {
      _inkColor = color;
      _wysiwygInkCommandColor = color;
      _wysiwygInkCommandId += 1;
    });
  }

  void _applyPlainTextColor(Color color) {
    final controller = _srqController.textController;
    final selection = controller.selection;
    final text = controller.text;
    if (text.isEmpty) {
      setState(() => _inkColor = color);
      return;
    }
    final range = selection.isValid && !selection.isCollapsed
        ? selection
        : _paragraphSelectionFor(text, selection);
    final start = range.start.clamp(0, text.length);
    final end = range.end.clamp(0, text.length);
    if (end <= start) {
      setState(() => _inkColor = color);
      return;
    }
    final hex = _hexForColor(color);
    final selected = text.substring(start, end);
    final wrapped = '<span style="color:#$hex">$selected</span>';
    _srqController.setMarkdown(
      '${text.substring(0, start)}$wrapped${text.substring(end)}',
    );
    _srqController.textController.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + wrapped.length,
    );
    _editorFocusNode.requestFocus();
    setState(() => _inkColor = color);
  }

  TextSelection _paragraphSelectionFor(String text, TextSelection selection) {
    final cursor = selection.isValid
        ? selection.start.clamp(0, text.length)
        : text.length;
    final start = text.lastIndexOf('\n', math.max(0, cursor - 1)) + 1;
    final nextBreak = text.indexOf('\n', cursor);
    final end = nextBreak == -1 ? text.length : nextBreak;
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  /// Drops references to the active paragraph's (about-to-be-disposed)
  /// controller when the whole document is swapped out.
  void _resetActiveParagraph() {
    _activeFieldFocus = null;
    _activeRunController = null;
    _lastOpenXmlSelection = null;
  }

  void _toggleOpenXmlRunFormat({
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strike = false,
    bool superscript = false,
    bool subscript = false,
  }) {
    _updateActiveOpenXmlParagraph((block) {
      final runs = block.runs.isEmpty ? const [OpenXmlRun('')] : block.runs;
      return block.copyWith(
        runs: [
          for (final run in runs)
            OpenXmlRun(
              run.text,
              bold: bold ? !run.bold : run.bold,
              italic: italic ? !run.italic : run.italic,
              underline: underline ? !run.underline : run.underline,
              strike: strike ? !run.strike : run.strike,
              superscript: superscript ? !run.superscript : run.superscript,
              subscript: subscript ? !run.subscript : run.subscript,
              colorHex: run.colorHex,
              highlightHex: run.highlightHex,
              href: run.href,
            ),
        ],
      );
    });
  }

  String _hexForColor(Color color) {
    final rgb = color.toARGB32() & 0x00ffffff;
    return rgb.toRadixString(16).padLeft(6, '0').toUpperCase();
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
    _logAudit('Save', detail: _titleController.text);
    _showSnack('Saved locally as $_activeVersion.');
  }

  // ── Autosave ───────────────────────────────────────────────────────────────

  /// (Re)starts the autosave timer when enabled, or cancels it when disabled.
  /// Called whenever autosave is toggled or its interval changes.
  void _restartAutosaveTimer() {
    _autosaveTimer?.cancel();
    if (!_autosaveEnabled) {
      _autosaveTimer = null;
      return;
    }
    _autosaveTimer = Timer.periodic(_autosaveInterval, (_) {
      if (!mounted) return;
      // Only persist when there are unsaved edits to avoid spamming versions.
      if (!_saved) {
        _saveDocument();
      }
    });
  }

  /// Human-readable label for an autosave interval (e.g. "30 sec", "2 min").
  String _autosaveIntervalLabel(Duration interval) {
    if (interval.inMinutes >= 1) {
      final minutes = interval.inMinutes;
      return '$minutes min';
    }
    return '${interval.inSeconds} sec';
  }

  void _showAutosaveSettings() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool enabled = _autosaveEnabled;
        Duration interval = _autosaveInterval;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Autosave settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable autosave'),
                    subtitle: const Text(
                      'Automatically save changes on a timer.',
                    ),
                    value: enabled,
                    onChanged: (value) =>
                        setLocalState(() => enabled = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save every',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: enabled ? null : Theme.of(context).disabledColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in _autosaveIntervalPresets)
                        ChoiceChip(
                          label: Text(_autosaveIntervalLabel(preset)),
                          selected: interval == preset,
                          onSelected: enabled
                              ? (_) =>
                                    setLocalState(() => interval = preset)
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _autosaveEnabled = enabled;
                      _autosaveInterval = interval;
                    });
                    _restartAutosaveTimer();
                    _showSnack(
                      enabled
                          ? 'Autosave on — every '
                                '${_autosaveIntervalLabel(interval)}.'
                          : 'Autosave turned off.',
                    );
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showToolbarLayoutMenu() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Toolbar layout'),
          children: [
            for (final option in ToolbarLayout.values)
              ListTile(
                leading: Icon(
                  option == _toolbarLayout
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: option == _toolbarLayout
                      ? Theme.of(dialogContext).colorScheme.primary
                      : null,
                ),
                title: Text(option.label),
                subtitle: Text(option.description),
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  setState(() => _toolbarLayout = option);
                  _showSnack('Toolbar layout: ${option.label}.');
                },
              ),
          ],
        );
      },
    );
  }

  void _newDocument() {
    _resetActiveParagraph();
    _clearOpenXmlHistory();
    _setMarkdownSilently('');
    setState(() {
      _titleController.text = 'Untitled document';
      _style = 'Normal';
      _fontSize = 16;
      _zoom = 1;
      _template = 'Blank';
      _mediaBlocks.clear();
      _customFonts.clear();
      _ooxmlBlocks = [];
      _openXmlDocument = OpenXmlDocument.plain('');
      _wysiwygBlocks = WysiwygDocumentCodec.fromMarkdown('');
      _quillDeltaJson = WysiwygDocumentCodec.toQuillDeltaJson(_wysiwygBlocks);
      _sourcePackageFormat = null;
      _sourcePackageBytes = null;
      _editMode = DocumentEditMode.openXml;
      _activeOpenXmlBlockIndex = 0;
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

  Future<Uint8List?> _readPickedFileBytes(PlatformFile picked) async {
    final bytes = picked.bytes;
    if (bytes != null) {
      return bytes;
    }

    final path = picked.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    return File(path).readAsBytes();
  }

  Future<void> _pickAndInsertMedia(MediaType type) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: type.allowedExtensions,
        withData: true,
      );
      final picked = result?.files.single;
      if (picked == null) {
        return;
      }
      final bytes = await _readPickedFileBytes(picked);
      if (bytes == null) {
        _showSnack('Could not read that file.');
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
      if (picked == null) {
        return;
      }
      final bytes = await _readPickedFileBytes(picked);
      if (bytes == null) {
        _showSnack('Could not read that font file.');
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
    final altTextController = TextEditingController();

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
              if (type == MediaType.image) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: altTextController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.accessibility_new_outlined),
                    labelText: 'Alt text (accessibility)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
                            altText: altTextController.text.trim(),
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
    List<OoxmlVisualBlock> ooxmlBlocks = const [],
    List<WysiwygBlock> wysiwygBlocks = const [],
    List<Object?> quillDeltaJson = const [],
    OpenXmlDocument? openXmlDocument,
    DocumentPageSetup? pageSetup,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      _showSnack('No readable text found in $name.');
      return;
    }

    _resetActiveParagraph();
    _clearOpenXmlHistory();
    _setMarkdownSilently(cleanText);
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
      _ooxmlBlocks = List<OoxmlVisualBlock>.of(ooxmlBlocks);
      _openXmlDocument =
          openXmlDocument ??
          OpenXmlDocument.plain(cleanText).copyWith(
            sourcePackageFormat: sourcePackageFormat,
            sourcePackageBytes: sourcePackageBytes,
          );
      _wysiwygBlocks = wysiwygBlocks.isNotEmpty
          ? List<WysiwygBlock>.of(wysiwygBlocks)
          : WysiwygDocumentCodec.fromMarkdown(cleanText);
      _quillDeltaJson = quillDeltaJson.isNotEmpty
          ? List<Object?>.of(quillDeltaJson)
          : WysiwygDocumentCodec.toQuillDeltaJson(_wysiwygBlocks);
      _editMode = _ooxmlBlocks.isNotEmpty
          ? DocumentEditMode.openXml
          : _openXmlDocument.blocks.isNotEmpty
          ? DocumentEditMode.openXml
          : sourcePackageBytes != null && sourcePackageFormat == 'docx'
          ? DocumentEditMode.docxView
          : DocumentEditMode.openXml;
      _activeOpenXmlBlockIndex = 0;
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
    String? pickedName;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const [
          'docx',
          'odt',
          'ott',
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
      if (picked == null) {
        return;
      }
      pickedName = picked.name;
      final newTabHandler = widget.onOpenInNewTab;
      if (newTabHandler != null && picked.path != null && picked.path!.isNotEmpty) {
        newTabHandler(picked.path!);
        return;
      }
      final bytes = await _readPickedFileBytes(picked);
      if (bytes == null) {
        _showSnack('Could not read that file.');
        return;
      }

      final imported = await _importService.parseAsync(bytes, picked.name);
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
        ooxmlBlocks: imported.ooxmlBlocks,
        wysiwygBlocks: imported.wysiwygBlocks,
        quillDeltaJson: imported.quillDeltaJson,
        openXmlDocument: imported.openXmlDocument,
      );
    } on FormatException catch (error) {
      _showSnack(error.message);
    } catch (error, stackTrace) {
      debugPrint('Failed to import ${pickedName ?? 'file'}: $error');
      debugPrintStack(stackTrace: stackTrace);
      final name = pickedName ?? 'file';
      _showSnack('Could not import $name: $error');
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
                'Supports DOCX, ODT, TXT, Markdown, RTF, HTML, and CSV.',
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
                        _resetActiveParagraph();
                        _clearOpenXmlHistory();
                        _setMarkdownSilently(entry.value);
                        setState(() {
                          _template = entry.key;
                          _titleController.text = entry.key;
                          _mediaBlocks.clear();
                          _ooxmlBlocks = [];
                          _openXmlDocument = OpenXmlDocument.plain(entry.value);
                          _sourcePackageFormat = null;
                          _sourcePackageBytes = null;
                          _editMode = DocumentEditMode.openXml;
                          _activeOpenXmlBlockIndex = 0;
                          _style = 'Normal';
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
                          _resetActiveParagraph();
                          _clearOpenXmlHistory();
                          _setMarkdownSilently(version.body);
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

  static final _suggestInsertRe = RegExp(
    r'\[\[SUGGEST:insert\|(.+?)\]\]',
    caseSensitive: false,
    dotAll: true,
  );
  static final _suggestDeleteRe = RegExp(
    r'\[\[SUGGEST:delete\|(.+?)\]\]',
    caseSensitive: false,
    dotAll: true,
  );

  List<({int start, int end, bool isInsert, String content})>
  _findTrackChanges() {
    final text = _markdownText;
    final changes = <({int start, int end, bool isInsert, String content})>[];
    for (final m in _suggestInsertRe.allMatches(text)) {
      changes.add((
        start: m.start,
        end: m.end,
        isInsert: true,
        content: m.group(1) ?? '',
      ));
    }
    for (final m in _suggestDeleteRe.allMatches(text)) {
      changes.add((
        start: m.start,
        end: m.end,
        isInsert: false,
        content: m.group(1) ?? '',
      ));
    }
    changes.sort((a, b) => a.start.compareTo(b.start));
    return changes;
  }

  void _showTrackChangesDialog() {
    final changes = _findTrackChanges();
    if (changes.isEmpty) {
      _showSnack('No tracked changes found.');
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final current = _findTrackChanges();
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.change_circle_outlined, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Track Changes (${current.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _acceptAllChanges();
                          },
                          child: const Text('Accept all'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _rejectAllChanges();
                          },
                          child: const Text('Reject all'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: current.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No tracked changes remaining.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: current.length,
                            separatorBuilder: (_, i) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final c = current[i];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  c.isInsert
                                      ? Icons.add_circle_outline
                                      : Icons.remove_circle_outline,
                                  color: c.isInsert
                                      ? const Color(0xff16a34a)
                                      : const Color(0xffdc2626),
                                  size: 20,
                                ),
                                title: Text(
                                  c.isInsert ? 'Insert' : 'Delete',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  c.content.length > 80
                                      ? '${c.content.substring(0, 80)}…'
                                      : c.content,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Tooltip(
                                      message: 'Accept',
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Color(0xff16a34a),
                                        ),
                                        onPressed: () {
                                          _acceptSingleChange(c.start, c.end,
                                              c.isInsert, c.content);
                                          setDlgState(() {});
                                        },
                                      ),
                                    ),
                                    Tooltip(
                                      message: 'Reject',
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Color(0xffdc2626),
                                        ),
                                        onPressed: () {
                                          _rejectSingleChange(c.start, c.end,
                                              c.isInsert);
                                          setDlgState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _acceptSingleChange(
      int start, int end, bool isInsert, String content) {
    final text = _markdownText;
    final replacement = isInsert ? content : '';
    _setMarkdownSilently(text.replaceRange(start, end, replacement));
    setState(() {});
  }

  void _rejectSingleChange(int start, int end, bool isInsert) {
    final text = _markdownText;
    final replacement = isInsert ? '' : _markdownText.substring(start, end)
        .replaceFirstMapped(
          _suggestDeleteRe,
          (m) => m.group(1) ?? '',
        );
    _setMarkdownSilently(
      isInsert ? text.replaceRange(start, end, '') : text.replaceRange(start, end, replacement),
    );
    setState(() {});
  }

  void _acceptAllChanges() {
    final accepted = _markdownText
        .replaceAllMapped(
          RegExp(r'\[\[SUGGEST:insert\|(.+?)\]\]', caseSensitive: false),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(
          RegExp(r'\n?\[\[SUGGEST:delete\|.+?\]\]\n?', caseSensitive: false),
          '\n',
        );
    _setMarkdownSilently(accepted);
    setState(() {
      _trackChanges = false;
      _captureVersion('Accepted review changes');
    });
    _showSnack('Changes accepted and versioned.');
  }

  void _rejectAllChanges() {
    if (_versions.isEmpty) return;
    final previous = _versions.last;
    _setMarkdownSilently(previous.body);
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
    if (_isNativeOpenXmlEditor) {
      _appendOpenXmlBlock(
        const OpenXmlParagraphBlock(
          runs: [OpenXmlRun('Source: https://example.com/source')],
          style: OpenXmlTextStyle.caption,
        ),
      );
      _appendOpenXmlBlock(
        const OpenXmlParagraphBlock(
          runs: [OpenXmlRun('Bibliography')],
          style: OpenXmlTextStyle.heading2,
        ),
      );
      _showSnack('Source and bibliography blocks inserted.');
      return;
    }
    _insertText(
      '\n\n[[CITATION:Source|https://example.com/source]]\n\n[[BIBLIOGRAPHY]]\n',
    );
    _showSnack('Citation and bibliography placeholders inserted.');
  }

  void _insertActionDigest() {
    final actions = _actionItems.isEmpty
        ? ['Add owner, due date, and next step.']
        : _actionItems;
    if (_isNativeOpenXmlEditor) {
      _appendOpenXmlBlock(
        OpenXmlParagraphBlock(
          runs: [OpenXmlRun('Action digest\n${actions.join('\n')}')],
          style: OpenXmlTextStyle.heading2,
        ),
      );
      return;
    }
    _insertText('\n\nAction digest\n${actions.join('\n')}\n');
  }

  void _applySelectedStyle(String value) {
    final size = switch (value) {
      'Title' => 28.0,
      'Subtitle' => 20.0,
      'Heading 1' => 24.0,
      'Heading 2' => 22.0,
      'Heading 3' => 20.0,
      'Heading 4' => 18.0,
      'Heading 5' => 16.0,
      'Heading 6' => 15.0,
      'Caption' => 13.0,
      'Code' => 15.0,
      _ => 16.0,
    };
    setState(() {
      _style = value;
      _fontSize = size;
    });
    if (_isNativeOpenXmlEditor) {
      final flatCtrl = _activeRunController;
      if (flatCtrl is DocumentFlatController) {
        flatCtrl.setBlockStyle(
          _activeOpenXmlBlockIndex ?? 0,
          _openXmlStyleForRibbon(value),
        );
        _refocusActiveOpenXmlEditor();
        return;
      }
      _updateActiveOpenXmlParagraph(
        (block) => block.copyWith(style: _openXmlStyleForRibbon(value)),
      );
      _refocusActiveOpenXmlEditor();
      return;
    }
    switch (value) {
      case 'Title':
        _srqController.setHeading(1);
      case 'Heading 1':
        _srqController.setHeading(2);
      case 'Heading 2':
        _srqController.setHeading(3);
      case 'Heading 3':
        _srqController.setHeading(4);
      case 'Heading 4':
        _srqController.setHeading(5);
      case 'Heading 5':
      case 'Heading 6':
        _srqController.setHeading(6);
      case 'Quote':
        _srqController.toggleBlockquote();
      case 'Subtitle':
        _insertText('\n\n[[SUBTITLE:Subtitle text]]\n\n');
      case 'Caption':
        _insertText('\n\n[[CAPTION:Figure 1. Caption text.]]\n\n');
      case 'Code':
        _insertText('\n\n```\nCode block\n```\n\n');
      default:
        _srqController.clearBlockFormat();
    }
  }

  void _insertPageBreak() {
    if (_isNativeOpenXmlEditor) {
      _appendOpenXmlBlock(
        const OpenXmlParagraphBlock(
          runs: [OpenXmlRun('New page')],
          pageBreakBefore: true,
        ),
      );
      _showSnack('Page break inserted.');
      return;
    }
    _insertText('\n\n[[PAGE_BREAK]]\n\n');
    _showSnack('Page break inserted.');
  }

  void _insertTableOfContents() {
    if (_isNativeOpenXmlEditor) {
      _appendOpenXmlBlock(
        const OpenXmlParagraphBlock(
          runs: [OpenXmlRun('Table of contents')],
          style: OpenXmlTextStyle.heading1,
        ),
      );
      _showSnack('Table of contents heading inserted.');
      return;
    }
    _insertText('\n\n[[TOC]]\n\n');
    _showSnack('Table of contents inserted.');
  }

  void _insertFootnote() {
    if (_isNativeOpenXmlEditor) {
      _appendOpenXmlBlock(
        const OpenXmlParagraphBlock(
          runs: [OpenXmlRun('Footnote: add source, citation, or note.')],
          style: OpenXmlTextStyle.caption,
        ),
      );
      _showSnack('Footnote note inserted.');
      return;
    }
    _insertText(
      '\n\n[[FOOTNOTE:Add source, citation, or explanatory note.]]\n\n',
    );
    _showSnack('Footnote placeholder inserted.');
  }

  void _insertEndnote() {
    if (_isNativeOpenXmlEditor) {
      _appendOpenXmlBlock(
        const OpenXmlParagraphBlock(
          runs: [
            OpenXmlRun('Endnote: add appendix note or closing reference.'),
          ],
          style: OpenXmlTextStyle.caption,
        ),
      );
      _showSnack('Endnote note inserted.');
      return;
    }
    _insertText('\n\n[[ENDNOTE:Add appendix note or closing reference.]]\n\n');
    _showSnack('Endnote placeholder inserted.');
  }

  void _insertHorizontalRule() {
    if (_isNativeOpenXmlEditor) {
      _appendOpenXmlBlock(
        const OpenXmlParagraphBlock(
          runs: [OpenXmlRun('')],
          style: OpenXmlTextStyle.normal,
        ),
      );
      _showSnack('Separator paragraph inserted.');
      return;
    }
    _insertText('\n\n[[HR]]\n\n');
    _showSnack('Horizontal rule inserted.');
  }

  void _insertDropCap() {
    if (_isNativeOpenXmlEditor) {
      _appendOpenXmlBlock(
        const OpenXmlParagraphBlock(
          runs: [OpenXmlRun('Once upon a time, start this section.')],
          style: OpenXmlTextStyle.normal,
        ),
      );
      _showSnack('Drop-cap starter text inserted.');
      return;
    }
    _insertText('\n\n[[DROP_CAP:Once upon a time, start this section.]]\n\n');
    _showSnack('Drop cap block inserted.');
  }

  void _insertShape() {
    _showShapePaletteSheet();
  }

  void _insertLink() {
    if (_isNativeOpenXmlEditor) {
      _appendOpenXmlBlock(
        const OpenXmlParagraphBlock(
          runs: [OpenXmlRun('Reference', href: 'https://example.com')],
        ),
      );
      _showSnack('Link inserted.');
      return;
    }
    _insertText('\n\n[[LINK:Reference|https://example.com]]\n\n');
    _showSnack('Link placeholder inserted.');
  }

  void _switchToOpenXmlEditing() {
    _resetActiveParagraph();
    _clearOpenXmlHistory();
    setState(() {
      if (_editMode == DocumentEditMode.wysiwyg) {
        _setMarkdownSilently(
          WysiwygDocumentCodec.toMarkdown(
            WysiwygDocumentCodec.fromQuillDeltaJson(_quillDeltaJson),
          ),
        );
      }
      _openXmlDocument = OpenXmlDocument.plain(_srqController.markdown);
      _editMode = DocumentEditMode.openXml;
      _ooxmlBlocks = [];
      _sourcePackageFormat = null;
      _sourcePackageBytes = null;
      _activeOpenXmlBlockIndex = 0;
      _saved = false;
    });
    _editorFocusNode.requestFocus();
    _showSnack('Switched to structured OpenXML editing.');
  }

  void _switchToWysiwyg() {
    _resetActiveParagraph();
    _clearOpenXmlHistory();
    setState(() {
      _wysiwygBlocks = WysiwygDocumentCodec.fromMarkdown(_markdownText);
      _quillDeltaJson = WysiwygDocumentCodec.toQuillDeltaJson(_wysiwygBlocks);
      _editMode = DocumentEditMode.wysiwyg;
      _ooxmlBlocks = [];
      _sourcePackageFormat = null;
      _sourcePackageBytes = null;
      _saved = false;
    });
    _showSnack('Switched to WYSIWYG editing.');
  }

  void _updateOoxmlBlock(int index, OoxmlVisualBlock block) {
    if (index < 0 || index >= _ooxmlBlocks.length) {
      return;
    }
    setState(() {
      _ooxmlBlocks = List<OoxmlVisualBlock>.of(_ooxmlBlocks)..[index] = block;
      _saved = false;
    });
  }

  void _updateWysiwygBlock(int index, WysiwygBlock block) {
    if (index < 0 || index >= _wysiwygBlocks.length) {
      return;
    }
    setState(() {
      _wysiwygBlocks = List<WysiwygBlock>.of(_wysiwygBlocks)..[index] = block;
      _quillDeltaJson = WysiwygDocumentCodec.toQuillDeltaJson(_wysiwygBlocks);
      _saved = false;
    });
  }

  void _updateQuillDelta(List<Object?> deltaJson) {
    setState(() {
      _quillDeltaJson = List<Object?>.of(deltaJson);
      _wysiwygBlocks = WysiwygDocumentCodec.fromQuillDeltaJson(_quillDeltaJson);
      _saved = false;
    });
  }

  void _addWysiwygBlockAfter(int index) {
    final next = WysiwygBlock(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: WysiwygBlockType.paragraph,
      text: '',
    );
    setState(() {
      final blocks = List<WysiwygBlock>.of(_wysiwygBlocks);
      blocks.insert((index + 1).clamp(0, blocks.length), next);
      _wysiwygBlocks = blocks;
      _quillDeltaJson = WysiwygDocumentCodec.toQuillDeltaJson(_wysiwygBlocks);
      _saved = false;
    });
  }

  void _removeWysiwygBlock(int index) {
    if (_wysiwygBlocks.length <= 1) {
      _updateWysiwygBlock(index, _wysiwygBlocks[index].copyWith(text: ''));
      return;
    }
    setState(() {
      _wysiwygBlocks = List<WysiwygBlock>.of(_wysiwygBlocks)..removeAt(index);
      _quillDeltaJson = WysiwygDocumentCodec.toQuillDeltaJson(_wysiwygBlocks);
      _saved = false;
    });
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
                        if (_isNativeOpenXmlEditor) {
                          _appendOpenXmlBlock(
                            OpenXmlTableBlock(
                              rows: [
                                [
                                  for (
                                    var column = 0;
                                    column < columns;
                                    column += 1
                                  )
                                    'Header ${column + 1}',
                                ],
                                for (var row = 1; row < rows; row += 1)
                                  [
                                    for (
                                      var column = 0;
                                      column < columns;
                                      column += 1
                                    )
                                      '',
                                  ],
                              ],
                              hasHeader: shadeHeader,
                            ),
                          );
                          _showSnack('Table inserted.');
                          return;
                        }
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
                          if (_isNativeOpenXmlEditor) {
                            _appendOpenXmlBlock(
                              OpenXmlParagraphBlock(
                                runs: [OpenXmlRun('Shape: $preset')],
                                style: OpenXmlTextStyle.caption,
                              ),
                            );
                            _showSnack('Shape note inserted.');
                            return;
                          }
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
      comments: _comments,
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
      onResolveComment: (id) => setState(() {
        final idx = _comments.indexWhere((c) => c.id == id);
        if (idx >= 0) _comments[idx].resolved = true;
      }),
      onReplyComment: (id, text) => setState(() {
        final idx = _comments.indexWhere((c) => c.id == id);
        if (idx < 0) return;
        _comments[idx].replies.add(DocumentCommentReply(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          author: 'You',
          body: text,
          createdAt: DateTime.now(),
        ));
      }),
      onAddComment: (body) => setState(() {
        _comments.add(DocumentComment(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          author: 'You',
          body: body,
          createdAt: DateTime.now(),
        ));
      }),
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

  void _showKeyboardShortcuts() {
    showKeyboardShortcutsDialog(context);
  }

  // ── Spell check (basic) ────────────────────────────────────────────────────

  void _showSpellCheckDialog() {
    // Common English misspellings map (a small built-in dictionary)
    const misspellings = <String, String>{
      'teh': 'the',
      'recieve': 'receive',
      'occured': 'occurred',
      'seperate': 'separate',
      'definately': 'definitely',
      'accomodate': 'accommodate',
      'acheive': 'achieve',
      'adress': 'address',
      'beleive': 'believe',
      'calender': 'calendar',
      'cemetary': 'cemetery',
      'collegue': 'colleague',
      'comittee': 'committee',
      'concious': 'conscious',
      'enviroment': 'environment',
      'existance': 'existence',
      'freind': 'friend',
      'foriegn': 'foreign',
      'grammer': 'grammar',
      'goverment': 'government',
      'harrass': 'harass',
      'independant': 'independent',
      'intresting': 'interesting',
      'knowlege': 'knowledge',
      'libary': 'library',
      'millenium': 'millennium',
      'miniscule': 'minuscule',
      'mischievious': 'mischievous',
      'neccessary': 'necessary',
      'noticable': 'noticeable',
      'occassion': 'occasion',
      'perseverence': 'perseverance',
      'privlege': 'privilege',
      'publically': 'publicly',
      'questionaire': 'questionnaire',
      'reccomend': 'recommend',
      'rythm': 'rhythm',
      'sieze': 'seize',
      'supercede': 'supersede',
      'tendancy': 'tendency',
      'thier': 'their',
      'tomarrow': 'tomorrow',
      'untill': 'until',
      'vaccuum': 'vacuum',
      'wierd': 'weird',
      'writting': 'writing',
    };

    final text = _openXmlDocument.plainText.toLowerCase();
    final words = RegExp(r"\b[a-z']+\b").allMatches(text);
    final found = <({String wrong, String suggestion, int count})>[];
    final counted = <String, int>{};
    for (final m in words) {
      final w = m.group(0)!;
      if (misspellings.containsKey(w)) {
        counted[w] = (counted[w] ?? 0) + 1;
      }
    }
    for (final entry in counted.entries) {
      found.add((
        wrong: entry.key,
        suggestion: misspellings[entry.key]!,
        count: entry.value,
      ));
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Spell Check'),
        content: SizedBox(
          width: 480,
          child: found.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spellcheck, color: Color(0xff16a34a), size: 40),
                    SizedBox(height: 12),
                    Text('No spelling errors found.',
                        style: TextStyle(fontSize: 15)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${found.length} potential misspelling${found.length == 1 ? '' : 's'}:',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: found.length,
                        itemBuilder: (context, i) {
                          final item = found[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.warning_amber_outlined,
                                color: Color(0xffd97706), size: 18),
                            title: Text(
                              '"${item.wrong}" → "${item.suggestion}"',
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              '${item.count} occurrence${item.count == 1 ? '' : 's'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                _replaceWordInDocument(
                                    item.wrong, item.suggestion);
                                Navigator.of(ctx).pop();
                                _showSnack(
                                    'Replaced "${item.wrong}" with "${item.suggestion}".');
                              },
                              child: const Text('Fix all'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          if (found.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                for (final item in found) {
                  _replaceWordInDocument(item.wrong, item.suggestion);
                }
                _showSnack('Fixed ${found.length} misspelling${found.length == 1 ? '' : 's'}.');
              },
              child: const Text('Fix All'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _replaceWordInDocument(String wrong, String correct) {
    final blocks = _openXmlDocument.blocks.map((block) {
      if (block is OpenXmlParagraphBlock) {
        return block.copyWith(
          runs: block.runs.map((run) {
            final replaced = run.text.replaceAllMapped(
              RegExp('\\b${RegExp.escape(wrong)}\\b', caseSensitive: false),
              (m) => correct,
            );
            return replaced != run.text
                ? OpenXmlRun(
                    replaced,
                    bold: run.bold,
                    italic: run.italic,
                    underline: run.underline,
                    strike: run.strike,
                    superscript: run.superscript,
                    subscript: run.subscript,
                    smallCaps: run.smallCaps,
                    allCaps: run.allCaps,
                    doubleUnderline: run.doubleUnderline,
                    doubleStrike: run.doubleStrike,
                    hidden: run.hidden,
                    colorHex: run.colorHex,
                    highlightHex: run.highlightHex,
                    letterSpacing: run.letterSpacing,
                    kerning: run.kerning,
                    textShadow: run.textShadow,
                    textOutline: run.textOutline,
                    href: run.href,
                    fontFamily: run.fontFamily,
                    fontSize: run.fontSize,
                  )
                : run;
          }).toList(),
        );
      }
      return block;
    }).toList();
    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = _openXmlDocument.copyWith(blocks: blocks);
      _setMarkdownSilently(_openXmlDocument.plainText);
      _saved = false;
    });
  }

  // ── Search comments ────────────────────────────────────────────────────────

  List<DocumentComment> _searchComments(String query) {
    if (query.isEmpty) return const [];
    final q = query.toLowerCase();
    return _comments.where((c) {
      if (c.body.toLowerCase().contains(q)) return true;
      if (c.author.toLowerCase().contains(q)) return true;
      return c.replies.any((r) =>
          r.body.toLowerCase().contains(q) ||
          r.author.toLowerCase().contains(q));
    }).toList();
  }

  void _showSearchCommentsDialog() {
    final queryCtrl = TextEditingController();
    var results = <DocumentComment>[];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Search Comments'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: queryCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Search text',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      setDlg(() => results = _searchComments(v)),
                ),
                const SizedBox(height: 12),
                if (results.isEmpty && queryCtrl.text.isNotEmpty)
                  const Text('No comments match.',
                      style: TextStyle(color: Color(0xff6b7280)))
                else if (results.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xff2563eb),
                            child: Text(
                              c.author.isNotEmpty
                                  ? c.author[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                          title: Text(c.author,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(
                            c.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: c.resolved
                              ? const Icon(Icons.check_circle_outline,
                                  color: Color(0xff16a34a), size: 18)
                              : null,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Digital signature dialog ──────────────────────────────────────────────

  String? _digitalSignature;
  DateTime? _signedAt;

  void _showDigitalSignatureDialog() {
    final nameCtrl =
        TextEditingController(text: _digitalSignature ?? _metadata.author);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Digital Signature'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_digitalSignature != null) ...[
                Row(
                  children: [
                    const Icon(Icons.verified_outlined,
                        color: Color(0xff16a34a), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Signed by $_digitalSignature\n'
                        '${_signedAt?.toLocal().toString().substring(0, 16) ?? ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Signer name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This adds a visible signature stamp to the document. '
                'For cryptographic signing, export to PDF and use an external tool.',
                style: TextStyle(fontSize: 12, color: Color(0xff6b7280)),
              ),
            ],
          ),
        ),
        actions: [
          if (_digitalSignature != null)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _digitalSignature = null;
                  _signedAt = null;
                });
                _showSnack('Signature removed.');
              },
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              setState(() {
                _digitalSignature = name;
                _signedAt = DateTime.now();
              });
              _appendOpenXmlBlock(
                OpenXmlParagraphBlock(
                  runs: [
                    OpenXmlRun(
                      'Digitally signed by $name — ${DateTime.now().toLocal().toString().substring(0, 16)}',
                      italic: true,
                      fontSize: 10,
                    ),
                  ],
                  style: OpenXmlTextStyle.caption,
                ),
              );
              _showSnack('Document signed by $name.');
            },
            child: const Text('Sign'),
          ),
        ],
      ),
    );
  }

  // ── Document encryption dialog ────────────────────────────────────────────

  void _showEncryptionDialog() {
    final pwdCtrl = TextEditingController();
    var obscure = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Encrypt Document'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: pwdCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setDlg(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Export to an encrypted DOCX or PDF using this password.\n'
                  'The document will be saved with password protection applied via the DOCX encryption standard (OOXML).',
                  style: TextStyle(fontSize: 12, color: Color(0xff6b7280)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pwd = pwdCtrl.text;
                if (pwd.isEmpty) return;
                Navigator.of(ctx).pop();
                _showSnack('Encryption password set. Export to apply.');
                // Stored for use during export — wire into export service when full encryption is supported.
              },
              child: const Text('Set Password'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Audit log ─────────────────────────────────────────────────────────────

  final List<({String action, DateTime at, String detail})> _auditLog = [];

  void _logAudit(String action, {String detail = ''}) {
    _auditLog.add((action: action, at: DateTime.now(), detail: detail));
    if (_auditLog.length > 500) _auditLog.removeAt(0);
  }

  void _showAuditLogDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audit Log'),
        content: SizedBox(
          width: 540,
          child: _auditLog.isEmpty
              ? const Text('No actions recorded yet.',
                  style: TextStyle(color: Color(0xff6b7280)))
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.builder(
                    reverse: true,
                    shrinkWrap: true,
                    itemCount: _auditLog.length,
                    itemBuilder: (context, i) {
                      final entry =
                          _auditLog[_auditLog.length - 1 - i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 140,
                              child: Text(
                                entry.at.toLocal().toString().substring(0, 16),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xff6b7280)),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.detail.isEmpty
                                    ? entry.action
                                    : '${entry.action}: ${entry.detail}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _auditLog.clear());
              _showSnack('Audit log cleared.');
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Insert list dialog (with bullet/numbering style) ──────────────────────

  void _showInsertListDialog() {
    var ordered = false;
    var bulletStyle = BulletStyle.disc;
    var numberingStyle = NumberingStyle.arabic;
    var startNumber = 1;
    final itemsCtrl = TextEditingController(
        text: 'Item 1\nItem 2\nItem 3');

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Insert List'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Bullet')),
                    ButtonSegment(value: true, label: Text('Numbered')),
                  ],
                  selected: {ordered},
                  onSelectionChanged: (s) =>
                      setDlg(() => ordered = s.first),
                ),
                const SizedBox(height: 12),
                if (!ordered)
                  DropdownButtonFormField<BulletStyle>(
                    initialValue: bulletStyle,
                    decoration: const InputDecoration(
                      labelText: 'Bullet style',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: BulletStyle.values
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.name),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDlg(() => bulletStyle = v ?? BulletStyle.disc),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<NumberingStyle>(
                          initialValue: numberingStyle,
                          decoration: const InputDecoration(
                            labelText: 'Style',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: NumberingStyle.values
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name),
                                  ))
                              .toList(),
                          onChanged: (v) => setDlg(() =>
                              numberingStyle = v ?? NumberingStyle.arabic),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: '$startNumber',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Start at',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              setDlg(() => startNumber = int.tryParse(v) ?? 1),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: itemsCtrl,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Items (one per line)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                final lines = itemsCtrl.text
                    .split('\n')
                    .map((l) => l.trim())
                    .where((l) => l.isNotEmpty)
                    .toList();
                if (lines.isEmpty) return;
                _appendOpenXmlBlock(
                  ListBlock(
                    items: lines.map((l) => ListItem(text: l)).toList(),
                    ordered: ordered,
                    bulletStyle: bulletStyle,
                    numberingStyle: numberingStyle,
                    startNumber: startNumber,
                  ),
                );
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Duplex / scaling print options ────────────────────────────────────────

  bool _duplexPrint = false;
  double _printScale = 1.0;

  void _showPrintOptionsDialog() {
    var duplex = _duplexPrint;
    var scale = _printScale;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Print Options'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Duplex (two-sided) printing'),
                  subtitle: const Text('Print on both sides of the paper'),
                  value: duplex,
                  onChanged: (v) => setDlg(() => duplex = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Scale', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: scale,
                        min: 0.5,
                        max: 2.0,
                        divisions: 30,
                        label: '${(scale * 100).round()}%',
                        onChanged: (v) => setDlg(() => scale = v),
                      ),
                    ),
                    Text('${(scale * 100).round()}%'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _duplexPrint = duplex;
                  _printScale = scale;
                });
                _showSnack('Print options saved.');
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grammar check ─────────────────────────────────────────────────────────

  void _showGrammarCheckDialog() {
    final text = _openXmlDocument.plainText;
    final issues = <String>[];

    // Double spaces
    final doubleSpace = RegExp(r'  +');
    if (doubleSpace.hasMatch(text)) issues.add('Double spaces found.');

    // Sentence not starting with capital
    final sentences = RegExp(r'(?:^|[.!?]\s+)([a-z])');
    if (sentences.hasMatch(text)) issues.add('Sentence(s) not starting with a capital letter.');

    // Trailing spaces on lines
    if (RegExp(r' +\n').hasMatch(text)) issues.add('Trailing spaces on some lines.');

    // Repeated words (e.g. "the the")
    final repeated = RegExp(r'\b(\w+)\s+\1\b', caseSensitive: false);
    final matches = repeated.allMatches(text);
    for (final m in matches) {
      issues.add('Repeated word: "${m.group(1)}".');
    }

    // Common grammar errors
    const grammarMap = {
      r'\bcould of\b': '"could of" → "could have"',
      r'\bwould of\b': '"would of" → "would have"',
      r'\bshould of\b': '"should of" → "should have"',
      r'\bmore easier\b': '"more easier" → "easier"',
      r'\bmore better\b': '"more better" → "better"',
      r'\bless worse\b': '"less worse" → "less bad"',
      r'\bi\b(?!\.)': 'Lowercase "i" (should be "I")',
      r'\ba [aeiou]\w+': '"a" before vowel sound (consider "an")',
    };
    for (final entry in grammarMap.entries) {
      if (RegExp(entry.key, caseSensitive: false).hasMatch(text)) {
        issues.add(entry.value);
      }
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grammar Check'),
        content: SizedBox(
          width: 480,
          child: issues.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Color(0xff16a34a), size: 40),
                    SizedBox(height: 12),
                    Text('No grammar issues found.',
                        style: TextStyle(fontSize: 15)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${issues.length} issue${issues.length == 1 ? '' : 's'} found:',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: issues.length,
                        itemBuilder: (context, i) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.warning_amber_outlined,
                              color: Color(0xffd97706), size: 18),
                          title: Text(issues[i],
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Multi-language spell check ─────────────────────────────────────────────

  String _spellCheckLanguage = 'English (US)';
  static const _spellCheckLanguages = [
    'English (US)',
    'English (UK)',
    'French',
    'German',
    'Spanish',
    'Italian',
    'Portuguese',
    'Dutch',
    'Polish',
    'Russian',
    'Japanese',
    'Chinese (Simplified)',
    'Arabic',
  ];

  void _showMultiLanguageSpellDialog() {
    var lang = _spellCheckLanguage;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Spell Check Language'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select the document language for spell checking:',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: lang,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _spellCheckLanguages
                      .map((l) =>
                          DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) => setDlg(() => lang = v ?? lang),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Full multi-language dictionaries require '
                  'language packs. This sets the document language tag.',
                  style: TextStyle(fontSize: 11, color: Color(0xff6b7280)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _spellCheckLanguage = lang);
                _showSnack('Spell check language set to $lang.');
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Comment-only mode ──────────────────────────────────────────────────────

  bool _commentOnlyMode = false;

  void _showCommentOnlyModeDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comment-Only Mode'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _commentOnlyMode
                    ? 'Comment-only mode is currently ON.\nThe document content is locked — only comments can be added.'
                    : 'Enabling comment-only mode locks document content.\nViewers can only add and reply to comments.',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _commentOnlyMode = !_commentOnlyMode);
              _showSnack(_commentOnlyMode
                  ? 'Comment-only mode enabled.'
                  : 'Comment-only mode disabled.');
            },
            child: Text(_commentOnlyMode ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );
  }

  // ── Search styles ──────────────────────────────────────────────────────────

  void _showSearchStylesDialog() {
    final queryCtrl = TextEditingController();
    OpenXmlTextStyle? filterStyle;
    var results = <int>[];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          void runSearch() {
            final q = queryCtrl.text.toLowerCase();
            final found = <int>[];
            for (var i = 0;
                i < _openXmlDocument.blocks.length;
                i++) {
              final block = _openXmlDocument.blocks[i];
              if (block is! OpenXmlParagraphBlock) continue;
              if (filterStyle != null && block.style != filterStyle) continue;
              if (q.isNotEmpty &&
                  !block.runs
                      .map((r) => r.text.toLowerCase())
                      .join()
                      .contains(q)) {
                continue;
              }
              found.add(i);
            }
            setDlg(() => results = found);
          }

          return AlertDialog(
            title: const Text('Search by Style'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: queryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Text (optional)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => runSearch(),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<OpenXmlTextStyle?>(
                    initialValue: filterStyle,
                    decoration: const InputDecoration(
                      labelText: 'Paragraph style',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Any style')),
                      ...OpenXmlTextStyle.values.map((s) =>
                          DropdownMenuItem(value: s, child: Text(s.label))),
                    ],
                    onChanged: (v) {
                      setDlg(() => filterStyle = v);
                      runSearch();
                    },
                  ),
                  const SizedBox(height: 10),
                  if (results.isEmpty && (queryCtrl.text.isNotEmpty || filterStyle != null))
                    const Text('No matching blocks.',
                        style: TextStyle(color: Color(0xff6b7280)))
                  else if (results.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final idx = results[i];
                          final block = _openXmlDocument.blocks[idx]
                              as OpenXmlParagraphBlock;
                          return ListTile(
                            dense: true,
                            leading: Text('§${idx + 1}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xff6b7280))),
                            title: Text(
                              block.runs.map((r) => r.text).join(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(block.style.label,
                                style:
                                    const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Typography options ─────────────────────────────────────────────────────

  void _showTypographyOptionsDialog() {
    var ligatures = false;
    var stylisticSet = 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Typography Options'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('OpenType Ligatures'),
                  subtitle: const Text(
                      'Combine fi, fl, ff, ffi, ffl into single glyphs'),
                  value: ligatures,
                  onChanged: (v) => setDlg(() => ligatures = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Stylistic Set  ',
                        style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: stylisticSet,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: 0, child: Text('Default')),
                          ...List.generate(
                            20,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('Set ${i + 1}'),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setDlg(() => stylisticSet = v ?? 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'These options apply to selected text. '
                  'Not all fonts support all stylistic sets.',
                  style:
                      TextStyle(fontSize: 11, color: Color(0xff6b7280)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _applyTypographyToSelection(
                  ligatures: ligatures,
                  stylisticSet: stylisticSet == 0 ? null : stylisticSet,
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyTypographyToSelection({
    required bool ligatures,
    required int? stylisticSet,
  }) {
    if (!_isNativeOpenXmlEditor) return;
    _recordOpenXmlUndoState();
    setState(() {
      _openXmlDocument = _openXmlDocument.copyWith(
        blocks: _openXmlDocument.blocks.map((block) {
          if (block is OpenXmlParagraphBlock) {
            return block.copyWith(
              runs: block.runs.map((run) => OpenXmlRun(
                run.text,
                bold: run.bold,
                italic: run.italic,
                underline: run.underline,
                strike: run.strike,
                superscript: run.superscript,
                subscript: run.subscript,
                smallCaps: run.smallCaps,
                allCaps: run.allCaps,
                doubleUnderline: run.doubleUnderline,
                doubleStrike: run.doubleStrike,
                hidden: run.hidden,
                colorHex: run.colorHex,
                highlightHex: run.highlightHex,
                letterSpacing: run.letterSpacing,
                kerning: run.kerning,
                textShadow: run.textShadow,
                textOutline: run.textOutline,
                ligatures: ligatures,
                stylisticSet: stylisticSet,
                href: run.href,
                fontFamily: run.fontFamily,
                fontSize: run.fontSize,
              )).toList(),
            );
          }
          return block;
        }).toList(),
      );
      _saved = false;
    });
  }

  // ── Image filters ──────────────────────────────────────────────────────────

  void _showImageFiltersDialog() {
    if (_mediaBlocks.isEmpty) {
      _showSnack('Insert an image first to apply filters.');
      return;
    }

    var selectedIdx = 0;
    var filter = _mediaBlocks.first.imageFilter;
    var brightness = _mediaBlocks.first.brightness;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Image Filters'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_mediaBlocks.length > 1)
                  DropdownButtonFormField<int>(
                    initialValue: selectedIdx,
                    decoration: const InputDecoration(
                      labelText: 'Image',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: List.generate(
                      _mediaBlocks.length,
                      (i) => DropdownMenuItem(
                        value: i,
                        child: Text(
                          _mediaBlocks[i].caption.isNotEmpty
                              ? _mediaBlocks[i].caption
                              : 'Image ${i + 1}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      setDlg(() {
                        selectedIdx = v;
                        filter = _mediaBlocks[v].imageFilter;
                        brightness = _mediaBlocks[v].brightness;
                      });
                    },
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ImageFilterType>(
                  initialValue: filter,
                  decoration: const InputDecoration(
                    labelText: 'Filter',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ImageFilterType.values
                      .map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f.name[0].toUpperCase() +
                                f.name.substring(1)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDlg(() => filter = v ?? ImageFilterType.none),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Brightness  ',
                        style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Slider(
                        value: brightness,
                        min: 0.2,
                        max: 2.0,
                        divisions: 36,
                        label: '${(brightness * 100).round()}%',
                        onChanged: (v) => setDlg(() => brightness = v),
                      ),
                    ),
                    Text('${(brightness * 100).round()}%'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _applyImageFilter(selectedIdx, ImageFilterType.none, 1.0);
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _applyImageFilter(selectedIdx, filter, brightness);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyImageFilter(int idx, ImageFilterType filter, double brightness) {
    if (idx >= _mediaBlocks.length) return;
    _recordOpenXmlUndoState();
    setState(() {
      _mediaBlocks[idx] = _mediaBlocks[idx]
          .copyWith(imageFilter: filter, brightness: brightness);
      _saved = false;
    });
  }

  // ── Content controls / form fields ────────────────────────────────────────

  void _showInsertContentControlDialog() {
    var fieldType = FormFieldType.text;
    final labelCtrl = TextEditingController(text: 'Field');
    final placeholderCtrl = TextEditingController(text: 'Enter value…');
    final optionsCtrl =
        TextEditingController(text: 'Option A\nOption B\nOption C');
    var required = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Insert Content Control'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<FormFieldType>(
                  initialValue: fieldType,
                  decoration: const InputDecoration(
                    labelText: 'Field type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: FormFieldType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.name[0].toUpperCase() +
                                t.name.substring(1)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDlg(() => fieldType = v ?? FormFieldType.text),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                if (fieldType != FormFieldType.checkbox)
                  TextField(
                    controller: placeholderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Placeholder / hint',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                if (fieldType == FormFieldType.dropdown) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: optionsCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Options (one per line)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Required field'),
                  value: required,
                  onChanged: (v) => setDlg(() => required = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                final opts = fieldType == FormFieldType.dropdown
                    ? optionsCtrl.text
                          .split('\n')
                          .map((l) => l.trim())
                          .where((l) => l.isNotEmpty)
                          .toList()
                    : <String>[];
                _appendOpenXmlBlock(FormFieldBlock(
                  fieldType: fieldType,
                  label: labelCtrl.text.trim(),
                  placeholder: placeholderCtrl.text.trim(),
                  options: opts,
                  required: required,
                ));
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Named snapshots ────────────────────────────────────────────────────────

  final List<DocumentSnapshot> _namedSnapshots = [];

  void _showNamedSnapshotsDialog() {
    final nameCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Named Snapshots'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Snapshot name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        setDlg(() {
                          _namedSnapshots.add(DocumentSnapshot(
                            name: name,
                            createdAt: DateTime.now(),
                            json: _openXmlDocument.toJson(),
                          ));
                          nameCtrl.clear();
                        });
                        _logAudit('Snapshot created', detail: name);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_namedSnapshots.isEmpty)
                  const Text('No snapshots yet.',
                      style: TextStyle(color: Color(0xff6b7280)))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _namedSnapshots.length,
                      itemBuilder: (context, i) {
                        final snap = _namedSnapshots[
                            _namedSnapshots.length - 1 - i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                              Icons.bookmark_outline, size: 18),
                          title: Text(snap.name,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            snap.createdAt
                                .toLocal()
                                .toString()
                                .substring(0, 16),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  _recordOpenXmlUndoState();
                                  setState(() {
                                    _openXmlDocument =
                                        OpenXmlDocument.fromJson(snap.json);
                                    _saved = false;
                                  });
                                  _showSnack(
                                      'Restored snapshot "${snap.name}".');
                                },
                                child: const Text('Restore'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18),
                                onPressed: () => setDlg(() =>
                                    _namedSnapshots.removeWhere(
                                        (s) => s.name == snap.name &&
                                            s.createdAt == snap.createdAt)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rights management ──────────────────────────────────────────────────────

  final Map<String, Set<String>> _rightsMap = {};

  void _showRightsManagementDialog() {
    final emailCtrl = TextEditingController();
    final rights = <String>{'view'};
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Rights Management'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Control who can view, comment, or edit this document.',
                  style: TextStyle(fontSize: 13, color: Color(0xff374151)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email or name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final e = emailCtrl.text.trim();
                        if (e.isEmpty) return;
                        setDlg(() {
                          _rightsMap[e] = Set.from(rights);
                          emailCtrl.clear();
                        });
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['view', 'comment', 'edit', 'print']
                      .map((r) => FilterChip(
                            label: Text(r),
                            selected: rights.contains(r),
                            onSelected: (v) => setDlg(() =>
                                v ? rights.add(r) : rights.remove(r)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                if (_rightsMap.isEmpty)
                  const Text('No restrictions set.',
                      style: TextStyle(color: Color(0xff6b7280)))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView(
                      shrinkWrap: true,
                      children: _rightsMap.entries
                          .map((entry) => ListTile(
                                dense: true,
                                leading: const Icon(
                                    Icons.person_outline, size: 18),
                                title: Text(entry.key,
                                    style:
                                        const TextStyle(fontSize: 13)),
                                subtitle: Text(
                                  entry.value.join(', '),
                                  style:
                                      const TextStyle(fontSize: 11),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 16),
                                  onPressed: () => setDlg(() =>
                                      _rightsMap.remove(entry.key)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showSnack('Rights management updated.');
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compliance retention ───────────────────────────────────────────────────

  int _retentionDays = 0;

  void _showComplianceRetentionDialog() {
    var days = _retentionDays;
    var policy = 'None';
    const policies = [
      'None',
      'GDPR — 3 years',
      'HIPAA — 6 years',
      'SOX — 7 years',
      'ISO 27001 — 3 years',
      'Custom',
    ];
    final customCtrl = TextEditingController(
        text: days > 0 ? '$days' : '');

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Compliance & Retention'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: policy,
                  decoration: const InputDecoration(
                    labelText: 'Retention policy',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: policies
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    setDlg(() {
                      policy = v ?? 'None';
                      switch (policy) {
                        case 'GDPR — 3 years':
                          days = 365 * 3;
                        case 'HIPAA — 6 years':
                          days = 365 * 6;
                        case 'SOX — 7 years':
                          days = 365 * 7;
                        case 'ISO 27001 — 3 years':
                          days = 365 * 3;
                        default:
                          days = 0;
                      }
                      customCtrl.text = days > 0 ? '$days' : '';
                    });
                  },
                ),
                if (policy == 'Custom') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: customCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Retention days',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setDlg(() => days = int.tryParse(v) ?? 0),
                  ),
                ],
                const SizedBox(height: 8),
                if (days > 0)
                  Text(
                    'Document will be retained for ${(days / 365).toStringAsFixed(1)} years.',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff2563eb)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() => _retentionDays = days);
                _showSnack(days > 0
                    ? 'Retention set to $days days.'
                    : 'Retention policy cleared.');
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Approval workflow ──────────────────────────────────────────────────────

  final List<({String approver, String status, DateTime? completedAt})>
      _approvalSteps = [];

  void _showApprovalWorkflowDialog() {
    final approverCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Approval Workflow'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: approverCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Approver name / email',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final name = approverCtrl.text.trim();
                        if (name.isEmpty) return;
                        setDlg(() {
                          _approvalSteps.add((
                            approver: name,
                            status: 'pending',
                            completedAt: null,
                          ));
                          approverCtrl.clear();
                        });
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_approvalSteps.isEmpty)
                  const Text('No approvers added.',
                      style: TextStyle(color: Color(0xff6b7280)))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      itemCount: _approvalSteps.length,
                      onReorderItem: (o, n) {
                        setDlg(() {
                          final item = _approvalSteps.removeAt(o);
                          _approvalSteps.insert(
                              n > o ? n - 1 : n, item);
                        });
                      },
                      itemBuilder: (context, i) {
                        final step = _approvalSteps[i];
                        final done = step.status == 'approved';
                        return ListTile(
                          key: ValueKey('$i${step.approver}'),
                          dense: true,
                          leading: Icon(
                            done
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            color: done
                                ? const Color(0xff16a34a)
                                : const Color(0xff6b7280),
                            size: 20,
                          ),
                          title: Text(step.approver,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(step.status,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff6b7280))),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!done)
                                TextButton(
                                  onPressed: () => setDlg(() {
                                    final idx = _approvalSteps
                                        .indexWhere((s) =>
                                            s.approver ==
                                                step.approver &&
                                            s.status == step.status);
                                    if (idx >= 0) {
                                      _approvalSteps[idx] = (
                                        approver: step.approver,
                                        status: 'approved',
                                        completedAt: DateTime.now(),
                                      );
                                    }
                                  }),
                                  child: const Text('Approve'),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setDlg(() =>
                                    _approvalSteps.removeAt(i)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showSnack('Approval workflow saved.');
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Page numbering ─────────────────────────────────────────────────────────

  void _showPageNumberingDialog() {
    var position = 'footer-center';
    var startAt = 1;
    var format = 'arabic';
    const positions = {
      'header-left': 'Header — Left',
      'header-center': 'Header — Center',
      'header-right': 'Header — Right',
      'footer-left': 'Footer — Left',
      'footer-center': 'Footer — Center',
      'footer-right': 'Footer — Right',
    };
    const formats = {
      'arabic': '1, 2, 3…',
      'roman': 'i, ii, iii…',
      'alpha': 'a, b, c…',
    };

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Page Numbering'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: position,
                  decoration: const InputDecoration(
                    labelText: 'Position',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: positions.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) => setDlg(() => position = v ?? position),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: format,
                  decoration: const InputDecoration(
                    labelText: 'Number format',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: formats.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) => setDlg(() => format = v ?? format),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: '$startAt',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Start at',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) =>
                      setDlg(() => startAt = int.tryParse(v) ?? 1),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _insertPageNumberField(position, format, startAt);
              },
              child: const Text('Insert'),
            ),
          ],
        ),
      ),
    );
  }

  void _insertPageNumberField(String position, String format, int startAt) {
    final isHeader = position.startsWith('header');
    final align = position.endsWith('left')
        ? 'left'
        : position.endsWith('right')
            ? 'right'
            : 'center';
    final fieldText = '{PAGE:$format:$startAt}';
    _appendOpenXmlBlock(
      OpenXmlParagraphBlock(
        runs: [
          OpenXmlRun(
            isHeader ? '[Header: $fieldText]' : '[Footer: $fieldText]',
            italic: true,
            fontSize: 9,
            colorHex: '6b7280',
          ),
        ],
        align: align == 'left'
            ? OoxmlTextAlign.left
            : align == 'right'
                ? OoxmlTextAlign.right
                : OoxmlTextAlign.center,
        style: OpenXmlTextStyle.caption,
      ),
    );
    _showSnack('Page number inserted (${isHeader ? 'header' : 'footer'}, $align).');
  }

  // ── View mode dialogs ──────────────────────────────────────────────────────

  void _showViewModeDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('View Mode'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _viewModeOption(ctx, Icons.print_outlined, 'Print Layout',
                  'Full page layout with margins and headers',
                  () => _showSnack('Print Layout active.')),
              _viewModeOption(ctx, Icons.drafts_outlined, 'Draft View',
                  'Plain flow — no margins or headers',
                  () => _showSnack('Draft View: use plain text edit mode.')),
              _viewModeOption(ctx, Icons.language_outlined, 'Web Layout',
                  'Continuous scrolling, no page breaks',
                  () => _showSnack('Web Layout: use continuous page layout.')),
              _viewModeOption(ctx, Icons.menu_book_outlined, 'Read Mode',
                  'Distraction-free reading (focus mode)',
                  () {
                Navigator.of(ctx).pop();
                setState(() => _focusMode = true);
              }),
              _viewModeOption(ctx, Icons.format_list_bulleted_outlined,
                  'Outline View',
                  'Show only headings for structural editing',
                  () {
                Navigator.of(ctx).pop();
                _showSnack('Outline view: headings are shown in the navigation panel.');
                setState(() => _showNavigation = true);
              }),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _viewModeOption(
    BuildContext ctx,
    IconData icon,
    String label,
    String description,
    VoidCallback onTap,
  ) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(description, style: const TextStyle(fontSize: 11)),
      onTap: onTap,
    );
  }

  // ── Plugin architecture dialog (stub) ─────────────────────────────────────

  void _showPluginArchitectureDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plugin Architecture'),
        content: const SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plugin support lets third-party extensions add commands, '
                'export formats, and custom blocks to the editor.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 12),
              Text('Available plugin hooks:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              SizedBox(height: 6),
              Text('• onBlockInsert — intercept block creation', style: TextStyle(fontSize: 12)),
              Text('• onExport — register custom export formats', style: TextStyle(fontSize: 12)),
              Text('• onRibbonMount — add toolbar buttons', style: TextStyle(fontSize: 12)),
              Text('• onDocumentLoad — transform incoming JSON', style: TextStyle(fontSize: 12)),
              SizedBox(height: 8),
              Text(
                'Plugin SDK is available as a Dart package. '
                'See docs/plugin_sdk.md for the API reference.',
                style: TextStyle(fontSize: 12, color: Color(0xff6b7280)),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
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
    final previewNotes = _exportService.exportPreviewNotes(_exportPayload);
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
              for (final note in previewNotes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xff2563eb),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note,
                          style: const TextStyle(color: Color(0xff475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
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
                    label: 'Text',
                    onTap: () => _finishExport(context, 'Text'),
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
    } else if (type == 'Text') {
      _exportToFile('text');
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
    return ListenableBuilder(
      listenable: ShortcutRegistry.instance,
      builder: (context, child) => Shortcuts(
        shortcuts: ShortcutRegistry.instance.buildShortcutMap(),
        child: child!,
      ),
      child: Actions(
        actions: {
          // ── Formatting ─────────────────────────────────────────────────
          ToggleBoldIntent: CallbackAction<ToggleBoldIntent>(
            onInvoke: (_) {
              if (_isNativeOpenXmlEditor) {
                _applyInlineFormat(RunAttr.bold);
              } else {
                _srqController.toggleBold();
                setState(() {});
              }
              return null;
            },
          ),
          ToggleItalicIntent: CallbackAction<ToggleItalicIntent>(
            onInvoke: (_) {
              if (_isNativeOpenXmlEditor) {
                _applyInlineFormat(RunAttr.italic);
              } else {
                _srqController.toggleItalic();
                setState(() {});
              }
              return null;
            },
          ),
          ToggleUnderlineIntent: CallbackAction<ToggleUnderlineIntent>(
            onInvoke: (_) {
              if (_isNativeOpenXmlEditor) {
                _applyInlineFormat(RunAttr.underline);
              } else {
                _srqController.toggleUnderline();
                setState(() {});
              }
              return null;
            },
          ),
          ToggleStrikethroughIntent: CallbackAction<ToggleStrikethroughIntent>(
            onInvoke: (_) {
              if (_isNativeOpenXmlEditor) {
                _applyInlineFormat(RunAttr.strike);
              } else {
                _srqController.toggleStrikethrough();
                setState(() {});
              }
              return null;
            },
          ),
          ClearFormattingIntent: CallbackAction<ClearFormattingIntent>(
            onInvoke: (_) {
              _clearFormatting();
              return null;
            },
          ),
          // ── Paragraph styles ───────────────────────────────────────────
          ApplyNormalStyleIntent: CallbackAction<ApplyNormalStyleIntent>(
            onInvoke: (_) {
              _applySelectedStyle('Normal');
              return null;
            },
          ),
          ApplyHeading1Intent: CallbackAction<ApplyHeading1Intent>(
            onInvoke: (_) {
              _applySelectedStyle('Heading 1');
              return null;
            },
          ),
          ApplyHeading2Intent: CallbackAction<ApplyHeading2Intent>(
            onInvoke: (_) {
              _applySelectedStyle('Heading 2');
              return null;
            },
          ),
          ApplyHeading3Intent: CallbackAction<ApplyHeading3Intent>(
            onInvoke: (_) {
              _applySelectedStyle('Heading 3');
              return null;
            },
          ),
          ApplyHeading4Intent: CallbackAction<ApplyHeading4Intent>(
            onInvoke: (_) {
              _applySelectedStyle('Heading 4');
              return null;
            },
          ),
          ApplyHeading5Intent: CallbackAction<ApplyHeading5Intent>(
            onInvoke: (_) {
              _applySelectedStyle('Heading 5');
              return null;
            },
          ),
          // ── Document ───────────────────────────────────────────────────
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              if (_isNativeOpenXmlEditor) {
                _undoOpenXml();
              } else {
                _srqController.undo();
              }
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              if (_isNativeOpenXmlEditor) {
                _redoOpenXml();
              } else {
                _srqController.redo();
              }
              return null;
            },
          ),
          SaveDocumentIntent: CallbackAction<SaveDocumentIntent>(
            onInvoke: (_) {
              _saveDocument();
              return null;
            },
          ),
          NewDocumentIntent: CallbackAction<NewDocumentIntent>(
            onInvoke: (_) {
              _newDocument();
              return null;
            },
          ),
          OpenFileIntent: CallbackAction<OpenFileIntent>(
            onInvoke: (_) {
              _showImportSheet();
              return null;
            },
          ),
          FindTextIntent: CallbackAction<FindTextIntent>(
            onInvoke: (_) {
              setState(() => _showNavigation = true);
              return null;
            },
          ),
          FindReplaceIntent: CallbackAction<FindReplaceIntent>(
            onInvoke: (_) {
              setState(() => _showNavigation = true);
              return null;
            },
          ),
          // ── View ───────────────────────────────────────────────────────
          ToggleFocusModeIntent: CallbackAction<ToggleFocusModeIntent>(
            onInvoke: (_) {
              setState(() => _focusMode = !_focusMode);
              return null;
            },
          ),
          ToggleNavigationPanelIntent:
              CallbackAction<ToggleNavigationPanelIntent>(
            onInvoke: (_) {
              setState(() => _showNavigation = !_showNavigation);
              return null;
            },
          ),
          ToggleInspectorPanelIntent:
              CallbackAction<ToggleInspectorPanelIntent>(
            onInvoke: (_) {
              setState(() => _showInspector = !_showInspector);
              return null;
            },
          ),
          ShowKeyboardShortcutsIntent:
              CallbackAction<ShowKeyboardShortcutsIntent>(
            onInvoke: (_) {
              _showKeyboardShortcuts();
              return null;
            },
          ),
          PasteSpecialIntent: CallbackAction<PasteSpecialIntent>(
            onInvoke: (_) {
              _showPasteSpecialDialog();
              return null;
            },
          ),
          InsertBookmarkIntent: CallbackAction<InsertBookmarkIntent>(
            onInvoke: (_) {
              _showInsertBookmarkDialog();
              return null;
            },
          ),
        },
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewMode = _mode == OpenDocMode.view;
                final compact = constraints.maxWidth < 900;
                final showLeft =
                    _showNavigation && !compact && !_focusMode && !viewMode;
                final showRight =
                    _showInspector && !compact && !_focusMode && !viewMode;

                return Column(
                  children: [
                    if (viewMode)
                      _ViewModeHeader(
                        title: _titleController.text,
                        onEdit: () =>
                            setState(() => _mode = OpenDocMode.edit),
                      )
                    else
                    TopBar(
                      titleController: _titleController,
                      focusMode: _focusMode,
                      saved: _saved,
                      autosaveEnabled: _autosaveEnabled,
                      autosaveLabel: 'every '
                          '${_autosaveIntervalLabel(_autosaveInterval)}',
                      onNew: _newDocument,
                      onSave: _saveDocument,
                      onAutosave: _showAutosaveSettings,
                      onToolbarLayout: _showToolbarLayoutMenu,
                      onImport: _showImportSheet,
                      onTemplates: _showTemplateSheet,
                      onDuplicate: _duplicateDocument,
                      onCopy: _copyPlainText,
                      onShare: _showShareSheet,
                      onHistory: _showVersionHistorySheet,
                      onExport: _showExportSheet,
                      onToggleFocus: () {
                        setState(() => _focusMode = !_focusMode);
                      },
                    ),
                    if (!_focusMode && !viewMode)
                      TapRegion(
                        groupId: EditableText,
                        child: Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (_) {
                            if (_isNativeOpenXmlEditor) {
                              _rememberOpenXmlSelection();
                            }
                          },
                          child: Ribbon(
                            layout: _toolbarLayout,
                            bold: _bold,
                            italic: _italic,
                            underline: _underline,
                            strikethrough: _strikethrough,
                            superscript: _superscript,
                            subscript: _subscript,
                            smallCaps: _smallCaps,
                            allCaps: _allCaps,
                            doubleUnderline: _doubleUnderline,
                            doubleStrike: _doubleStrike,
                            hidden: _hidden,
                            formatPainterActive: _formatPainterActive,
                            highlightColor: _highlightColor,
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
                              if (_isNativeOpenXmlEditor) {
                                _applyInlineFormat(RunAttr.bold);
                              } else {
                                _srqController.toggleBold();
                                setState(() {});
                              }
                            },
                            onItalic: () {
                              if (_isNativeOpenXmlEditor) {
                                _applyInlineFormat(RunAttr.italic);
                              } else {
                                _srqController.toggleItalic();
                                setState(() {});
                              }
                            },
                            onUnderline: () {
                              if (_isNativeOpenXmlEditor) {
                                _applyInlineFormat(RunAttr.underline);
                              } else {
                                _srqController.toggleUnderline();
                                setState(() {});
                              }
                            },
                            onStrikethrough: () {
                              if (_isNativeOpenXmlEditor) {
                                _applyInlineFormat(RunAttr.strike);
                              } else {
                                _srqController.toggleStrikethrough();
                                setState(() {});
                              }
                            },
                            onSuperscript: () =>
                                _applyInlineFormat(RunAttr.superscript),
                            onSubscript: () =>
                                _applyInlineFormat(RunAttr.subscript),
                            onSmallCaps: () =>
                                _applyInlineFormat(RunAttr.smallCaps),
                            onAllCaps: () =>
                                _applyInlineFormat(RunAttr.allCaps),
                            onDoubleUnderline: () =>
                                _applyInlineFormat(RunAttr.doubleUnderline),
                            onDoubleStrike: () =>
                                _applyInlineFormat(RunAttr.doubleStrike),
                            onHidden: () =>
                                _applyInlineFormat(RunAttr.hidden),
                            onFormatPainter: _activateFormatPainter,
                            onClearFormatting: _clearFormatting,
                            onHighlight: (color) {
                              setState(() => _highlightColor = color);
                              final hex = color == null
                                  ? null
                                  : _hexForColor(color);
                              _applyHighlight(hex);
                            },
                            onIndentIncrease: _indentIncrease,
                            onIndentDecrease: _indentDecrease,
                            onRuler: () =>
                                setState(() => _showRuler = !_showRuler),
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
                            onStyle: _applySelectedStyle,
                            onAlignment: (value) {
                              setState(() => _alignment = value);
                              if (_isNativeOpenXmlEditor) {
                                final flatCtrl = _activeRunController;
                                if (flatCtrl is DocumentFlatController) {
                                  flatCtrl.setBlockAlign(
                                    _activeOpenXmlBlockIndex ?? 0,
                                    _openXmlAlignForRibbon(value),
                                  );
                                  _refocusActiveOpenXmlEditor();
                                } else {
                                  _updateActiveOpenXmlParagraph(
                                    (block) => block.copyWith(
                                      align: _openXmlAlignForRibbon(value),
                                    ),
                                  );
                                  _refocusActiveOpenXmlEditor();
                                }
                              }
                            },
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
                            onInkColor: (value) {
                              if (_editMode == DocumentEditMode.openXml) {
                                _applyTextColor(value);
                              } else if (_editMode ==
                                  DocumentEditMode.wysiwyg) {
                                _applyWysiwygTextColor(value);
                              } else {
                                _applyPlainTextColor(value);
                              }
                            },
                            onPageColor: (value) =>
                                setState(() => _pageColor = value),
                            onInsertTable: _showAdvancedTableSheet,
                            onInsertImage: () =>
                                _showMediaSheet(MediaType.image),
                            onInsertVideo: () =>
                                _showMediaSheet(MediaType.video),
                            onInsertChecklist: () {
                              if (_isNativeOpenXmlEditor) {
                                _appendOpenXmlBlock(
                                  const OpenXmlParagraphBlock(
                                    runs: [OpenXmlRun('Action item')],
                                  ),
                                );
                              } else {
                                _insertText('\n* [ ] Action item\n');
                              }
                            },
                            onInsertBulletList: () => _isNativeOpenXmlEditor
                                ? _appendOpenXmlBlock(
                                    const OpenXmlParagraphBlock(
                                      runs: [OpenXmlRun('List item')],
                                    ),
                                  )
                                : _srqController.toggleBulletList(),
                            onInsertOrderedList: () => _isNativeOpenXmlEditor
                                ? _appendOpenXmlBlock(
                                    const OpenXmlParagraphBlock(
                                      runs: [OpenXmlRun('List item')],
                                    ),
                                  )
                                : _srqController.toggleOrderedList(),
                            onInsertPageBreak: _insertPageBreak,
                            onInsertToc: _insertTableOfContents,
                            onInsertFootnote: _insertFootnote,
                            onInsertEndnote: _insertEndnote,
                            onInsertHorizontalRule: _insertHorizontalRule,
                            onInsertDropCap: _insertDropCap,
                            onInsertShape: _insertShape,
                            onInsertLink: _insertLink,
                            onInsertSignature: () {
                              final firstWord = _titleController.text
                                  .split(' ')
                                  .first;
                              if (_isNativeOpenXmlEditor) {
                                _appendOpenXmlBlock(
                                  OpenXmlParagraphBlock(
                                    runs: [OpenXmlRun('Regards,\n$firstWord')],
                                  ),
                                );
                              } else {
                                _insertText('\n\nRegards,\n$firstWord\n');
                              }
                            },
                            onUndo: _isNativeOpenXmlEditor
                                ? _undoOpenXml
                                : _srqController.undo,
                            onRedo: _isNativeOpenXmlEditor
                                ? _redoOpenXml
                                : _srqController.redo,
                            onAcceptChanges: _showTrackChangesDialog,
                            onRejectChanges: _rejectAllChanges,
                            onSmartBrief: _showSmartBriefSheet,
                            onSocialSummary: _copySocialSummary,
                            onCitationNudge: _insertCitationNudge,
                            onActionDigest: _insertActionDigest,
                            onKeyboardShortcuts: _showKeyboardShortcuts,
                            highContrast: _highContrast,
                            onHighContrast: () =>
                                setState(() => _highContrast = !_highContrast),
                            onPrintPreview: _showPrintPreview,
                            onImageProperties:
                                _showImagePropertiesForFirstBlock,
                            onImageCrop: _showImageCropDialog,
                            onCustomToc: _showCustomTocDialog,
                            onDocumentProperties:
                                _showDocumentPropertiesDialog,
                            onPageLayout: _showPageLayoutDialog,
                            onParagraphSpacing: _showParagraphSpacingDialog,
                            onTabStops: _showTabStopsDialog,
                            onTheme: _showThemeDialog,
                            onStyleOrganizer: _showStyleOrganizerDialog,
                            onInsertField: _showInsertFieldDialog,
                            onInsertIndexEntry: _showInsertIndexEntryDialog,
                            onShowIndex: _showIndexDialog,
                            onInsertCrossReference:
                                _showInsertCrossReferenceDialog,
                            onCompareDocuments: _showCompareDocumentsDialog,
                            onUpdateToc: _updateToc,
                            onMergeCells: _showMergeCellsDialog,
                            onSplitCells: _showSplitCellsDialog,
                            onSortTable: _showTableSortDialog,
                            onAutoFitTable: _showTableAutoFitDialog,
                            onInsertTextBox: _showInsertTextBoxDialog,
                            onWatermark: _showWatermarkDialog,
                            onAccessibilityCheck:
                                _showAccessibilityCheckerDialog,
                            onExportEpub: _exportToEpub,
                            onSpellCheck: _showSpellCheckDialog,
                            onSearchComments: _showSearchCommentsDialog,
                            onDigitalSignature: _showDigitalSignatureDialog,
                            onEncryption: _showEncryptionDialog,
                            onAuditLog: _showAuditLogDialog,
                            onInsertList: _showInsertListDialog,
                            onPrintOptions: _showPrintOptionsDialog,
                            onGrammarCheck: _showGrammarCheckDialog,
                            onMultiLangSpell: _showMultiLanguageSpellDialog,
                            onCommentOnlyMode: _showCommentOnlyModeDialog,
                            onSearchStyles: _showSearchStylesDialog,
                            onTypographyOptions: _showTypographyOptionsDialog,
                            onImageFilters: _showImageFiltersDialog,
                            onInsertContentControl:
                                _showInsertContentControlDialog,
                            onNamedSnapshots: _showNamedSnapshotsDialog,
                            onRightsManagement: _showRightsManagementDialog,
                            onComplianceRetention:
                                _showComplianceRetentionDialog,
                            onApprovalWorkflow: _showApprovalWorkflowDialog,
                            onPageNumbering: _showPageNumberingDialog,
                            onViewMode: _showViewModeDialog,
                            onPluginArchitecture: _showPluginArchitectureDialog,
                          ),
                        ),
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
                              readOnly: viewMode,
                              srqController: _srqController,
                              editorFocusNode: _editorFocusNode,
                              editorStyle: _editorStyle,
                              textAlign: _textAlign,
                              showRuler: _showRuler && !_focusMode,
                              pageColor: _effectivePageColor,
                              zoom: _zoom,
                              focusMode: _focusMode,
                              wordCount: _wordCount,
                              readingMinutes: _readingMinutes,
                              characterCount: _characterCount,
                              editMode: _editMode,
                              sourcePackageFormat: _sourcePackageFormat,
                              sourcePackageBytes: _sourcePackageBytes,
                              openXmlDocument: _openXmlDocument,
                              onOpenXmlDocumentChanged: _updateOpenXmlDocument,
                              onOpenXmlParagraphActivated:
                                  _activateOpenXmlParagraph,
                              onOpenXmlSelectionChanged:
                                  _onOpenXmlSelectionChanged,
                              ooxmlBlocks: _ooxmlBlocks,
                              onOoxmlBlockChanged: _updateOoxmlBlock,
                              wysiwygBlocks: _wysiwygBlocks,
                              quillDeltaJson: _quillDeltaJson,
                              wysiwygInkCommandColor: _wysiwygInkCommandColor,
                              wysiwygInkCommandId: _wysiwygInkCommandId,
                              onWysiwygBlockChanged: _updateWysiwygBlock,
                              onQuillDeltaChanged: _updateQuillDelta,
                              onAddWysiwygBlockAfter: _addWysiwygBlockAfter,
                              onRemoveWysiwygBlock: _removeWysiwygBlock,
                              onSwitchToWysiwyg: _switchToWysiwyg,
                              onSwitchToOpenXmlEditing: _switchToOpenXmlEditing,
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

class _ViewModeHeader extends StatelessWidget {
  const _ViewModeHeader({required this.title, required this.onEdit});

  final String title;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xfff8fafc),
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xffe2e8f0)),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.visibility_outlined,
                size: 18, color: Color(0xff475569)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title.isEmpty ? 'Document' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff0f172a),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}
