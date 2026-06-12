// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../services/document_export_service.dart';
import 'common_controls.dart';

class Ribbon extends StatelessWidget {
  const Ribbon({
    super.key,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
    required this.superscript,
    required this.subscript,
    required this.smallCaps,
    required this.allCaps,
    required this.doubleUnderline,
    required this.doubleStrike,
    required this.hidden,
    required this.formatPainterActive,
    required this.highlightColor,
    required this.showRuler,
    required this.trackChanges,
    required this.commentsMode,
    required this.fontSize,
    required this.zoom,
    required this.fontFamily,
    required this.fontFamilies,
    required this.style,
    required this.alignment,
    required this.audienceProfile,
    required this.toneMode,
    required this.pageSize,
    required this.pageOrientation,
    required this.marginPreset,
    required this.inkColor,
    required this.pageColor,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onStrikethrough,
    required this.onSuperscript,
    required this.onSubscript,
    required this.onSmallCaps,
    required this.onAllCaps,
    required this.onDoubleUnderline,
    required this.onDoubleStrike,
    required this.onHidden,
    required this.onFormatPainter,
    required this.onClearFormatting,
    required this.onHighlight,
    required this.onIndentIncrease,
    required this.onIndentDecrease,
    required this.onRuler,
    required this.onTrackChanges,
    required this.onCommentsMode,
    required this.onFontSize,
    required this.onZoom,
    required this.onFontFamily,
    required this.onImportFont,
    required this.onStyle,
    required this.onAlignment,
    required this.onAudienceProfile,
    required this.onToneMode,
    required this.onPageSize,
    required this.onPageOrientation,
    required this.onMarginPreset,
    required this.onInkColor,
    required this.onPageColor,
    required this.onInsertTable,
    required this.onInsertImage,
    required this.onInsertVideo,
    required this.onInsertChecklist,
    required this.onInsertBulletList,
    required this.onInsertOrderedList,
    required this.onInsertPageBreak,
    required this.onInsertToc,
    required this.onInsertFootnote,
    required this.onInsertEndnote,
    required this.onInsertHorizontalRule,
    required this.onInsertDropCap,
    required this.onInsertShape,
    required this.onInsertLink,
    required this.onInsertSignature,
    required this.onUndo,
    required this.onRedo,
    required this.onAcceptChanges,
    required this.onRejectChanges,
    required this.onSmartBrief,
    required this.onSocialSummary,
    required this.onCitationNudge,
    required this.onActionDigest,
    required this.onKeyboardShortcuts,
    required this.highContrast,
    required this.onHighContrast,
    required this.onPrintPreview,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool superscript;
  final bool subscript;
  final bool smallCaps;
  final bool allCaps;
  final bool doubleUnderline;
  final bool doubleStrike;
  final bool hidden;
  final bool formatPainterActive;
  final Color? highlightColor;
  final bool showRuler;
  final bool trackChanges;
  final bool commentsMode;
  final double fontSize;
  final double zoom;
  final String fontFamily;
  final List<String> fontFamilies;
  final String style;
  final String alignment;
  final String audienceProfile;
  final String toneMode;
  final DocumentPageSize pageSize;
  final DocumentPageOrientation pageOrientation;
  final DocumentMarginPreset marginPreset;
  final Color inkColor;
  final Color pageColor;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onStrikethrough;
  final VoidCallback onSuperscript;
  final VoidCallback onSubscript;
  final VoidCallback onSmallCaps;
  final VoidCallback onAllCaps;
  final VoidCallback onDoubleUnderline;
  final VoidCallback onDoubleStrike;
  final VoidCallback onHidden;
  final VoidCallback onFormatPainter;
  final VoidCallback onClearFormatting;
  final ValueChanged<Color?> onHighlight;
  final VoidCallback onIndentIncrease;
  final VoidCallback onIndentDecrease;
  final VoidCallback onRuler;
  final VoidCallback onTrackChanges;
  final VoidCallback onCommentsMode;
  final ValueChanged<double> onFontSize;
  final ValueChanged<double> onZoom;
  final ValueChanged<String> onFontFamily;
  final VoidCallback onImportFont;
  final ValueChanged<String> onStyle;
  final ValueChanged<String> onAlignment;
  final ValueChanged<String> onAudienceProfile;
  final ValueChanged<String> onToneMode;
  final ValueChanged<DocumentPageSize> onPageSize;
  final ValueChanged<DocumentPageOrientation> onPageOrientation;
  final ValueChanged<DocumentMarginPreset> onMarginPreset;
  final ValueChanged<Color> onInkColor;
  final ValueChanged<Color> onPageColor;
  final VoidCallback onInsertTable;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertVideo;
  final VoidCallback onInsertChecklist;
  final VoidCallback onInsertBulletList;
  final VoidCallback onInsertOrderedList;
  final VoidCallback onInsertPageBreak;
  final VoidCallback onInsertToc;
  final VoidCallback onInsertFootnote;
  final VoidCallback onInsertEndnote;
  final VoidCallback onInsertHorizontalRule;
  final VoidCallback onInsertDropCap;
  final VoidCallback onInsertShape;
  final VoidCallback onInsertLink;
  final VoidCallback onInsertSignature;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onAcceptChanges;
  final VoidCallback onRejectChanges;
  final VoidCallback onSmartBrief;
  final VoidCallback onSocialSummary;
  final VoidCallback onCitationNudge;
  final VoidCallback onActionDigest;
  final VoidCallback onKeyboardShortcuts;
  final bool highContrast;
  final VoidCallback onHighContrast;
  final VoidCallback onPrintPreview;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xfffbfcfe),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          return Container(
            height: 112,
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 16,
              10,
              compact ? 10 : 16,
              compact ? 8 : 12,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xffdbe3ef))),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                RibbonGroup(
                  label: 'Document',
                  child: Row(
                    children: [
                      ToolButton(
                        icon: Icons.table_chart_outlined,
                        label: 'Table',
                        onTap: onInsertTable,
                      ),
                      ToolButton(
                        icon: Icons.image_outlined,
                        label: 'Image',
                        onTap: onInsertImage,
                      ),
                      ToolButton(
                        icon: Icons.smart_display_outlined,
                        label: 'Video',
                        onTap: onInsertVideo,
                      ),
                      ToolButton(
                        icon: Icons.format_list_bulleted_outlined,
                        label: 'Bullet',
                        onTap: onInsertBulletList,
                      ),
                      ToolButton(
                        icon: Icons.format_list_numbered_outlined,
                        label: 'List',
                        onTap: onInsertOrderedList,
                      ),
                      ToolButton(
                        icon: Icons.checklist_outlined,
                        label: 'Tasks',
                        onTap: onInsertChecklist,
                      ),
                      ToolButton(
                        icon: Icons.vertical_split_outlined,
                        label: 'Break',
                        onTap: onInsertPageBreak,
                      ),
                      ToolButton(
                        icon: Icons.format_list_numbered_rtl_outlined,
                        label: 'TOC',
                        onTap: onInsertToc,
                      ),
                      ToolButton(
                        icon: Icons.note_alt_outlined,
                        label: 'Footnote',
                        onTap: onInsertFootnote,
                      ),
                      ToolButton(
                        icon: Icons.notes_outlined,
                        label: 'Endnote',
                        onTap: onInsertEndnote,
                      ),
                      ToolButton(
                        icon: Icons.horizontal_rule_outlined,
                        label: 'Rule',
                        onTap: onInsertHorizontalRule,
                      ),
                      ToolButton(
                        icon: Icons.format_size_outlined,
                        label: 'Drop',
                        onTap: onInsertDropCap,
                      ),
                      ToolButton(
                        icon: Icons.category_outlined,
                        label: 'Shape',
                        onTap: onInsertShape,
                      ),
                      ToolButton(
                        icon: Icons.link_outlined,
                        label: 'Link',
                        onTap: onInsertLink,
                      ),
                      ToolButton(
                        icon: Icons.draw_outlined,
                        label: 'Sign',
                        onTap: onInsertSignature,
                      ),
                    ],
                  ),
                ),
                RibbonGroup(
                  label: 'Style',
                  child: Row(
                    children: [
                      DropdownChip(
                        value: style,
                        width: 132,
                        values: const [
                          'Normal',
                          'Title',
                          'Subtitle',
                          'Heading 1',
                          'Heading 2',
                          'Heading 3',
                          'Heading 4',
                          'Heading 5',
                          'Heading 6',
                          'Quote',
                          'Code',
                          'Caption',
                        ],
                        onChanged: onStyle,
                      ),
                      const SizedBox(width: 8),
                      DropdownChip(
                        value: fontFamily,
                        width: 132,
                        values: fontFamilies,
                        onChanged: onFontFamily,
                      ),
                      IconAction(
                        icon: Icons.upload_file_outlined,
                        label: 'Import font',
                        onTap: onImportFont,
                      ),
                      const SizedBox(width: 8),
                      StepperChip(
                        value: fontSize,
                        min: 10,
                        max: 34,
                        onChanged: onFontSize,
                      ),
                    ],
                  ),
                ),
                RibbonGroup(
                  label: 'Format',
                  child: Row(
                    children: [
                      ToggleTool(
                        icon: Icons.format_bold,
                        label: 'Bold',
                        selected: bold,
                        onTap: onBold,
                      ),
                      ToggleTool(
                        icon: Icons.format_italic,
                        label: 'Italic',
                        selected: italic,
                        onTap: onItalic,
                      ),
                      ToggleTool(
                        icon: Icons.format_underlined,
                        label: 'Underline',
                        selected: underline,
                        onTap: onUnderline,
                      ),
                      ToggleTool(
                        icon: Icons.format_strikethrough,
                        label: 'Strike',
                        selected: strikethrough,
                        onTap: onStrikethrough,
                      ),
                      ToggleTool(
                        icon: Icons.superscript,
                        label: 'Super',
                        selected: superscript,
                        onTap: onSuperscript,
                      ),
                      ToggleTool(
                        icon: Icons.subscript,
                        label: 'Sub',
                        selected: subscript,
                        onTap: onSubscript,
                      ),
                      ToggleTool(
                        icon: Icons.text_fields_outlined,
                        label: 'Small Caps',
                        selected: smallCaps,
                        onTap: onSmallCaps,
                      ),
                      ToggleTool(
                        icon: Icons.text_fields,
                        label: 'All Caps',
                        selected: allCaps,
                        onTap: onAllCaps,
                      ),
                      ToggleTool(
                        icon: Icons.format_underlined_outlined,
                        label: 'Double Underline',
                        selected: doubleUnderline,
                        onTap: onDoubleUnderline,
                      ),
                      ToggleTool(
                        icon: Icons.strikethrough_s_outlined,
                        label: 'Double Strikethrough',
                        selected: doubleStrike,
                        onTap: onDoubleStrike,
                      ),
                      ToggleTool(
                        icon: Icons.visibility_off_outlined,
                        label: 'Hidden Text',
                        selected: hidden,
                        onTap: onHidden,
                      ),
                      const SizedBox(width: 4),
                      ToggleTool(
                        icon: Icons.format_paint_outlined,
                        label: 'Format Painter',
                        selected: formatPainterActive,
                        onTap: onFormatPainter,
                      ),
                      const SizedBox(width: 4),
                      _HighlightButton(
                        color: highlightColor,
                        onChanged: onHighlight,
                      ),
                      ToolButton(
                        icon: Icons.format_clear,
                        label: 'Clear',
                        onTap: onClearFormatting,
                      ),
                      const SizedBox(width: 8),
                      DropdownChip(
                        value: alignment,
                        width: 112,
                        values: const ['Left', 'Center', 'Right', 'Justify'],
                        onChanged: onAlignment,
                      ),
                      const SizedBox(width: 4),
                      ToolButton(
                        icon: Icons.format_indent_increase,
                        label: 'Indent',
                        onTap: onIndentIncrease,
                      ),
                      ToolButton(
                        icon: Icons.format_indent_decrease,
                        label: 'Outdent',
                        onTap: onIndentDecrease,
                      ),
                    ],
                  ),
                ),
                RibbonGroup(
                  label: 'Color',
                  child: Row(
                    children: [
                      ColorDot(
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
                      ColorDot(
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
                RibbonGroup(
                  label: 'Page',
                  child: Row(
                    children: [
                      EnumDropdownChip<DocumentPageSize>(
                        value: pageSize,
                        width: 96,
                        values: DocumentPageSize.values,
                        labelFor: (value) => value.label,
                        onChanged: onPageSize,
                      ),
                      const SizedBox(width: 8),
                      EnumDropdownChip<DocumentPageOrientation>(
                        value: pageOrientation,
                        width: 122,
                        values: DocumentPageOrientation.values,
                        labelFor: (value) => value.label,
                        onChanged: onPageOrientation,
                      ),
                      const SizedBox(width: 8),
                      EnumDropdownChip<DocumentMarginPreset>(
                        value: marginPreset,
                        width: 104,
                        values: DocumentMarginPreset.values,
                        labelFor: (value) => value.label,
                        onChanged: onMarginPreset,
                      ),
                    ],
                  ),
                ),
                RibbonGroup(
                  label: 'Review',
                  child: Row(
                    children: [
                      ToggleTool(
                        icon: Icons.rate_review_outlined,
                        label: 'Comments',
                        selected: commentsMode,
                        onTap: onCommentsMode,
                      ),
                      ToggleTool(
                        icon: Icons.change_circle_outlined,
                        label: 'Track',
                        selected: trackChanges,
                        onTap: onTrackChanges,
                      ),
                      ToggleTool(
                        icon: Icons.straighten_outlined,
                        label: 'Ruler',
                        selected: showRuler,
                        onTap: onRuler,
                      ),
                      const SizedBox(width: 8),
                      ToolButton(
                        icon: Icons.undo_outlined,
                        label: 'Undo',
                        onTap: onUndo,
                      ),
                      ToolButton(
                        icon: Icons.redo_outlined,
                        label: 'Redo',
                        onTap: onRedo,
                      ),
                      const SizedBox(width: 8),
                      ToolButton(
                        icon: Icons.done_all_outlined,
                        label: 'Accept',
                        onTap: onAcceptChanges,
                      ),
                      ToolButton(
                        icon: Icons.replay_outlined,
                        label: 'Reject',
                        onTap: onRejectChanges,
                      ),
                    ],
                  ),
                ),
                RibbonGroup(
                  label: 'Smart',
                  child: Row(
                    children: [
                      DropdownChip(
                        value: audienceProfile,
                        width: 128,
                        values: const ['Millennial', 'Gen Z', 'Alpha', 'Beta'],
                        onChanged: onAudienceProfile,
                      ),
                      const SizedBox(width: 8),
                      DropdownChip(
                        value: toneMode,
                        width: 112,
                        values: const ['Clear', 'Warm', 'Bold', 'Brief'],
                        onChanged: onToneMode,
                      ),
                      const SizedBox(width: 8),
                      ToolButton(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Brief',
                        onTap: onSmartBrief,
                      ),
                      ToolButton(
                        icon: Icons.ios_share_outlined,
                        label: 'Social',
                        onTap: onSocialSummary,
                      ),
                      ToolButton(
                        icon: Icons.verified_outlined,
                        label: 'Source',
                        onTap: onCitationNudge,
                      ),
                      ToolButton(
                        icon: Icons.task_alt_outlined,
                        label: 'Actions',
                        onTap: onActionDigest,
                      ),
                    ],
                  ),
                ),
                RibbonGroup(
                  label: 'View',
                  child: Row(
                    children: [
                      SizedBox(
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
                      const SizedBox(width: 4),
                      ToggleTool(
                        icon: Icons.contrast_outlined,
                        label: 'High Contrast',
                        selected: highContrast,
                        onTap: onHighContrast,
                      ),
                      ToolButton(
                        icon: Icons.print_outlined,
                        label: 'Preview',
                        onTap: onPrintPreview,
                      ),
                      ToolButton(
                        icon: Icons.keyboard_outlined,
                        label: 'Keys',
                        onTap: onKeyboardShortcuts,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Highlight colour picker button ───────────────────────────────────────────

class _HighlightButton extends StatelessWidget {
  const _HighlightButton({required this.color, required this.onChanged});

  final Color? color;
  final ValueChanged<Color?> onChanged;

  static const _colors = <Color>[
    Color(0xfffffb00), // yellow
    Color(0xff00ff00), // green
    Color(0xff00ffff), // cyan
    Color(0xffff69b4), // pink
    Color(0xffff8c00), // orange
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Color?>(
      tooltip: 'Highlight',
      offset: const Offset(0, 44),
      itemBuilder: (_) => [
        for (final c in _colors)
          PopupMenuItem<Color?>(
            value: c,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(color: const Color(0xffcccccc)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuItem<Color?>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.format_color_reset, size: 18),
              SizedBox(width: 6),
              Text('Remove'),
            ],
          ),
        ),
      ],
      onSelected: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.format_color_fill, size: 18),
            Container(
              width: 18,
              height: 3,
              color: color ?? const Color(0xfffffb00),
            ),
            const SizedBox(height: 2),
            const Text(
              'Highlight',
              style: TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
