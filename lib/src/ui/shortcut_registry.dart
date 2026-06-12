import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import 'editor_intents.dart';

enum ShortcutCategory {
  formatting,
  paragraphStyle,
  document,
  view;

  String get label => switch (this) {
        ShortcutCategory.formatting => 'Formatting',
        ShortcutCategory.paragraphStyle => 'Paragraph Style',
        ShortcutCategory.document => 'Document',
        ShortcutCategory.view => 'View',
      };
}

class ShortcutDef {
  const ShortcutDef({
    required this.id,
    required this.label,
    required this.category,
    required this.key,
    this.shift = false,
    this.alt = false,
    required this.makeIntent,
  });

  final String id;
  final String label;
  final ShortcutCategory category;
  final LogicalKeyboardKey key;
  final bool shift;
  final bool alt;
  final Intent Function() makeIntent;
}

class ShortcutRegistry extends ChangeNotifier {
  ShortcutRegistry._() {
    _load();
  }

  static final ShortcutRegistry instance = ShortcutRegistry._();

  final Map<String, SingleActivator> _overrides = {};

  // ignore: prefer_const_constructors_in_immutables
  static final List<ShortcutDef> definitions = [
    // ── Formatting ─────────────────────────────────────────────────────────
    ShortcutDef(
      id: 'bold',
      label: 'Bold',
      category: ShortcutCategory.formatting,
      key: LogicalKeyboardKey.keyB,
      makeIntent: ToggleBoldIntent.new,
    ),
    ShortcutDef(
      id: 'italic',
      label: 'Italic',
      category: ShortcutCategory.formatting,
      key: LogicalKeyboardKey.keyI,
      makeIntent: ToggleItalicIntent.new,
    ),
    ShortcutDef(
      id: 'underline',
      label: 'Underline',
      category: ShortcutCategory.formatting,
      key: LogicalKeyboardKey.keyU,
      makeIntent: ToggleUnderlineIntent.new,
    ),
    ShortcutDef(
      id: 'strikethrough',
      label: 'Strikethrough',
      category: ShortcutCategory.formatting,
      key: LogicalKeyboardKey.keyS,
      shift: true,
      makeIntent: ToggleStrikethroughIntent.new,
    ),
    ShortcutDef(
      id: 'clear_format',
      label: 'Clear Formatting',
      category: ShortcutCategory.formatting,
      key: LogicalKeyboardKey.backslash,
      makeIntent: ClearFormattingIntent.new,
    ),
    // ── Paragraph Style ─────────────────────────────────────────────────────
    ShortcutDef(
      id: 'style_normal',
      label: 'Normal text',
      category: ShortcutCategory.paragraphStyle,
      key: LogicalKeyboardKey.digit0,
      alt: true,
      makeIntent: ApplyNormalStyleIntent.new,
    ),
    ShortcutDef(
      id: 'style_h1',
      label: 'Heading 1',
      category: ShortcutCategory.paragraphStyle,
      key: LogicalKeyboardKey.digit1,
      alt: true,
      makeIntent: ApplyHeading1Intent.new,
    ),
    ShortcutDef(
      id: 'style_h2',
      label: 'Heading 2',
      category: ShortcutCategory.paragraphStyle,
      key: LogicalKeyboardKey.digit2,
      alt: true,
      makeIntent: ApplyHeading2Intent.new,
    ),
    ShortcutDef(
      id: 'style_h3',
      label: 'Heading 3',
      category: ShortcutCategory.paragraphStyle,
      key: LogicalKeyboardKey.digit3,
      alt: true,
      makeIntent: ApplyHeading3Intent.new,
    ),
    ShortcutDef(
      id: 'style_h4',
      label: 'Heading 4',
      category: ShortcutCategory.paragraphStyle,
      key: LogicalKeyboardKey.digit4,
      alt: true,
      makeIntent: ApplyHeading4Intent.new,
    ),
    ShortcutDef(
      id: 'style_h5',
      label: 'Heading 5',
      category: ShortcutCategory.paragraphStyle,
      key: LogicalKeyboardKey.digit5,
      alt: true,
      makeIntent: ApplyHeading5Intent.new,
    ),
    // ── Document ────────────────────────────────────────────────────────────
    ShortcutDef(
      id: 'undo',
      label: 'Undo',
      category: ShortcutCategory.document,
      key: LogicalKeyboardKey.keyZ,
      makeIntent: UndoIntent.new,
    ),
    ShortcutDef(
      id: 'redo',
      label: 'Redo',
      category: ShortcutCategory.document,
      key: LogicalKeyboardKey.keyZ,
      shift: true,
      makeIntent: RedoIntent.new,
    ),
    ShortcutDef(
      id: 'redo_alt',
      label: 'Redo (Alt)',
      category: ShortcutCategory.document,
      key: LogicalKeyboardKey.keyY,
      makeIntent: RedoIntent.new,
    ),
    ShortcutDef(
      id: 'save',
      label: 'Save Document',
      category: ShortcutCategory.document,
      key: LogicalKeyboardKey.keyS,
      makeIntent: SaveDocumentIntent.new,
    ),
    ShortcutDef(
      id: 'new_doc',
      label: 'New Document',
      category: ShortcutCategory.document,
      key: LogicalKeyboardKey.keyN,
      makeIntent: NewDocumentIntent.new,
    ),
    ShortcutDef(
      id: 'open',
      label: 'Open / Import',
      category: ShortcutCategory.document,
      key: LogicalKeyboardKey.keyO,
      makeIntent: OpenFileIntent.new,
    ),
    ShortcutDef(
      id: 'find',
      label: 'Find',
      category: ShortcutCategory.document,
      key: LogicalKeyboardKey.keyF,
      makeIntent: FindTextIntent.new,
    ),
    ShortcutDef(
      id: 'find_replace',
      label: 'Find & Replace',
      category: ShortcutCategory.document,
      key: LogicalKeyboardKey.keyH,
      makeIntent: FindReplaceIntent.new,
    ),
    // ── View ────────────────────────────────────────────────────────────────
    ShortcutDef(
      id: 'focus_mode',
      label: 'Toggle Focus Mode',
      category: ShortcutCategory.view,
      key: LogicalKeyboardKey.keyF,
      shift: true,
      makeIntent: ToggleFocusModeIntent.new,
    ),
    ShortcutDef(
      id: 'nav_panel',
      label: 'Toggle Navigation Panel',
      category: ShortcutCategory.view,
      key: LogicalKeyboardKey.keyN,
      shift: true,
      makeIntent: ToggleNavigationPanelIntent.new,
    ),
    ShortcutDef(
      id: 'inspector',
      label: 'Toggle Inspector Panel',
      category: ShortcutCategory.view,
      key: LogicalKeyboardKey.keyI,
      shift: true,
      makeIntent: ToggleInspectorPanelIntent.new,
    ),
    ShortcutDef(
      id: 'shortcuts_dialog',
      label: 'Keyboard Shortcuts',
      category: ShortcutCategory.view,
      key: LogicalKeyboardKey.slash,
      shift: true,
      makeIntent: ShowKeyboardShortcutsIntent.new,
    ),
  ];

