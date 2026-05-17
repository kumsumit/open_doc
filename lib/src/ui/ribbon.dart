part of '../../main.dart';

class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
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
    required this.onStrikethrough,
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
    required this.onInsertBulletList,
    required this.onInsertOrderedList,
    required this.onInsertSignature,
    required this.onUndo,
    required this.onRedo,
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
  final bool strikethrough;
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
  final VoidCallback onStrikethrough;
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
  final VoidCallback onInsertBulletList;
  final VoidCallback onInsertOrderedList;
  final VoidCallback onInsertSignature;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
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
                        icon: Icons.format_list_bulleted_outlined,
                        label: 'Bullet',
                        onTap: onInsertBulletList,
                      ),
                      _ToolButton(
                        icon: Icons.format_list_numbered_outlined,
                        label: 'List',
                        onTap: onInsertOrderedList,
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
                      _ToggleTool(
                        icon: Icons.format_strikethrough,
                        label: 'Strike',
                        selected: strikethrough,
                        onTap: onStrikethrough,
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
                        icon: Icons.undo_outlined,
                        label: 'Undo',
                        onTap: onUndo,
                      ),
                      _ToolButton(
                        icon: Icons.redo_outlined,
                        label: 'Redo',
                        onTap: onRedo,
                      ),
                      const SizedBox(width: 8),
                      _ToolButton(
                        icon: Icons.done_all_outlined,
                        label: 'Accept',
                        onTap: onAcceptChanges,
                      ),
                      _ToolButton(
                        icon: Icons.replay_outlined,
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
          );
        },
      ),
    );
  }
}
