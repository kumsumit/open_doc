import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_node.dart';

// ============================================================
// MATH ELEMENT BASE
// ============================================================

/// Base class for all math elements (OMML / MathML).
abstract class DocxMathElement {
  const DocxMathElement();

  /// Writes Office Math Markup Language (OMML) XML.
  void buildOmml(XmlBuilder builder);

  /// Converts to LaTeX string.
  String toLatex();

  /// Converts to MathML string.
  String toMathML();
}

// ============================================================
// MATH RUN (PLAIN TEXT IN AN EQUATION)
// ============================================================

/// A plain text/symbol run inside an equation.
class DocxMathRun extends DocxMathElement {
  final String text;
  final bool italic;
  final bool bold;

  const DocxMathRun(this.text, {this.italic = true, this.bold = false});

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:r', nest: () {
      builder.element('m:rPr', nest: () {
        if (!italic) {
          builder.element('m:nor');
        }
        if (bold) {
          builder.element('m:b', nest: () {
            builder.attribute('m:val', '1');
          });
        }
      });
      builder.element('m:t', nest: () {
        builder.text(text);
      });
    });
  }

  @override
  String toLatex() => text;

  @override
  String toMathML() => '<mi${italic ? '' : ' mathvariant="normal"'}>$text</mi>';
}

// ============================================================
// FRACTION
// ============================================================

/// A fraction: numerator / denominator.
///
/// ```dart
/// DocxFraction(
///   numerator: DocxMathRun('x'),
///   denominator: DocxMathRun('y'),
/// )
/// ```
class DocxFraction extends DocxMathElement {
  final DocxMathElement numerator;
  final DocxMathElement denominator;
  final bool displayStyle; // false = inline slash fraction

  const DocxFraction({
    required this.numerator,
    required this.denominator,
    this.displayStyle = true,
  });

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:f', nest: () {
      if (!displayStyle) {
        builder.element('m:fPr', nest: () {
          builder.element('m:type', nest: () {
            builder.attribute('m:val', 'lin');
          });
        });
      }
      builder.element('m:num', nest: () => numerator.buildOmml(builder));
      builder.element('m:den', nest: () => denominator.buildOmml(builder));
    });
  }

  @override
  String toLatex() {
    if (displayStyle) return '\\frac{${numerator.toLatex()}}{${denominator.toLatex()}}';
    return '${numerator.toLatex()}/${denominator.toLatex()}';
  }

  @override
  String toMathML() =>
      '<mfrac><mrow>${numerator.toMathML()}</mrow><mrow>${denominator.toMathML()}</mrow></mfrac>';
}

// ============================================================
// RADICAL / ROOT
// ============================================================

/// A square root or nth root.
///
/// ```dart
/// DocxRadical(base: DocxMathRun('x'))                    // √x
/// DocxRadical(base: DocxMathRun('x'), degree: DocxMathRun('3')) // ∛x
/// ```
class DocxRadical extends DocxMathElement {
  final DocxMathElement base;
  final DocxMathElement? degree; // null = square root

  const DocxRadical({required this.base, this.degree});

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:rad', nest: () {
      if (degree == null) {
        builder.element('m:radPr', nest: () {
          builder.element('m:degHide', nest: () {
            builder.attribute('m:val', '1');
          });
        });
        builder.element('m:deg');
      } else {
        builder.element('m:deg', nest: () => degree!.buildOmml(builder));
      }
      builder.element('m:e', nest: () => base.buildOmml(builder));
    });
  }

  @override
  String toLatex() {
    if (degree == null) return '\\sqrt{${base.toLatex()}}';
    return '\\sqrt[${degree!.toLatex()}]{${base.toLatex()}}';
  }

  @override
  String toMathML() {
    if (degree == null) {
      return '<msqrt><mrow>${base.toMathML()}</mrow></msqrt>';
    }
    return '<mroot><mrow>${base.toMathML()}</mrow><mrow>${degree!.toMathML()}</mrow></mroot>';
  }
}

// ============================================================
// SUPERSCRIPT / SUBSCRIPT
// ============================================================

