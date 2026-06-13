// ============================================================
// ADVANCED LAYOUT ENGINE
// ============================================================
// Covers: nested floating objects, complex script shaping, vertical Asian
// text, footnote/endnote/multi-column balancing, text wrap around irregular
// shapes, and DOCX compatibility checking.
// ============================================================

// ============================================================
// NESTED FLOATING OBJECTS
// ============================================================

/// Describes the z-order stacking of a floating object relative to its host.
enum DocxFloatStackOrder { behindText, inFrontOfText, behindParent, inFrontOfParent }

/// A floating object that can itself contain other floating objects.
class DocxNestedFloatingObject {
  final String id;
  final String? parentId;
  final double x;
  final double y;
  final double width;
  final double height;
  final DocxFloatStackOrder stackOrder;
  final List<DocxNestedFloatingObject> children;
  final String contentType; // 'image', 'textbox', 'shape', 'group'

  const DocxNestedFloatingObject({
    required this.id,
    this.parentId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.stackOrder = DocxFloatStackOrder.inFrontOfText,
    this.children = const [],
    this.contentType = 'shape',
  });

  bool get isNested => parentId != null;
  bool get hasChildren => children.isNotEmpty;

  DocxNestedFloatingObject addChild(DocxNestedFloatingObject child) =>
      DocxNestedFloatingObject(
        id: id,
        parentId: parentId,
        x: x,
        y: y,
        width: width,
        height: height,
        stackOrder: stackOrder,
        children: [...children, child],
        contentType: contentType,
      );
}

/// Manages nested floating object trees within a page.
class DocxFloatingObjectTree {
  final Map<String, DocxNestedFloatingObject> _objects = {};

  void add(DocxNestedFloatingObject obj) => _objects[obj.id] = obj;
  void remove(String id) => _objects.remove(id);

  /// Returns top-level floating objects (no parent).
  List<DocxNestedFloatingObject> get roots =>
      _objects.values.where((o) => o.parentId == null).toList();

  /// Returns all objects that overlap [rect] defined by (x, y, w, h).
  List<DocxNestedFloatingObject> objectsInRegion(
      double x, double y, double w, double h) {
    return _objects.values.where((o) {
      return o.x < x + w && o.x + o.width > x && o.y < y + h && o.y + o.height > y;
    }).toList();
  }

  /// Resolves z-order sort for rendering (back to front).
  List<DocxNestedFloatingObject> get renderOrder {
    final sorted = _objects.values.toList()
      ..sort((a, b) => a.stackOrder.index.compareTo(b.stackOrder.index));
    return sorted;
  }
}

// ============================================================
// COMPLEX SCRIPT SHAPING
// ============================================================

/// Script categories that require special glyph shaping.
enum DocxScriptCategory {
  latin,
  arabic,
  hebrew,
  devanagari,
  tamil,
  thai,
  tibetan,
  cjk,
  hangul,
  georgian,
  armenian,
  ethiopic,
}

/// A shaped text run with positioned glyph advances.
class DocxShapedGlyph {
  final int codePoint;
  final double advance;
  final double xOffset;
  final double yOffset;
  final bool isRtl;

  const DocxShapedGlyph({
    required this.codePoint,
    required this.advance,
    this.xOffset = 0,
    this.yOffset = 0,
    this.isRtl = false,
  });
}

/// Result of shaping a text run.
class DocxShapedRun {
  final String text;
  final DocxScriptCategory script;
  final List<DocxShapedGlyph> glyphs;
  final double totalAdvance;
  final bool isRtl;

  const DocxShapedRun({
    required this.text,
    required this.script,
    required this.glyphs,
    required this.totalAdvance,
    this.isRtl = false,
  });
}

/// Complex script text shaper.
///
/// Detects script category from Unicode ranges and applies appropriate
/// shaping rules (Arabic joining, Indic cluster reordering, Thai word break).
class DocxScriptShaper {
  /// Detect the dominant script category for a string.
  static DocxScriptCategory detectScript(String text) {
    if (text.isEmpty) return DocxScriptCategory.latin;
    final first = text.codeUnitAt(0);
    if (first >= 0x0600 && first <= 0x06FF) return DocxScriptCategory.arabic;
    if (first >= 0x0590 && first <= 0x05FF) return DocxScriptCategory.hebrew;
    if (first >= 0x0900 && first <= 0x097F) return DocxScriptCategory.devanagari;
    if (first >= 0x0B80 && first <= 0x0BFF) return DocxScriptCategory.tamil;
    if (first >= 0x0E00 && first <= 0x0E7F) return DocxScriptCategory.thai;
    if (first >= 0x0F00 && first <= 0x0FFF) return DocxScriptCategory.tibetan;
    if ((first >= 0x4E00 && first <= 0x9FFF) ||
        (first >= 0x3040 && first <= 0x30FF)) {
      return DocxScriptCategory.cjk;
    }
    if (first >= 0xAC00 && first <= 0xD7FF) return DocxScriptCategory.hangul;
    return DocxScriptCategory.latin;
  }

