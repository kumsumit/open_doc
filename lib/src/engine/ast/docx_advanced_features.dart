import 'package:xml/xml.dart';

import 'docx_node.dart';

// ============================================================
// CONDITIONAL TEXT
// ============================================================

/// A conditional text block that is shown/hidden based on a field value.
///
/// ```dart
/// DocxConditionalText(
///   condition: 'UserRole == "Admin"',
///   children: [DocxParagraph.text('Admin-only section')],
/// )
/// ```
class DocxConditionalText extends DocxBlock {
  final String condition;
  final List<DocxBlock> children;
  final List<DocxBlock>? elseChildren;
  final bool isHidden;

  const DocxConditionalText({
    required this.condition,
    required this.children,
    this.elseChildren,
    this.isHidden = false,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    if (!isHidden) {
      for (final child in children) {
        child.buildXml(builder);
      }
    } else if (elseChildren != null) {
      for (final child in elseChildren!) {
        child.buildXml(builder);
      }
    }
  }
}

// ============================================================
// MASTER DOCUMENT
// ============================================================

/// A subdocument reference within a master document.
class DocxSubdocumentRef extends DocxBlock {
  final String filePath;
  final String? title;
  final bool locked;

  const DocxSubdocumentRef({
    required this.filePath,
    this.title,
    this.locked = false,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:rPr', nest: () {
          builder.element('w:rStyle', nest: () {
            builder.attribute('w:val', 'Hyperlink');
          });
        });
        builder.element('w:t', nest: () {
          builder.text('[Subdocument: ${title ?? filePath}]');
        });
      });
    });
  }
}

/// A master document container that assembles multiple subdocuments.
///
/// ```dart
/// DocxMasterDocument(
///   subdocuments: [
///     DocxSubdocumentRef(filePath: 'chapter1.docx', title: 'Chapter 1'),
///     DocxSubdocumentRef(filePath: 'chapter2.docx', title: 'Chapter 2'),
///   ],
/// )
/// ```
class DocxMasterDocument {
  final String id;
  final String? title;
  final List<DocxSubdocumentRef> subdocuments;
  final bool continuousPageNumbering;
  final bool sharedStyles;

  const DocxMasterDocument({
    required this.id,
    this.title,
    this.subdocuments = const [],
    this.continuousPageNumbering = true,
    this.sharedStyles = true,
  });
}

// ============================================================
// SCREEN READER / ACCESSIBILITY
// ============================================================

/// Accessibility metadata attached to a document element.
class DocxAccessibilityLabel {
  final String nodeId;
  final String altText;
  final String? longDescription;
  final DocxAccessibilityRole role;
  final bool isDecorative;

  const DocxAccessibilityLabel({
    required this.nodeId,
    required this.altText,
    this.longDescription,
    this.role = DocxAccessibilityRole.generic,
    this.isDecorative = false,
  });
}

enum DocxAccessibilityRole {
  generic,
  heading,
  paragraph,
  table,
  figure,
  list,
  listItem,
  link,
  button,
  image,
  equation,
  chart,
}

/// Document-level accessibility checker.
class DocxAccessibilityChecker {
  final List<DocxAccessibilityIssue> _issues = [];

  List<DocxAccessibilityIssue> get issues => List.unmodifiable(_issues);
  bool get hasErrors => _issues.any((i) => i.severity == DocxIssueSeverity.error);
  bool get hasWarnings => _issues.any((i) => i.severity == DocxIssueSeverity.warning);

  void checkNode(String nodeId, String nodeType, Map<String, dynamic> properties) {
    // Image without alt text
    if (nodeType == 'image' &&
        (properties['altText'] == null || (properties['altText'] as String).isEmpty)) {
      _issues.add(DocxAccessibilityIssue(
        nodeId: nodeId,
        message: 'Image is missing alt text.',
        severity: DocxIssueSeverity.error,
        ruleId: 'alt-text-missing',
      ));
    }
    // Table without header row
    if (nodeType == 'table' && properties['hasHeader'] != true) {
      _issues.add(DocxAccessibilityIssue(
        nodeId: nodeId,
        message: 'Table is missing a header row.',
        severity: DocxIssueSeverity.warning,
        ruleId: 'table-header-missing',
      ));
    }
    // Heading level skipped
    if (nodeType == 'heading') {
      final level = properties['level'] as int? ?? 1;
      final prevLevel = properties['previousLevel'] as int? ?? 0;
      if (level > prevLevel + 1) {
        _issues.add(DocxAccessibilityIssue(
          nodeId: nodeId,
          message: 'Heading level skipped (from H$prevLevel to H$level).',
          severity: DocxIssueSeverity.warning,
          ruleId: 'heading-level-skip',
        ));
      }
    }
    // Colour contrast (placeholder)
    if (properties['foreground'] != null && properties['background'] != null) {
      // Real implementation would check WCAG contrast ratio
      _issues.add(DocxAccessibilityIssue(
        nodeId: nodeId,
        message: 'Colour contrast check: verify WCAG 2.1 AA ratio ≥ 4.5:1.',
        severity: DocxIssueSeverity.info,
        ruleId: 'color-contrast',
      ));
    }
  }

