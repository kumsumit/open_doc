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
    required this.onOpenXmlParagraphFocused,
    required this.ooxmlBlocks,
    required this.onOoxmlBlockChanged,
    required this.wysiwygBlocks,
    required this.quillDeltaJson,
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
  final void Function(int index, OpenXmlParagraphBlock block)
  onOpenXmlParagraphFocused;
  final List<OoxmlVisualBlock> ooxmlBlocks;
  final void Function(int index, OoxmlVisualBlock block) onOoxmlBlockChanged;
  final List<WysiwygBlock> wysiwygBlocks;
  final List<Object?> quillDeltaJson;
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
                                        onParagraphFocused:
                                            onOpenXmlParagraphFocused,
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
    required this.onParagraphFocused,
  });

  final OpenXmlDocument document;
  final TextStyle style;
  final TextAlign textAlign;
  final ValueChanged<OpenXmlDocument> onChanged;
  final void Function(int index, OpenXmlParagraphBlock block)
  onParagraphFocused;

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
        block: block,
        style: _styleForParagraph(block),
        textAlign: _flutterAlignFor(block.align, textAlign),
        onChanged: (updated) => _replaceBlock(index, updated),
        onFocused: () => onParagraphFocused(index, block),
        onInsertAfter: () => _insertBlock(
          index,
          const OpenXmlParagraphBlock(runs: [OpenXmlRun('')]),
        ),
        onRemove: () => _removeBlock(index),
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
    final base = style.copyWith(
      fontFamily: block.style == OpenXmlTextStyle.code
          ? 'Courier New'
          : style.fontFamily,
      fontStyle: block.runs.any((run) => run.italic)
          ? FontStyle.italic
          : style.fontStyle,
      fontWeight: block.runs.any((run) => run.bold)
          ? FontWeight.w700
          : style.fontWeight,
      decoration: block.runs.any((run) => run.underline)
          ? TextDecoration.underline
          : style.decoration,
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

  void _removeBlock(int index) {
    final blocks = List<OpenXmlBlock>.of(document.blocks);
    if (blocks.length <= 1) {
      _replaceBlock(index, const OpenXmlParagraphBlock(runs: [OpenXmlRun('')]));
      return;
    }
    blocks.removeAt(index);
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

class _OpenXmlParagraphEditor extends StatelessWidget {
  const _OpenXmlParagraphEditor({
    super.key,
    required this.block,
    required this.style,
    required this.textAlign,
    required this.onChanged,
    required this.onFocused,
    required this.onInsertAfter,
    required this.onRemove,
  });

  final OpenXmlParagraphBlock block;
  final TextStyle style;
  final TextAlign textAlign;
  final ValueChanged<OpenXmlParagraphBlock> onChanged;
  final VoidCallback onFocused;
  final VoidCallback onInsertAfter;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasPageBreak = block.pageBreakBefore;
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
        TextFormField(
          initialValue: block.plainText,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textAlign: textAlign,
          style: style,
          cursorColor: const Color(0xff2563eb),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: block.style == OpenXmlTextStyle.title
                ? 'Document title'
                : 'Type here',
            contentPadding: EdgeInsets.zero,
          ),
          onTap: onFocused,
          onChanged: (value) {
            onFocused();
            final previous = block.runs.isEmpty
                ? const OpenXmlRun('')
                : block.runs.first;
            onChanged(
              block.copyWith(
                runs: [
                  OpenXmlRun(
                    value,
                    bold: previous.bold,
                    italic: previous.italic,
                    underline: previous.underline,
                    strike: previous.strike,
                    href: previous.href,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BlockMenu extends StatelessWidget {
  const _BlockMenu({
    required this.style,
    required this.align,
    required this.onStyleChanged,
    required this.onAlignChanged,
    required this.onInsertAfter,
    required this.onRemove,
  });

  final OpenXmlTextStyle style;
  final OoxmlTextAlign align;
  final ValueChanged<OpenXmlTextStyle> onStyleChanged;
  final ValueChanged<OoxmlTextAlign> onAlignChanged;
  final VoidCallback onInsertAfter;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_BlockCommand>(
      tooltip: 'Block options',
      icon: const Icon(Icons.more_horiz, size: 18),
      onSelected: (command) {
        switch (command.kind) {
          case _BlockCommandKind.style:
            onStyleChanged(command.style ?? OpenXmlTextStyle.normal);
          case _BlockCommandKind.align:
            onAlignChanged(command.align ?? OoxmlTextAlign.left);
          case _BlockCommandKind.insert:
            onInsertAfter();
          case _BlockCommandKind.remove:
            onRemove();
        }
      },
      itemBuilder: (context) => [
        for (final value in OpenXmlTextStyle.values)
          PopupMenuItem(
            value: _BlockCommand.style(value),
            child: Row(
              children: [
                Icon(
                  value == style ? Icons.check : Icons.text_fields,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(value.label),
              ],
            ),
          ),
        const PopupMenuDivider(),
        for (final value in OoxmlTextAlign.values)
          PopupMenuItem(
            value: _BlockCommand.align(value),
            child: Row(
              children: [
                Icon(
                  value == align ? Icons.check : Icons.format_align_left,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(value.name),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _BlockCommand.insert(),
          child: Row(
            children: [
              Icon(Icons.add, size: 16),
              SizedBox(width: 8),
              Text('Insert paragraph'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: _BlockCommand.remove(),
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16),
              SizedBox(width: 8),
              Text('Remove block'),
            ],
          ),
        ),
      ],
    );
  }
}

enum _BlockCommandKind { style, align, insert, remove }

class _BlockCommand {
  const _BlockCommand.style(this.style)
    : kind = _BlockCommandKind.style,
      align = null;

  const _BlockCommand.align(this.align)
    : kind = _BlockCommandKind.align,
      style = null;

  const _BlockCommand.insert()
    : kind = _BlockCommandKind.insert,
      style = null,
      align = null;

  const _BlockCommand.remove()
    : kind = _BlockCommandKind.remove,
      style = null,
      align = null;

  final _BlockCommandKind kind;
  final OpenXmlTextStyle? style;
  final OoxmlTextAlign? align;
}

class _QuillWysiwygEditor extends StatefulWidget {
  const _QuillWysiwygEditor({
    required this.blocks,
    required this.deltaJson,
    required this.onDeltaChanged,
  });

  final List<WysiwygBlock> blocks;
  final List<Object?> deltaJson;
  final ValueChanged<List<Object?>> onDeltaChanged;

  @override
  State<_QuillWysiwygEditor> createState() => _QuillWysiwygEditorState();
}

class _QuillWysiwygEditorState extends State<_QuillWysiwygEditor> {
  late quill.QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _controller = _controllerFromWidget();
    _controller.addListener(_notifyDeltaChanged);
  }

  @override
  void didUpdateWidget(covariant _QuillWysiwygEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deltaJson != widget.deltaJson &&
        !_sameDelta(oldWidget.deltaJson, widget.deltaJson)) {
      _controller
        ..removeListener(_notifyDeltaChanged)
        ..dispose();
      _controller = _controllerFromWidget();
      _controller.addListener(_notifyDeltaChanged);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_notifyDeltaChanged)
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
              showFontSize: true,
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
