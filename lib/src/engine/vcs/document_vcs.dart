import 'dart:convert';

// ============================================================
// VERSION CONTROL SYSTEM (GIT-LIKE)
// ============================================================

/// A snapshot of a document at a point in time.
class DocxSnapshot {
  final String id;
  final String name;
  final String? description;
  final DateTime timestamp;
  final String authorId;
  final String? parentId;
  final String branchName;
  final Map<String, dynamic> content;
  final List<DocxVcsDiff> diff;

  const DocxSnapshot({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.authorId,
    required this.branchName,
    required this.content,
    this.description,
    this.parentId,
    this.diff = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'authorId': authorId,
        'parentId': parentId,
        'branchName': branchName,
        'diff': diff.map((d) => d.toJson()).toList(),
      };
}

/// A diff between two document snapshots.
class DocxVcsDiff {
  final String nodeId;
  final DocxDiffType type;
  final String? before;
  final String? after;
  final Map<String, dynamic>? metadata;

  const DocxVcsDiff({
    required this.nodeId,
    required this.type,
    this.before,
    this.after,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'nodeId': nodeId,
        'type': type.name,
        'before': before,
        'after': after,
      };
}

enum DocxDiffType { insert, delete, modify, move, format }

/// A VCS branch.
class DocxBranch {
  final String name;
  final String? parentBranch;
  final String headSnapshotId;
  final DateTime createdAt;
  final String authorId;
  final bool isDefault;

  const DocxBranch({
    required this.name,
    required this.headSnapshotId,
    required this.createdAt,
    required this.authorId,
    this.parentBranch,
    this.isDefault = false,
  });

  DocxBranch copyWith({String? headSnapshotId}) => DocxBranch(
        name: name,
        headSnapshotId: headSnapshotId ?? this.headSnapshotId,
        createdAt: createdAt,
        authorId: authorId,
        parentBranch: parentBranch,
        isDefault: isDefault,
      );
}

/// The full version history for a document.
///
/// ```dart
/// final vcs = DocxVersionControl(documentId: 'doc-1', authorId: 'user-1');
/// vcs.commit(name: 'Initial draft', content: {'text': '...'});
/// vcs.createBranch('feature/new-section');
/// vcs.checkout('feature/new-section');
/// ```
class DocxVersionControl {
  final String documentId;
  final String authorId;

  final List<DocxSnapshot> _snapshots = [];
  final Map<String, DocxBranch> _branches = {};
  String _currentBranch = 'main';

  DocxVersionControl({required this.documentId, required this.authorId}) {
    _branches['main'] = DocxBranch(
      name: 'main',
      headSnapshotId: '',
      createdAt: DateTime.now(),
      authorId: authorId,
      isDefault: true,
    );
  }

  String get currentBranch => _currentBranch;
  List<DocxSnapshot> get history => List.unmodifiable(_snapshots);
  List<DocxBranch> get branches => _branches.values.toList();

  DocxSnapshot? get head {
    final branchHead = _branches[_currentBranch]?.headSnapshotId;
    if (branchHead == null || branchHead.isEmpty) return null;
    return _snapshots.lastWhere((s) => s.id == branchHead, orElse: () => _snapshots.last);
  }

  /// Commit a snapshot to the current branch.
  DocxSnapshot commit({
    required String name,
    required Map<String, dynamic> content,
    String? description,
    List<DocxVcsDiff> diff = const [],
  }) {
    final snapshot = DocxSnapshot(
      id: '${documentId}_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      timestamp: DateTime.now(),
      authorId: authorId,
      branchName: _currentBranch,
      content: content,
      parentId: head?.id,
      diff: diff,
    );
    _snapshots.add(snapshot);
    _branches[_currentBranch] = _branches[_currentBranch]!.copyWith(
      headSnapshotId: snapshot.id,
    );
    return snapshot;
  }

  /// Create a new branch from the current head.
  DocxBranch createBranch(String name) {
    final branch = DocxBranch(
      name: name,
      headSnapshotId: head?.id ?? '',
      createdAt: DateTime.now(),
      authorId: authorId,
      parentBranch: _currentBranch,
    );
    _branches[name] = branch;
    return branch;
  }

  /// Check out a branch.
  void checkout(String branchName) {
    if (!_branches.containsKey(branchName)) {
      throw StateError('Branch "$branchName" does not exist.');
    }
    _currentBranch = branchName;
  }

  /// Revert to a specific snapshot.
  void revertTo(String snapshotId) {
    final snapshot = _snapshots.firstWhere(
      (s) => s.id == snapshotId,
      orElse: () => throw StateError('Snapshot "$snapshotId" not found.'),
    );
    _branches[_currentBranch] = _branches[_currentBranch]!.copyWith(
      headSnapshotId: snapshot.id,
    );
  }

  /// Compute diff between two snapshots.
  List<DocxVcsDiff> diff(String fromId, String toId) {
    final from = _snapshots.firstWhere((s) => s.id == fromId);
    final to = _snapshots.firstWhere((s) => s.id == toId);
    return _computeDiff(from.content, to.content);
  }

  List<DocxVcsDiff> _computeDiff(
    Map<String, dynamic> from,
    Map<String, dynamic> to,
  ) {
    final diffs = <DocxVcsDiff>[];
    final allKeys = {...from.keys, ...to.keys};
    for (final key in allKeys) {
      if (!from.containsKey(key)) {
        diffs.add(DocxVcsDiff(
          nodeId: key,
          type: DocxDiffType.insert,
          after: jsonEncode(to[key]),
        ));
      } else if (!to.containsKey(key)) {
        diffs.add(DocxVcsDiff(
          nodeId: key,
          type: DocxDiffType.delete,
          before: jsonEncode(from[key]),
        ));
      } else {
        final fromVal = jsonEncode(from[key]);
        final toVal = jsonEncode(to[key]);
        if (fromVal != toVal) {
          diffs.add(DocxVcsDiff(
            nodeId: key,
            type: DocxDiffType.modify,
            before: fromVal,
            after: toVal,
          ));
        }
      }
    }
    return diffs;
  }

  /// Serialise the full history to JSON.
  String toJson() => jsonEncode({
        'documentId': documentId,
        'currentBranch': _currentBranch,
        'snapshots': _snapshots.map((s) => s.toJson()).toList(),
        'branches': _branches.map((k, v) => MapEntry(k, {
              'name': v.name,
              'parentBranch': v.parentBranch,
              'headSnapshotId': v.headSnapshotId,
              'createdAt': v.createdAt.toIso8601String(),
              'authorId': v.authorId,
              'isDefault': v.isDefault,
            })),
      });
}