  void clear() => _issues.clear();
}

class DocxAccessibilityIssue {
  final String nodeId;
  final String message;
  final DocxIssueSeverity severity;
  final String ruleId;

  const DocxAccessibilityIssue({
    required this.nodeId,
    required this.message,
    required this.severity,
    required this.ruleId,
  });
}

enum DocxIssueSeverity { info, warning, error }

// ============================================================
// STYLUS / HANDWRITING INPUT
// ============================================================

/// A handwriting/stylus stroke (sequence of pressure-sensitive points).
class DocxStylusStroke {
  final String id;
  final List<DocxStylusPoint> points;
  final double baseLineWidth;
  final String color;
  final DocxStylusTool tool;

  const DocxStylusStroke({
    required this.id,
    required this.points,
    this.baseLineWidth = 2.0,
    this.color = '000000',
    this.tool = DocxStylusTool.pen,
  });
}

class DocxStylusPoint {
  final double x;
  final double y;
  final double pressure; // 0.0–1.0
  final double tilt;     // degrees
  final double rotation; // degrees
  final DateTime timestamp;

  const DocxStylusPoint({
    required this.x,
    required this.y,
    this.pressure = 0.5,
    this.tilt = 0,
    this.rotation = 0,
    required this.timestamp,
  });
}

enum DocxStylusTool { pen, pencil, highlighter, eraser, marker }

/// A collection of stylus annotations on a document page.
class DocxStylusLayer {
  final String pageId;
  final List<DocxStylusStroke> strokes;

  const DocxStylusLayer({
    required this.pageId,
    this.strokes = const [],
  });

  DocxStylusLayer addStroke(DocxStylusStroke stroke) =>
      DocxStylusLayer(pageId: pageId, strokes: [...strokes, stroke]);

  DocxStylusLayer removeStroke(String strokeId) => DocxStylusLayer(
        pageId: pageId,
        strokes: strokes.where((s) => s.id != strokeId).toList(),
      );
}

// ============================================================
// MULTI-WINDOW SUPPORT
// ============================================================

/// Represents one window/tab showing a document.
class DocxWindowState {
  final String windowId;
  final String documentId;
  final int scrollPosition;
  final double zoomLevel;
  final String? selectedNodeId;
  final bool isReadOnly;

  const DocxWindowState({
    required this.windowId,
    required this.documentId,
    this.scrollPosition = 0,
    this.zoomLevel = 1.0,
    this.selectedNodeId,
    this.isReadOnly = false,
  });

  DocxWindowState copyWith({
    int? scrollPosition,
    double? zoomLevel,
    String? selectedNodeId,
    bool? isReadOnly,
  }) =>
      DocxWindowState(
        windowId: windowId,
        documentId: documentId,
        scrollPosition: scrollPosition ?? this.scrollPosition,
        zoomLevel: zoomLevel ?? this.zoomLevel,
        selectedNodeId: selectedNodeId ?? this.selectedNodeId,
        isReadOnly: isReadOnly ?? this.isReadOnly,
      );
}

/// Manages multiple windows showing the same or different documents.
class DocxMultiWindowManager {
  final Map<String, DocxWindowState> _windows = {};

  List<DocxWindowState> get windows => _windows.values.toList();
  int get windowCount => _windows.length;

  DocxWindowState openWindow(String documentId, {bool isReadOnly = false}) {
    final state = DocxWindowState(
      windowId: 'w${DateTime.now().millisecondsSinceEpoch}',
      documentId: documentId,
      isReadOnly: isReadOnly,
    );
    _windows[state.windowId] = state;
    return state;
  }

  void closeWindow(String windowId) => _windows.remove(windowId);

  void updateWindow(DocxWindowState state) => _windows[state.windowId] = state;

  List<DocxWindowState> windowsForDocument(String documentId) =>
      _windows.values.where((w) => w.documentId == documentId).toList();
}

// ============================================================
// MULTIPLE CURSORS
// ============================================================

/// A single editing cursor position.
class DocxCursor {
  final String id;
  final int offset;
  final String? nodeId;
  final int? anchorOffset; // for selection (null = collapsed cursor)

  const DocxCursor({
    required this.id,
    required this.offset,
    this.nodeId,
    this.anchorOffset,
  });

  bool get isSelection => anchorOffset != null && anchorOffset != offset;
  int get selectionStart => isSelection ? (offset < anchorOffset! ? offset : anchorOffset!) : offset;
  int get selectionEnd => isSelection ? (offset > anchorOffset! ? offset : anchorOffset!) : offset;

