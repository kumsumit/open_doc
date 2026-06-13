// ============================================================
// EXTENDED CHARTS: BOX PLOT, VIOLIN PLOT, HEATMAP,
// LOGARITHMIC SCALE, ERROR BARS
// ============================================================

import 'package:xml/xml.dart';

import 'docx_node.dart';

// ============================================================
// SHARED TYPES
// ============================================================

/// Scale type for a chart axis.
enum DocxAxisScale { linear, logarithmic, symLog, sqrt }

/// Error bar style.
enum DocxErrorBarStyle { standard, standardDeviation, confidence95, custom }

/// Error bar definition for a data series.
class DocxErrorBar {
  final DocxErrorBarStyle style;
  final List<double>? plusValues;  // per-point positive error (custom)
  final List<double>? minusValues; // per-point negative error (custom)
  final double? fixedValue;        // used for standard/stddev
  final String color;
  final double lineWidth;
  final bool showCaps;

  const DocxErrorBar({
    this.style = DocxErrorBarStyle.standard,
    this.plusValues,
    this.minusValues,
    this.fixedValue,
    this.color = '000000',
    this.lineWidth = 1.0,
    this.showCaps = true,
  });

  /// Compute ± values from a data list for standard deviation bars.
  static (double, double) stddev(List<double> data) {
    if (data.isEmpty) return (0, 0);
    final mean = data.reduce((a, b) => a + b) / data.length;
    final variance = data.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / data.length;
    final sd = variance == 0 ? 0 : _sqrt(variance);
    return (mean + sd, mean - sd);
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 20; i++) { g = (g + x / g) / 2; }
    return g;
  }
}

/// A single data series with optional error bars and log scale config.
class DocxExtendedSeries {
  final String name;
  final List<double> values;
  final String color;
  final DocxErrorBar? errorBars;

  const DocxExtendedSeries({
    required this.name,
    required this.values,
    this.color = '4472C4',
    this.errorBars,
  });
}

// ============================================================
// BOX PLOT
// ============================================================

/// Five-number summary for a box plot.
class DocxBoxStats {
  final double min;
  final double q1;
  final double median;
  final double q3;
  final double max;
  final List<double> outliers;

  const DocxBoxStats({
    required this.min,
    required this.q1,
    required this.median,
    required this.q3,
    required this.max,
    this.outliers = const [],
  });

  factory DocxBoxStats.fromData(List<double> data) {
    if (data.isEmpty) {
      return const DocxBoxStats(min: 0, q1: 0, median: 0, q3: 0, max: 0);
    }
    final sorted = [...data]..sort();
    double percentile(double p) {
      final idx = p * (sorted.length - 1);
      final lo = idx.floor();
      final hi = idx.ceil();
      if (lo == hi) return sorted[lo];
      return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo);
    }
    final q1 = percentile(0.25);
    final q3 = percentile(0.75);
    final iqr = q3 - q1;
    final lowerFence = q1 - 1.5 * iqr;
    final upperFence = q3 + 1.5 * iqr;
    final inliers = sorted.where((v) => v >= lowerFence && v <= upperFence).toList();
    final outliers = sorted.where((v) => v < lowerFence || v > upperFence).toList();
    return DocxBoxStats(
      min: inliers.isNotEmpty ? inliers.first : sorted.first,
      q1: q1,
      median: percentile(0.5),
      q3: q3,
      max: inliers.isNotEmpty ? inliers.last : sorted.last,
      outliers: outliers,
    );
  }
}

/// A box plot (box-and-whisker) chart.
class DocxBoxPlot extends DocxBlock {
  final List<String> categories;
  final List<List<double>> dataSets; // one list per category
  final List<String> colors;
  final String? title;
  final String? yAxisLabel;
  final DocxAxisScale yScale;
  final int widthEmu;
  final int heightEmu;

