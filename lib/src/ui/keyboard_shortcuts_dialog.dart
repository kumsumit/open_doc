import 'dart:io';

import 'package:flutter/material.dart' hide ShortcutRegistry;
import 'package:flutter/services.dart';

import 'shortcut_registry.dart';

/// Shows a modal dialog listing all keyboard shortcuts, grouped by category.
/// Users can click any row to rebind that shortcut.
Future<void> showKeyboardShortcutsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _KeyboardShortcutsDialog(),
  );
}

class _KeyboardShortcutsDialog extends StatefulWidget {
  const _KeyboardShortcutsDialog();

  @override
  State<_KeyboardShortcutsDialog> createState() =>
      _KeyboardShortcutsDialogState();
}

class _KeyboardShortcutsDialogState extends State<_KeyboardShortcutsDialog> {
  String? _recordingId;
  SingleActivator? _pendingActivator;

  @override
  Widget build(BuildContext context) {
    final registry = ShortcutRegistry.instance;
    final groups = <ShortcutCategory, List<ShortcutDef>>{};
    for (final def in ShortcutRegistry.definitions) {
      groups.putIfAbsent(def.category, () => []).add(def);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.keyboard_outlined, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Keyboard Shortcuts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        registry.clearAll();
                        _recordingId = null;
                        _pendingActivator = null;
                      });
                    },
                    child: const Text('Reset all'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Shortcut list ────────────────────────────────────────────────
            Flexible(
              child: ListenableBuilder(
                listenable: registry,
                builder: (context2, snapshot) => ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    for (final entry in groups.entries) ...[
                      _CategoryHeader(entry.key.label),
                      for (final def in entry.value)
                        _ShortcutRow(
                          def: def,
                          registry: registry,
                          isRecording: _recordingId == def.id,
                          pendingActivator: _recordingId == def.id
                              ? _pendingActivator
                              : null,
                          onStartRecord: () => setState(() {
                            _recordingId = def.id;
                            _pendingActivator = null;
                          }),
                          onConfirm: (activator) {
                            registry.setOverride(def.id, activator);
                            setState(() {
                              _recordingId = null;
                              _pendingActivator = null;
                            });
                          },
                          onCancel: () => setState(() {
                            _recordingId = null;
                            _pendingActivator = null;
                          }),
                          onKey: (activator) => setState(
                            () => _pendingActivator = activator,
                          ),
                          onReset: registry.overrideFor(def.id) != null
                              ? () {
                                  registry.clearOverride(def.id);
                                  setState(() {});
                                }
                              : null,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                Platform.isMacOS
                    ? '⌘ Cmd  ⌃ Ctrl  ⌥ Alt  ⇧ Shift'
                    : 'Ctrl / Alt / Shift modifiers supported',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xff6b7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category header ──────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xff6b7280),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Single shortcut row ───────────────────────────────────────────────────────

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.def,
    required this.registry,
    required this.isRecording,
    required this.pendingActivator,
    required this.onStartRecord,
    required this.onConfirm,
    required this.onCancel,
    required this.onKey,
    required this.onReset,
  });

  final ShortcutDef def;
  final ShortcutRegistry registry;
  final bool isRecording;
  final SingleActivator? pendingActivator;
  final VoidCallback onStartRecord;
  final ValueChanged<SingleActivator> onConfirm;
  final VoidCallback onCancel;
  final ValueChanged<SingleActivator> onKey;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final override = registry.overrideFor(def.id);
    final display = override ?? registry.defaultActivator(def);
    final isCustom = override != null;

    return ListTile(
      dense: true,
      title: Text(def.label, style: const TextStyle(fontSize: 13)),
      trailing: isRecording
          ? _RecorderWidget(
              pending: pendingActivator,
              onKey: onKey,
              onConfirm: onConfirm,
              onCancel: onCancel,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCustom)
                  Tooltip(
                    message: 'Reset to default',
                    child: IconButton(
                      icon: const Icon(
                        Icons.refresh,
                        size: 14,
                        color: Color(0xff9ca3af),
                      ),
                      onPressed: onReset,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                GestureDetector(
                  onTap: onStartRecord,
                  child: _ShortcutBadge(
                    label: formatActivator(display),
                    isCustom: isCustom,
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Shortcut badge ────────────────────────────────────────────────────────────

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({required this.label, required this.isCustom});
  final String label;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCustom
            ? const Color(0xffeff6ff)
            : const Color(0xfff3f4f6),
        border: Border.all(
          color: isCustom
              ? const Color(0xff93c5fd)
              : const Color(0xffd1d5db),
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: isCustom
              ? const Color(0xff1d4ed8)
              : const Color(0xff374151),
        ),
      ),
    );
  }
}

// ── Key recorder widget ───────────────────────────────────────────────────────

class _RecorderWidget extends StatelessWidget {
  const _RecorderWidget({
    required this.pending,
    required this.onKey,
    required this.onConfirm,
    required this.onCancel,
  });

  final SingleActivator? pending;
  final ValueChanged<SingleActivator> onKey;
  final ValueChanged<SingleActivator> onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyCapture(onKey: onKey, pending: pending),
        const SizedBox(width: 4),
        if (pending != null)
          IconButton(
            icon: const Icon(Icons.check, size: 16, color: Color(0xff16a34a)),
            onPressed: () => onConfirm(pending!),
            visualDensity: VisualDensity.compact,
            tooltip: 'Save',
          ),
        IconButton(
          icon: const Icon(Icons.close, size: 16, color: Color(0xff6b7280)),
          onPressed: onCancel,
          visualDensity: VisualDensity.compact,
          tooltip: 'Cancel',
        ),
      ],
    );
  }
}

class _KeyCapture extends StatefulWidget {
  const _KeyCapture({required this.onKey, required this.pending});
  final ValueChanged<SingleActivator> onKey;
  final SingleActivator? pending;

  @override
  State<_KeyCapture> createState() => _KeyCaptureState();
}

class _KeyCaptureState extends State<_KeyCapture> {
  final FocusNode _focus = FocusNode();

  static final _modifierKeys = {
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_modifierKeys.contains(key)) return KeyEventResult.handled;

    final hw = HardwareKeyboard.instance;
    final ctrl = hw.isControlPressed;
    final meta = hw.isMetaPressed;
    final shift = hw.isShiftPressed;
    final alt = hw.isAltPressed;

    if (!ctrl && !meta && !alt) return KeyEventResult.handled;

    final activator = SingleActivator(
      key,
      control: ctrl,
      meta: meta,
      shift: shift,
      alt: alt,
    );
    widget.onKey(activator);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.pending != null
        ? formatActivator(widget.pending!)
        : 'Press shortcut…';
    return Focus(
      focusNode: _focus,
      onKeyEvent: _handleKey,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xfffef9c3),
          border: Border.all(color: const Color(0xfffacc15)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: Color(0xff92400e),
          ),
        ),
      ),
    );
  }
}
