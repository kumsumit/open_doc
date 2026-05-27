import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/document_models.dart';

/// Character-level inline formatting attributes.
enum RunAttr { bold, italic, underline, strike }

/// Immutable formatting flags carried by a single character.
@immutable
class CharFormat {
  const CharFormat({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.href,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final String? href;

  CharFormat copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strike,
    String? href,
  }) {
    return CharFormat(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strike: strike ?? this.strike,
      href: href ?? this.href,
    );
  }

  bool get(RunAttr attr) => switch (attr) {
    RunAttr.bold => bold,
    RunAttr.italic => italic,
    RunAttr.underline => underline,
    RunAttr.strike => strike,
  };

  CharFormat set(RunAttr attr, bool value) => switch (attr) {
    RunAttr.bold => copyWith(bold: value),
    RunAttr.italic => copyWith(italic: value),
    RunAttr.underline => copyWith(underline: value),
    RunAttr.strike => copyWith(strike: value),
  };

  bool sameAs(CharFormat other) =>
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline &&
      strike == other.strike &&
      href == other.href;
}

/// A [TextEditingController] that keeps a parallel per-character formatting map
/// so a single editable field can render and edit mixed inline styles (bold,
/// italic, underline, strikethrough) the way Microsoft Word does within one
/// paragraph.
class RichRunController extends TextEditingController {
  RichRunController({required List<OpenXmlRun> runs})
    : super(text: runs.map((run) => run.text).join()) {
    _formats = _expand(runs);
  }

  late List<CharFormat> _formats;

  static List<CharFormat> _expand(List<OpenXmlRun> runs) {
    final out = <CharFormat>[];
    for (final run in runs) {
      final format = CharFormat(
        bold: run.bold,
        italic: run.italic,
        underline: run.underline,
        strike: run.strike,
        href: run.href,
      );
      for (var i = 0; i < run.text.length; i += 1) {
        out.add(format);
      }
    }
    return out;
  }

  /// Coalesces the per-character map back into OpenXML runs for the model.
  List<OpenXmlRun> get runs {
    if (text.isEmpty) {
      return const [OpenXmlRun('')];
    }
    final out = <OpenXmlRun>[];
    final buffer = StringBuffer();
    var current = _formats.isNotEmpty ? _formats[0] : const CharFormat();
    for (var i = 0; i < text.length; i += 1) {
      final format = i < _formats.length ? _formats[i] : const CharFormat();
      if (i > 0 && !format.sameAs(current)) {
        out.add(_runFrom(buffer.toString(), current));
        buffer.clear();
        current = format;
      }
      buffer.write(text[i]);
    }
    out.add(_runFrom(buffer.toString(), current));
    return out;
  }

  OpenXmlRun _runFrom(String text, CharFormat format) => OpenXmlRun(
    text,
    bold: format.bold,
    italic: format.italic,
    underline: format.underline,
    strike: format.strike,
    href: format.href,
  );

  /// Replaces the formatting map (e.g. when the backing block is swapped for
  /// an unrelated document) without disturbing the text the field already has.
  void resetRuns(List<OpenXmlRun> runs) {
    _formats = _expand(runs);
    notifyListeners();
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    if (oldText != newValue.text) {
      _formats = _splice(oldText, newValue.text, _formats);
    }
    super.value = newValue;
  }

  /// Re-maps the formatting array across a plain-text edit by diffing the
  /// common prefix/suffix; inserted characters inherit the style to their left.
  static List<CharFormat> _splice(
    String oldText,
    String newText,
    List<CharFormat> formats,
  ) {
    final maxScan = math.min(oldText.length, newText.length);
    var prefix = 0;
    while (prefix < maxScan && oldText[prefix] == newText[prefix]) {
      prefix += 1;
    }
    var suffix = 0;
    while (suffix < maxScan - prefix &&
        oldText[oldText.length - 1 - suffix] ==
            newText[newText.length - 1 - suffix]) {
      suffix += 1;
    }
    final insertCount = newText.length - prefix - suffix;
    final inherit = prefix > 0 && prefix - 1 < formats.length
        ? formats[prefix - 1]
        : (prefix < formats.length ? formats[prefix] : const CharFormat());
    return [
      ...formats.sublist(0, math.min(prefix, formats.length)),
      for (var i = 0; i < insertCount; i += 1) inherit,
      ...formats.sublist(math.min(oldText.length - suffix, formats.length)),
    ];
  }

  /// True when every character in [start, end) carries [attr].
  bool isActive(int start, int end, RunAttr attr) {
    final lo = start.clamp(0, _formats.length);
    final hi = end.clamp(0, _formats.length);
    if (lo >= hi) {
      return false;
    }
    for (var i = lo; i < hi; i += 1) {
      if (!_formats[i].get(attr)) {
        return false;
      }
    }
    return true;
  }

  /// True when any character in [start, end) carries [attr].
  bool anyActive(int start, int end, RunAttr attr) {
    final lo = start.clamp(0, _formats.length);
    final hi = end.clamp(0, _formats.length);
    for (var i = lo; i < hi; i += 1) {
      if (_formats[i].get(attr)) {
        return true;
      }
    }
    return false;
  }

