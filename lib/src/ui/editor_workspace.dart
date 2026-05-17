// ignore_for_file: use_key_in_widget_constructors

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smart_rich_text_quill/smart_rich_text_quill.dart';

import '../document/document_models.dart';
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
    required this.mediaBlocks,
    required this.onRemoveMedia,
    required this.onToggleNavigation,
    required this.onToggleInspector,
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
  final List<MediaBlock> mediaBlocks;
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
                                    controller: srqController.textController,
                                    focusNode: editorFocusNode,
                                    maxLines: null,
                                    minLines: 28,
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