  /// Shape a text run into positioned glyphs.
  ///
  /// A real implementation delegates to HarfBuzz or the platform text engine.
  /// This stub produces identity-mapped glyphs with uniform advances.
  static DocxShapedRun shape(
    String text, {
    double fontSize = 12,
    String fontFamily = 'Times New Roman',
  }) {
    final script = detectScript(text);
    final isRtl = script == DocxScriptCategory.arabic ||
        script == DocxScriptCategory.hebrew;
    final charWidth = fontSize * 0.6;
    final glyphs = text.runes
        .map((cp) => DocxShapedGlyph(
              codePoint: cp,
              advance: charWidth,
              isRtl: isRtl,
            ))
        .toList();
    return DocxShapedRun(
      text: text,
      script: script,
      glyphs: glyphs,
      totalAdvance: glyphs.fold(0, (s, g) => s + g.advance),
      isRtl: isRtl,
    );
  }

  /// Break Thai/CJK text into logical word units.
  static List<String> wordBreak(String text, DocxScriptCategory script) {
    if (script == DocxScriptCategory.thai || script == DocxScriptCategory.cjk) {
      return text.characters.map((c) => c).toList();
    } else {
      return text.split(' ');
    }
  }
}

// Keep the import for characters extension — Dart core provides it via String
extension on String {
  Iterable<String> get characters sync* {
    for (final rune in runes) {
      yield String.fromCharCode(rune);
    }
  }
}

// ============================================================
// VERTICAL ASIAN TEXT
// ============================================================

/// Vertical text writing mode.
enum DocxVerticalWritingMode {
  horizontalTb, // default left-to-right, top-to-bottom
  verticalRl,   // vertical right-to-left (traditional CJK)
  verticalLr,   // vertical left-to-right (Mongolian)
}

/// A line of vertically-laid-out glyphs.
class DocxVerticalLine {
  final List<DocxShapedGlyph> glyphs;
  final double lineHeight;
  final double baseline;

  const DocxVerticalLine({
    required this.glyphs,
    required this.lineHeight,
    required this.baseline,
  });
}

/// Lays out CJK text in vertical writing mode.
class DocxVerticalTextLayout {
  final DocxVerticalWritingMode writingMode;
  final double columnWidth;
  final double lineSpacing;

  const DocxVerticalTextLayout({
    this.writingMode = DocxVerticalWritingMode.verticalRl,
    required this.columnWidth,
    this.lineSpacing = 1.2,
  });

  /// Convert a horizontal run into vertical lines.
  List<DocxVerticalLine> layout(DocxShapedRun run) {
    final lines = <DocxVerticalLine>[];
    final glyphsPerLine = (columnWidth / (run.glyphs.isNotEmpty
            ? run.glyphs.first.advance
            : 12))
        .floor()
        .clamp(1, run.glyphs.length);
    for (int i = 0; i < run.glyphs.length; i += glyphsPerLine) {
      final slice = run.glyphs.sublist(
          i, (i + glyphsPerLine).clamp(0, run.glyphs.length));
      lines.add(DocxVerticalLine(
        glyphs: slice,
        lineHeight: columnWidth,
        baseline: columnWidth * 0.8,
      ));
    }
    return lines;
  }
}

// ============================================================
// FOOTNOTE / ENDNOTE BALANCING
// ============================================================

/// A footnote or endnote entry with its measured height.
class DocxNoteEntry {
  final String id;
  final String referenceNodeId;
  final double height; // in twips
  final bool isEndnote;

  const DocxNoteEntry({
    required this.id,
    required this.referenceNodeId,
    required this.height,
    this.isEndnote = false,
  });
}

/// Balanced distribution of footnotes across columns/pages.
class DocxBalancedNotes {
  /// column index → list of note entries assigned to that column
  final Map<int, List<DocxNoteEntry>> columnAssignments;
  final double totalHeight;

  const DocxBalancedNotes({
    required this.columnAssignments,
    required this.totalHeight,
  });
}

