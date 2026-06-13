// ============================================================
// COMPUTATIONAL ENGINE: INTERACTIVE EQUATIONS, LIVE SLIDERS,
// DYNAMIC PLOTS, SYMBOL DEFINITIONS, SYMBOLIC ALGEBRA,
// CALCULUS SOLVING, MATRIX OPERATIONS, STATISTICS
// ============================================================

import 'package:xml/xml.dart';

import 'docx_node.dart';
import 'docx_equation.dart';

// ============================================================
// SYMBOL DEFINITIONS
// ============================================================

/// A named mathematical symbol with optional value and unit.
class DocxSymbolDefinition {
  final String symbol;
  final String description;
  final double? numericValue;
  final String? unit;
  final String? latexRepr;
  final String? domain; // e.g. 'ℝ', 'ℤ', 'ℂ'

  const DocxSymbolDefinition({
    required this.symbol,
    required this.description,
    this.numericValue,
    this.unit,
    this.latexRepr,
    this.domain,
  });

  @override
  String toString() {
    final val = numericValue != null ? ' = $numericValue' : '';
    final u = unit != null ? ' $unit' : '';
    return '$symbol$val$u — $description';
  }
}

/// A symbol table attached to a document or equation block.
class DocxSymbolTable {
  final List<DocxSymbolDefinition> definitions;

  const DocxSymbolTable({this.definitions = const []});

  DocxSymbolDefinition? lookup(String symbol) =>
      definitions.cast<DocxSymbolDefinition?>().firstWhere(
        (d) => d?.symbol == symbol,
        orElse: () => null,
      );

  DocxSymbolTable add(DocxSymbolDefinition def) =>
      DocxSymbolTable(definitions: [...definitions, def]);

  DocxSymbolTable remove(String symbol) => DocxSymbolTable(
        definitions: definitions.where((d) => d.symbol != symbol).toList(),
      );
}

// ============================================================
// LIVE PARAMETER SLIDER
// ============================================================

/// A parameter that can be adjusted interactively via a slider.
class DocxParameterSlider {
  final String parameterId;
  final String label;
  final double min;
  final double max;
  final double step;
  final double defaultValue;
  final String? unit;

  const DocxParameterSlider({
    required this.parameterId,
    required this.label,
    required this.min,
    required this.max,
    this.step = 0.1,
    required this.defaultValue,
    this.unit,
  });

  double clamp(double value) =>
      (value < min ? min : (value > max ? max : value));

  double snap(double value) {
    if (step <= 0) return clamp(value);
    final snapped = (value / step).round() * step;
    return clamp(snapped);
  }
}

// ============================================================
// DYNAMIC PLOT
// ============================================================

/// A plot whose functions reference live parameter values.
class DocxDynamicPlot extends DocxBlock {
  /// Parametric expression strings, e.g. 'a * sin(b * x)'
  final List<String> expressions;
  final List<DocxParameterSlider> sliders;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final String? title;
  final int widthEmu;
  final int heightEmu;

  const DocxDynamicPlot({
    required this.expressions,
    required this.sliders,
    this.xMin = -10,
    this.xMax = 10,
    this.yMin = -10,
    this.yMax = 10,
    this.title,
    this.widthEmu = 3429000,
    this.heightEmu = 2286000,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Dynamic Plot: ${expressions.join(', ')}'
              ' | sliders: ${sliders.map((s) => s.parameterId).join(', ')}'
              '${title != null ? " – $title" : ""}]');
        });
      });
    });
  }
}

// ============================================================
// INTERACTIVE EQUATION (LINKED TO GRAPH)
// ============================================================

/// An equation block whose parameters can be tuned via sliders,
/// with a live graph that updates when parameters change.
class DocxInteractiveEquation extends DocxBlock {
  final DocxEquation equation;
  final List<DocxParameterSlider> sliders;
  final DocxDynamicPlot? linkedPlot;
  final DocxSymbolTable symbolTable;
  final String? description;

