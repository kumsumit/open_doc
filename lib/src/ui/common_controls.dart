// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../services/document_models.dart';

class Ruler extends StatelessWidget {
  const Ruler();

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

/// Provides the toolbar density to descendant [RibbonGroup]s so a single
/// wrapper can hide every group caption for the compact toolbar layout.
class RibbonGroupLabels extends InheritedWidget {
  const RibbonGroupLabels({
    required this.visible,
    required super.child,
  });

  final bool visible;

  static bool of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RibbonGroupLabels>();
    return scope?.visible ?? true;
  }

  @override
  bool updateShouldNotify(RibbonGroupLabels oldWidget) =>
      visible != oldWidget.visible;
}

class RibbonGroup extends StatelessWidget {
  const RibbonGroup({
    required this.label,
    required this.child,
    this.showLabel = true,
  });

  final String label;
  final Widget child;

  /// When false the group caption is hidden, yielding a denser toolbar used
  /// by the compact toolbar layout. Defers to an ancestor [RibbonGroupLabels]
  /// when present so the layout can toggle every group at once.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final showLabel = this.showLabel && RibbonGroupLabels.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 14),
      padding: showLabel
          ? const EdgeInsets.fromLTRB(10, 8, 10, 5)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe2e8f0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          if (showLabel) ...[
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
        ],
      ),
    );
  }
}

class IconAction extends StatelessWidget {
  const IconAction({
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

class TopBarCommand extends StatelessWidget {
  const TopBarCommand({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    final iconWidget = Icon(icon, size: 18);
    final labelWidget = Text(label);
    return SizedBox(
      height: 38,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: iconWidget,
              label: labelWidget,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: shape,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: iconWidget,
              label: labelWidget,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: shape,
              ),
            ),
    );
  }
}

class ToolButton extends StatelessWidget {
  const ToolButton({
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

class ToggleTool extends StatelessWidget {
  const ToggleTool({
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

class DropdownChip extends StatelessWidget {
  const DropdownChip({
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

class EnumDropdownChip<T> extends StatelessWidget {
  const EnumDropdownChip({
    super.key,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
    this.width = 112,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        border: Border.all(color: const Color(0xffcbd5e1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 18),
          items: values
              .map(
                (entry) => DropdownMenuItem<T>(
                  value: entry,
                  child: Text(labelFor(entry), overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class StepperChip extends StatelessWidget {
  const StepperChip({
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

class ColorDot extends StatelessWidget {
  const ColorDot({
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

class PanelHeader extends StatelessWidget {
  const PanelHeader({
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

class MetricCard extends StatelessWidget {
  const MetricCard({required this.label, required this.value});

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

class StatusTile extends StatelessWidget {
  const StatusTile({
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

class InspectorToggleTile extends StatelessWidget {
  const InspectorToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onToggle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: value ? activeColor : Colors.grey),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        activeThumbColor: activeColor,
        activeTrackColor: activeColor.withValues(alpha: 0.35),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: (_) => onToggle(),
      ),
    );
  }
}

class InspectorSelectTile extends StatelessWidget {
  const InspectorSelectTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.options,
    required this.color,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String value;
  final List<String> options;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        style: Theme.of(context).textTheme.bodyMedium,
        isDense: true,
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class CommentCard extends StatefulWidget {
  const CommentCard({
    required this.comment,
    required this.onResolve,
    required this.onReply,
  });

  final DocumentComment comment;
  final VoidCallback onResolve;
  final ValueChanged<String> onReply;

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool _showReplyField = false;
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    if (comment.resolved) return const SizedBox.shrink();
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
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.author,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Tooltip(
                message: 'Resolve',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: widget.onResolve,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Color(0xff16a34a),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(comment.body),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final reply in comment.replies)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.subdirectory_arrow_right,
                        size: 14, color: Color(0xff9ca3af)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xff374151)),
                          children: [
                            TextSpan(
                              text: '${reply.author}: ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: reply.body),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          if (_showReplyField) ...[
            TextField(
              controller: _replyController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Reply…',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, size: 16),
                  onPressed: () {
                    final text = _replyController.text.trim();
                    if (text.isEmpty) return;
                    widget.onReply(text);
                    _replyController.clear();
                    setState(() => _showReplyField = false);
                  },
                ),
              ),
              onSubmitted: (text) {
                if (text.isEmpty) return;
                widget.onReply(text);
                _replyController.clear();
                setState(() => _showReplyField = false);
              },
            ),
          ] else
            GestureDetector(
              onTap: () => setState(() => _showReplyField = true),
              child: const Text(
                'Reply',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xff2563eb),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SuggestionTile extends StatelessWidget {
  const SuggestionTile({
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

class ExportTile extends StatelessWidget {
  const ExportTile({
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

class TemplateTile extends StatelessWidget {
  const TemplateTile({
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