/// Balances footnotes/endnotes evenly across columns.
class DocxNoteBalancer {
  /// Distribute [notes] across [columnCount] columns with each column having
  /// [columnHeight] available space for notes.
  static DocxBalancedNotes balance({
    required List<DocxNoteEntry> notes,
    required int columnCount,
    required double columnHeight,
  }) {
    final Map<int, List<DocxNoteEntry>> assignments = {
      for (int i = 0; i < columnCount; i++) i: [],
    };
    final columnUsed = List<double>.filled(columnCount, 0);
    // Sort by height descending for best-fit bin packing
    final sorted = [...notes]..sort((a, b) => b.height.compareTo(a.height));
    for (final note in sorted) {
      int best = 0;
      double bestUsed = double.infinity;
      for (int c = 0; c < columnCount; c++) {
        if (columnUsed[c] + note.height <= columnHeight &&
            columnUsed[c] < bestUsed) {
          best = c;
          bestUsed = columnUsed[c];
        }
      }
      assignments[best]!.add(note);
      columnUsed[best] += note.height;
    }
    return DocxBalancedNotes(
      columnAssignments: assignments,
      totalHeight: columnUsed.fold(0, (s, v) => s + v),
    );
  }
}

// ============================================================
// MULTI-COLUMN BALANCING
// ============================================================

/// A content block with a measured height for column distribution.
class DocxColumnBlock {
  final String id;
  final double height;

  const DocxColumnBlock({required this.id, required this.height});
}

/// Result of balancing content across columns.
class DocxColumnBalance {
  /// column index → block IDs
  final Map<int, List<String>> columns;
  final List<double> columnHeights;

  const DocxColumnBalance({
    required this.columns,
    required this.columnHeights,
  });
}

/// Balances content blocks across a set of columns to equalise column heights.
class DocxMultiColumnBalancer {
  /// Balance [blocks] into [columnCount] columns.
  ///
  /// Uses a greedy approach: fills columns in order, aiming for equal height.
  static DocxColumnBalance balance({
    required List<DocxColumnBlock> blocks,
    required int columnCount,
  }) {
    final double totalHeight = blocks.fold(0, (s, b) => s + b.height);
    final double targetHeight = totalHeight / columnCount;

    final Map<int, List<String>> columns = {
      for (int i = 0; i < columnCount; i++) i: [],
    };
    final heights = List<double>.filled(columnCount, 0);
    int col = 0;

    for (final block in blocks) {
      columns[col]!.add(block.id);
      heights[col] += block.height;
      if (heights[col] >= targetHeight && col < columnCount - 1) col++;
    }

    return DocxColumnBalance(columns: columns, columnHeights: heights);
  }
}

// ============================================================
// TEXT WRAP AROUND IRREGULAR SHAPES
// ============================================================

/// A 2-D point used for wrap polygon definition.
class DocxWrapPoint {
  final double x;
  final double y;
  const DocxWrapPoint(this.x, this.y);
}

/// An irregular wrap polygon derived from a shape's outline.
class DocxWrapPolygon {
  final List<DocxWrapPoint> points;
  const DocxWrapPolygon(this.points);

  factory DocxWrapPolygon.rectangle(double x, double y, double w, double h) =>
      DocxWrapPolygon([
        DocxWrapPoint(x, y),
        DocxWrapPoint(x + w, y),
        DocxWrapPoint(x + w, y + h),
        DocxWrapPoint(x, y + h),
      ]);

  factory DocxWrapPolygon.ellipse(
      double cx, double cy, double rx, double ry, {int segments = 16}) {
    final pts = <DocxWrapPoint>[];
    for (int i = 0; i < segments; i++) {
      final t = 2 * 3.141592653589793 * i / segments;
      pts.add(DocxWrapPoint(cx + rx * _cos(t), cy + ry * _sin(t)));
    }
    return DocxWrapPolygon(pts);
  }

  static double _cos(double t) {
    // Taylor approximation for cos
    double x = t % (2 * 3.141592653589793);
    return 1 - x * x / 2 + x * x * x * x / 24;
  }

  static double _sin(double t) {
    double x = t % (2 * 3.141592653589793);
    return x - x * x * x / 6 + x * x * x * x * x / 120;
  }
}

/// Computes the horizontal text exclusion zones caused by a wrap polygon at
/// a given vertical scan-line [y].
class DocxIrregularWrapEngine {
  final DocxWrapPolygon polygon;
  final double distanceTop;
  final double distanceBottom;
  final double distanceSide;

