// ignore_for_file: use_key_in_widget_constructors

import 'dart:math' as math;
import 'dart:typed_data';

import '../viewer/docx_view.dart';
import '../viewer/docx_view_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:smart_rich_text_quill/smart_rich_text_quill.dart';

import '../services/document_models.dart';
import 'common_controls.dart';
import 'inline_format.dart';

class EditorWorkspace extends StatelessWidget {
  const EditorWorkspace({
    required this.srqController,
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
    required this.editMode,
    required this.sourcePackageFormat,
    required this.openXmlDocument,
    required this.onOpenXmlDocumentChanged,
    required this.onOpenXmlParagraphActivated,
    required this.onOpenXmlSelectionChanged,
    required this.ooxmlBlocks,
    required this.onOoxmlBlockChanged,
    required this.wysiwygBlocks,
    required this.quillDeltaJson,
    required this.wysiwygInkCommandColor,
    required this.wysiwygInkCommandId,
    required this.onWysiwygBlockChanged,
    required this.onQuillDeltaChanged,
    required this.onAddWysiwygBlockAfter,
    required this.onRemoveWysiwygBlock,
    required this.onSwitchToWysiwyg,
    required this.onSwitchToOpenXmlEditing,
    required this.mediaBlocks,
    required this.onRemoveMedia,
    required this.onToggleNavigation,
    required this.onToggleInspector,
    this.sourcePackageBytes,
  });