  DocxCursor copyWith({int? offset, String? nodeId, int? anchorOffset}) => DocxCursor(
        id: id,
        offset: offset ?? this.offset,
        nodeId: nodeId ?? this.nodeId,
        anchorOffset: anchorOffset ?? this.anchorOffset,
      );
}

/// Manages multiple editing cursors (multi-cursor editing support).
class DocxMultiCursorManager {
  final List<DocxCursor> _cursors = [];

  List<DocxCursor> get cursors => List.unmodifiable(_cursors);
  int get cursorCount => _cursors.length;

  void addCursor(DocxCursor cursor) {
    _cursors.removeWhere((c) => c.id == cursor.id);
    _cursors.add(cursor);
  }

  void removeCursor(String id) => _cursors.removeWhere((c) => c.id == id);
  void removeAll() => _cursors.clear();

  void moveCursor(String id, int newOffset, {String? nodeId}) {
    final idx = _cursors.indexWhere((c) => c.id == id);
    if (idx >= 0) {
      _cursors[idx] = _cursors[idx].copyWith(offset: newOffset, nodeId: nodeId);
    }
  }

  void mergeOverlapping() {
    _cursors.sort((a, b) => a.offset.compareTo(b.offset));
    for (int i = _cursors.length - 1; i > 0; i--) {
      if (_cursors[i].offset == _cursors[i - 1].offset &&
          _cursors[i].nodeId == _cursors[i - 1].nodeId) {
        _cursors.removeAt(i);
      }
    }
  }
}

// ============================================================
// END-TO-END ENCRYPTION
// ============================================================

/// Configuration for document encryption.
class DocxEncryptionConfig {
  final DocxEncryptionAlgorithm algorithm;
  final int keyLengthBits;
  final bool encryptMetadata;
  final bool signDocument;

  const DocxEncryptionConfig({
    this.algorithm = DocxEncryptionAlgorithm.aes256,
    this.keyLengthBits = 256,
    this.encryptMetadata = true,
    this.signDocument = false,
  });
}

enum DocxEncryptionAlgorithm { aes128, aes256, chacha20 }

/// Manages document encryption and decryption.
abstract class DocxEncryptionService {
  Future<List<int>> encrypt(List<int> plaintext, DocxEncryptionConfig config, String key);
  Future<List<int>> decrypt(List<int> ciphertext, DocxEncryptionConfig config, String key);
  Future<bool> verify(List<int> document, String signature, String publicKey);
}

// ============================================================
// INTERACTIVE WIDGETS
// ============================================================

/// An interactive widget embedded in the document.
class DocxInteractiveWidget extends DocxBlock {
  final String widgetType;
  final Map<String, dynamic> config;
  final int width;
  final int height;
  final String? fallbackText;

  const DocxInteractiveWidget({
    required this.widgetType,
    required this.config,
    this.width = 400,
    this.height = 300,
    this.fallbackText,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text(fallbackText ?? '[Interactive widget: $widgetType]');
        });
      });
    });
  }
}

/// Predefined interactive widget types.
class DocxWidgetTypes {
  static const String liveSlider = 'live_slider';
  static const String interactiveGraph = 'interactive_graph';
  static const String dynamicPlot = 'dynamic_plot';
  static const String poll = 'poll';
  static const String calculator = 'calculator';
  static const String timer = 'timer';
  static const String progressBar = 'progress_bar';
  static const String codePlayground = 'code_playground';
}

// ============================================================
// CRDT SYNC
// ============================================================

/// Configuration for CRDT-based offline-first synchronisation.
class DocxCrdtSyncConfig {
  final String serverUrl;
  final String documentId;
  final String userId;
  final int syncIntervalMs;
  final bool enableOfflineMode;
  final bool enableEndToEndEncryption;

  const DocxCrdtSyncConfig({
    required this.serverUrl,
    required this.documentId,
    required this.userId,
    this.syncIntervalMs = 5000,
    this.enableOfflineMode = true,
    this.enableEndToEndEncryption = false,
  });
}

/// Sync status for the CRDT layer.
enum DocxSyncStatus { synced, syncing, offline, conflict, error }

/// Manages CRDT synchronisation state for a document.
class DocxCrdtSyncManager {
  final DocxCrdtSyncConfig config;
  DocxSyncStatus _status = DocxSyncStatus.offline;
  DateTime? _lastSyncTime;
  final List<String> _pendingOperationIds = [];

  DocxCrdtSyncManager(this.config);

  DocxSyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingOperationCount => _pendingOperationIds.length;

  void enqueue(String operationId) => _pendingOperationIds.add(operationId);

  Future<void> sync() async {
    _status = DocxSyncStatus.syncing;
    try {
      // Real implementation: POST pending ops to server, receive remote ops
      _pendingOperationIds.clear();
      _lastSyncTime = DateTime.now();
      _status = DocxSyncStatus.synced;
    } catch (_) {
      _status = DocxSyncStatus.error;
    }
  }

  void goOffline() => _status = DocxSyncStatus.offline;
}