  const DocxInteractiveEquation({
    required this.equation,
    this.sliders = const [],
    this.linkedPlot,
    this.symbolTable = const DocxSymbolTable(),
    this.description,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    // Render the equation
    equation.buildXml(builder);
    // Render the slider annotations as a paragraph
    if (sliders.isNotEmpty) {
      builder.element('w:p', nest: () {
        builder.element('w:r', nest: () {
          builder.element('w:t', nest: () {
            final sliderStr = sliders
                .map((s) => '${s.label}: [${s.min}..${s.max}]')
                .join(', ');
            builder.text('[Parameters: $sliderStr]');
          });
        });
      });
    }
    // Render the linked plot if present
    linkedPlot?.buildXml(builder);
  }
}

// ============================================================
// COMPUTATIONAL ENGINE (STUBS)
// ============================================================

/// Result of a symbolic computation.
class DocxComputeResult {
  final String expression;
  final String? simplified;
  final double? numericValue;
  final String? steps;
  final bool success;
  final String? error;

  const DocxComputeResult({
    required this.expression,
    this.simplified,
    this.numericValue,
    this.steps,
    this.success = true,
    this.error,
  });
}

/// Abstract computational engine interface.
///
/// Concrete implementations may delegate to a CAS (Computer Algebra System)
/// such as SymPy (via FFI/process), Maxima, or a pure-Dart math library.
abstract class DocxComputationalEngine {
  // ---- Symbolic Algebra ----

  /// Simplify an expression string.
  Future<DocxComputeResult> simplify(String expression);

  /// Expand an expression (e.g. (x+1)² → x²+2x+1).
  Future<DocxComputeResult> expand(String expression);

  /// Factor an expression.
  Future<DocxComputeResult> factor(String expression);

  /// Solve an equation for a variable.
  Future<List<DocxComputeResult>> solve(String equation, String variable);

  // ---- Calculus ----

  /// Differentiate with respect to a variable.
  Future<DocxComputeResult> differentiate(String expression, String variable,
      {int order = 1});

  /// Indefinite integral.
  Future<DocxComputeResult> integrate(String expression, String variable);

  /// Definite integral from [from] to [to].
  Future<DocxComputeResult> definiteIntegral(
      String expression, String variable, double from, double to);

  // ---- Matrix Operations ----

  /// Multiply two matrices.
  Future<List<List<double>>> matrixMultiply(
      List<List<double>> a, List<List<double>> b);

  /// Compute matrix determinant.
  Future<double> determinant(List<List<double>> matrix);

  /// Compute matrix inverse.
  Future<List<List<double>>> inverse(List<List<double>> matrix);

  /// Compute eigenvalues.
  Future<List<double>> eigenvalues(List<List<double>> matrix);

  // ---- Statistics ----

  /// Descriptive statistics for a dataset.
  Future<DocxDescriptiveStats> describe(List<double> data);

  /// Linear regression (returns [slope, intercept]).
  Future<(double slope, double intercept)> linearRegression(
      List<double> x, List<double> y);

  /// Pearson correlation coefficient.
  Future<double> correlation(List<double> x, List<double> y);
}

/// Descriptive statistics result.
class DocxDescriptiveStats {
  final double mean;
  final double median;
  final double stdDev;
  final double variance;
  final double min;
  final double max;
  final double range;
  final double skewness;
  final double kurtosis;
  final int count;

  const DocxDescriptiveStats({
    required this.mean,
    required this.median,
    required this.stdDev,
    required this.variance,
    required this.min,
    required this.max,
    required this.range,
    required this.skewness,
    required this.kurtosis,
    required this.count,
  });

  /// Compute descriptive stats from a list of doubles.
  factory DocxDescriptiveStats.fromData(List<double> data) {
    if (data.isEmpty) {
      return const DocxDescriptiveStats(
        mean: 0, median: 0, stdDev: 0, variance: 0,
        min: 0, max: 0, range: 0, skewness: 0, kurtosis: 0, count: 0,
      );
    }
    final n = data.length;
    final sorted = [...data]..sort();
    final mean = data.reduce((a, b) => a + b) / n;
    final median = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    final variance =
        data.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / n;
    final stdDev = _sqrt(variance);
    final min = sorted.first;
    final max = sorted.last;

    // Skewness (Fisher–Pearson)
    final m3 = data.map((v) {
      final d = v - mean;
      return d * d * d;
    }).reduce((a, b) => a + b) / n;
    final skewness = stdDev == 0 ? 0.0 : m3 / (stdDev * stdDev * stdDev);

    // Excess kurtosis
    final m4 = data.map((v) {
      final d = v - mean;
      return d * d * d * d;
    }).reduce((a, b) => a + b) / n;
    final kurtosis = stdDev == 0 ? 0.0 : m4 / (variance * variance) - 3;

    return DocxDescriptiveStats(
      mean: mean,
      median: median,
      stdDev: stdDev,
      variance: variance,
      min: min,
      max: max,
      range: max - min,
      skewness: skewness,
      kurtosis: kurtosis,
      count: n,
    );
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double g = x / 2;
    for (int i = 0; i < 20; i++) { g = (g + x / g) / 2; }
    return g;
  }
}

/// Pure-Dart stub implementation of [DocxComputationalEngine].
///
/// Returns placeholder results; real CAS integration requires an FFI
/// bridge to SymPy/Maxima or an embedded expression parser.
class DocxStubComputationalEngine extends DocxComputationalEngine {
  @override
  Future<DocxComputeResult> simplify(String expression) async =>
      DocxComputeResult(expression: expression, simplified: expression, success: true);

