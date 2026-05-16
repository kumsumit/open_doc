import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const OpenDocApp());
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
  final TextEditingController _bodyController = TextEditingController(
    text: _starterDocument,
  );
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _editorFocusNode = FocusNode();

  bool _bold = false;
  bool _italic = false;
  bool _underline = false;
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
  Color _inkColor = const Color(0xff111827);
  Color _pageColor = Colors.white;
  DateTime _savedAt = DateTime.now();
  final List<_MediaBlock> _mediaBlocks = [];
  final List<_DocumentVersion> _versions = [];
  final List<_Collaborator> _collaborators = const [
    _Collaborator('Asha', 'Editing', Color(0xff2563eb)),
    _Collaborator('Legal', 'Commenting', Color(0xff047857)),
    _Collaborator('Mina', 'Viewing', Color(0xffb45309)),
  ];

  @override
  void initState() {
    super.initState();
    _bodyController.addListener(_refresh);
    _titleController.addListener(_refresh);
    _searchController.addListener(_refresh);
    _captureVersion('Created first draft');
  }

  @override
  void dispose() {
    _bodyController
      ..removeListener(_refresh)
      ..dispose();
    _titleController
      ..removeListener(_refresh)
      ..dispose();
    _searchController
      ..removeListener(_refresh)
      ..dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() => _saved = false);
    }
  }

  int get _wordCount {
    final matches = RegExp(r"\b[\w'-]+\b").allMatches(_bodyController.text);
    return matches.length;
  }

  int get _characterCount => _bodyController.text.length;

  int get _readingMinutes => math.max(1, (_wordCount / 220).ceil());

  int get _sentenceCount {
    final matches = RegExp(r'[^.!?]+[.!?]').allMatches(_bodyController.text);
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
      r'(^|\n)(-|[0-9]+\.|\[ \])',
    ).allMatches(_bodyController.text).length.clamp(0, 8);
    final score = 58 + mediaBoost + listBoost + (_headings.length * 3);
    return score.clamp(35, 100);
  }

  int get _sourceCount {
    return RegExp(
      r'https?://|doi:|Source:',
      caseSensitive: false,
    ).allMatches(_bodyController.text).length;
  }

  int get _citationNudgeCount {
    final numberClaims = RegExp(
      r'\b\d{2,}(%|x|k|m| billion| million)?\b',
      caseSensitive: false,
    ).allMatches(_bodyController.text).length;
    return math.max(0, numberClaims - _sourceCount);
  }

  List<String> get _actionItems {
    final lines = _bodyController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines
        .where(
          (line) =>
              line.startsWith('[ ]') ||
              line.toLowerCase().startsWith('todo') ||
              line.toLowerCase().contains('follow up') ||
              line.toLowerCase().contains('owner:'),
        )
        .take(5)
        .toList();
  }

  int get _searchMatches {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return 0;
    }
    return RegExp(
      RegExp.escape(query),
    ).allMatches(_bodyController.text.toLowerCase()).length;
  }

  List<String> get _headings {
    final lines = _bodyController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines
        .where(
          (line) =>
              line.length < 60 &&
              (line.startsWith('#') ||
                  line.endsWith(':') ||
                  !line.endsWith('.')),
        )
        .take(8)
        .map((line) => line.replaceAll('#', '').replaceAll(':', '').trim())
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

  FontWeight get _fontWeight => _bold ? FontWeight.w700 : FontWeight.w400;

  TextStyle get _editorStyle {
    return TextStyle(
      color: _inkColor,
      fontFamily: _fontFamily == 'Aptos' ? null : _fontFamily,
      fontSize: _fontSize,
      height: 1.55,
      fontWeight: _fontWeight,
      fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
      decoration: _underline ? TextDecoration.underline : TextDecoration.none,
    );
  }

  void _insertText(String value) {
    final selection = _bodyController.selection;
    final text = _bodyController.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    _bodyController.value = TextEditingValue(
      text: text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    _editorFocusNode.requestFocus();
  }

  void _captureVersion(String label) {
    final nextVersion = 'v${_versions.length + 1}';
    _activeVersion = nextVersion;
    _versions.insert(
      0,
      _DocumentVersion(
        nextVersion,
        label,
        _titleController.text,
        _bodyController.text,
        List<_MediaBlock>.of(_mediaBlocks),
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
    setState(() {
      _titleController.text = 'Untitled document';
      _bodyController.text = '';
      _style = 'Body';
      _fontSize = 16;
      _zoom = 1;
      _template = 'Blank';
      _mediaBlocks.clear();
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

  void _showMediaSheet(_MediaType type) {
    final urlController = TextEditingController(
      text: type == _MediaType.image
          ? 'https://images.unsplash.com/photo-1497366754035-f200968a6e72?w=1200'
          : 'https://videos.open-doc.local/project-overview.mp4',
    );
    final captionController = TextEditingController(
      text: type == _MediaType.image
          ? 'Workspace reference image'
          : 'Project overview video',
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final title = type == _MediaType.image
            ? 'Insert image'
            : 'Insert video';
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
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    type == _MediaType.image
                        ? Icons.image_outlined
                        : Icons.smart_display_outlined,
                  ),
                  labelText: type == _MediaType.image
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
                          _MediaBlock(
                            id: DateTime.now().microsecondsSinceEpoch
                                .toString(),
                            type: type,
                            source: source,
                            caption: captionController.text.trim(),
                          ),
                        );
                        _saved = false;
                      });
                      _showSnack(
                        type == _MediaType.image
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
                'Import text',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
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
                      setState(() {
                        _bodyController.text = text;
                        _template = 'Imported';
                        _captureVersion('Imported text content');
                      });
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
                  for (final entry in _templateLibrary.entries)
                    _TemplateTile(
                      label: entry.key,
                      selected: entry.key == _template,
                      onTap: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _template = entry.key;
                          _titleController.text = entry.key;
                          _bodyController.text = entry.value;
                          _mediaBlocks.clear();
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
                          setState(() {
                            _activeVersion = version.id;
                            _titleController.text = version.title;
                            _bodyController.text = version.body;
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
    if (_versions.isEmpty) {
      return;
    }
    final previous = _versions.last;
    setState(() {
      _titleController.text = previous.title;
      _bodyController.text = previous.body;
      _mediaBlocks
        ..clear()
        ..addAll(previous.mediaBlocks);
      _trackChanges = false;
      _saved = true;
    });
    _showSnack('Draft reset to the original version.');
  }

  String _smartBriefText() {
    final firstParagraph = _bodyController.text
        .split('\n')
        .map((line) => line.trim())
        .firstWhere(
          (line) => line.length > 80,
          orElse: () => _bodyController.text.trim(),
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
                  _ExportTile(
                    icon: Icons.description_outlined,
                    label: 'DOCX',
                    onTap: () => _finishExport(context, 'DOCX'),
                  ),
                  _ExportTile(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF',
                    onTap: () => _finishExport(context, 'PDF'),
                  ),
                  _ExportTile(
                    icon: Icons.text_snippet_outlined,
                    label: 'Plain text',
                    onTap: () => _finishExport(context, 'plain text'),
                  ),
                  _ExportTile(
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
    final mediaNote = _mediaBlocks.isEmpty
        ? ''
        : ' with ${_mediaBlocks.length} media block${_mediaBlocks.length == 1 ? '' : 's'}';
    _showSnack('$type export queued$mediaNote.');
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
            '${_titleController.text}\n\n${_bodyController.text}${mediaText.isEmpty ? '' : '\n\nMedia\n$mediaText'}',
      ),
    );
    _showSnack('Document copied to clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _ToggleBoldIntent(),
        SingleActivator(LogicalKeyboardKey.keyI, control: true):
            _ToggleItalicIntent(),
        SingleActivator(LogicalKeyboardKey.keyU, control: true):
            _ToggleUnderlineIntent(),
      },
      child: Actions(
        actions: {
          _ToggleBoldIntent: CallbackAction<_ToggleBoldIntent>(
            onInvoke: (_) {
              setState(() => _bold = !_bold);
              return null;
            },
          ),
          _ToggleItalicIntent: CallbackAction<_ToggleItalicIntent>(
            onInvoke: (_) {
              setState(() => _italic = !_italic);
              return null;
            },
          ),
          _ToggleUnderlineIntent: CallbackAction<_ToggleUnderlineIntent>(
            onInvoke: (_) {
              setState(() => _underline = !_underline);
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
                    _TopBar(
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
                      _Ribbon(
                        bold: _bold,
                        italic: _italic,
                        underline: _underline,
                        showRuler: _showRuler,
                        trackChanges: _trackChanges,
                        commentsMode: _commentsMode,
                        fontSize: _fontSize,
                        zoom: _zoom,
                        fontFamily: _fontFamily,
                        style: _style,
                        alignment: _alignment,
                        audienceProfile: _audienceProfile,
                        toneMode: _toneMode,
                        inkColor: _inkColor,
                        pageColor: _pageColor,
                        onBold: () => setState(() => _bold = !_bold),
                        onItalic: () => setState(() => _italic = !_italic),
                        onUnderline: () =>
                            setState(() => _underline = !_underline),
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
                        onStyle: (value) => setState(() {
                          _style = value;
                          _fontSize = value == 'Title'
                              ? 28
                              : value == 'Heading'
                              ? 22
                              : 16;
                          _bold = value != 'Body';
                        }),
                        onAlignment: (value) =>
                            setState(() => _alignment = value),
                        onAudienceProfile: (value) =>
                            setState(() => _audienceProfile = value),
                        onToneMode: (value) =>
                            setState(() => _toneMode = value),
                        onInkColor: (value) =>
                            setState(() => _inkColor = value),
                        onPageColor: (value) =>
                            setState(() => _pageColor = value),
                        onInsertTable: () => _insertText(
                          '\n| Column 1 | Column 2 | Column 3 |\n| --- | --- | --- |\n|  |  |  |\n',
                        ),
                        onInsertImage: () => _showMediaSheet(_MediaType.image),
                        onInsertVideo: () => _showMediaSheet(_MediaType.video),
                        onInsertChecklist: () =>
                            _insertText('\n[ ] Action item\n[ ] Follow up\n'),
                        onInsertSignature: () => _insertText(
                          '\n\nRegards,\n${_titleController.text.split(' ').first}\n',
                        ),
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
                            _NavigationRailPanel(
                              headings: _headings,
                              searchController: _searchController,
                              searchMatches: _searchMatches,
                              onClose: () =>
                                  setState(() => _showNavigation = false),
                            ),
                          Expanded(
                            child: _EditorWorkspace(
                              bodyController: _bodyController,
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
                              mediaBlocks: _mediaBlocks,
                              onRemoveMedia: _removeMediaBlock,
                              onToggleNavigation: () => setState(
                                () => _showNavigation = !_showNavigation,
                              ),
                              onToggleInspector: () => setState(
                                () => _showInspector = !_showInspector,
                              ),
                            ),
                          ),
                          if (showRight)
                            _InspectorPanel(
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
                                  .where(
                                    (block) => block.type == _MediaType.image,
                                  )
                                  .length,
                              videoCount: _mediaBlocks
                                  .where(
                                    (block) => block.type == _MediaType.video,
                                  )
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
                              onClose: () =>
                                  setState(() => _showInspector = false),
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

class _ToggleBoldIntent extends Intent {
  const _ToggleBoldIntent();
}

class _ToggleItalicIntent extends Intent {
  const _ToggleItalicIntent();
}

class _ToggleUnderlineIntent extends Intent {
  const _ToggleUnderlineIntent();
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.titleController,
    required this.focusMode,
    required this.saved,
    required this.onNew,
    required this.onSave,
    required this.onImport,
    required this.onTemplates,
    required this.onDuplicate,
    required this.onCopy,
    required this.onShare,
    required this.onHistory,
    required this.onExport,
    required this.onToggleFocus,
  });

  final TextEditingController titleController;
  final bool focusMode;
  final bool saved;
  final VoidCallback onNew;
  final VoidCallback onSave;
  final VoidCallback onImport;
  final VoidCallback onTemplates;
  final VoidCallback onDuplicate;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onHistory;
  final VoidCallback onExport;
  final VoidCallback onToggleFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffe5e7eb))),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xff2563eb),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.article_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: TextField(
              controller: titleController,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: saved ? const Color(0xffecfdf5) : const Color(0xfffffbeb),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: saved
                    ? const Color(0xffbbf7d0)
                    : const Color(0xfffde68a),
              ),
            ),
            child: Text(
              saved ? 'Saved' : 'Unsaved',
              style: TextStyle(
                color: saved
                    ? const Color(0xff047857)
                    : const Color(0xff92400e),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  _IconAction(
                    icon: Icons.note_add_outlined,
                    label: 'New',
                    onTap: onNew,
                  ),
                  _IconAction(
                    icon: Icons.save_outlined,
                    label: 'Save',
                    onTap: onSave,
                  ),
                  _IconAction(
                    icon: Icons.upload_file_outlined,
                    label: 'Import',
                    onTap: onImport,
                  ),
                  _IconAction(
                    icon: Icons.dashboard_customize_outlined,
                    label: 'Templates',
                    onTap: onTemplates,
                  ),
                  _IconAction(
                    icon: Icons.copy_outlined,
                    label: 'Duplicate',
                    onTap: onDuplicate,
                  ),
                  _IconAction(
                    icon: Icons.content_copy_outlined,
                    label: 'Copy',
                    onTap: onCopy,
                  ),
                  _IconAction(
                    icon: Icons.group_add_outlined,
                    label: 'Share',
                    onTap: onShare,
                  ),
                  _IconAction(
                    icon: Icons.history_outlined,
                    label: 'Versions',
                    onTap: onHistory,
                  ),
                  _IconAction(
                    icon: Icons.ios_share_outlined,
                    label: 'Export',
                    onTap: onExport,
                  ),
                  _IconAction(
                    icon: focusMode
                        ? Icons.fullscreen_exit_outlined
                        : Icons.fullscreen_outlined,
                    label: focusMode ? 'Exit focus' : 'Focus',
                    onTap: onToggleFocus,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.bold,
    required this.italic,
    required this.underline,
    required this.showRuler,
    required this.trackChanges,
    required this.commentsMode,
    required this.fontSize,
    required this.zoom,
    required this.fontFamily,
    required this.style,
    required this.alignment,
    required this.audienceProfile,
    required this.toneMode,
    required this.inkColor,
    required this.pageColor,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onRuler,
    required this.onTrackChanges,
    required this.onCommentsMode,
    required this.onFontSize,
    required this.onZoom,
    required this.onFontFamily,
    required this.onStyle,
    required this.onAlignment,
    required this.onAudienceProfile,
    required this.onToneMode,
    required this.onInkColor,
    required this.onPageColor,
    required this.onInsertTable,
    required this.onInsertImage,
    required this.onInsertVideo,
    required this.onInsertChecklist,
    required this.onInsertSignature,
    required this.onAcceptChanges,
    required this.onRejectChanges,
    required this.onSmartBrief,
    required this.onSocialSummary,
    required this.onCitationNudge,
    required this.onActionDigest,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool showRuler;
  final bool trackChanges;
  final bool commentsMode;
  final double fontSize;
  final double zoom;
  final String fontFamily;
  final String style;
  final String alignment;
  final String audienceProfile;
  final String toneMode;
  final Color inkColor;
  final Color pageColor;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onRuler;
  final VoidCallback onTrackChanges;
  final VoidCallback onCommentsMode;
  final ValueChanged<double> onFontSize;
  final ValueChanged<double> onZoom;
  final ValueChanged<String> onFontFamily;
  final ValueChanged<String> onStyle;
  final ValueChanged<String> onAlignment;
  final ValueChanged<String> onAudienceProfile;
  final ValueChanged<String> onToneMode;
  final ValueChanged<Color> onInkColor;
  final ValueChanged<Color> onPageColor;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertVideo;
  final VoidCallback onInsertChecklist;
  final VoidCallback onInsertSignature;
  final VoidCallback onAcceptChanges;
  final VoidCallback onRejectChanges;
  final VoidCallback onSmartBrief;
  final VoidCallback onSocialSummary;
  final VoidCallback onCitationNudge;
  final VoidCallback onActionDigest;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xfffbfcfe),
      child: Container(
        height: 112,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xffdbe3ef))),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _RibbonGroup(
              label: 'Document',
              child: Row(
                children: [
                  _ToolButton(
                    icon: Icons.table_chart_outlined,
                    label: 'Table',
                    onTap: onInsertTable,
                  ),
                  _ToolButton(
                    icon: Icons.image_outlined,
                    label: 'Image',
                    onTap: onInsertImage,
                  ),
                  _ToolButton(
                    icon: Icons.smart_display_outlined,
                    label: 'Video',
                    onTap: onInsertVideo,
                  ),
                  _ToolButton(
                    icon: Icons.checklist_outlined,
                    label: 'Tasks',
                    onTap: onInsertChecklist,
                  ),
                  _ToolButton(
                    icon: Icons.draw_outlined,
                    label: 'Sign',
                    onTap: onInsertSignature,
                  ),
                ],
              ),
            ),
            _RibbonGroup(
              label: 'Style',
              child: Row(
                children: [
                  _DropdownChip(
                    value: style,
                    width: 112,
                    values: const ['Body', 'Title', 'Heading', 'Quote'],
                    onChanged: onStyle,
                  ),
                  const SizedBox(width: 8),
                  _DropdownChip(
                    value: fontFamily,
                    width: 112,
                    values: const ['Aptos', 'Arial', 'Georgia', 'Times'],
                    onChanged: onFontFamily,
                  ),
                  const SizedBox(width: 8),
                  _StepperChip(
                    value: fontSize,
                    min: 10,
                    max: 34,
                    onChanged: onFontSize,
                  ),
                ],
              ),
            ),
            _RibbonGroup(
              label: 'Format',
              child: Row(
                children: [
                  _ToggleTool(
                    icon: Icons.format_bold,
                    label: 'Bold',
                    selected: bold,
                    onTap: onBold,
                  ),
                  _ToggleTool(
                    icon: Icons.format_italic,
                    label: 'Italic',
                    selected: italic,
                    onTap: onItalic,
                  ),
                  _ToggleTool(
                    icon: Icons.format_underlined,
                    label: 'Underline',
                    selected: underline,
                    onTap: onUnderline,
                  ),
                  const SizedBox(width: 8),
                  _DropdownChip(
                    value: alignment,
                    width: 112,
                    values: const ['Left', 'Center', 'Right', 'Justify'],
                    onChanged: onAlignment,
                  ),
                ],
              ),
            ),
            _RibbonGroup(
              label: 'Color',
              child: Row(
                children: [
                  _ColorDot(
                    label: 'Ink',
                    value: inkColor,
                    colors: const [
                      Color(0xff111827),
                      Color(0xffb91c1c),
                      Color(0xff047857),
                      Color(0xff1d4ed8),
                    ],
                    onChanged: onInkColor,
                  ),
                  const SizedBox(width: 10),
                  _ColorDot(
                    label: 'Page',
                    value: pageColor,
                    colors: const [
                      Colors.white,
                      Color(0xfffffbeb),
                      Color(0xffecfdf5),
                      Color(0xffeff6ff),
                    ],
                    onChanged: onPageColor,
                  ),
                ],
              ),
            ),
            _RibbonGroup(
              label: 'Review',
              child: Row(
                children: [
                  _ToggleTool(
                    icon: Icons.rate_review_outlined,
                    label: 'Comments',
                    selected: commentsMode,
                    onTap: onCommentsMode,
                  ),
                  _ToggleTool(
                    icon: Icons.change_circle_outlined,
                    label: 'Track',
                    selected: trackChanges,
                    onTap: onTrackChanges,
                  ),
                  _ToggleTool(
                    icon: Icons.straighten_outlined,
                    label: 'Ruler',
                    selected: showRuler,
                    onTap: onRuler,
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                    icon: Icons.done_all_outlined,
                    label: 'Accept',
                    onTap: onAcceptChanges,
                  ),
                  _ToolButton(
                    icon: Icons.undo_outlined,
                    label: 'Reject',
                    onTap: onRejectChanges,
                  ),
                ],
              ),
            ),
            _RibbonGroup(
              label: 'Smart',
              child: Row(
                children: [
                  _DropdownChip(
                    value: audienceProfile,
                    width: 128,
                    values: const ['Millennial', 'Gen Z', 'Alpha', 'Beta'],
                    onChanged: onAudienceProfile,
                  ),
                  const SizedBox(width: 8),
                  _DropdownChip(
                    value: toneMode,
                    width: 112,
                    values: const ['Clear', 'Warm', 'Bold', 'Brief'],
                    onChanged: onToneMode,
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                    icon: Icons.auto_awesome_outlined,
                    label: 'Brief',
                    onTap: onSmartBrief,
                  ),
                  _ToolButton(
                    icon: Icons.ios_share_outlined,
                    label: 'Social',
                    onTap: onSocialSummary,
                  ),
                  _ToolButton(
                    icon: Icons.verified_outlined,
                    label: 'Source',
                    onTap: onCitationNudge,
                  ),
                  _ToolButton(
                    icon: Icons.task_alt_outlined,
                    label: 'Actions',
                    onTap: onActionDigest,
                  ),
                ],
              ),
            ),
            _RibbonGroup(
              label: 'View',
              child: SizedBox(
                width: 180,
                child: Row(
                  children: [
                    const Icon(Icons.zoom_in_outlined, size: 20),
                    Expanded(
                      child: Slider(
                        value: zoom,
                        min: .75,
                        max: 1.4,
                        divisions: 13,
                        onChanged: onZoom,
                      ),
                    ),
                    Text('${(zoom * 100).round()}%'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorWorkspace extends StatelessWidget {
  const _EditorWorkspace({
    required this.bodyController,
    required this.editorFocusNode,
    required this.editorStyle,
    required this.textAlign,
    required this.showRuler,
    required this.pageColor,
    required this.zoom,
    required this.focusMode,
    required this.wordCount,
    required this.readingMinutes,
    required this.characterCount,
    required this.mediaBlocks,
    required this.onRemoveMedia,
    required this.onToggleNavigation,
    required this.onToggleInspector,
  });

  final TextEditingController bodyController;
  final FocusNode editorFocusNode;
  final TextStyle editorStyle;
  final TextAlign textAlign;
  final bool showRuler;
  final Color pageColor;
  final double zoom;
  final bool focusMode;
  final int wordCount;
  final int readingMinutes;
  final int characterCount;
  final List<_MediaBlock> mediaBlocks;
  final ValueChanged<String> onRemoveMedia;
  final VoidCallback onToggleNavigation;
  final VoidCallback onToggleInspector;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!focusMode)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xffeef3f9),
            child: Row(
              children: [
                _IconAction(
                  icon: Icons.menu_open_outlined,
                  label: 'Navigation',
                  onTap: onToggleNavigation,
                ),
                _IconAction(
                  icon: Icons.tune_outlined,
                  label: 'Inspector',
                  onTap: onToggleInspector,
                ),
                const Spacer(),
                Text(
                  '$wordCount words  •  $characterCount chars  •  $readingMinutes min read',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xff526070),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: focusMode
                ? const Color(0xfff8fafc)
                : const Color(0xffe9eff7),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
                child: Transform.scale(
                  scale: zoom,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 760,
                    constraints: const BoxConstraints(minHeight: 980),
                    decoration: BoxDecoration(
                      color: pageColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xffd6dee9)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1f0f172a),
                          blurRadius: 28,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (showRuler) const _Ruler(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(72, 56, 72, 72),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final block in mediaBlocks) ...[
                                _MediaDocumentBlock(
                                  block: block,
                                  onRemove: () => onRemoveMedia(block.id),
                                ),
                                const SizedBox(height: 18),
                              ],
                              TextField(
                                key: const ValueKey('document-editor'),
                                controller: bodyController,
                                focusNode: editorFocusNode,
                                maxLines: null,
                                minLines: 28,
                                keyboardType: TextInputType.multiline,
                                textAlign: textAlign,
                                style: editorStyle,
                                cursorColor: const Color(0xff2563eb),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Start writing your document...',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaDocumentBlock extends StatelessWidget {
  const _MediaDocumentBlock({required this.block, required this.onRemove});

  final _MediaBlock block;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = block.type == _MediaType.image;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffdbe3ef)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: isImage ? 16 / 9 : 16 / 6,
            child: isImage
                ? Image.network(
                    block.source,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _MediaFallback(block: block),
                  )
                : _VideoPreview(block: block),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Icon(block.type.icon, size: 18, color: const Color(0xff2563eb)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    block.caption.isEmpty ? block.source : block.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove media',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.block});

  final _MediaBlock block;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff111827), Color(0xff334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xff2563eb),
                size: 42,
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Text(
              block.source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.block});

  final _MediaBlock block;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xffeef3f9),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(block.type.icon, size: 42, color: const Color(0xff64748b)),
              const SizedBox(height: 8),
              Text(
                block.source,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xff475569)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationRailPanel extends StatelessWidget {
  const _NavigationRailPanel({
    required this.headings,
    required this.searchController,
    required this.searchMatches,
    required this.onClose,
  });

  final List<String> headings;
  final TextEditingController searchController;
  final int searchMatches;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: 'Navigation',
            icon: Icons.subject_outlined,
            onClose: onClose,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_outlined),
                suffixText: searchController.text.isEmpty
                    ? null
                    : '$searchMatches',
                hintText: 'Search document',
                isDense: true,
                filled: true,
                fillColor: const Color(0xfff6f8fb),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              'Outline',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              children: [
                for (final heading in headings)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.notes_outlined, size: 20),
                    title: Text(
                      heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                if (headings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Headings appear here as you write.'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel({
    required this.wordCount,
    required this.characterCount,
    required this.readingMinutes,
    required this.commentsMode,
    required this.trackChanges,
    required this.permission,
    required this.template,
    required this.savedAt,
    required this.activeVersion,
    required this.collaborators,
    required this.versions,
    required this.mediaCount,
    required this.imageCount,
    required this.videoCount,
    required this.audienceProfile,
    required this.toneMode,
    required this.clarityScore,
    required this.attentionScore,
    required this.averageSentenceLength,
    required this.sourceCount,
    required this.citationNudgeCount,
    required this.actionItems,
    required this.onSave,
    required this.onShare,
    required this.onHistory,
    required this.onSmartBrief,
    required this.onActionDigest,
    required this.onClose,
  });

  final int wordCount;
  final int characterCount;
  final int readingMinutes;
  final bool commentsMode;
  final bool trackChanges;
  final String permission;
  final String template;
  final DateTime savedAt;
  final String activeVersion;
  final List<_Collaborator> collaborators;
  final List<_DocumentVersion> versions;
  final int mediaCount;
  final int imageCount;
  final int videoCount;
  final String audienceProfile;
  final String toneMode;
  final int clarityScore;
  final int attentionScore;
  final int averageSentenceLength;
  final int sourceCount;
  final int citationNudgeCount;
  final List<String> actionItems;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onHistory;
  final VoidCallback onSmartBrief;
  final VoidCallback onActionDigest;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 292,
      color: Colors.white,
      child: ListView(
        children: [
          _PanelHeader(
            title: 'Inspector',
            icon: Icons.fact_check_outlined,
            onClose: onClose,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(label: 'Words', value: '$wordCount'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'Read',
                        value: '${readingMinutes}m',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MetricCard(label: 'Characters', value: '$characterCount'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(label: 'Images', value: '$imageCount'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(label: 'Videos', value: '$videoCount'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'Clarity',
                        value: '$clarityScore',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'Attention',
                        value: '$attentionScore',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _StatusTile(
            icon: Icons.psychology_alt_outlined,
            title: 'Audience fit',
            value: '$audienceProfile • $toneMode tone',
            color: const Color(0xff7c3aed),
          ),
          _StatusTile(
            icon: Icons.speed_outlined,
            title: 'Scanability',
            value: '$averageSentenceLength words per sentence',
            color: averageSentenceLength <= 18
                ? const Color(0xff047857)
                : const Color(0xffb45309),
          ),
          _StatusTile(
            icon: Icons.verified_outlined,
            title: 'Trust layer',
            value: citationNudgeCount == 0
                ? '$sourceCount source signal${sourceCount == 1 ? '' : 's'} found'
                : '$citationNudgeCount claim${citationNudgeCount == 1 ? '' : 's'} may need a source',
            color: citationNudgeCount == 0
                ? const Color(0xff047857)
                : const Color(0xffbe123c),
          ),
          _StatusTile(
            icon: Icons.perm_media_outlined,
            title: 'Media',
            value:
                '$mediaCount embedded block${mediaCount == 1 ? '' : 's'} in document',
            color: const Color(0xffbe123c),
          ),
          _StatusTile(
            icon: Icons.rate_review_outlined,
            title: 'Comments',
            value: commentsMode ? 'Open for review' : 'Hidden',
            color: commentsMode ? const Color(0xff047857) : Colors.grey,
          ),
          _StatusTile(
            icon: Icons.change_circle_outlined,
            title: 'Track changes',
            value: trackChanges ? 'Recording edits' : 'Paused',
            color: trackChanges ? const Color(0xff1d4ed8) : Colors.grey,
          ),
          _StatusTile(
            icon: Icons.lock_open_outlined,
            title: 'Permission',
            value: permission,
            color: const Color(0xff7c3aed),
          ),
          _StatusTile(
            icon: Icons.dashboard_customize_outlined,
            title: 'Template',
            value: template,
            color: const Color(0xff0f766e),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSmartBrief,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Brief'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onActionDigest,
                    icon: const Icon(Icons.task_alt_outlined),
                    label: const Text('Actions'),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'Next actions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (actionItems.isEmpty)
            const _SuggestionTile(
              icon: Icons.task_alt_outlined,
              title: 'No open actions',
              body: 'Add [ ] tasks or owner lines to build a digest.',
            )
          else
            for (final item in actionItems)
              _SuggestionTile(
                icon: Icons.task_alt_outlined,
                title: 'Action',
                body: item,
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Collaborators',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: onShare, child: const Text('Manage')),
              ],
            ),
          ),
          for (final collaborator in collaborators)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: collaborator.color,
                child: Text(
                  collaborator.name.substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text(collaborator.name),
              subtitle: Text(collaborator.status),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Version history',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: onHistory, child: const Text('Open')),
              ],
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.history_outlined),
            title: Text('$activeVersion saved ${_formatTime(savedAt)}'),
            subtitle: Text('${versions.length} saved versions'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'Comments',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const _CommentCard(
            author: 'Asha',
            body: 'Strengthen the objective with one measurable outcome.',
          ),
          const _CommentCard(
            author: 'Legal',
            body: 'Check whether this proposal needs a confidentiality note.',
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'Suggestions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const _SuggestionTile(
            icon: Icons.spellcheck_outlined,
            title: 'Tone',
            body: 'The document reads clear and professional.',
          ),
          const _SuggestionTile(
            icon: Icons.format_line_spacing_outlined,
            title: 'Layout',
            body: 'Margins and line height are ready for print.',
          ),
        ],
      ),
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 72),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffe5e7eb))),
      ),
      child: Row(
        children: List.generate(
          12,
          (index) => Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                width: 1,
                height: index.isEven ? 15 : 8,
                color: const Color(0xffb6c1d1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonGroup extends StatelessWidget {
  const _RibbonGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe2e8f0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xff64748b),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 46,
        height: 42,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleTool extends StatelessWidget {
  const _ToggleTool({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: IconButton(
          isSelected: selected,
          selectedIcon: Icon(icon),
          onPressed: onTap,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: selected
                ? const Color(0xffdbeafe)
                : Colors.transparent,
            foregroundColor: selected
                ? const Color(0xff1d4ed8)
                : const Color(0xff334155),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownChip extends StatelessWidget {
  const _DropdownChip({
    required this.value,
    required this.values,
    required this.onChanged,
    required this.width,
  });

  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd6dee9)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 18),
          items: [
            for (final option in values)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _StepperChip extends StatelessWidget {
  const _StepperChip({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffd6dee9)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 32,
            child: Text(
              value.round().toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final Color value;
  final List<Color> colors;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        for (final color in colors)
          Tooltip(
            message: label,
            child: InkWell(
              onTap: () => onChanged(color),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value == color
                        ? const Color(0xff2563eb)
                        : const Color(0xffcbd5e1),
                    width: value == color ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.icon,
    required this.onClose,
  });

  final String title;
  final IconData icon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffe5e7eb))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: const Color(0xff2563eb)),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff6f8fb),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xff64748b))),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(value),
      dense: true,
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.author, required this.body});

  final String author;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfffffbeb),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xfffde68a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(author, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(body),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xff2563eb)),
      title: Text(title),
      subtitle: Text(body),
      dense: true,
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(
          selected ? Icons.radio_button_checked : Icons.article_outlined,
        ),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _DocumentVersion {
  const _DocumentVersion(
    this.id,
    this.label,
    this.title,
    this.body,
    this.mediaBlocks,
    this.createdAt,
    this.wordCount,
  );

  final String id;
  final String label;
  final String title;
  final String body;
  final List<_MediaBlock> mediaBlocks;
  final DateTime createdAt;
  final int wordCount;
}

enum _MediaType {
  image('Image', Icons.image_outlined),
  video('Video', Icons.smart_display_outlined);

  const _MediaType(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _MediaBlock {
  const _MediaBlock({
    required this.id,
    required this.type,
    required this.source,
    required this.caption,
  });

  final String id;
  final _MediaType type;
  final String source;
  final String caption;
}

class _Collaborator {
  const _Collaborator(this.name, this.status, this.color);

  final String name;
  final String status;
  final Color color;
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

const _templateLibrary = {
  'Proposal': _starterDocument,
  'Resume': '''
Professional summary

Write a concise summary of your role, strengths, and measurable impact.

Experience

Company name - Role title
- Led a meaningful project and describe the result.
- Improved a process, metric, or customer outcome.

Education

Degree, institution, year

Skills

Writing, analysis, planning, collaboration
''',
  'Letter': '''
Recipient name
Company or address

Dear recipient,

Use this opening paragraph to state the purpose of the letter clearly.

Add supporting details, dates, decisions, or requests in the body.

Sincerely,
Your name
''',
  'Contract': '''
Agreement overview

This agreement is between Party A and Party B and begins on the effective date.

Scope of work

1. Define responsibilities.
2. Define deliverables.
3. Define review and approval steps.

Terms

Payment, confidentiality, termination, and governing law should be reviewed by legal counsel.
''',
  'Invoice': '''
Invoice

Bill to:
Client name

| Item | Qty | Rate | Amount |
| --- | --- | --- | --- |
| Service | 1 | 0.00 | 0.00 |

Subtotal:
Tax:
Total:

Payment terms: due on receipt.
''',
  'Report': '''
Report title

Overview

Summarize the finding, decision, or project status.

Findings

- Key observation
- Supporting evidence
- Impact

Recommendations

1. Recommended action
2. Owner
3. Timeline
''',
};

const _starterDocument = '''
Executive summary

Open Doc is a modern writing workspace for proposals, reports, letters, contracts, and research notes. It keeps the familiar power of a desktop word processor while making the core writing flow faster, calmer, and easier to review.

Goals:
- Create documents with print-ready layout, typography, tables, comments, and review tools.
- Keep the interface focused on the page instead of burying everyday actions.
- Make collaboration, export, and versioning visible without interrupting writing.

Project scope

This first draft covers the editor experience, document outline, search, formatting controls, comments, change tracking states, page zoom, copy, and export actions. The next production milestone can add real DOCX parsing, cloud sync, advanced rich text spans, and PDF generation.

Key milestones:
1. Build a polished editor shell with page layout and responsive panels.
2. Add document persistence and file import/export.
3. Add collaborative editing, permissions, and version history.
4. Add templates for resumes, letters, proposals, invoices, and reports.
''';