  const DocxBoxPlot({
    required this.categories,
    required this.dataSets,
    this.colors = const ['4472C4', 'ED7D31', 'A9D18E'],
    this.title,
    this.yAxisLabel,
    this.yScale = DocxAxisScale.linear,
    this.widthEmu = 3429000,
    this.heightEmu = 2286000,
    super.id,
  });

  List<DocxBoxStats> get stats =>
      dataSets.map(DocxBoxStats.fromData).toList();

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Box Plot: ${categories.join(', ')}'
              '${title != null ? " – $title" : ""}]');
        });
      });
    });
  }
}

// ============================================================
// VIOLIN PLOT
// ============================================================

/// A single violin (kernel density estimate wrapper) for a category.
class DocxViolin {
  final String category;
  final List<double> data;
  final String color;
  final bool showBoxPlot; // overlay box plot inside the violin

  const DocxViolin({
    required this.category,
    required this.data,
    this.color = '4472C4',
    this.showBoxPlot = true,
  });

  DocxBoxStats get boxStats => DocxBoxStats.fromData(data);

  /// Rough kernel density estimate at a grid of y-values.
  List<(double y, double density)> kernelDensity({int steps = 40}) {
    if (data.isEmpty) return [];
    final minV = data.reduce((a, b) => a < b ? a : b);
    final maxV = data.reduce((a, b) => a > b ? a : b);
    final bandwidth = (maxV - minV) / 8;
    if (bandwidth == 0) return [(minV, 1.0)];
    final result = <(double, double)>[];
    for (int i = 0; i <= steps; i++) {
      final y = minV + (maxV - minV) * i / steps;
      double d = 0;
      for (final v in data) {
        final u = (y - v) / bandwidth;
        // Gaussian kernel: exp(-u²/2) / √(2π)
        d += _exp(-u * u / 2) / 2.5066;
      }
      result.add((y, d / (data.length * bandwidth)));
    }
    return result;
  }

  static double _exp(double x) {
    if (x < -20) return 0;
    double r = 1;
    double term = 1;
    for (int i = 1; i <= 15; i++) {
      term *= x / i;
      r += term;
    }
    return r;
  }
}

/// A violin plot showing distribution shape per category.
class DocxViolinPlot extends DocxBlock {
  final List<DocxViolin> violins;
  final String? title;
  final String? yAxisLabel;
  final DocxAxisScale yScale;
  final int widthEmu;
  final int heightEmu;

  const DocxViolinPlot({
    required this.violins,
    this.title,
    this.yAxisLabel,
    this.yScale = DocxAxisScale.linear,
    this.widthEmu = 3429000,
    this.heightEmu = 2286000,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    final cats = violins.map((v) => v.category).join(', ');
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Violin Plot: $cats'
              '${title != null ? " – $title" : ""}]');
        });
      });
    });
  }
}

// ============================================================
// HEATMAP
// ============================================================

/// A single cell in the heatmap grid.
class DocxHeatmapCell {
  final int row;
  final int col;
  final double value;

  const DocxHeatmapCell({
    required this.row,
    required this.col,
    required this.value,
  });
}

/// Color scale definition for a heatmap.
class DocxHeatmapColorScale {
  final String lowColor;   // hex, e.g. 'FFFFFF' (white)
  final String midColor;   // optional midpoint color
  final String highColor;  // hex, e.g. '2F5496' (dark blue)
  final bool hasMidpoint;

  const DocxHeatmapColorScale({
    this.lowColor = 'FFFFFF',
    this.midColor = 'FFFF00',
    this.highColor = '2F5496',
    this.hasMidpoint = false,
  });

  static const DocxHeatmapColorScale blueWhiteRed = DocxHeatmapColorScale(
    lowColor: '2F5496', midColor: 'FFFFFF', highColor: 'C00000', hasMidpoint: true,
  );
  static const DocxHeatmapColorScale viridis = DocxHeatmapColorScale(
    lowColor: '440154', midColor: '21918C', highColor: 'FDE725',
  );
  static const DocxHeatmapColorScale greenYellowRed = DocxHeatmapColorScale(
    lowColor: '00B050', midColor: 'FFFF00', highColor: 'FF0000', hasMidpoint: true,
  );
}

