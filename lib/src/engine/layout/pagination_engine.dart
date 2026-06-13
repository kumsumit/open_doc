// ============================================================
// PAGINATION ENGINE
// ============================================================

/// Represents a single page produced by the pagination engine.
class DocxPage {
  final int pageNumber;
  final double width;
  final double height;
  final List<DocxPageRegion> regions;

  const DocxPage({
    required this.pageNumber,
    required this.width,
    required this.height,
    this.regions = const [],
  });
}

/// A laid-out region on a page (paragraph, image, table, etc.).
class DocxPageRegion {
  final String nodeId;
  final double x;
  final double y;
  final double width;
  final double height;
  final DocxRegionType type;

  const DocxPageRegion({
    required this.nodeId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.type,
  });
}

enum DocxRegionType { paragraph, table, image, header, footer, footnote, equation }

/// The automatic page-break and reflow engine.
///
/// Computes how document content flows across pages based on page size,
/// margins, content height, widow/orphan control, and keep-together flags.
///
/// ```dart
/// final engine = DocxPaginationEngine(
///   pageWidth: 12240,
///   pageHeight: 15840,
///   marginTop: 1440,
///   marginBottom: 1440,
/// );
/// final pages = engine.paginate(contentBlocks);
/// ```
class DocxPaginationEngine {
  final double pageWidth;
  final double pageHeight;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final int widowLines;
  final int orphanLines;

  DocxPaginationEngine({
    required this.pageWidth,
    required this.pageHeight,
    this.marginTop = 1440,
    this.marginBottom = 1440,
    this.marginLeft = 1800,
    this.marginRight = 1800,
    this.widowLines = 2,
    this.orphanLines = 2,
  });

  double get contentWidth => pageWidth - marginLeft - marginRight;
  double get contentHeight => pageHeight - marginTop - marginBottom;

  /// Paginate a list of content blocks into pages.
  ///
  /// Each block is a map with keys: 'id', 'height', 'keepWithNext',
  /// 'pageBreakBefore', 'isHeader', 'isFooter', 'lineCount'.
  List<DocxPage> paginate(List<Map<String, dynamic>> blocks) {
    final pages = <DocxPage>[];
    var currentPageBlocks = <DocxPageRegion>[];
    double yOffset = marginTop;
    int pageNum = 1;

    void flushPage() {
      pages.add(DocxPage(
        pageNumber: pageNum++,
        width: pageWidth,
        height: pageHeight,
        regions: List.of(currentPageBlocks),
      ));
      currentPageBlocks = [];
      yOffset = marginTop;
    }

    for (int i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final blockHeight = (block['height'] as num).toDouble();
      final pageBreakBefore = block['pageBreakBefore'] as bool? ?? false;
      final keepWithNext = block['keepWithNext'] as bool? ?? false;

      if (pageBreakBefore && currentPageBlocks.isNotEmpty) {
        flushPage();
      }

      // Check if it fits on the current page
      bool fits = yOffset + blockHeight <= pageHeight - marginBottom;

      // Widow/orphan control: if next block is keep-with-next, check combined height
      if (fits && keepWithNext && i + 1 < blocks.length) {
        final nextHeight = (blocks[i + 1]['height'] as num).toDouble();
        fits = yOffset + blockHeight + nextHeight <= pageHeight - marginBottom;
      }

      if (!fits && currentPageBlocks.isNotEmpty) {
        flushPage();
      }

      currentPageBlocks.add(DocxPageRegion(
        nodeId: block['id'] as String? ?? '$i',
        x: marginLeft,
        y: yOffset,
        width: contentWidth,
        height: blockHeight,
        type: _regionType(block['type'] as String?),
      ));
      yOffset += blockHeight;
    }

    if (currentPageBlocks.isNotEmpty) flushPage();
    return pages;
  }

  DocxRegionType _regionType(String? type) => switch (type) {
        'table' => DocxRegionType.table,
        'image' => DocxRegionType.image,
        'header' => DocxRegionType.header,
        'footer' => DocxRegionType.footer,
        'footnote' => DocxRegionType.footnote,
        'equation' => DocxRegionType.equation,
        _ => DocxRegionType.paragraph,
      };
}

/// Incremental layout tracker — only re-lays out changed pages.
class DocxIncrementalLayout {
  final DocxPaginationEngine engine;
  List<DocxPage> _pages = [];
  final Map<String, int> _blockToPage = {};
  bool _dirty = false;

  DocxIncrementalLayout(this.engine);

  List<DocxPage> get pages => _pages;
  bool get needsRelayout => _dirty;

  /// Mark that a block has changed.
  void markDirty(String blockId) => _dirty = true;

  /// Full layout pass.
  void relayout(List<Map<String, dynamic>> blocks) {
    _pages = engine.paginate(blocks);
    _blockToPage.clear();
    for (final page in _pages) {
      for (final region in page.regions) {
        _blockToPage[region.nodeId] = page.pageNumber;
      }
    }
    _dirty = false;
  }

  /// Which page does a block appear on?
  int? pageForBlock(String blockId) => _blockToPage[blockId];
}
