// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../document/document_models.dart';
import 'common_controls.dart';

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class NavigationRailPanel extends StatelessWidget {
  const NavigationRailPanel({
    super.key,
    required this.headings,
    required this.searchController,
    required this.replaceController,
    required this.searchMatches,
    required this.currentMatchIndex,
    required this.onFindNext,
    required this.onFindPrev,
    required this.onReplaceOne,
    required this.onReplaceAll,
    required this.onClose,
  });

  final List<String> headings;
  final TextEditingController searchController;
  final TextEditingController replaceController;
  final int searchMatches;
  final int currentMatchIndex;
  final VoidCallback onFindNext;
  final VoidCallback onFindPrev;
  final VoidCallback onReplaceOne;
  final VoidCallback onReplaceAll;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final hasQuery = searchController.text.trim().isNotEmpty;
    final matchLabel = !hasQuery
        ? ''
        : searchMatches == 0
        ? 'No matches'
        : '${currentMatchIndex < 0 ? 1 : currentMatchIndex + 1}/$searchMatches';

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelHeader(
            title: 'Navigation',
            icon: Icons.subject_outlined,
            onClose: onClose,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_outlined, size: 18),
                suffix: hasQuery
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            matchLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff6b7280),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: onFindPrev,
                            child: const Icon(
                              Icons.keyboard_arrow_up,
                              size: 18,
                            ),
                          ),
                          InkWell(
                            onTap: onFindNext,
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                            ),
                          ),
                        ],
                      )
                    : null,
                hintText: 'Find in document',
                isDense: true,
                filled: true,
                fillColor: const Color(0xfff6f8fb),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: replaceController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.find_replace_outlined,
                        size: 18,
                      ),
                      hintText: 'Replace with',
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xfff6f8fb),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: 'Replace',
                  child: IconButton(
                    onPressed: hasQuery ? onReplaceOne : null,
                    icon: const Icon(
                      Icons.published_with_changes_outlined,
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Tooltip(
                  message: 'Replace all',
                  child: IconButton(
                    onPressed: hasQuery ? onReplaceAll : null,
                    icon: const Icon(Icons.sync_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Text(
              'Outline',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              children: [
                for (final heading in headings)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.notes_outlined, size: 20),
                    title: Text(
                      heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                if (headings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Headings appear here as you write.'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    super.key,
    required this.wordCount,
    required this.characterCount,
    required this.readingMinutes,
    required this.commentsMode,
    required this.trackChanges,
    required this.permission,
    required this.template,
    required this.savedAt,
    required this.activeVersion,
    required this.collaborators,
    required this.versions,
    required this.mediaCount,
    required this.imageCount,
    required this.videoCount,
    required this.audienceProfile,
    required this.toneMode,
    required this.clarityScore,
    required this.attentionScore,
    required this.averageSentenceLength,
    required this.sourceCount,
    required this.citationNudgeCount,
    required this.actionItems,
    required this.onSave,
    required this.onShare,
    required this.onHistory,
    required this.onSmartBrief,
    required this.onActionDigest,
    required this.onCommentsToggle,
    required this.onTrackChangesToggle,
    required this.onPermissionChange,
    required this.onAudienceProfileChange,
    required this.onToneModeChange,
    required this.onClose,
  });

  final int wordCount;
  final int characterCount;
  final int readingMinutes;
  final bool commentsMode;
  final bool trackChanges;
  final String permission;
  final String template;
  final DateTime savedAt;
  final String activeVersion;
  final List<Collaborator> collaborators;
  final List<DocumentVersion> versions;
  final int mediaCount;
  final int imageCount;
  final int videoCount;
  final String audienceProfile;
  final String toneMode;
  final int clarityScore;
  final int attentionScore;
  final int averageSentenceLength;
  final int sourceCount;
  final int citationNudgeCount;
  final List<String> actionItems;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onHistory;
  final VoidCallback onSmartBrief;
  final VoidCallback onActionDigest;
  final VoidCallback onCommentsToggle;
  final VoidCallback onTrackChangesToggle;
  final ValueChanged<String> onPermissionChange;
  final ValueChanged<String> onAudienceProfileChange;
  final ValueChanged<String> onToneModeChange;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: ListView(
        children: [
          PanelHeader(
            title: 'Inspector',
            icon: Icons.fact_check_outlined,
            onClose: onClose,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(label: 'Words', value: '$wordCount'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(
                        label: 'Read',
                        value: '${readingMinutes}m',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                MetricCard(label: 'Characters', value: '$characterCount'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(label: 'Images', value: '$imageCount'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(label: 'Videos', value: '$videoCount'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Clarity',
                        value: '$clarityScore',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricCard(
                        label: 'Attention',
                        value: '$attentionScore',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          InspectorSelectTile(
            icon: Icons.psychology_alt_outlined,
            title: 'Audience',
            value: audienceProfile,
            options: const ['Millennial', 'Gen Z', 'Alpha', 'Beta'],
            color: const Color(0xff7c3aed),
            onChanged: onAudienceProfileChange,
          ),
          InspectorSelectTile(
            icon: Icons.record_voice_over_outlined,
            title: 'Tone',
            value: toneMode,
            options: const ['Clear', 'Warm', 'Bold', 'Brief'],
            color: const Color(0xff7c3aed),
            onChanged: onToneModeChange,
          ),
          StatusTile(
            icon: Icons.speed_outlined,
            title: 'Scanability',
            value: '$averageSentenceLength words per sentence',
            color: averageSentenceLength <= 18
                ? const Color(0xff047857)
                : const Color(0xffb45309),
          ),
          StatusTile(
            icon: Icons.verified_outlined,
            title: 'Trust layer',
            value: citationNudgeCount == 0
                ? '$sourceCount source signal${sourceCount == 1 ? '' : 's'} found'
                : '$citationNudgeCount claim${citationNudgeCount == 1 ? '' : 's'} may need a source',
            color: citationNudgeCount == 0
                ? const Color(0xff047857)
                : const Color(0xffbe123c),
          ),
          StatusTile(
            icon: Icons.perm_media_outlined,
            title: 'Media',
            value:
                '$mediaCount embedded block${mediaCount == 1 ? '' : 's'} in document',
            color: const Color(0xffbe123c),
          ),
          InspectorToggleTile(
            icon: Icons.rate_review_outlined,
            title: 'Comments',
            subtitle: commentsMode ? 'Open for review' : 'Hidden',
            value: commentsMode,
            activeColor: const Color(0xff047857),
            onToggle: onCommentsToggle,
          ),
          InspectorToggleTile(
            icon: Icons.change_circle_outlined,
            title: 'Track changes',
            subtitle: trackChanges ? 'Recording edits' : 'Paused',
            value: trackChanges,
            activeColor: const Color(0xff1d4ed8),
            onToggle: onTrackChangesToggle,
          ),
          InspectorSelectTile(
            icon: Icons.lock_open_outlined,
            title: 'Permission',
            value: permission,
            options: const ['Can view', 'Can comment', 'Can edit'],
            color: const Color(0xff7c3aed),
            onChanged: onPermissionChange,
          ),
          StatusTile(
            icon: Icons.dashboard_customize_outlined,
            title: 'Template',
            value: template,
            color: const Color(0xff0f766e),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSmartBrief,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Brief'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onActionDigest,
                    icon: const Icon(Icons.task_alt_outlined),
                    label: const Text('Actions'),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'Next actions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (actionItems.isEmpty)
            const SuggestionTile(
              icon: Icons.task_alt_outlined,
              title: 'No open actions',
              body: 'Add [ ] tasks or owner lines to build a digest.',
            )
          else
            for (final item in actionItems)
              SuggestionTile(
                icon: Icons.task_alt_outlined,
                title: 'Action',
                body: item,
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Collaborators',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: onShare, child: const Text('Manage')),
              ],
            ),
          ),
          for (final collaborator in collaborators)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 15,
                backgroundColor: collaborator.color,
                child: Text(
                  collaborator.name.substring(0, 1),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text(collaborator.name),
              subtitle: Text(collaborator.status),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Version history',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(onPressed: onHistory, child: const Text('Open')),
              ],
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.history_outlined),
            title: Text('$activeVersion saved ${_formatTime(savedAt)}'),
            subtitle: Text('${versions.length} saved versions'),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'Comments',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const CommentCard(
            author: 'Asha',
            body: 'Strengthen the objective with one measurable outcome.',
          ),
          const CommentCard(
            author: 'Legal',
            body: 'Check whether this proposal needs a confidentiality note.',
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Text(
              'Suggestions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SuggestionTile(
            icon: Icons.spellcheck_outlined,
            title: 'Tone',
            body: 'The document reads clear and professional.',
          ),
          const SuggestionTile(
            icon: Icons.format_line_spacing_outlined,
            title: 'Layout',
            body: 'Margins and line height are ready for print.',
          ),
        ],
      ),
    );
  }
}