  final SrqController srqController;
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
  final DocumentEditMode editMode;
  final String? sourcePackageFormat;
  final OpenXmlDocument openXmlDocument;
  final ValueChanged<OpenXmlDocument> onOpenXmlDocumentChanged;
  final void Function(
    int index,
    OpenXmlParagraphBlock block,
    RichRunController controller,
    FocusNode focusNode,
  )
  onOpenXmlParagraphActivated;
  final VoidCallback onOpenXmlSelectionChanged;
  final List<OoxmlVisualBlock> ooxmlBlocks;
  final void Function(int index, OoxmlVisualBlock block) onOoxmlBlockChanged;
  final List<WysiwygBlock> wysiwygBlocks;
  final List<Object?> quillDeltaJson;
  final Color? wysiwygInkCommandColor;
  final int wysiwygInkCommandId;
  final void Function(int index, WysiwygBlock block) onWysiwygBlockChanged;
  final ValueChanged<List<Object?>> onQuillDeltaChanged;
  final ValueChanged<int> onAddWysiwygBlockAfter;
  final ValueChanged<int> onRemoveWysiwygBlock;
  final VoidCallback onSwitchToWysiwyg;
  final VoidCallback onSwitchToOpenXmlEditing;
  final List<MediaBlock> mediaBlocks;
  final ValueChanged<String> onRemoveMedia;
  final VoidCallback onToggleNavigation;
  final VoidCallback onToggleInspector;
  final Uint8List? sourcePackageBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!focusMode)
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: const Color(0xffeef3f9),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final stats = compact
                    ? '$wordCount words • ${readingMinutes}m'
                    : '$wordCount words  •  $characterCount chars  •  $readingMinutes min read';
                return Row(
                  children: [
                    IconAction(
                      icon: Icons.menu_open_outlined,
                      label: 'Navigation',
                      onTap: onToggleNavigation,
                    ),
                    IconAction(
                      icon: Icons.tune_outlined,
                      label: 'Inspector',
                      onTap: onToggleInspector,
                    ),
                    const Spacer(),
                    if (editMode != DocumentEditMode.openXml) ...[
                      Tooltip(
                        message:
                            'Preserving original ${sourcePackageFormat?.toUpperCase() ?? 'DOCX'} package',
                        child: Chip(
                          avatar: Icon(editMode.icon, size: 16),
                          label: Text(
                            editMode == DocumentEditMode.docxVisual
                                ? 'OOXML visual'
                                : editMode == DocumentEditMode.wysiwyg
                                ? 'WYSIWYG'
                                : editMode == DocumentEditMode.docxView
                                ? 'DOCX viewer'
                                : 'Round-trip',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onSwitchToOpenXmlEditing,
                        icon: const Icon(Icons.edit_note_outlined, size: 18),
                        label: const Text('Edit in Word mode'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (editMode == DocumentEditMode.openXml) ...[
                      TextButton.icon(
                        onPressed: onSwitchToWysiwyg,
                        icon: const Icon(Icons.edit_document, size: 18),
                        label: const Text('WYSIWYG'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        stats,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xff526070),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        if (editMode == DocumentEditMode.docxView && sourcePackageBytes != null)
          Expanded(
            child: DocxViewWithSearch(
              bytes: sourcePackageBytes!,
              config: const DocxViewConfig(
                enableSearch: true,
                enableZoom: true,
                enableSelection: true,
                pageMode: DocxPageMode.paged,
                showPageBreaks: true,
              ),
            ),
          )
        else
          Expanded(
            child: ColoredBox(
              color: focusMode
                  ? const Color(0xfff8fafc)
                  : const Color(0xffe9eff7),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final edgePadding = compact ? 10.0 : 22.0;
                  final availableWidth = math.max(
                    280.0,
                    constraints.maxWidth - (edgePadding * 2),
                  );
                  final pageWidth = math.min(760.0, availableWidth / zoom);
                  final pageHeight = math.max(
                    constraints.maxHeight - 56,
                    pageWidth * 1.29,
                  );
                  final pageInset = compact
                      ? 24.0
                      : pageWidth < 620
                      ? 42.0
                      : 72.0;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        edgePadding,
                        compact ? 14 : 28,
                        edgePadding,
                        40,
                      ),
                      child: Transform.scale(
                        scale: zoom,
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: pageWidth,
                          constraints: BoxConstraints(minHeight: pageHeight),
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
                              if (showRuler) const Ruler(),
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  pageInset,
                                  compact ? 30 : 56,
                                  pageInset,
                                  compact ? 42 : 72,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final block in mediaBlocks) ...[
                                      _MediaDocumentBlock(
                                        block: block,
                                        onRemove: () => onRemoveMedia(block.id),
                                      ),
                                      const SizedBox(height: 18),
                                    ],
                                    if (editMode !=
                                        DocumentEditMode.openXml) ...[
                                      _RoundTripNotice(
                                        editMode: editMode,
                                        sourcePackageFormat:
                                            sourcePackageFormat,
                                        onSwitchToOpenXmlEditing:
                                            onSwitchToOpenXmlEditing,
                                      ),
                                      const SizedBox(height: 18),
                                    ],
                                    if (editMode == DocumentEditMode.docxVisual)
                                      _OoxmlVisualEditor(
                                        blocks: ooxmlBlocks,
                                        style: editorStyle,
                                        onBlockChanged: onOoxmlBlockChanged,
                                      )
                                    else if (editMode ==
                                        DocumentEditMode.wysiwyg)
                                      _QuillWysiwygEditor(
                                        blocks: wysiwygBlocks,
                                        deltaJson: quillDeltaJson,
                                        inkCommandColor: wysiwygInkCommandColor,
                                        inkCommandId: wysiwygInkCommandId,
                                        onDeltaChanged: onQuillDeltaChanged,
                                      )
                                    else if (editMode ==
                                        DocumentEditMode.openXml)
                                      _OpenXmlStructuredEditor(
                                        key: const ValueKey('document-editor'),
                                        document: openXmlDocument,
                                        style: editorStyle,
                                        textAlign: textAlign,
                                        onChanged: onOpenXmlDocumentChanged,
                                        onParagraphActivated:
                                            onOpenXmlParagraphActivated,
                                        onSelectionChanged:
                                            onOpenXmlSelectionChanged,
                                      )
                                    else
                                      TextField(
                                        controller:
                                            srqController.textController,
                                        focusNode: editorFocusNode,
                                        maxLines: null,
                                        minLines: 28,
                                        readOnly:
                                            editMode ==
                                            DocumentEditMode.docxRoundTrip,
                                        keyboardType: TextInputType.multiline,
                                        textAlign: textAlign,
                                        style: editorStyle,
                                        cursorColor: const Color(0xff2563eb),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          hintText:
                                              'Start writing your document...',
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
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _MediaDocumentBlock extends StatelessWidget {
  const _MediaDocumentBlock({required this.block, required this.onRemove});

  final MediaBlock block;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isImage = block.type == MediaType.image;
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
                ? block.bytes == null
                      ? Image.network(
                          block.source,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _MediaFallback(block: block),
                        )
                      : Image.memory(
                          block.bytes!,
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

class _RoundTripNotice extends StatelessWidget {
  const _RoundTripNotice({
    required this.editMode,
    required this.sourcePackageFormat,
    required this.onSwitchToOpenXmlEditing,
  });

  final DocumentEditMode editMode;
  final String? sourcePackageFormat;
  final VoidCallback onSwitchToOpenXmlEditing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffeff6ff),
        border: Border.all(color: const Color(0xffbfdbfe)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.description_outlined, color: Color(0xff1d4ed8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              editMode == DocumentEditMode.docxVisual
                  ? 'This ${sourcePackageFormat?.toUpperCase() ?? 'DOCX'} is in visual OOXML mode. Paragraph and table blocks are editable while style IDs, alignment, page breaks, and table structure are preserved for DOCX export.'
                  : editMode == DocumentEditMode.wysiwyg
                  ? 'This document is in WYSIWYG mode. Blocks are edited visually and synchronized into the OpenXML document model for export.'
                  : 'This ${sourcePackageFormat?.toUpperCase() ?? 'DOCX'} is in round-trip mode. The original styled package is preserved for export; switch to OpenXML editing when you want to normalize it into the native model.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xff1e3a8a)),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onSwitchToOpenXmlEditing,
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _OoxmlVisualEditor extends StatelessWidget {
  const _OoxmlVisualEditor({
    required this.blocks,
    required this.style,
    required this.onBlockChanged,
  });

  final List<OoxmlVisualBlock> blocks;
  final TextStyle style;
  final void Function(int index, OoxmlVisualBlock block) onBlockChanged;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return Text(
        'No editable OOXML blocks were detected in this document.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xff64748b)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index++) ...[
          _buildBlock(context, index, blocks[index]),
          if (index != blocks.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, int index, OoxmlVisualBlock block) {
    return switch (block) {
      OoxmlParagraphBlock() => TextFormField(
        key: ValueKey('ooxml-paragraph-$index'),
        initialValue: block.text,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: style,
        textAlign: _flutterAlignFor(block.align),
        decoration: InputDecoration(
          labelText: block.styleId?.isEmpty == false
              ? block.styleId
              : 'Paragraph',
          alignLabelWithHint: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (value) {
          onBlockChanged(index, block.copyWith(text: value));
        },
      ),
      OoxmlTableBlock() => _OoxmlTableEditor(
        index: index,
        block: block,
        style: style,
        onChanged: (updated) => onBlockChanged(index, updated),
      ),
      OoxmlPartTextBlock() => TextFormField(
        key: ValueKey('ooxml-part-${block.partPath}-${block.paragraphIndex}'),
        initialValue: block.text,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        style: style,
        decoration: InputDecoration(
          labelText: '${block.label} • ${block.partPath}',
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (value) {
          onBlockChanged(index, block.copyWith(text: value));
        },
      ),
      _ => const SizedBox.shrink(),
    };
  }

  TextAlign _flutterAlignFor(OoxmlTextAlign align) {
    return switch (align) {
      OoxmlTextAlign.center => TextAlign.center,
      OoxmlTextAlign.right => TextAlign.right,
      OoxmlTextAlign.justify => TextAlign.justify,
      OoxmlTextAlign.left => TextAlign.left,
    };
  }
}

class _OpenXmlStructuredEditor extends StatelessWidget {
  const _OpenXmlStructuredEditor({
    super.key,
    required this.document,
    required this.style,
    required this.textAlign,
    required this.onChanged,
    required this.onParagraphActivated,
    required this.onSelectionChanged,
  });

  final OpenXmlDocument document;
  final TextStyle style;
  final TextAlign textAlign;
  final ValueChanged<OpenXmlDocument> onChanged;
  final void Function(
    int index,
    OpenXmlParagraphBlock block,
    RichRunController controller,
    FocusNode focusNode,
  )
  onParagraphActivated;
  final VoidCallback onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final blocks = document.blocks.isEmpty
        ? const [
            OpenXmlParagraphBlock(runs: [OpenXmlRun('')]),
          ]
        : document.blocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < blocks.length; index += 1) ...[
          _buildBlock(context, index, blocks[index]),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _insertBlock(
                  blocks.length - 1,
                  const OpenXmlParagraphBlock(runs: [OpenXmlRun('')]),
                ),
                icon: const Icon(Icons.notes_outlined, size: 18),
                label: const Text('Paragraph'),
              ),
              OutlinedButton.icon(
                onPressed: () => _insertBlock(
                  blocks.length - 1,
                  const OpenXmlTableBlock(
                    rows: [
                      ['Header 1', 'Header 2'],
                      ['', ''],
                    ],
                  ),
                ),
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: const Text('Table'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlock(BuildContext context, int index, OpenXmlBlock block) {
    return switch (block) {
      OpenXmlParagraphBlock() => _OpenXmlParagraphEditor(
        key: ValueKey('openxml-paragraph-$index'),
        index: index,
        block: block,
        style: _styleForParagraph(block),
        textAlign: _flutterAlignFor(block.align, textAlign),
        onChanged: (updated) => _replaceBlock(index, updated),
        onActivated: onParagraphActivated,
        onSelectionChanged: onSelectionChanged,
      ),
      OpenXmlTableBlock() => _OoxmlTableEditor(
        index: index,
        block: OoxmlTableBlock(
          rows: block.rows,
          hasHeader: block.hasHeader,
          columnWidths: block.columnWidths,
          rowHeights: block.rowHeights,
        ),
        style: style,
        onChanged: (updated) => _replaceBlock(
          index,
          OpenXmlTableBlock(
            rows: updated.rows,
            hasHeader: updated.hasHeader,
            columnWidths: updated.columnWidths,
            rowHeights: updated.rowHeights,
          ),
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  TextStyle _styleForParagraph(OpenXmlParagraphBlock block) {
    // Run-level bold/italic/underline are rendered per character by
    // RichRunController.buildTextSpan, so the base style only carries the
    // paragraph-level (style) attributes here.
    final base = style.copyWith(
      fontFamily: block.style == OpenXmlTextStyle.code
          ? 'Courier New'
          : style.fontFamily,
    );
    return switch (block.style) {
      OpenXmlTextStyle.title => base.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      OpenXmlTextStyle.subtitle => base.copyWith(
        fontSize: 20,
        color: const Color(0xff475569),
        height: 1.32,
      ),
      OpenXmlTextStyle.heading1 => base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      OpenXmlTextStyle.heading2 => base.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.28,
      ),
      OpenXmlTextStyle.heading3 => base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.32,
      ),
      OpenXmlTextStyle.heading4 ||
      OpenXmlTextStyle.heading5 ||
      OpenXmlTextStyle.heading6 => base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      OpenXmlTextStyle.quote => base.copyWith(
        color: const Color(0xff475569),
        fontStyle: FontStyle.italic,
      ),
      OpenXmlTextStyle.code => base.copyWith(
        fontSize: 14,
        backgroundColor: const Color(0xfff1f5f9),
      ),
      OpenXmlTextStyle.caption => base.copyWith(
        fontSize: 13,
        color: const Color(0xff64748b),
        fontStyle: FontStyle.italic,
      ),
      OpenXmlTextStyle.normal => base,
    };
  }

  void _replaceBlock(int index, OpenXmlBlock block) {
    final blocks = List<OpenXmlBlock>.of(document.blocks);
    if (index < 0 || index >= blocks.length) {
      return;
    }
    blocks[index] = block;
    onChanged(document.copyWith(blocks: blocks));
  }

  void _insertBlock(int index, OpenXmlBlock block) {
    final blocks = List<OpenXmlBlock>.of(document.blocks);
    blocks.insert((index + 1).clamp(0, blocks.length), block);
    onChanged(document.copyWith(blocks: blocks));
  }

  TextAlign _flutterAlignFor(OoxmlTextAlign align, TextAlign fallback) {
    return switch (align) {
      OoxmlTextAlign.center => TextAlign.center,
      OoxmlTextAlign.right => TextAlign.right,
      OoxmlTextAlign.justify => TextAlign.justify,
      OoxmlTextAlign.left => fallback,
    };
  }
}

class _OpenXmlParagraphEditor extends StatefulWidget {
  const _OpenXmlParagraphEditor({
    super.key,
    required this.index,
    required this.block,
    required this.style,
    required this.textAlign,
    required this.onChanged,
    required this.onActivated,
    required this.onSelectionChanged,
  });

  final int index;
  final OpenXmlParagraphBlock block;
  final TextStyle style;
  final TextAlign textAlign;
  final ValueChanged<OpenXmlParagraphBlock> onChanged;
  final void Function(
    int index,
    OpenXmlParagraphBlock block,
    RichRunController controller,
    FocusNode focusNode,
  )
  onActivated;
  final VoidCallback onSelectionChanged;

  @override
  State<_OpenXmlParagraphEditor> createState() =>
      _OpenXmlParagraphEditorState();
}

class _OpenXmlParagraphEditorState extends State<_OpenXmlParagraphEditor> {
  late RichRunController _controller;
  final FocusNode _focusNode = FocusNode();
  TextSelection _lastSelection = const TextSelection.collapsed(offset: 0);
  late String _lastText;
  late String _lastSignature;

  @override
  void initState() {
    super.initState();
    _controller = RichRunController(runs: widget.block.runs);
    _lastText = _controller.text;
    _lastSignature = _runSignature(_controller.runs);
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _OpenXmlParagraphEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only rebuild the controller when the text itself changed from the
    // outside (template/import/version restore). Run-only changes that we
    // originated keep the controller authoritative so the caret never jumps.
    if (widget.block.plainText != _controller.text) {
      _controller.removeListener(_handleControllerChanged);
      _controller.dispose();
      _controller = RichRunController(runs: widget.block.runs);
      _lastText = _controller.text;
      _lastSignature = _runSignature(_controller.runs);
      _controller.addListener(_handleControllerChanged);
    } else {
      final blockSignature = _runSignature(widget.block.runs);
      if (blockSignature != _lastSignature) {
        _lastSignature = blockSignature;
        _controller.resetRuns(widget.block.runs, notify: false);
      }
    }
  }

  static String _runSignature(List<OpenXmlRun> runs) {
    return runs
        .map(
          (run) =>
              '${run.text.length}:${run.bold ? 1 : 0}${run.italic ? 1 : 0}'
              '${run.underline ? 1 : 0}${run.strike ? 1 : 0}'
              ':${run.colorHex ?? ''}',
        )
        .join('|');
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      widget.onActivated(widget.index, widget.block, _controller, _focusNode);
    }
  }

  void _handleControllerChanged() {
    final runs = _controller.runs;
    final signature = _runSignature(runs);
    if (_controller.text != _lastText || signature != _lastSignature) {
      _lastText = _controller.text;
      _lastSignature = signature;
      // Propagate content/formatting changes to the document model.
      widget.onChanged(widget.block.copyWith(runs: runs));
    }
    if (_controller.selection != _lastSelection) {
      _lastSelection = _controller.selection;
      if (_focusNode.hasFocus) {
        widget.onSelectionChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPageBreak = widget.block.pageBreakBefore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPageBreak)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: const [
                Expanded(child: Divider(color: Color(0xffcbd5e1))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Page break',
                    style: TextStyle(fontSize: 11, color: Color(0xff64748b)),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xffcbd5e1))),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textAlign: widget.textAlign,
          style: widget.style,
          cursorColor: const Color(0xff2563eb),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: widget.block.style == OpenXmlTextStyle.title
                ? 'Document title'
                : 'Type here',
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () => widget.onActivated(
            widget.index,
            widget.block,
            _controller,
            _focusNode,
          ),
        ),
      ],
    );
  }
}

class _QuillWysiwygEditor extends StatefulWidget {
  const _QuillWysiwygEditor({
    required this.blocks,
    required this.deltaJson,
    required this.inkCommandColor,
    required this.inkCommandId,
    required this.onDeltaChanged,
  });

  final List<WysiwygBlock> blocks;
  final List<Object?> deltaJson;
  final Color? inkCommandColor;
  final int inkCommandId;
  final ValueChanged<List<Object?>> onDeltaChanged;

  @override
  State<_QuillWysiwygEditor> createState() => _QuillWysiwygEditorState();
}

class _QuillWysiwygEditorState extends State<_QuillWysiwygEditor> {
  late quill.QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  TextSelection? _lastSelection;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _controller = _controllerFromWidget();
    _controller.addListener(_notifyDeltaChanged);
    _controller.addListener(_rememberSelection);
  }

  @override
  void didUpdateWidget(covariant _QuillWysiwygEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deltaJson != widget.deltaJson &&
        !_sameDelta(oldWidget.deltaJson, widget.deltaJson)) {
      _controller
        ..removeListener(_notifyDeltaChanged)
        ..removeListener(_rememberSelection)
        ..dispose();
      _controller = _controllerFromWidget();
      _controller.addListener(_notifyDeltaChanged);
      _controller.addListener(_rememberSelection);
    }
    if (oldWidget.inkCommandId != widget.inkCommandId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _applyInkCommand();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_notifyDeltaChanged)
      ..removeListener(_rememberSelection)
      ..dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xfff8fafc),
            border: Border.all(color: const Color(0xffdbe3ef)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: quill.QuillToolbar.basic(
              controller: _controller,
              showFontFamily: false,
              showFontSize: false,
              fontSizeValues: const {
                'Small': 'small',
                'Large': 'large',
                'Huge': 'huge',
                'Clear': '0',
              },
              fontFamilyValues: const {
                'Sans Serif': 'sans-serif',
                'Serif': 'serif',
                'Monospace': 'monospace',
                'Clear': 'Clear',
              },
              showInlineCode: false,
              showCodeBlock: false,
              showSearchButton: false,
              showDirection: false,
              showAlignmentButtons: true,
              multiRowsDisplay: true,
            ),
          ),
        ),
        const SizedBox(height: 16),
        quill.QuillEditor(
          controller: _controller,
          focusNode: _focusNode,
          scrollController: _scrollController,
          scrollable: false,
          padding: EdgeInsets.zero,
          autoFocus: false,
          readOnly: false,
          expands: false,
          minHeight: 420,
          placeholder: 'Start writing your document...',
        ),
      ],
    );
  }

  quill.QuillController _controllerFromWidget() {
    final deltaJson = widget.deltaJson.isNotEmpty
        ? widget.deltaJson
        : WysiwygDocumentCodec.toQuillDeltaJson(widget.blocks);
    return quill.QuillController(
      document: quill.Document.fromJson(deltaJson),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void _notifyDeltaChanged() {
    widget.onDeltaChanged(
      List<Object?>.of(_controller.document.toDelta().toJson()),
    );
  }

  void _rememberSelection() {
    final selection = _controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      _lastSelection = selection;
    }
  }

  void _applyInkCommand() {
    final color = widget.inkCommandColor;
    if (color == null) {
      return;
    }
    final documentLength = math.max(0, _controller.document.length - 1);
    final selection =
        _controller.selection.isValid && !_controller.selection.isCollapsed
        ? _controller.selection
        : _lastSelection;
    final range =
        selection != null &&
            selection.isValid &&
            !selection.isCollapsed &&
            selection.start < documentLength
        ? selection
        : _paragraphSelectionForQuill(documentLength);
    final start = range.start.clamp(0, documentLength);
    final end = range.end.clamp(0, documentLength);
    if (end <= start) {
      return;
    }
    _controller.updateSelection(
      TextSelection(baseOffset: start, extentOffset: end),
      quill.ChangeSource.LOCAL,
    );
    _controller.formatSelection(quill.ColorAttribute(_hexColor(color)));
    _lastSelection = TextSelection(baseOffset: start, extentOffset: end);
  }

  TextSelection _paragraphSelectionForQuill(int documentLength) {
    final plainText = _controller.document.toPlainText();
    if (plainText.isEmpty || documentLength == 0) {
      return const TextSelection.collapsed(offset: 0);
    }
    final selection = _controller.selection;
    final cursor = selection.isValid
        ? selection.start.clamp(0, documentLength)
        : documentLength;
    final start = plainText.lastIndexOf('\n', math.max(0, cursor - 1)) + 1;
    final nextBreak = plainText.indexOf('\n', cursor);
    final end = (nextBreak == -1 ? documentLength : nextBreak).clamp(
      0,
      documentLength,
    );
    return TextSelection(baseOffset: start, extentOffset: end);
  }

  String _hexColor(Color color) {
    final rgb = color.toARGB32() & 0x00ffffff;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  bool _sameDelta(List<Object?> left, List<Object?> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index].toString() != right[index].toString()) {
        return false;
      }
    }
    return true;
  }
}

class _OoxmlTableEditor extends StatelessWidget {
  const _OoxmlTableEditor({
    required this.index,
    required this.block,
    required this.style,
    required this.onChanged,
  });

  final int index;
  final OoxmlTableBlock block;
  final TextStyle style;
  final ValueChanged<OoxmlTableBlock> onChanged;

  static const double _twipsPerPixel = 15;
  static const int _defaultColumnWidth = 1800;
  static const int _defaultRowHeight = 660;
  static const int _minColumnWidth = 720;
  static const int _minRowHeight = 420;

  @override
  Widget build(BuildContext context) {
    if (block.rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final columnCount = block.rows.fold<int>(
      0,
      (count, row) => math.max(count, row.length),
    );
    if (columnCount == 0) {
      return const SizedBox.shrink();
    }
    final columnWidths = _resolvedColumnWidths(columnCount);
    final rowHeights = _resolvedRowHeights();

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffcbd5e1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var rowIndex = 0; rowIndex < block.rows.length; rowIndex++)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      var columnIndex = 0;
                      columnIndex < columnCount;
                      columnIndex++
                    )
                      _ResizableOoxmlTableCell(
                        tableIndex: index,
                        rowIndex: rowIndex,
                        columnIndex: columnIndex,
                        value: columnIndex < block.rows[rowIndex].length
                            ? block.rows[rowIndex][columnIndex]
                            : '',
                        width: _twipsToPixels(columnWidths[columnIndex]),
                        height: _twipsToPixels(rowHeights[rowIndex]),
                        isHeader: block.hasHeader && rowIndex == 0,
                        style: style,
                        onTextChanged: (value) {
                          final rows = block.rows
                              .map((row) => List<String>.of(row))
                              .toList();
                          while (rows[rowIndex].length <= columnIndex) {
                            rows[rowIndex].add('');
                          }
                          rows[rowIndex][columnIndex] = value;
                          onChanged(block.copyWith(rows: rows));
                        },
                        onColumnDrag: (delta) {
                          final widths = List<int>.of(columnWidths);
                          widths[columnIndex] = math.max(
                            _minColumnWidth,
                            widths[columnIndex] +
                                _pixelsToTwips(delta.delta.dx),
                          );
                          onChanged(block.copyWith(columnWidths: widths));
                        },
                        onRowDrag: (delta) {
                          final heights = List<int>.of(rowHeights);
                          heights[rowIndex] = math.max(
                            _minRowHeight,
                            heights[rowIndex] + _pixelsToTwips(delta.delta.dy),
                          );
                          onChanged(block.copyWith(rowHeights: heights));
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<int> _resolvedColumnWidths(int columnCount) {
    return [
      for (var index = 0; index < columnCount; index += 1)
        index < block.columnWidths.length && block.columnWidths[index] > 0
            ? block.columnWidths[index]
            : _defaultColumnWidth,
    ];
  }

  List<int> _resolvedRowHeights() {
    return [
      for (var index = 0; index < block.rows.length; index += 1)
        index < block.rowHeights.length && block.rowHeights[index] > 0
            ? block.rowHeights[index]
            : _defaultRowHeight,
    ];
  }

  double _twipsToPixels(int twips) => twips / _twipsPerPixel;

  int _pixelsToTwips(double pixels) => (pixels * _twipsPerPixel).round();
}

class _ResizableOoxmlTableCell extends StatelessWidget {
  const _ResizableOoxmlTableCell({
    required this.tableIndex,
    required this.rowIndex,
    required this.columnIndex,
    required this.value,
    required this.width,
    required this.height,
    required this.isHeader,
    required this.style,
    required this.onTextChanged,
    required this.onColumnDrag,
    required this.onRowDrag,
  });

  final int tableIndex;
  final int rowIndex;
  final int columnIndex;
  final String value;
  final double width;
  final double height;
  final bool isHeader;
  final TextStyle style;
  final ValueChanged<String> onTextChanged;
  final GestureDragUpdateCallback onColumnDrag;
  final GestureDragUpdateCallback onRowDrag;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isHeader ? const Color(0xfff1f5f9) : Colors.transparent,
          border: const Border(
            right: BorderSide(color: Color(0xffcbd5e1)),
            bottom: BorderSide(color: Color(0xffcbd5e1)),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: TextFormField(
                  key: ValueKey(
                    'ooxml-table-$tableIndex-$rowIndex-$columnIndex',
                  ),
                  initialValue: value,
                  maxLines: null,
                  expands: true,
                  style: style.copyWith(
                    fontWeight: isHeader ? FontWeight.w700 : style.fontWeight,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: onTextChanged,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 8,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: onColumnDrag,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 8,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: onRowDrag,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.block});

  final MediaBlock block;

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
            top: 12,
            left: 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  block.bytes == null ? 'Linked video' : 'Device video',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
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

  final MediaBlock block;

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