  /// Effective activators for a definition (user override, or ctrl+meta pair).
  List<SingleActivator> activatorsFor(ShortcutDef def) {
    if (_overrides.containsKey(def.id)) return [_overrides[def.id]!];
    return [
      SingleActivator(def.key, control: true, shift: def.shift, alt: def.alt),
      SingleActivator(def.key, meta: true, shift: def.shift, alt: def.alt),
    ];
  }

  /// The default activator (Ctrl variant) for display purposes.
  SingleActivator defaultActivator(ShortcutDef def) =>
      SingleActivator(def.key, control: true, shift: def.shift, alt: def.alt);

  SingleActivator? overrideFor(String id) => _overrides[id];

  void setOverride(String id, SingleActivator activator) {
    _overrides[id] = activator;
    notifyListeners();
    _save();
  }

  void clearOverride(String id) {
    _overrides.remove(id);
    notifyListeners();
    _save();
  }

  void clearAll() {
    _overrides.clear();
    notifyListeners();
    _save();
  }

  Map<ShortcutActivator, Intent> buildShortcutMap() {
    final map = <ShortcutActivator, Intent>{};
    for (final def in definitions) {
      final intent = def.makeIntent();
      for (final activator in activatorsFor(def)) {
        map[activator] = intent;
      }
    }
    return map;
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<File?> _file() async {
    try {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      final dir = Directory(p.join(home, '.config', 'open_doc'));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return File(p.join(dir.path, 'shortcuts.json'));
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final file = await _file();
    if (file == null) return;
    try {
      final data = {
        for (final e in _overrides.entries) e.key: _encode(e.value),
      };
      file.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _load() async {
    final file = await _file();
    if (file == null || !file.existsSync()) return;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final e in json.entries) {
        final a = _decode(e.value as Map<String, dynamic>);
        if (a != null) _overrides[e.key] = a;
      }
      notifyListeners();
    } catch (_) {}
  }

  Map<String, dynamic> _encode(SingleActivator a) => {
        'keyId': a.trigger.keyId,
        'control': a.control,
        'meta': a.meta,
        'shift': a.shift,
        'alt': a.alt,
      };

  SingleActivator? _decode(Map<String, dynamic> m) {
    try {
      return SingleActivator(
        LogicalKeyboardKey(m['keyId'] as int),
        control: m['control'] as bool? ?? false,
        meta: m['meta'] as bool? ?? false,
        shift: m['shift'] as bool? ?? false,
        alt: m['alt'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Human-readable label for a [SingleActivator].
String formatActivator(SingleActivator a) {
  final isMac = Platform.isMacOS;
  final parts = <String>[];
  if (isMac) {
    if (a.control) parts.add('⌃');
    if (a.alt) parts.add('⌥');
    if (a.shift) parts.add('⇧');
    if (a.meta) parts.add('⌘');
    parts.add(_keyLabel(a.trigger));
    return parts.join('');
  } else {
    if (a.control) parts.add('Ctrl');
    if (a.alt) parts.add('Alt');
    if (a.shift) parts.add('Shift');
    if (a.meta) parts.add('Win');
    parts.add(_keyLabel(a.trigger));
    return parts.join('+');
  }
}

String _keyLabel(LogicalKeyboardKey key) {
  if (key == LogicalKeyboardKey.backspace) return '⌫';
  if (key == LogicalKeyboardKey.delete) return 'Del';
  if (key == LogicalKeyboardKey.escape) return 'Esc';
  if (key == LogicalKeyboardKey.enter) return 'Enter';
  if (key == LogicalKeyboardKey.tab) return 'Tab';
  if (key == LogicalKeyboardKey.space) return 'Space';
  if (key == LogicalKeyboardKey.arrowLeft) return '←';
  if (key == LogicalKeyboardKey.arrowRight) return '→';
  if (key == LogicalKeyboardKey.arrowUp) return '↑';
  if (key == LogicalKeyboardKey.arrowDown) return '↓';
  if (key == LogicalKeyboardKey.home) return 'Home';
  if (key == LogicalKeyboardKey.end) return 'End';
  if (key == LogicalKeyboardKey.pageUp) return 'PgUp';
  if (key == LogicalKeyboardKey.pageDown) return 'PgDn';
  if (key == LogicalKeyboardKey.slash) return '/';
  if (key == LogicalKeyboardKey.backslash) return '\\';
  final label = key.keyLabel;
  if (label.length == 1) return label.toUpperCase();
  return label.isEmpty ? '?' : label;
}
