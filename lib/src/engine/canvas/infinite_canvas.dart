// ============================================================
// INFINITE CANVAS MODE
// ============================================================

/// A positioned object on the infinite canvas.
class DocxCanvasObject {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final DocxCanvasObjectType type;
  final Map<String, dynamic> content;
  final int zIndex;

  const DocxCanvasObject({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
    required this.content,
    this.rotation = 0,
    this.zIndex = 0,
  });

  DocxCanvasObject copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    Map<String, dynamic>? content,
  }) =>
      DocxCanvasObject(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        type: type,
        content: content ?? this.content,
        rotation: rotation ?? this.rotation,
        zIndex: zIndex ?? this.zIndex,
      );
}

enum DocxCanvasObjectType {
  textBlock,
  image,
  shape,
  connector,
  chart,
  table,
  equation,
  stickyNote,
  frame,
}

/// An infinite-canvas document model.
///
/// Objects can be freely positioned anywhere in 2D space.
/// Supports zoom, pan, grouping, and layering.
///
/// ```dart
/// final canvas = DocxInfiniteCanvas(id: 'canvas-1');
/// canvas.add(DocxCanvasObject(
///   id: 'text-1',
///   x: 100, y: 100,
///   width: 300, height: 200,
///   type: DocxCanvasObjectType.textBlock,
///   content: {'text': 'Hello, canvas!'},
/// ));
/// ```
class DocxInfiniteCanvas {
  final String id;
  final List<DocxCanvasObject> objects;
  double viewportX;
  double viewportY;
  double zoomLevel;
  final double minZoom;
  final double maxZoom;
  final List<String> _selectedIds;

  DocxInfiniteCanvas({
    required this.id,
    List<DocxCanvasObject>? objects,
    this.viewportX = 0,
    this.viewportY = 0,
    this.zoomLevel = 1.0,
    this.minZoom = 0.1,
    this.maxZoom = 8.0,
  })  : objects = objects ?? [],
        _selectedIds = [];

  List<String> get selectedIds => List.unmodifiable(_selectedIds);

  /// Add an object to the canvas.
  void add(DocxCanvasObject obj) => objects.add(obj);

  /// Remove an object by ID.
  void remove(String id) => objects.removeWhere((o) => o.id == id);

  /// Move an object to a new position.
  void move(String id, double x, double y) {
    final idx = objects.indexWhere((o) => o.id == id);
    if (idx >= 0) {
      objects[idx] = objects[idx].copyWith(x: x, y: y);
    }
  }

  /// Resize an object.
  void resize(String id, double width, double height) {
    final idx = objects.indexWhere((o) => o.id == id);
    if (idx >= 0) {
      objects[idx] = objects[idx].copyWith(width: width, height: height);
    }
  }

  /// Select objects.
  void select(List<String> ids) {
    _selectedIds.clear();
    _selectedIds.addAll(ids);
  }

  /// Pan the viewport.
  void pan(double dx, double dy) {
    viewportX += dx;
    viewportY += dy;
  }

  /// Zoom the canvas.
  void zoom(double factor) {
    zoomLevel = (zoomLevel * factor).clamp(minZoom, maxZoom);
  }

  /// Get all objects sorted by zIndex.
  List<DocxCanvasObject> get sortedObjects =>
      List.of(objects)..sort((a, b) => a.zIndex.compareTo(b.zIndex));

  /// Get objects within a viewport rectangle.
  List<DocxCanvasObject> objectsInViewport(
      double vx, double vy, double vw, double vh) {
    return objects.where((o) {
      return o.x < vx + vw &&
          o.x + o.width > vx &&
          o.y < vy + vh &&
          o.y + o.height > vy;
    }).toList();
  }
}

// ============================================================
// KNOWLEDGE GRAPH
// ============================================================

/// A node in the document knowledge graph.
class DocxKnowledgeNode {
  final String id;
  final String documentId;
  final String? sectionId;
  final String label;
  final String? excerpt;
  final List<String> tags;

  const DocxKnowledgeNode({
    required this.id,
    required this.documentId,
    required this.label,
    this.sectionId,
    this.excerpt,
    this.tags = const [],
  });
}

/// A link between two knowledge nodes.
class DocxKnowledgeLink {
  final String id;
  final String sourceId;
  final String targetId;
  final DocxLinkType type;
  final String? label;

  const DocxKnowledgeLink({
    required this.id,
    required this.sourceId,
    required this.targetId,
    this.type = DocxLinkType.reference,
    this.label,
  });
}

enum DocxLinkType { reference, backlink, related, citation, footnote }

/// A knowledge graph linking documents and sections.
///
/// ```dart
/// final graph = DocxKnowledgeGraph();
/// graph.addNode(DocxKnowledgeNode(id: 'n1', documentId: 'doc1', label: 'Introduction'));
/// graph.addNode(DocxKnowledgeNode(id: 'n2', documentId: 'doc2', label: 'Related Work'));
/// graph.addLink(DocxKnowledgeLink(id: 'l1', sourceId: 'n1', targetId: 'n2'));
/// ```
class DocxKnowledgeGraph {
  final Map<String, DocxKnowledgeNode> _nodes = {};
  final List<DocxKnowledgeLink> _links = [];