  @override
  Future<DocxComputeResult> expand(String expression) async =>
      DocxComputeResult(expression: expression, simplified: expression, success: true);

  @override
  Future<DocxComputeResult> factor(String expression) async =>
      DocxComputeResult(expression: expression, simplified: expression, success: true);

  @override
  Future<List<DocxComputeResult>> solve(String equation, String variable) async =>
      [DocxComputeResult(
        expression: equation,
        error: 'CAS not available — install a SymPy bridge for symbolic solving.',
        success: false,
      )];

  @override
  Future<DocxComputeResult> differentiate(String expression, String variable,
      {int order = 1}) async =>
      DocxComputeResult(expression: 'd($expression)/d$variable', success: true);

  @override
  Future<DocxComputeResult> integrate(String expression, String variable) async =>
      DocxComputeResult(expression: '∫($expression)d$variable', success: true);

  @override
  Future<DocxComputeResult> definiteIntegral(
      String expression, String variable, double from, double to) async =>
      DocxComputeResult(expression: '∫_{$from}^{$to}($expression)d$variable',
          success: true);

  @override
  Future<List<List<double>>> matrixMultiply(
      List<List<double>> a, List<List<double>> b) async {
    final rows = a.length;
    final cols = b.isNotEmpty ? b.first.length : 0;
    final inner = b.length;
    final result = List.generate(rows, (_) => List<double>.filled(cols, 0));
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        for (int k = 0; k < inner; k++) {
          result[i][j] += a[i][k] * b[k][j];
        }
      }
    }
    return result;
  }

  @override
  Future<double> determinant(List<List<double>> matrix) async {
    final n = matrix.length;
    if (n == 1) return matrix[0][0];
    if (n == 2) {
      return matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0];
    }
    // Laplace expansion (stub for n>2)
    double det = 0;
    for (int j = 0; j < n; j++) {
      final minor = [
        for (int i = 1; i < n; i++)
          [for (int k = 0; k < n; k++) if (k != j) matrix[i][k]]
      ];
      final sign = j.isEven ? 1.0 : -1.0;
      det += sign * matrix[0][j] * (await determinant(minor));
    }
    return det;
  }

  @override
  Future<List<List<double>>> inverse(List<List<double>> matrix) async =>
      matrix; // stub

  @override
  Future<List<double>> eigenvalues(List<List<double>> matrix) async =>
      List<double>.filled(matrix.length, 0); // stub

  @override
  Future<DocxDescriptiveStats> describe(List<double> data) async =>
      DocxDescriptiveStats.fromData(data);

  @override
  Future<(double, double)> linearRegression(
      List<double> x, List<double> y) async {
    final n = x.length;
    if (n < 2) return (0.0, 0.0);
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;
    double num = 0, den = 0;
    for (int i = 0; i < n; i++) {
      num += (x[i] - meanX) * (y[i] - meanY);
      den += (x[i] - meanX) * (x[i] - meanX);
    }
    final slope = den == 0 ? 0.0 : num / den;
    final intercept = meanY - slope * meanX;
    return (slope, intercept);
  }

  @override
  Future<double> correlation(List<double> x, List<double> y) async {
    final (slope, _) = await linearRegression(x, y);
    final n = x.length;
    if (n < 2) return 0;
    final sdX = DocxDescriptiveStats.fromData(x).stdDev;
    final sdY = DocxDescriptiveStats.fromData(y).stdDev;
    return sdY == 0 ? 0 : slope * sdX / sdY;
  }
}