  void setAttr(int start, int end, RunAttr attr, bool value) {
    final lo = start.clamp(0, _formats.length);
    final hi = end.clamp(0, _formats.length);
    if (lo >= hi) {
      return;
    }
    for (var i = lo; i < hi; i += 1) {
      _formats[i] = _formats[i].set(attr, value);
    }
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    if (text.isEmpty) {
      return TextSpan(text: '', style: base);
    }
    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    var current = _formats.isNotEmpty ? _formats[0] : const CharFormat();

    void flush() {
      if (buffer.isNotEmpty) {
        spans.add(
          TextSpan(text: buffer.toString(), style: _styleFor(base, current)),
        );
        buffer.clear();
      }
    }

    for (var i = 0; i < text.length; i += 1) {
      final format = i < _formats.length ? _formats[i] : const CharFormat();
      if (i > 0 && !format.sameAs(current)) {
        flush();
        current = format;
      }
      buffer.write(text[i]);
    }
    flush();
    return TextSpan(style: base, children: spans);
  }

  TextStyle _styleFor(TextStyle base, CharFormat format) {
    final decorations = <TextDecoration>[
      if (format.underline) TextDecoration.underline,
      if (format.strike) TextDecoration.lineThrough,
    ];
    return base.copyWith(
      fontWeight: format.bold ? FontWeight.w700 : base.fontWeight,
      fontStyle: format.italic ? FontStyle.italic : base.fontStyle,
      decoration: decorations.isEmpty
          ? base.decoration
          : TextDecoration.combine(decorations),
      color: format.href != null ? const Color(0xff2563eb) : base.color,
    );
  }
}

/// Microsoft Word style floating mini-toolbar that appears next to the active
/// paragraph. Wrapped so its buttons never steal focus from the editor, which
/// keeps the current text selection alive while a command is applied.
class FloatingFormatToolbar extends StatelessWidget {
  const FloatingFormatToolbar({
    super.key,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strikethrough,
    required this.style,
    required this.alignment,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onStrikethrough,
    required this.onStyle,
    required this.onAlignment,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final String style;
  final String alignment;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onStrikethrough;
  final ValueChanged<String> onStyle;
  final ValueChanged<String> onAlignment;

  static const _styles = <String>[
    'Normal',
    'Title',
    'Subtitle',
    'Heading 1',
    'Heading 2',
    'Heading 3',
    'Quote',
    'Code',
    'Caption',
  ];

  @override
  Widget build(BuildContext context) {
    // The toolbar lives in an Overlay, outside the editor's TapRegion. Sharing
    // the EditableText group id keeps taps on it from counting as "tap outside"
    // (which would unfocus the field and drop the selection), and
    // descendantsAreFocusable:false stops the buttons from pulling keyboard
    // focus off the TextField — so the selection survives every command.
    return TapRegion(
      groupId: EditableText,
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffd6dee9)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ToolButton(
                  icon: Icons.format_bold,
                  tooltip: 'Bold',
                  active: bold,
                  onTap: onBold,
                ),
                _ToolButton(
                  icon: Icons.format_italic,
                  tooltip: 'Italic',
                  active: italic,
                  onTap: onItalic,
                ),
                _ToolButton(
                  icon: Icons.format_underlined,
                  tooltip: 'Underline',
                  active: underline,
                  onTap: onUnderline,
                ),
                _ToolButton(
                  icon: Icons.strikethrough_s,
                  tooltip: 'Strikethrough',
                  active: strikethrough,
                  onTap: onStrikethrough,
                ),
                const _Divider(),
                _StylePicker(value: style, onChanged: onStyle),
                const _Divider(),
                _ToolButton(
                  icon: Icons.format_align_left,
                  tooltip: 'Align left',
                  active: alignment == 'Left',
                  onTap: () => onAlignment('Left'),
                ),
                _ToolButton(
                  icon: Icons.format_align_center,
                  tooltip: 'Center',
                  active: alignment == 'Center',
                  onTap: () => onAlignment('Center'),
                ),
                _ToolButton(
                  icon: Icons.format_align_right,
                  tooltip: 'Align right',
                  active: alignment == 'Right',
                  onTap: () => onAlignment('Right'),
                ),
                _ToolButton(
                  icon: Icons.format_align_justify,
                  tooltip: 'Justify',
                  active: alignment == 'Justify',
                  onTap: () => onAlignment('Justify'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // No Tooltip here on purpose: Tooltip uses an OverlayPortal that reads its
    // paint transform during layout, which a CompositedTransformFollower (our
    // anchor) cannot provide until after layout. Semantics keeps a11y labels.
    return Semantics(
      label: tooltip,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: active ? const Color(0xffdbeafe) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? const Color(0xff1d4ed8) : const Color(0xff334155),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: const Color(0xffe2e8f0),
    );
  }
}

class _StylePicker extends StatelessWidget {
  const _StylePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  // Uses showMenu on tap (after layout) rather than PopupMenuButton, whose
  // built-in Tooltip would read the paint transform during layout and clash
  // with the CompositedTransformFollower anchoring the toolbar.
  Future<void> _openMenu(BuildContext context) async {
    final button = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;
    final topLeft = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );
    final bottomRight = button.localToGlobal(
      button.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    );
    final selected = await showMenu<String>(
      context: context,
      position: position,
      items: [
        for (final style in FloatingFormatToolbar._styles)
          PopupMenuItem(value: style, child: Text(style)),
      ],
    );
    if (selected != null) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _openMenu(context),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff334155),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Color(0xff64748b),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
