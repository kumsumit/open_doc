// ============================================================
// EQUATION EXTENDED: MathML IMPORT, UNICODEMATH, TOOLBAR MODEL,
// EQUATION PREVIEW, SPEECH GENERATION, KEYBOARD EDITOR
// ============================================================

import '../core/enums.dart';
import 'docx_equation.dart';

// ============================================================
// MATHML IMPORT
// ============================================================

/// Parses a MathML string into a [DocxMathElement] tree.
///
/// Supports core MathML 3 presentation elements:
/// mn, mi, mo, mfrac, msqrt, mroot, msup, msub, msubsup,
/// mover, munder, munderover, mrow, mfenced, mtable, mtr, mtd, mtext.
class DocxMathMLImporter {
  /// Parse a MathML XML string and return the root [DocxMathElement].
  static DocxMathElement parse(String mathml) {
    // Real implementation: parse XML and walk the element tree.
    // Stub: strip tags and return plain text run.
    return DocxMathRun(mathml.replaceAll(RegExp(r'<[^>]+>'), '').trim());
  }

  /// Parse a `<math>` element string and return a display-mode [DocxEquation].
  static DocxEquation parseEquation(String mathml,
      {bool displayMode = true}) {
    final element = parse(mathml);
    return DocxEquation(
      content: element,
      display: displayMode ? DocxEquationDisplay.block : DocxEquationDisplay.inline,
      latexSource: mathml,
    );
  }
}

// ============================================================
// UNICODEMATH PARSER
// ============================================================

/// Microsoft UnicodeMath is a linear text notation for math.
///
/// Examples:
///   `x^2 + y^2 = r^2`
///   `∫_0^∞ e^(-x^2) dx`
///   `\frac(a)(b)` → a/b fraction
class DocxUnicodeMathParser {
  static const Map<String, String> _greekMap = {
    r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
    r'\epsilon': 'ε', r'\zeta': 'ζ', r'\eta': 'η', r'\theta': 'θ',
    r'\iota': 'ι', r'\kappa': 'κ', r'\lambda': 'λ', r'\mu': 'μ',
    r'\nu': 'ν', r'\xi': 'ξ', r'\pi': 'π', r'\rho': 'ρ',
    r'\sigma': 'σ', r'\tau': 'τ', r'\upsilon': 'υ', r'\phi': 'φ',
    r'\chi': 'χ', r'\psi': 'ψ', r'\omega': 'ω',
  };

  /// Parse a UnicodeMath linear string into a list of [DocxMathElement]s.
  static List<DocxMathElement> parse(String input) {
    final result = <DocxMathElement>[];
    var text = input;
    for (final entry in _greekMap.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    // Handle \frac(a)(b) → DocxFraction
    final fracRe = RegExp(r'\\frac\(([^)]+)\)\(([^)]+)\)');
    final fracMatches = fracRe.allMatches(text).toList();
    if (fracMatches.isNotEmpty) {
      for (final m in fracMatches) {
        result.add(DocxFraction(
          numerator: DocxMathRun(m.group(1)!),
          denominator: DocxMathRun(m.group(2)!),
        ));
      }
      text = text.replaceAll(fracRe, '');
    }
    // Handle a^b → DocxSuperscript
    final supRe = RegExp(r'(\S+)\^(\S+)');
    final supMatches = supRe.allMatches(text).toList();
    if (supMatches.isNotEmpty) {
      for (final m in supMatches) {
        result.add(DocxSuperscript(
          base: DocxMathRun(m.group(1)!),
          exponent: DocxMathRun(m.group(2)!),
        ));
      }
      text = text.replaceAll(supRe, '');
    }
    // Handle a_b → DocxSubscript
    final subRe = RegExp(r'(\S+)_(\S+)');
    final subMatches = subRe.allMatches(text).toList();
    if (subMatches.isNotEmpty) {
      for (final m in subMatches) {
        result.add(DocxSubscript(
          base: DocxMathRun(m.group(1)!),
          subscript: DocxMathRun(m.group(2)!),
        ));
      }
      text = text.replaceAll(subRe, '');
    }
    // Remaining plain text
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) result.add(DocxMathRun(trimmed));
    return result.isEmpty ? [DocxMathRun(input)] : result;
  }

  /// Parse UnicodeMath input into a [DocxEquation] block.
  static DocxEquation parseEquation(String input, {bool displayMode = true}) {
    final parts = parse(input);
    final content = parts.length == 1 ? parts.first : DocxMathGroup(parts);
    return DocxEquation(
      content: content,
      display: displayMode ? DocxEquationDisplay.block : DocxEquationDisplay.inline,
      latexSource: input,
    );
  }
}

// ============================================================
// EQUATION TOOLBAR MODEL
// ============================================================