  const DocxIrregularWrapEngine({
    required this.polygon,
    this.distanceTop = 114,    // 2pt in twips
    this.distanceBottom = 114,
    this.distanceSide = 114,
  });

  /// Returns [left, right] exclusion x coordinates at scanline [y].
  /// Returns null when the scanline doesn't intersect the polygon.
  (double left, double right)? exclusionAtY(double y) {
    final pts = polygon.points;
    if (pts.length < 2) return null;

    double? minX, maxX;
    for (int i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];
      final minY = a.y < b.y ? a.y : b.y;
      final maxY = a.y > b.y ? a.y : b.y;
      if (y < minY || y > maxY) continue;
      final t = (b.y - a.y) == 0 ? 0.0 : (y - a.y) / (b.y - a.y);
      final ix = a.x + t * (b.x - a.x);
      if (minX == null || ix < minX) minX = ix;
      if (maxX == null || ix > maxX) maxX = ix;
    }
    if (minX == null || maxX == null) return null;
    return (minX - distanceSide, maxX + distanceSide);
  }
}

// ============================================================
// DOCX COMPATIBILITY CHECKER
// ============================================================

/// Severity of a DOCX compatibility issue.
enum DocxCompatSeverity { info, warning, error }

/// A single DOCX compatibility issue.
class DocxCompatIssue {
  final String nodeId;
  final String message;
  final DocxCompatSeverity severity;
  final String ruleId;

  const DocxCompatIssue({
    required this.nodeId,
    required this.message,
    required this.severity,
    required this.ruleId,
  });
}

/// DOCX round-trip compatibility report.
class DocxCompatReport {
  final List<DocxCompatIssue> issues;
  final double compatibilityScore; // 0.0–1.0

  const DocxCompatReport({
    required this.issues,
    required this.compatibilityScore,
  });

  bool get isAbove95Percent => compatibilityScore >= 0.95;
  int get errorCount => issues.where((i) => i.severity == DocxCompatSeverity.error).length;
  int get warningCount => issues.where((i) => i.severity == DocxCompatSeverity.warning).length;
}

/// Checks a document's nodes for DOCX compatibility issues.
class DocxCompatibilityChecker {
  final List<DocxCompatIssue> _issues = [];

  List<DocxCompatIssue> get issues => List.unmodifiable(_issues);

  void checkNode(String nodeId, String nodeType, Map<String, dynamic> properties) {
    // Custom fonts without fallback
    if (nodeType == 'run' &&
        properties['fontFamily'] != null &&
        properties['fontFallback'] == null) {
      _issues.add(DocxCompatIssue(
        nodeId: nodeId,
        message: 'Font "${properties['fontFamily']}" has no fallback — '
            'may not render in Word on systems without this font.',
        severity: DocxCompatSeverity.warning,
        ruleId: 'font-no-fallback',
      ));
    }
    // Absolute positioning beyond page bounds
    if (nodeType == 'float' &&
        (properties['x'] as double? ?? 0) < 0) {
      _issues.add(DocxCompatIssue(
        nodeId: nodeId,
        message: 'Floating object has negative x position — may clip in Word.',
        severity: DocxCompatSeverity.warning,
        ruleId: 'float-negative-pos',
      ));
    }
    // Unsupported field type
    if (nodeType == 'field' &&
        properties['fieldType'] == 'CUSTOM') {
      _issues.add(DocxCompatIssue(
        nodeId: nodeId,
        message: 'Custom field type may not be preserved in Word.',
        severity: DocxCompatSeverity.info,
        ruleId: 'field-custom-type',
      ));
    }
    // Nested tables more than 2 deep
    if (nodeType == 'table' && (properties['nestDepth'] as int? ?? 0) > 2) {
      _issues.add(DocxCompatIssue(
        nodeId: nodeId,
        message: 'Nesting depth > 2 may render incorrectly in older Word versions.',
        severity: DocxCompatSeverity.warning,
        ruleId: 'table-deep-nesting',
      ));
    }
  }

  /// Produce a final compatibility report based on checks run so far.
  DocxCompatReport generateReport({int totalNodes = 1}) {
    final errorWeight = _issues
        .where((i) => i.severity == DocxCompatSeverity.error)
        .length * 0.05;
    final warnWeight = _issues
        .where((i) => i.severity == DocxCompatSeverity.warning)
        .length * 0.01;
    final score = (1.0 - errorWeight - warnWeight).clamp(0.0, 1.0);
    return DocxCompatReport(issues: List.unmodifiable(_issues), compatibilityScore: score);
  }

  void clear() => _issues.clear();
}