/// Superscript (x^n).
class DocxSuperscript extends DocxMathElement {
  final DocxMathElement base;
  final DocxMathElement exponent;

  const DocxSuperscript({required this.base, required this.exponent});

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:sSup', nest: () {
      builder.element('m:e', nest: () => base.buildOmml(builder));
      builder.element('m:sup', nest: () => exponent.buildOmml(builder));
    });
  }

  @override
  String toLatex() => '{${base.toLatex()}}^{${exponent.toLatex()}}';

  @override
  String toMathML() =>
      '<msup><mrow>${base.toMathML()}</mrow><mrow>${exponent.toMathML()}</mrow></msup>';
}

/// Subscript (x_n).
class DocxSubscript extends DocxMathElement {
  final DocxMathElement base;
  final DocxMathElement subscript;

  const DocxSubscript({required this.base, required this.subscript});

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:sSub', nest: () {
      builder.element('m:e', nest: () => base.buildOmml(builder));
      builder.element('m:sub', nest: () => subscript.buildOmml(builder));
    });
  }

  @override
  String toLatex() => '{${base.toLatex()}}_{${subscript.toLatex()}}';

  @override
  String toMathML() =>
      '<msub><mrow>${base.toMathML()}</mrow><mrow>${subscript.toMathML()}</mrow></msub>';
}

/// Combined super + subscript (x_m^n).
class DocxSubSuperscript extends DocxMathElement {
  final DocxMathElement base;
  final DocxMathElement sub;
  final DocxMathElement sup;

  const DocxSubSuperscript({
    required this.base,
    required this.sub,
    required this.sup,
  });

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:sSubSup', nest: () {
      builder.element('m:e', nest: () => base.buildOmml(builder));
      builder.element('m:sub', nest: () => sub.buildOmml(builder));
      builder.element('m:sup', nest: () => sup.buildOmml(builder));
    });
  }

  @override
  String toLatex() => '{${base.toLatex()}}_{${sub.toLatex()}}^{${sup.toLatex()}}';

  @override
  String toMathML() =>
      '<msubsup><mrow>${base.toMathML()}</mrow><mrow>${sub.toMathML()}</mrow><mrow>${sup.toMathML()}</mrow></msubsup>';
}

// ============================================================
// N-ARY OPERATORS (INTEGRAL, SUMMATION, PRODUCT, ETC.)
// ============================================================

/// N-ary operator (integral, sum, product, union, intersection, etc.).
///
/// ```dart
/// // Integral ∫_a^b f(x) dx
/// DocxNary(
///   chr: '∫',
///   lower: DocxMathRun('a'),
///   upper: DocxMathRun('b'),
///   body: DocxMathGroup([DocxMathRun('f(x)dx')]),
/// )
///
/// // Sum ∑_{i=0}^{n}
/// DocxNary(
///   chr: '∑',
///   lower: DocxMathRun('i=0'),
///   upper: DocxMathRun('n'),
///   body: DocxMathRun('i'),
/// )
/// ```
class DocxNary extends DocxMathElement {
  /// The operator character (∫, ∑, ∏, ∪, ∩, etc.)
  final String chr;
  final DocxMathElement? lower;
  final DocxMathElement? upper;
  final DocxMathElement body;
  final bool limLocUndOvr; // limits above/below vs. sub/superscript

  const DocxNary({
    required this.chr,
    this.lower,
    this.upper,
    required this.body,
    this.limLocUndOvr = false,
  });

  static DocxNary integral({
    DocxMathElement? from,
    DocxMathElement? to,
    required DocxMathElement body,
  }) =>
      DocxNary(chr: '∫', lower: from, upper: to, body: body);

  static DocxNary doubleIntegral({required DocxMathElement body}) =>
      DocxNary(chr: '∬', body: body);

  static DocxNary tripleIntegral({required DocxMathElement body}) =>
      DocxNary(chr: '∭', body: body);

  static DocxNary closedContourIntegral({required DocxMathElement body}) =>
      DocxNary(chr: '∮', body: body);

  static DocxNary surfaceIntegral({required DocxMathElement body}) =>
      DocxNary(chr: '∯', body: body);