/// A heatmap (2D grid with colour-coded values).
class DocxHeatmap extends DocxBlock {
  final List<String> rowLabels;
  final List<String> colLabels;
  final List<DocxHeatmapCell> cells;
  final DocxHeatmapColorScale colorScale;
  final String? title;
  final bool showValues;
  final int widthEmu;
  final int heightEmu;

  const DocxHeatmap({
    required this.rowLabels,
    required this.colLabels,
    required this.cells,
    this.colorScale = const DocxHeatmapColorScale(),
    this.title,
    this.showValues = true,
    this.widthEmu = 3429000,
    this.heightEmu = 3429000,
    super.id,
  });

  factory DocxHeatmap.fromMatrix({
    required List<List<double>> matrix,
    required List<String> rowLabels,
    required List<String> colLabels,
    DocxHeatmapColorScale colorScale = const DocxHeatmapColorScale(),
    String? title,
  }) {
    final cells = <DocxHeatmapCell>[];
    for (int r = 0; r < matrix.length; r++) {
      for (int c = 0; c < matrix[r].length; c++) {
        cells.add(DocxHeatmapCell(row: r, col: c, value: matrix[r][c]));
      }
    }
    return DocxHeatmap(
      rowLabels: rowLabels,
      colLabels: colLabels,
      cells: cells,
      colorScale: colorScale,
      title: title,
    );
  }

  double get minValue =>
      cells.isEmpty ? 0 : cells.map((c) => c.value).reduce((a, b) => a < b ? a : b);
  double get maxValue =>
      cells.isEmpty ? 1 : cells.map((c) => c.value).reduce((a, b) => a > b ? a : b);

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Heatmap: ${rowLabels.length}×${colLabels.length}'
              '${title != null ? " – $title" : ""}]');
        });
      });
    });
  }
}

// ============================================================
// LOG-SCALE AXIS EXTENSION
// ============================================================

/// Extended axis configuration supporting logarithmic scale and error bars.
class DocxExtendedAxis {
  final String title;
  final double? min;
  final double? max;
  final DocxAxisScale scale;
  final double? logBase; // for logarithmic scale (default 10)
  final bool showMajorGridLines;
  final bool showMinorGridLines;
  final String? numberFormat;

  const DocxExtendedAxis({
    this.title = '',
    this.min,
    this.max,
    this.scale = DocxAxisScale.linear,
    this.logBase = 10,
    this.showMajorGridLines = true,
    this.showMinorGridLines = false,
    this.numberFormat,
  });

  bool get isLogarithmic => scale == DocxAxisScale.logarithmic;

  /// Build DrawingML axis XML with log scale settings.
  void buildXml(XmlBuilder builder, String axisId, String crossAxisId, bool isX) {
    final elemName = isX ? 'c:catAx' : 'c:valAx';
    builder.element(elemName, nest: () {
      builder.element('c:axId', nest: () => builder.attribute('val', axisId));
      builder.element('c:scaling', nest: () {
        if (isLogarithmic) {
          builder.element('c:logBase', nest: () =>
              builder.attribute('val', (logBase ?? 10).toString()));
        }
        if (min != null) {
          builder.element('c:min', nest: () =>
              builder.attribute('val', min.toString()));
        }
        if (max != null) {
          builder.element('c:max', nest: () =>
              builder.attribute('val', max.toString()));
        }
        builder.element('c:orientation', nest: () =>
            builder.attribute('val', 'minMax'));
      });
      builder.element('c:title', nest: () {
        builder.element('c:tx', nest: () {
          builder.element('c:rich', nest: () {
            builder.element('a:p', nest: () {
              builder.element('a:r', nest: () {
                builder.element('a:t', nest: () => builder.text(title));
              });
            });
          });
        });
      });
      builder.element('c:crossAx', nest: () =>
          builder.attribute('val', crossAxisId));
    });
  }
}