  List<DocxKnowledgeNode> get nodes => _nodes.values.toList();
  List<DocxKnowledgeLink> get links => List.unmodifiable(_links);

  void addNode(DocxKnowledgeNode node) => _nodes[node.id] = node;
  void removeNode(String id) {
    _nodes.remove(id);
    _links.removeWhere((l) => l.sourceId == id || l.targetId == id);
  }

  void addLink(DocxKnowledgeLink link) => _links.add(link);
  void removeLink(String id) => _links.removeWhere((l) => l.id == id);

  /// Get all backlinks (nodes that link TO the given node).
  List<DocxKnowledgeNode> backlinks(String nodeId) {
    final sourceIds = _links
        .where((l) => l.targetId == nodeId)
        .map((l) => l.sourceId)
        .toSet();
    return sourceIds
        .map((id) => _nodes[id])
        .whereType<DocxKnowledgeNode>()
        .toList();
  }

  /// Get all outgoing links from a node.
  List<DocxKnowledgeNode> outlinks(String nodeId) {
    final targetIds = _links
        .where((l) => l.sourceId == nodeId)
        .map((l) => l.targetId)
        .toSet();
    return targetIds
        .map((id) => _nodes[id])
        .whereType<DocxKnowledgeNode>()
        .toList();
  }

  /// Search nodes by label or tags.
  List<DocxKnowledgeNode> search(String query) {
    final q = query.toLowerCase();
    return nodes
        .where((n) =>
            n.label.toLowerCase().contains(q) ||
            (n.excerpt?.toLowerCase().contains(q) ?? false) ||
            n.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();
  }
}

// ============================================================
// EMBEDDED DATABASE
// ============================================================

/// A column definition for an embedded database table.
class DocxDbColumn {
  final String name;
  final DocxDbColumnType type;
  final bool required;
  final dynamic defaultValue;
  final String? relatedTableId;

  const DocxDbColumn({
    required this.name,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.relatedTableId,
  });
}

enum DocxDbColumnType { text, number, boolean, date, select, relation, formula, url }

/// A row in an embedded database table.
class DocxDbRow {
  final String id;
  final Map<String, dynamic> values;

  const DocxDbRow({required this.id, required this.values});

  DocxDbRow copyWith(Map<String, dynamic> updates) =>
      DocxDbRow(id: id, values: {...values, ...updates});
}

/// An embedded database (Notion-style table with typed columns).
///
/// ```dart
/// final db = DocxEmbeddedDatabase(id: 'tasks', name: 'Tasks');
/// db.addColumn(DocxDbColumn(name: 'Title', type: DocxDbColumnType.text));
/// db.addColumn(DocxDbColumn(name: 'Done', type: DocxDbColumnType.boolean));
/// db.addRow({'Title': 'Write intro', 'Done': false});
/// ```
class DocxEmbeddedDatabase {
  final String id;
  final String name;
  final List<DocxDbColumn> columns;
  final List<DocxDbRow> rows;
  int _rowCounter = 0;

  DocxEmbeddedDatabase({
    required this.id,
    required this.name,
    List<DocxDbColumn>? columns,
    List<DocxDbRow>? rows,
  })  : columns = columns ?? [],
        rows = rows ?? [];

  void addColumn(DocxDbColumn col) => columns.add(col);

  DocxDbRow addRow(Map<String, dynamic> values) {
    final row = DocxDbRow(
      id: '${id}_row_${_rowCounter++}',
      values: values,
    );
    rows.add(row);
    return row;
  }

  void updateRow(String rowId, Map<String, dynamic> updates) {
    final idx = rows.indexWhere((r) => r.id == rowId);
    if (idx >= 0) rows[idx] = rows[idx].copyWith(updates);
  }

  void deleteRow(String rowId) => rows.removeWhere((r) => r.id == rowId);

  /// Filter rows by a column value.
  List<DocxDbRow> filter(String columnName, dynamic value) =>
      rows.where((r) => r.values[columnName] == value).toList();

  /// Sort rows by a column.
  List<DocxDbRow> sortBy(String columnName, {bool ascending = true}) {
    final sorted = List.of(rows);
    sorted.sort((a, b) {
      final av = a.values[columnName];
      final bv = b.values[columnName];
      if (av == null && bv == null) return 0;
      if (av == null) return ascending ? -1 : 1;
      if (bv == null) return ascending ? 1 : -1;
      final cmp = av.toString().compareTo(bv.toString());
      return ascending ? cmp : -cmp;
    });
    return sorted;
  }

  /// Evaluate a formula-type column for a row.
  dynamic evaluateFormula(DocxDbColumn col, DocxDbRow row) {
    // Placeholder: real implementation would parse formula expressions
    return null;
  }
}