  static DocxNary volumeIntegral({required DocxMathElement body}) =>
      DocxNary(chr: '∰', body: body);

  static DocxNary sum({
    DocxMathElement? from,
    DocxMathElement? to,
    required DocxMathElement body,
  }) =>
      DocxNary(chr: '∑', lower: from, upper: to, body: body, limLocUndOvr: true);

  static DocxNary product({
    DocxMathElement? from,
    DocxMathElement? to,
    required DocxMathElement body,
  }) =>
      DocxNary(chr: '∏', lower: from, upper: to, body: body, limLocUndOvr: true);

  static DocxNary union({
    DocxMathElement? from,
    DocxMathElement? to,
    required DocxMathElement body,
  }) =>
      DocxNary(chr: '⋃', lower: from, upper: to, body: body, limLocUndOvr: true);

  static DocxNary intersection({
    DocxMathElement? from,
    DocxMathElement? to,
    required DocxMathElement body,
  }) =>
      DocxNary(chr: '⋂', lower: from, upper: to, body: body, limLocUndOvr: true);

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:nary', nest: () {
      builder.element('m:naryPr', nest: () {
        builder.element('m:chr', nest: () {
          builder.attribute('m:val', chr);
        });
        if (limLocUndOvr) {
          builder.element('m:limLoc', nest: () {
            builder.attribute('m:val', 'undOvr');
          });
        }
        if (lower == null) {
          builder.element('m:subHide', nest: () {
            builder.attribute('m:val', '1');
          });
        }
        if (upper == null) {
          builder.element('m:supHide', nest: () {
            builder.attribute('m:val', '1');
          });
        }
      });
      builder.element('m:sub', nest: () {
        if (lower != null) lower!.buildOmml(builder);
      });
      builder.element('m:sup', nest: () {
        if (upper != null) upper!.buildOmml(builder);
      });
      builder.element('m:e', nest: () => body.buildOmml(builder));
    });
  }

  @override
  String toLatex() {
    final op = switch (chr) {
      '∫' => '\\int',
      '∬' => '\\iint',
      '∭' => '\\iiint',
      '∮' => '\\oint',
      '∯' => '\\oiint',
      '∰' => '\\oiiint',
      '∑' => '\\sum',
      '∏' => '\\prod',
      '⋃' => '\\bigcup',
      '⋂' => '\\bigcap',
      _ => chr,
    };
    final fromStr = lower != null ? '_{${lower!.toLatex()}}' : '';
    final toStr = upper != null ? '^{${upper!.toLatex()}}' : '';
    return '$op$fromStr$toStr{${body.toLatex()}}';
  }

  @override
  String toMathML() {
    final opChar = chr;
    if (lower != null || upper != null) {
      return '<munderover><mo>$opChar</mo><mrow>${lower?.toMathML() ?? ''}</mrow><mrow>${upper?.toMathML() ?? ''}</mrow></munderover><mrow>${body.toMathML()}</mrow>';
    }
    return '<mo>$opChar</mo><mrow>${body.toMathML()}</mrow>';
  }
}

// ============================================================
// MATRIX
// ============================================================

/// A matrix (can represent: matrix, determinant, piecewise, augmented).
///
/// ```dart
/// DocxMatrix(
///   rows: [
///     [DocxMathRun('a'), DocxMathRun('b')],
///     [DocxMathRun('c'), DocxMathRun('d')],
///   ],
///   brackets: DocxMatrixBrackets.parentheses,
/// )
/// ```
class DocxMatrix extends DocxMathElement {
  final List<List<DocxMathElement>> rows;
  final DocxMatrixBrackets brackets;
  final int? augmentColumnIndex;

  const DocxMatrix({
    required this.rows,
    this.brackets = DocxMatrixBrackets.none,
    this.augmentColumnIndex,
  });

  @override
  void buildOmml(XmlBuilder builder) {
    final (open, close) = brackets.chars;
    if (open != null) {
      builder.element('m:d', nest: () {
        builder.element('m:dPr', nest: () {
          builder.element('m:begChr', nest: () {
            builder.attribute('m:val', open);
          });
          builder.element('m:endChr', nest: () {
            builder.attribute('m:val', close ?? '');
          });
        });
        builder.element('m:e', nest: () => _buildMatrix(builder));
      });
    } else {
      _buildMatrix(builder);
    }
  }

