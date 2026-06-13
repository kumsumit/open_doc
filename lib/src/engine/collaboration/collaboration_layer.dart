import 'dart:async';
import 'dart:convert';

import '../../engine/core/enums.dart';

// ============================================================
// OPERATION TYPES (OPERATIONAL TRANSFORM)
// ============================================================

/// Base class for all document operations in OT/CRDT.
abstract class DocxOperation {
  final String id;
  final String authorId;
  final DateTime timestamp;

  const DocxOperation({
    required this.id,
    required this.authorId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson();
  DocxOperation invert();
}

/// Insert text at a position.
class DocxInsertOperation extends DocxOperation {
  final int offset;
  final String text;
  final String? nodeId;

  const DocxInsertOperation({
    required super.id,
    required super.authorId,
    required super.timestamp,
    required this.offset,
    required this.text,
    this.nodeId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'insert',
        'id': id,
        'authorId': authorId,
        'timestamp': timestamp.toIso8601String(),
        'offset': offset,
        'text': text,
        'nodeId': nodeId,
      };

  @override
  DocxOperation invert() => DocxDeleteOperation(
        id: '${id}_inv',
        authorId: authorId,
        timestamp: timestamp,
        offset: offset,
        length: text.length,
        nodeId: nodeId,
      );
}

/// Delete text at a position.
class DocxDeleteOperation extends DocxOperation {
  final int offset;
  final int length;
  final String? nodeId;
  final String? deletedText;

  const DocxDeleteOperation({
    required super.id,
    required super.authorId,
    required super.timestamp,
    required this.offset,
    required this.length,
    this.nodeId,
    this.deletedText,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'delete',
        'id': id,
        'authorId': authorId,
        'timestamp': timestamp.toIso8601String(),
        'offset': offset,
        'length': length,
        'nodeId': nodeId,
      };

  @override
  DocxOperation invert() => DocxInsertOperation(
        id: '${id}_inv',
        authorId: authorId,
        timestamp: timestamp,
        offset: offset,
        text: deletedText ?? '',
        nodeId: nodeId,
      );
}

/// Format change operation.
class DocxFormatOperation extends DocxOperation {
  final int offset;
  final int length;
  final Map<String, dynamic> attributes;
  final Map<String, dynamic>? previousAttributes;
  final String? nodeId;

  const DocxFormatOperation({
    required super.id,
    required super.authorId,
    required super.timestamp,
    required this.offset,
    required this.length,
    required this.attributes,
    this.previousAttributes,
    this.nodeId,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'format',
        'id': id,
        'authorId': authorId,
        'timestamp': timestamp.toIso8601String(),
        'offset': offset,
        'length': length,
        'attributes': attributes,
        'nodeId': nodeId,
      };

  @override
  DocxOperation invert() => DocxFormatOperation(
        id: '${id}_inv',
        authorId: authorId,
        timestamp: timestamp,
        offset: offset,
        length: length,
        attributes: previousAttributes ?? {},
        previousAttributes: attributes,
        nodeId: nodeId,
      );
}

// ============================================================
// OPERATIONAL TRANSFORM ENGINE
// ============================================================

/// Transforms operation [op] against a concurrent operation [against].
/// Returns the transformed version of [op] that can be applied after [against].
class DocxOperationalTransform {
  /// Transform two concurrent insert operations.
  static DocxOperation transform(DocxOperation op, DocxOperation against) {
    if (op is DocxInsertOperation && against is DocxInsertOperation) {
      return _transformInsertInsert(op, against);
    }
    if (op is DocxInsertOperation && against is DocxDeleteOperation) {
      return _transformInsertDelete(op, against);
    }
    if (op is DocxDeleteOperation && against is DocxInsertOperation) {
      return _transformDeleteInsert(op, against);
    }
    if (op is DocxDeleteOperation && against is DocxDeleteOperation) {
      return _transformDeleteDelete(op, against);
    }
    return op;
  }

  static DocxInsertOperation _transformInsertInsert(
      DocxInsertOperation op, DocxInsertOperation against) {
    if (op.offset < against.offset ||
        (op.offset == against.offset && op.id.compareTo(against.id) < 0)) {
      return op;
    }
    return DocxInsertOperation(
      id: op.id,
      authorId: op.authorId,
      timestamp: op.timestamp,
      offset: op.offset + against.text.length,
      text: op.text,
      nodeId: op.nodeId,
    );
  }

  static DocxInsertOperation _transformInsertDelete(
      DocxInsertOperation op, DocxDeleteOperation against) {
    if (op.offset <= against.offset) return op;
    if (op.offset >= against.offset + against.length) {
      return DocxInsertOperation(
        id: op.id,
        authorId: op.authorId,
        timestamp: op.timestamp,
        offset: op.offset - against.length,
        text: op.text,
        nodeId: op.nodeId,
      );
    }
    // Insert falls within deleted range — move to deletion start
    return DocxInsertOperation(
      id: op.id,
      authorId: op.authorId,
      timestamp: op.timestamp,
      offset: against.offset,
      text: op.text,
      nodeId: op.nodeId,
    );
  }

  static DocxDeleteOperation _transformDeleteInsert(
      DocxDeleteOperation op, DocxInsertOperation against) {
    if (against.offset >= op.offset + op.length) return op;
    if (against.offset <= op.offset) {
      return DocxDeleteOperation(
        id: op.id,
        authorId: op.authorId,
        timestamp: op.timestamp,
        offset: op.offset + against.text.length,
        length: op.length,
        nodeId: op.nodeId,
      );
    }
    // Insert falls within delete range — extend length
    return DocxDeleteOperation(
      id: op.id,
      authorId: op.authorId,
      timestamp: op.timestamp,
      offset: op.offset,
      length: op.length + against.text.length,
      nodeId: op.nodeId,
    );
  }

  static DocxDeleteOperation _transformDeleteDelete(
      DocxDeleteOperation op, DocxDeleteOperation against) {
    if (against.offset >= op.offset + op.length ||
        op.offset >= against.offset + against.length) {
      // No overlap
      final offset = against.offset < op.offset
          ? op.offset - against.length
          : op.offset;
      return DocxDeleteOperation(
        id: op.id,
        authorId: op.authorId,
        timestamp: op.timestamp,
        offset: offset,
        length: op.length,
        nodeId: op.nodeId,
      );
    }
    // Overlapping deletes — compute remaining range
    final start = op.offset < against.offset ? op.offset : against.offset;
    final end1 = op.offset + op.length;
    final end2 = against.offset + against.length;
    final end = end1 > end2 ? end1 : end2;
    final remaining = (end - start) - against.length;
    return DocxDeleteOperation(
      id: op.id,
      authorId: op.authorId,
      timestamp: op.timestamp,
      offset: op.offset < against.offset ? op.offset : against.offset,
      length: remaining > 0 ? remaining : 0,
      nodeId: op.nodeId,
    );
  }
}

// ============================================================
// CRDT (CONFLICT-FREE REPLICATED DATA TYPE)
// ============================================================

/// A CRDT character atom (Logoot/LSEQ-style).
class DocxCrdtAtom {
  final String id;
  final String authorId;
  final String? character;
  final bool deleted;

  const DocxCrdtAtom({
    required this.id,
    required this.authorId,
    this.character,
    this.deleted = false,
  });

  DocxCrdtAtom withDeleted() =>
      DocxCrdtAtom(id: id, authorId: authorId, character: character, deleted: true);

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'character': character,
        'deleted': deleted,
      };

  factory DocxCrdtAtom.fromJson(Map<String, dynamic> json) => DocxCrdtAtom(
        id: json['id'] as String,
        authorId: json['authorId'] as String,
        character: json['character'] as String?,
        deleted: json['deleted'] as bool? ?? false,
      );
}

/// A CRDT-based text sequence (append-only list with tombstones).
class DocxCrdtText {
  final List<DocxCrdtAtom> _atoms;
  final String _localId;
  int _clock = 0;

  DocxCrdtText(this._localId) : _atoms = [];

  /// Visible (non-deleted) content.
  String get text => _atoms
      .where((a) => !a.deleted && a.character != null)
      .map((a) => a.character!)
      .join();

  /// Insert a character after the atom with [afterId] (null = beginning).
  DocxCrdtAtom insert(String char, {String? afterId}) {
    final atom = DocxCrdtAtom(
      id: '$_localId:${_clock++}',
      authorId: _localId,
      character: char,
    );
    final idx = afterId == null
        ? 0
        : _atoms.indexWhere((a) => a.id == afterId) + 1;
    _atoms.insert(idx < 0 ? _atoms.length : idx, atom);
    return atom;
  }

  /// Mark an atom as deleted.
  void delete(String atomId) {
    final idx = _atoms.indexWhere((a) => a.id == atomId);
    if (idx >= 0) {
      _atoms[idx] = _atoms[idx].withDeleted();
    }
  }

  /// Merge remote atoms into local sequence.
  void merge(List<DocxCrdtAtom> remoteAtoms) {
    for (final remote in remoteAtoms) {
      final existing = _atoms.indexWhere((a) => a.id == remote.id);
      if (existing < 0) {
        _atoms.add(remote);
      } else if (remote.deleted) {
        _atoms[existing] = _atoms[existing].withDeleted();
      }
    }
  }

  /// Serialise all atoms to JSON.
  String toJson() => jsonEncode(_atoms.map((a) => a.toJson()).toList());

  /// Load atoms from JSON snapshot.
  factory DocxCrdtText.fromJson(String localId, String json) {
    final obj = DocxCrdtText(localId);
    final list = jsonDecode(json) as List<dynamic>;
    obj._atoms.addAll(list
        .map((e) => DocxCrdtAtom.fromJson(e as Map<String, dynamic>))
        .toList());
    return obj;
  }
}

// ============================================================
// PRESENCE / LIVE CURSORS
// ============================================================

/// A collaborating user's cursor/selection state.
class DocxUserPresence {
  final String userId;
  final String displayName;
  final String color;
  final DocxPresenceState state;
  final int? cursorOffset;
  final int? selectionStart;
  final int? selectionEnd;
  final String? nodeId;
  final DateTime lastSeen;

  const DocxUserPresence({
    required this.userId,
    required this.displayName,
    required this.color,
    this.state = DocxPresenceState.active,
    this.cursorOffset,
    this.selectionStart,
    this.selectionEnd,
    this.nodeId,
    required this.lastSeen,
  });

  DocxUserPresence copyWith({
    DocxPresenceState? state,
    int? cursorOffset,
    int? selectionStart,
    int? selectionEnd,
    String? nodeId,
    DateTime? lastSeen,
  }) =>
      DocxUserPresence(
        userId: userId,
        displayName: displayName,
        color: color,
        state: state ?? this.state,
        cursorOffset: cursorOffset ?? this.cursorOffset,
        selectionStart: selectionStart ?? this.selectionStart,
        selectionEnd: selectionEnd ?? this.selectionEnd,
        nodeId: nodeId ?? this.nodeId,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'color': color,
        'state': state.name,
        'cursorOffset': cursorOffset,
        'selectionStart': selectionStart,
        'selectionEnd': selectionEnd,
        'nodeId': nodeId,
        'lastSeen': lastSeen.toIso8601String(),
      };
}

/// Manages presence of multiple collaborators.
class DocxPresenceManager {
  final Map<String, DocxUserPresence> _users = {};
  final _controller = StreamController<Map<String, DocxUserPresence>>.broadcast();

  Stream<Map<String, DocxUserPresence>> get presenceStream => _controller.stream;

  Map<String, DocxUserPresence> get users => Map.unmodifiable(_users);

  void updatePresence(DocxUserPresence presence) {
    _users[presence.userId] = presence;
    _controller.add(Map.unmodifiable(_users));
  }

  void removeUser(String userId) {
    _users.remove(userId);
    _controller.add(Map.unmodifiable(_users));
  }

  void dispose() => _controller.close();
}

// ============================================================
// COLLABORATION SESSION
// ============================================================

/// Manages a real-time collaboration session for a document.
class DocxCollaborationSession {
  final String documentId;
  final String localUserId;
  final DocxPresenceManager presenceManager;
  final DocxCrdtText _crdtText;

  final _operationController = StreamController<DocxOperation>.broadcast();
  final List<DocxOperation> _history = [];

  DocxCollaborationSession({
    required this.documentId,
    required this.localUserId,
  })  : presenceManager = DocxPresenceManager(),
        _crdtText = DocxCrdtText(localUserId);

  Stream<DocxOperation> get operationStream => _operationController.stream;
  List<DocxOperation> get history => List.unmodifiable(_history);
  DocxCrdtText get crdtText => _crdtText;

  /// Apply a local operation and broadcast it.
  void applyLocal(DocxOperation op) {
    _history.add(op);
    _operationController.add(op);
  }

  /// Apply a remote operation (with OT transform against pending local ops).
  void applyRemote(DocxOperation remoteOp) {
    var transformed = remoteOp;
    // Transform against all local ops that are newer
    for (final local in _history.reversed) {
      if (local.timestamp.isAfter(remoteOp.timestamp)) {
        transformed = DocxOperationalTransform.transform(transformed, local);
      }
    }
    _history.add(transformed);
    _operationController.add(transformed);
  }

  void dispose() {
    _operationController.close();
    presenceManager.dispose();
  }
}

// ============================================================
// PREDEFINED USER COLORS
// ============================================================

/// Pool of distinct colors for collaboration users.
class DocxCollaborationColors {
  static const List<String> palette = [
    '#E53935', // red
    '#8E24AA', // purple
    '#1E88E5', // blue
    '#00897B', // teal
    '#F4511E', // orange
    '#6D4C41', // brown
    '#039BE5', // light blue
    '#43A047', // green
    '#FFB300', // amber
    '#D81B60', // pink
  ];

  static String forIndex(int index) => palette[index % palette.length];
}
