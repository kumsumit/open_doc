part of '../../main.dart';

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return Row(
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
              Flexible(
                flex: compact ? 2 : 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: compact ? 128 : 240,
                    minWidth: compact ? 88 : 180,
                  ),
                  child: TextField(
                    controller: titleController,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: saved
                        ? const Color(0xffecfdf5)
                        : const Color(0xfffffbeb),
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
              ],
              const SizedBox(width: 8),
              Expanded(
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
                      if (compact) ...[
                        _IconAction(
                          icon: Icons.upload_file_outlined,
                          label: 'Import',
                          onTap: onImport,
                        ),
                        _IconAction(
                          icon: Icons.ios_share_outlined,
                          label: 'Export',
                          onTap: onExport,
                        ),
                      ] else ...[
                        _TopBarCommand(
                          icon: Icons.upload_file_outlined,
                          label: 'Import',
                          onTap: onImport,
                        ),
                        const SizedBox(width: 8),
                        _TopBarCommand(
                          icon: Icons.ios_share_outlined,
                          label: 'Export',
                          onTap: onExport,
                          filled: true,
                        ),
                      ],
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
          );
        },
      ),
    );
  }
}