  void _buildMatrix(XmlBuilder builder) {
    builder.element('m:m', nest: () {
      for (final row in rows) {
        builder.element('m:mr', nest: () {
          for (final cell in row) {
            builder.element('m:e', nest: () => cell.buildOmml(builder));
          }
        });
      }
    });
  }

  @override
  String toLatex() {
    final env = switch (brackets) {
      DocxMatrixBrackets.none => 'matrix',
      DocxMatrixBrackets.parentheses => 'pmatrix',
      DocxMatrixBrackets.brackets => 'bmatrix',
      DocxMatrixBrackets.braces => 'Bmatrix',
      DocxMatrixBrackets.pipes => 'vmatrix',
      DocxMatrixBrackets.doublePipes => 'Vmatrix',
    };
    final rowsStr =
        rows.map((r) => r.map((e) => e.toLatex()).join(' & ')).join(' \\\\ ');
    return '\\begin{$env}$rowsStr\\end{$env}';
  }

  @override
  String toMathML() {
    final rowsStr = rows
        .map((r) =>
            '<mtr>${r.map((e) => '<mtd>${e.toMathML()}</mtd>').join()}</mtr>')
        .join();
    return '<mtable>$rowsStr</mtable>';
  }
}

enum DocxMatrixBrackets { none, parentheses, brackets, braces, pipes, doublePipes }

extension DocxMatrixBracketsExt on DocxMatrixBrackets {
  (String?, String?) get chars => switch (this) {
        DocxMatrixBrackets.none => (null, null),
        DocxMatrixBrackets.parentheses => ('(', ')'),
        DocxMatrixBrackets.brackets => ('[', ']'),
        DocxMatrixBrackets.braces => ('{', '}'),
        DocxMatrixBrackets.pipes => ('|', '|'),
        DocxMatrixBrackets.doublePipes => ('‖', '‖'),
      };
}

// ============================================================
// DELIMITER (BRACKETS)
// ============================================================

/// A delimited expression: brackets, parentheses, braces around math.
class DocxDelimiter extends DocxMathElement {
  final DocxMathElement content;
  final String openChr;
  final String closeChr;

  const DocxDelimiter({
    required this.content,
    this.openChr = '(',
    this.closeChr = ')',
  });

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:d', nest: () {
      builder.element('m:dPr', nest: () {
        builder.element('m:begChr', nest: () {
          builder.attribute('m:val', openChr);
        });
        builder.element('m:endChr', nest: () {
          builder.attribute('m:val', closeChr);
        });
      });
      builder.element('m:e', nest: () => content.buildOmml(builder));
    });
  }

  @override
  String toLatex() => '\\left$openChr ${content.toLatex()} \\right$closeChr';

  @override
  String toMathML() => '<mfenced open="$openChr" close="$closeChr"><mrow>${content.toMathML()}</mrow></mfenced>';
}

// ============================================================
// GROUP (SEQUENCE OF MATH ELEMENTS)
// ============================================================

/// A sequence of math elements displayed side by side.
class DocxMathGroup extends DocxMathElement {
  final List<DocxMathElement> elements;

  const DocxMathGroup(this.elements);

  @override
  void buildOmml(XmlBuilder builder) {
    for (final e in elements) {
      e.buildOmml(builder);
    }
  }

  @override
  String toLatex() => elements.map((e) => e.toLatex()).join();

  @override
  String toMathML() => elements.map((e) => e.toMathML()).join();
}

// ============================================================
// ACCENT (OVER-DECORATION)
// ============================================================

/// An accented element (hat, tilde, bar, dot, etc. over a base).
class DocxAccent extends DocxMathElement {
  final DocxMathElement base;
  final String chr;

  const DocxAccent({required this.base, required this.chr});