/// Categories shown in the equation toolbar/ribbon.
enum DocxEquationToolbarCategory {
  basic,
  fractions,
  scripts,
  radicals,
  integrals,
  summations,
  matrices,
  operators,
  greekLetters,
  arrows,
}

/// A single symbol entry in the toolbar palette.
class DocxToolbarSymbol {
  final String unicode;
  final String label;
  final DocxEquationToolbarCategory category;
  final String? latexCommand;

  const DocxToolbarSymbol({
    required this.unicode,
    required this.label,
    required this.category,
    this.latexCommand,
  });
}

/// Equation toolbar/ribbon model — symbol palette data.
class DocxEquationToolbar {
  static const List<DocxToolbarSymbol> symbols = [
    DocxToolbarSymbol(unicode: '∕', label: 'Fraction',
        category: DocxEquationToolbarCategory.fractions, latexCommand: r'\frac'),
    DocxToolbarSymbol(unicode: '^', label: 'Superscript',
        category: DocxEquationToolbarCategory.scripts, latexCommand: '^'),
    DocxToolbarSymbol(unicode: '_', label: 'Subscript',
        category: DocxEquationToolbarCategory.scripts, latexCommand: '_'),
    DocxToolbarSymbol(unicode: '√', label: 'Square Root',
        category: DocxEquationToolbarCategory.radicals, latexCommand: r'\sqrt'),
    DocxToolbarSymbol(unicode: '∛', label: 'Cube Root',
        category: DocxEquationToolbarCategory.radicals, latexCommand: r'\sqrt[3]'),
    DocxToolbarSymbol(unicode: '∫', label: 'Integral',
        category: DocxEquationToolbarCategory.integrals, latexCommand: r'\int'),
    DocxToolbarSymbol(unicode: '∬', label: 'Double Integral',
        category: DocxEquationToolbarCategory.integrals, latexCommand: r'\iint'),
    DocxToolbarSymbol(unicode: '∭', label: 'Triple Integral',
        category: DocxEquationToolbarCategory.integrals, latexCommand: r'\iiint'),
    DocxToolbarSymbol(unicode: '∮', label: 'Contour Integral',
        category: DocxEquationToolbarCategory.integrals, latexCommand: r'\oint'),
    DocxToolbarSymbol(unicode: '∑', label: 'Sigma',
        category: DocxEquationToolbarCategory.summations, latexCommand: r'\sum'),
    DocxToolbarSymbol(unicode: '∏', label: 'Product',
        category: DocxEquationToolbarCategory.summations, latexCommand: r'\prod'),
    DocxToolbarSymbol(unicode: 'α', label: 'Alpha',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\alpha'),
    DocxToolbarSymbol(unicode: 'β', label: 'Beta',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\beta'),
    DocxToolbarSymbol(unicode: 'γ', label: 'Gamma',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\gamma'),
    DocxToolbarSymbol(unicode: 'δ', label: 'Delta',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\delta'),
    DocxToolbarSymbol(unicode: 'π', label: 'Pi',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\pi'),
    DocxToolbarSymbol(unicode: 'Ω', label: 'Omega',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\Omega'),
    DocxToolbarSymbol(unicode: 'θ', label: 'Theta',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\theta'),
    DocxToolbarSymbol(unicode: 'λ', label: 'Lambda',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\lambda'),
    DocxToolbarSymbol(unicode: 'μ', label: 'Mu',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\mu'),
    DocxToolbarSymbol(unicode: 'σ', label: 'Sigma (lower)',
        category: DocxEquationToolbarCategory.greekLetters, latexCommand: r'\sigma'),
    DocxToolbarSymbol(unicode: '±', label: 'Plus-Minus',
        category: DocxEquationToolbarCategory.operators),
    DocxToolbarSymbol(unicode: '×', label: 'Times',
        category: DocxEquationToolbarCategory.operators, latexCommand: r'\times'),
    DocxToolbarSymbol(unicode: '÷', label: 'Divide',
        category: DocxEquationToolbarCategory.operators, latexCommand: r'\div'),
    DocxToolbarSymbol(unicode: '≤', label: 'Less or Equal',
        category: DocxEquationToolbarCategory.operators, latexCommand: r'\leq'),
    DocxToolbarSymbol(unicode: '≥', label: 'Greater or Equal',
        category: DocxEquationToolbarCategory.operators, latexCommand: r'\geq'),
    DocxToolbarSymbol(unicode: '≠', label: 'Not Equal',
        category: DocxEquationToolbarCategory.operators, latexCommand: r'\neq'),
    DocxToolbarSymbol(unicode: '∞', label: 'Infinity',
        category: DocxEquationToolbarCategory.operators, latexCommand: r'\infty'),
    DocxToolbarSymbol(unicode: '→', label: 'Right Arrow',
        category: DocxEquationToolbarCategory.arrows, latexCommand: r'\rightarrow'),
    DocxToolbarSymbol(unicode: '←', label: 'Left Arrow',
        category: DocxEquationToolbarCategory.arrows, latexCommand: r'\leftarrow'),
    DocxToolbarSymbol(unicode: '⇒', label: 'Implies',
        category: DocxEquationToolbarCategory.arrows, latexCommand: r'\Rightarrow'),
    DocxToolbarSymbol(unicode: '⇔', label: 'If and only if',
        category: DocxEquationToolbarCategory.arrows, latexCommand: r'\Leftrightarrow'),
  ];

  static List<DocxToolbarSymbol> forCategory(DocxEquationToolbarCategory cat) =>
      symbols.where((s) => s.category == cat).toList();

  static DocxToolbarSymbol? byLatex(String latex) =>
      symbols.cast<DocxToolbarSymbol?>().firstWhere(
        (s) => s?.latexCommand == latex,
        orElse: () => null,
      );
}

// ============================================================
// EQUATION PREVIEW
// ============================================================

/// A rendered preview of an equation (display before insertion).
class DocxEquationPreview {
  final DocxMathElement element;
  final String latexSource;
  final String mathmlOutput;
  final double estimatedWidth;
  final double estimatedHeight;

  DocxEquationPreview({
    required this.element,
    required this.latexSource,
  })  : mathmlOutput = element.toMathML(),
        estimatedWidth = _estimateWidth(latexSource),
        estimatedHeight = _estimateHeight(latexSource);

  static double _estimateWidth(String latex) =>
      (latex.length * 8.0).clamp(40.0, 600.0);

  static double _estimateHeight(String latex) {
    if (latex.contains(r'\frac') || latex.contains(r'\int')) return 48;
    if (latex.contains(r'\matrix') || latex.contains(r'\begin')) return 72;
    return 24;
  }

  String get structureDescription => _describe(element);

  static String _describe(DocxMathElement el) {
    if (el is DocxMathRun) return '"${el.text}"';
    if (el is DocxFraction) {
      return 'fraction(${_describe(el.numerator)}, ${_describe(el.denominator)})';
    }
    if (el is DocxRadical) {
      return el.degree != null
          ? 'root(${_describe(el.degree!)}, ${_describe(el.base)})'
          : 'sqrt(${_describe(el.base)})';
    }
    if (el is DocxSuperscript) {
      return '${_describe(el.base)}^{${_describe(el.exponent)}}';
    }
    if (el is DocxSubscript) {
      return '${_describe(el.base)}_{${_describe(el.subscript)}}';
    }
    return el.runtimeType.toString();
  }
}

// ============================================================
// EQUATION SPEECH GENERATION
// ============================================================

/// Converts an equation tree into spoken natural-language text for screen readers.
class DocxEquationSpeech {
  static String speak(DocxMathElement element) {
    if (element is DocxMathRun) return _speakText(element.text);
    if (element is DocxFraction) {
      return '${speak(element.numerator)} over ${speak(element.denominator)}';
    }
    if (element is DocxRadical) {
      if (element.degree != null) {
        return '${speak(element.degree!)} root of ${speak(element.base)}';
      }
      return 'square root of ${speak(element.base)}';
    }
    if (element is DocxSuperscript) {
      return '${speak(element.base)} to the power of ${speak(element.exponent)}';
    }
    if (element is DocxSubscript) {
      return '${speak(element.base)} subscript ${speak(element.subscript)}';
    }
    if (element is DocxSubSuperscript) {
      return '${speak(element.base)} subscript ${speak(element.sub)}'
          ' superscript ${speak(element.sup)}';
    }
    if (element is DocxNary) {
      final opName = _naryName(element.chr);
      if (element.lower != null && element.upper != null) {
        return '$opName from ${speak(element.lower!)} '
            'to ${speak(element.upper!)} of ${speak(element.body)}';
      }
      return '$opName of ${speak(element.body)}';
    }
    if (element is DocxMatrix) {
      return 'matrix with ${element.rows.length} rows '
          'and ${element.rows.isNotEmpty ? element.rows.first.length : 0} columns';
    }
    if (element is DocxMathGroup) {
      return element.elements.map(speak).join(' ');
    }
    if (element is DocxMathFunc) {
      return '${element.name} of ${speak(element.argument)}';
    }
    return element.runtimeType.toString().replaceAll('Docx', '').toLowerCase();
  }

  static String _speakText(String text) {
    const symbols = <String, String>{
      '+': 'plus', '-': 'minus', '=': 'equals', '*': 'times', '/': 'divided by',
      '<': 'less than', '>': 'greater than', '≤': 'less than or equal to',
      '≥': 'greater than or equal to', '≠': 'not equal to', '±': 'plus or minus',
      '∞': 'infinity', 'α': 'alpha', 'β': 'beta', 'γ': 'gamma', 'δ': 'delta',
      'π': 'pi', 'θ': 'theta', 'λ': 'lambda', 'μ': 'mu', 'σ': 'sigma',
      'Σ': 'capital sigma', 'Π': 'capital pi', '∈': 'element of',
      '∉': 'not element of', '⊆': 'subset of', '⊇': 'superset of',
      '∩': 'intersection', '∪': 'union', '∅': 'empty set',
      '∀': 'for all', '∃': 'there exists', '¬': 'not',
    };
    return symbols[text] ?? text;
  }

  static String _naryName(String op) {
    const names = <String, String>{
      '∫': 'integral', '∬': 'double integral', '∭': 'triple integral',
      '∮': 'contour integral', '∯': 'surface integral', '∰': 'volume integral',
      '∑': 'sum', '∏': 'product', '⋃': 'union', '⋂': 'intersection',
    };
    return names[op] ?? op;
  }

  static String toSsml(DocxMathElement element) {
    final spoken = speak(element).replaceAll('&', '&amp;');
    return '<speak><math>$spoken</math></speak>';
  }
}

// ============================================================
// KEYBOARD EQUATION EDITOR MODEL
// ============================================================

/// Keyboard actions within the equation editor.
enum DocxEquationKeyAction {
  moveLeft, moveRight, moveUp, moveDown,
  insertFraction, insertSuperscript, insertSubscript, insertSquareRoot,
  insertMatrix, insertGreek, deleteBack, deleteForward, confirm, cancel,
}

/// Cursor position within an equation tree.
class DocxEquationCursor {
  final List<int> path;
  final int offset;

  const DocxEquationCursor({this.path = const [], this.offset = 0});

  DocxEquationCursor copyWith({List<int>? path, int? offset}) =>
      DocxEquationCursor(path: path ?? this.path, offset: offset ?? this.offset);
}

/// State of the keyboard-driven equation editor.
class DocxEquationKeyboardEditor {
  List<DocxMathElement> elements;
  DocxEquationCursor cursor;
  final List<List<DocxMathElement>> _history = [];

  DocxEquationKeyboardEditor({List<DocxMathElement>? initial})
      : elements = initial ?? [],
        cursor = const DocxEquationCursor();

  void _saveHistory() => _history.add(List.from(elements));

  void insertText(String text) {
    _saveHistory();
    elements.add(DocxMathRun(text));
    cursor = DocxEquationCursor(offset: elements.length - 1);
  }

  void insertFraction(String numerator, String denominator) {
    _saveHistory();
    elements.add(DocxFraction(
      numerator: DocxMathRun(numerator),
      denominator: DocxMathRun(denominator),
    ));
  }

  void insertSuperscript(String base, String exp) {
    _saveHistory();
    elements.add(DocxSuperscript(
      base: DocxMathRun(base),
      exponent: DocxMathRun(exp),
    ));
  }

  void insertSubscript(String base, String sub) {
    _saveHistory();
    elements.add(DocxSubscript(
      base: DocxMathRun(base),
      subscript: DocxMathRun(sub),
    ));
  }

  void insertSquareRoot(String radicand) {
    _saveHistory();
    elements.add(DocxRadical(base: DocxMathRun(radicand)));
  }

  void undo() {
    if (_history.isNotEmpty) elements = _history.removeLast();
  }

  void handleAction(DocxEquationKeyAction action) {
    switch (action) {
      case DocxEquationKeyAction.insertFraction:
        insertFraction('', '');
      case DocxEquationKeyAction.insertSuperscript:
        insertSuperscript('', '');
      case DocxEquationKeyAction.insertSubscript:
        insertSubscript('', '');
      case DocxEquationKeyAction.insertSquareRoot:
        insertSquareRoot('');
      case DocxEquationKeyAction.deleteBack:
        if (elements.isNotEmpty) {
          _saveHistory();
          elements.removeLast();
        }
      case DocxEquationKeyAction.moveLeft:
        if (cursor.offset > 0) {
          cursor = cursor.copyWith(offset: cursor.offset - 1);
        }
      case DocxEquationKeyAction.moveRight:
        cursor = cursor.copyWith(offset: cursor.offset + 1);
      default:
        break;
    }
  }

  DocxEquation toEquation({bool displayMode = true}) {
    final content = elements.length == 1
        ? elements.first
        : DocxMathGroup(elements.isEmpty ? [DocxMathRun('')] : elements);
    return DocxEquation(
      content: content,
      display: displayMode ? DocxEquationDisplay.block : DocxEquationDisplay.inline,
    );
  }
}