  static DocxAccent hat(DocxMathElement base) => DocxAccent(base: base, chr: '̂');
  static DocxAccent tilde(DocxMathElement base) => DocxAccent(base: base, chr: '̃');
  static DocxAccent bar(DocxMathElement base) => DocxAccent(base: base, chr: '̄');
  static DocxAccent dot(DocxMathElement base) => DocxAccent(base: base, chr: '̇');
  static DocxAccent ddot(DocxMathElement base) => DocxAccent(base: base, chr: '̈');
  static DocxAccent vec(DocxMathElement base) => DocxAccent(base: base, chr: '⃗');

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:acc', nest: () {
      builder.element('m:accPr', nest: () {
        builder.element('m:chr', nest: () {
          builder.attribute('m:val', chr);
        });
      });
      builder.element('m:e', nest: () => base.buildOmml(builder));
    });
  }

  @override
  String toLatex() {
    final cmd = switch (chr) {
      '̂' => '\\hat',
      '̃' => '\\tilde',
      '̄' => '\\bar',
      '̇' => '\\dot',
      '̈' => '\\ddot',
      '⃗' => '\\vec',
      _ => '\\hat',
    };
    return '$cmd{${base.toLatex()}}';
  }

  @override
  String toMathML() => '<mover>${base.toMathML()}<mo>$chr</mo></mover>';
}

// ============================================================
// LIMIT
// ============================================================

/// A limit expression: lim_{x→0} f(x).
class DocxLimit extends DocxMathElement {
  final DocxMathElement base;
  final DocxMathElement limit;
  final bool above; // false = under (standard lim)

  const DocxLimit({required this.base, required this.limit, this.above = false});

  @override
  void buildOmml(XmlBuilder builder) {
    final tag = above ? 'm:limUpp' : 'm:limLow';
    builder.element(tag, nest: () {
      builder.element('m:e', nest: () => base.buildOmml(builder));
      builder.element('m:lim', nest: () => limit.buildOmml(builder));
    });
  }

  @override
  String toLatex() =>
      above ? '\\overset{${limit.toLatex()}}{${base.toLatex()}}' : '\\underset{${limit.toLatex()}}{${base.toLatex()}}';

  @override
  String toMathML() {
    final tag = above ? 'mover' : 'munder';
    return '<$tag>${base.toMathML()}<mrow>${limit.toMathML()}</mrow></$tag>';
  }
}

// ============================================================
// FUNCTION
// ============================================================

/// A named function call: sin(x), cos(θ), etc.
class DocxMathFunc extends DocxMathElement {
  final String name;
  final DocxMathElement argument;

  const DocxMathFunc({required this.name, required this.argument});

  @override
  void buildOmml(XmlBuilder builder) {
    builder.element('m:func', nest: () {
      builder.element('m:fName', nest: () {
        builder.element('m:r', nest: () {
          builder.element('m:rPr', nest: () {
            builder.element('m:nor');
          });
          builder.element('m:t', nest: () => builder.text(name));
        });
      });
      builder.element('m:e', nest: () => argument.buildOmml(builder));
    });
  }

  @override
  String toLatex() => '\\$name\\left(${argument.toLatex()}\\right)';

  @override
  String toMathML() => '<mrow><mi>$name</mi><mo>⁡</mo><mrow>${argument.toMathML()}</mrow></mrow>';
}

// ============================================================
// VECTOR
// ============================================================

/// A vector notation (bold or arrow over symbol).
class DocxVector extends DocxMathElement {
  final DocxMathElement base;
  final DocxVectorNotation notation;

  const DocxVector({required this.base, this.notation = DocxVectorNotation.arrow});

  @override
  void buildOmml(XmlBuilder builder) {
    if (notation == DocxVectorNotation.bold) {
      builder.element('m:r', nest: () {
        builder.element('m:rPr', nest: () {
          builder.element('m:b', nest: () => builder.attribute('m:val', '1'));
        });
        builder.element('m:t', nest: () => builder.text(base.toLatex()));
      });
    } else {
      DocxAccent.vec(base).buildOmml(builder);
    }
  }

  @override
  String toLatex() => switch (notation) {
        DocxVectorNotation.arrow => '\\vec{${base.toLatex()}}',
        DocxVectorNotation.bold => '\\mathbf{${base.toLatex()}}',
        DocxVectorNotation.unit => '\\hat{${base.toLatex()}}',
      };

  @override
  String toMathML() => '<mover>${base.toMathML()}<mo>→</mo></mover>';
}

enum DocxVectorNotation { arrow, bold, unit }

// ============================================================
// GREEK SYMBOLS
// ============================================================

/// Predefined Greek symbol constants.
class DocxGreek {
  static final alpha = DocxMathRun('α');
  static final beta = DocxMathRun('β');
  static final gamma = DocxMathRun('γ');
  static final delta = DocxMathRun('δ');
  static final epsilon = DocxMathRun('ε');
  static final zeta = DocxMathRun('ζ');
  static final eta = DocxMathRun('η');
  static final theta = DocxMathRun('θ');
  static final iota = DocxMathRun('ι');
  static final kappa = DocxMathRun('κ');
  static final lambda = DocxMathRun('λ');
  static final mu = DocxMathRun('μ');
  static final nu = DocxMathRun('ν');
  static final xi = DocxMathRun('ξ');
  static final pi = DocxMathRun('π');
  static final rho = DocxMathRun('ρ');
  static final sigma = DocxMathRun('σ');
  static final tau = DocxMathRun('τ');
  static final upsilon = DocxMathRun('υ');
  static final phi = DocxMathRun('φ');
  static final chi = DocxMathRun('χ');
  static final psi = DocxMathRun('ψ');
  static final omega = DocxMathRun('ω');
  static final capitalAlpha = DocxMathRun('Α');
  static final capitalBeta = DocxMathRun('Β');
  static final capitalGamma = DocxMathRun('Γ');
  static final capitalDelta = DocxMathRun('Δ');
  static final capitalTheta = DocxMathRun('Θ');
  static final capitalLambda = DocxMathRun('Λ');
  static final capitalPi = DocxMathRun('Π');
  static final capitalSigma = DocxMathRun('Σ');
  static final capitalPhi = DocxMathRun('Φ');
  static final capitalPsi = DocxMathRun('Ψ');
  static final capitalOmega = DocxMathRun('Ω');
}

// ============================================================
// EQUATION NODE (TOP-LEVEL BLOCK/INLINE)
// ============================================================

/// A mathematical equation (inline or block display).
///
/// ## Inline equation
/// ```dart
/// DocxEquation(
///   display: DocxEquationDisplay.inline,
///   content: DocxFraction(
///     numerator: DocxMathRun('x'),
///     denominator: DocxMathRun('y'),
///   ),
/// )
/// ```
///
/// ## Block equation with number
/// ```dart
/// DocxEquation(
///   display: DocxEquationDisplay.block,
///   label: 'eq:pythagoras',
///   number: '(1)',
///   content: DocxMathGroup([
///     DocxSuperscript(base: DocxMathRun('a'), exponent: DocxMathRun('2')),
///     DocxMathRun('+'),
///     DocxSuperscript(base: DocxMathRun('b'), exponent: DocxMathRun('2')),
///     DocxMathRun('='),
///     DocxSuperscript(base: DocxMathRun('c'), exponent: DocxMathRun('2')),
///   ]),
/// )
/// ```
class DocxEquation extends DocxBlock {
  final DocxEquationDisplay display;
  final DocxMathElement content;
  final String? label;
  final String? number;
  final String? latexSource;

  const DocxEquation({
    required this.content,
    this.display = DocxEquationDisplay.block,
    this.label,
    this.number,
    this.latexSource,
    super.id,
  });

  /// Creates a block equation from a LaTeX string.
  factory DocxEquation.fromLatex(String latex, {String? label, String? number}) {
    return DocxEquation(
      content: DocxMathRun(latex),
      display: DocxEquationDisplay.block,
      label: label,
      number: number,
      latexSource: latex,
    );
  }

  /// Exports this equation as a LaTeX string.
  String toLatex() {
    if (latexSource != null) return latexSource!;
    return content.toLatex();
  }

  /// Exports this equation as a MathML string.
  String toMathML() {
    return '<math xmlns="http://www.w3.org/1998/Math/MathML">'
        '${content.toMathML()}'
        '</math>';
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      if (display == DocxEquationDisplay.block) {
        builder.element('w:pPr', nest: () {
          builder.element('w:jc', nest: () {
            builder.attribute('w:val', 'center');
          });
        });
      }
      builder.element('m:oMathPara',
          namespaceUris: {
            'm': 'http://schemas.openxmlformats.org/officeDocument/2006/math'
          },
          nest: () {
        if (display == DocxEquationDisplay.block) {
          builder.element('m:oMathParaPr', nest: () {
            builder.element('m:jc', nest: () {
              builder.attribute('m:val', 'center');
            });
          });
        }
        builder.element('m:oMath', nest: () {
          content.buildOmml(builder);
        });
      });
    });
  }
}

// ============================================================
// INLINE EQUATION
// ============================================================

/// An inline equation (inside a paragraph run).
class DocxInlineEquation extends DocxInline {
  final DocxMathElement content;
  final String? latexSource;

  const DocxInlineEquation({
    required this.content,
    this.latexSource,
    super.id,
  });

  factory DocxInlineEquation.fromLatex(String latex) {
    return DocxInlineEquation(
      content: DocxMathRun(latex),
      latexSource: latex,
    );
  }

  String toLatex() => latexSource ?? content.toLatex();
  String toMathML() =>
      '<math xmlns="http://www.w3.org/1998/Math/MathML" display="inline">${content.toMathML()}</math>';

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('m:oMath',
        namespaceUris: {
          'm': 'http://schemas.openxmlformats.org/officeDocument/2006/math'
        },
        nest: () {
      content.buildOmml(builder);
    });
  }
}

// ============================================================
// LATEX PARSER (BASIC)
// ============================================================

/// Basic LaTeX-to-DocxMathElement parser.
///
/// Supports: fractions, roots, superscripts, subscripts, Greek letters,
/// common functions, and plain text runs.
class DocxLatexParser {
  static final _greekMap = {
    r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
    r'\epsilon': 'ε', r'\zeta': 'ζ', r'\eta': 'η', r'\theta': 'θ',
    r'\iota': 'ι', r'\kappa': 'κ', r'\lambda': 'λ', r'\mu': 'μ',
    r'\nu': 'ν', r'\xi': 'ξ', r'\pi': 'π', r'\rho': 'ρ',
    r'\sigma': 'σ', r'\tau': 'τ', r'\upsilon': 'υ', r'\phi': 'φ',
    r'\chi': 'χ', r'\psi': 'ψ', r'\omega': 'ω',
    r'\Gamma': 'Γ', r'\Delta': 'Δ', r'\Theta': 'Θ', r'\Lambda': 'Λ',
    r'\Pi': 'Π', r'\Sigma': 'Σ', r'\Phi': 'Φ', r'\Psi': 'Ψ', r'\Omega': 'Ω',
    r'\infty': '∞', r'\partial': '∂', r'\nabla': '∇',
    r'\times': '×', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
    r'\leq': '≤', r'\geq': '≥', r'\neq': '≠', r'\approx': '≈',
    r'\in': '∈', r'\notin': '∉', r'\subset': '⊂', r'\supset': '⊃',
    r'\cup': '∪', r'\cap': '∩', r'\emptyset': '∅',
    r'\forall': '∀', r'\exists': '∃', r'\neg': '¬',
    r'\land': '∧', r'\lor': '∨', r'\Rightarrow': '⇒',
    r'\Leftrightarrow': '⟺', r'\rightarrow': '→', r'\leftarrow': '←',
  };

  /// Parses a LaTeX string into a [DocxMathElement] tree.
  static DocxMathElement parse(String latex) {
    // Replace known Greek letters and symbols
    String processed = latex.trim();
    _greekMap.forEach((key, value) {
      processed = processed.replaceAll(key, value);
    });
    return DocxMathRun(processed);
  }

  /// Parses a LaTeX string into a [DocxEquation] block.
  static DocxEquation parseBlock(String latex,
      {String? label, String? number}) {
    return DocxEquation.fromLatex(latex, label: label, number: number);
  }
}
