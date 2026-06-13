/// Style and formatting enums/classes for `docx_ai_creator`.
library;

// ============================================================
// TEXT & PARAGRAPH ALIGNMENT
// ============================================================

/// Text alignment within a paragraph or table cell.
enum DocxAlign { left, center, right, justify }

extension DocxAlignExtension on DocxAlign {
  String get xmlValue {
    switch (this) {
      case DocxAlign.left:
        return 'start';
      case DocxAlign.center:
        return 'center';
      case DocxAlign.right:
        return 'end';
      case DocxAlign.justify:
        return 'both';
    }
  }
}

// ============================================================
// VERTICAL TEXT ALIGNMENT
// ============================================================

/// Vertical text alignment within a line (e.g., relative to an image).
enum DocxTextAlignment { auto, baseline, bottom, center, top }

extension DocxTextAlignmentExtension on DocxTextAlignment {
  String get xmlValue => name;
}

// ============================================================
// COLOR (Flexible Class)
// ============================================================

/// A color value for text, backgrounds, and borders.
///
/// ## Predefined Colors
/// ```dart
/// DocxText('Red', color: DocxColor.red)
/// DocxText('Blue', color: DocxColor.blue)
/// ```
///
/// ## Custom Hex Colors
/// ```dart
/// DocxText('Brand', color: DocxColor('#4285F4'))
/// DocxText('Custom', color: DocxColor('FF5722'))
/// ```
class DocxColor {
  /// The hex color value (without #).
  final String hex;

  /// Theme color reference (e.g. 'accent1').
  final String? themeColor;

  /// Theme color tint.
  final String? themeTint;

  /// Theme color shade.
  final String? themeShade;

  /// Private const constructor for predefined colors.
  const DocxColor._(this.hex,
      {this.themeColor, this.themeTint, this.themeShade});

  /// Creates a color from a hex string.
  ///
  /// Accepts formats: 'RRGGBB', '#RRGGBB', '0xRRGGBB'
  factory DocxColor(String value,
      {String? themeColor, String? themeTint, String? themeShade}) {
    String hex = value.toUpperCase();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.startsWith('0X')) hex = hex.substring(2);
    return DocxColor._(hex,
        themeColor: themeColor, themeTint: themeTint, themeShade: themeShade);
  }

  /// Creates a color from a hex string, removing # or 0x prefix.
  factory DocxColor.fromHex(String value) => DocxColor(value);

  // Predefined colors
  static const auto = DocxColor._('auto');
  static const black = DocxColor._('000000');
  static const white = DocxColor._('FFFFFF');
  static const red = DocxColor._('FF0000');
  static const blue = DocxColor._('0000FF');
  static const green = DocxColor._('00FF00');
  static const yellow = DocxColor._('FFFF00');
  static const orange = DocxColor._('FFA500');
  static const purple = DocxColor._('800080');
  static const gray = DocxColor._('808080');
  static const lightGray = DocxColor._('D3D3D3');
  static const darkGray = DocxColor._('404040');
  static const cyan = DocxColor._('00FFFF');
  static const magenta = DocxColor._('FF00FF');
  static const pink = DocxColor._('FFC0CB');
  static const brown = DocxColor._('8B4513');
  static const navy = DocxColor._('000080');
  static const teal = DocxColor._('008080');
  static const lime = DocxColor._('32CD32');
  static const gold = DocxColor._('FFD700');
  static const silver = DocxColor._('C0C0C0');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DocxColor && hex == other.hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => 'DocxColor($hex)';
}

// ============================================================
// BORDERS
// ============================================================

/// Border styles for tables, paragraphs, and sections.
enum DocxBorder { none, single, double, dashed, dotted, thick, triple }

extension DocxBorderExtension on DocxBorder {
  String get xmlValue {
    switch (this) {
      case DocxBorder.none:
        return 'nil';
      case DocxBorder.single:
        return 'single';
      case DocxBorder.double:
        return 'double';
      case DocxBorder.dashed:
        return 'dashed';
      case DocxBorder.dotted:
        return 'dotted';
      case DocxBorder.thick:
        return 'thick';
      case DocxBorder.triple:
        return 'triple';
    }
  }
}

/// Defines a single border side properties.
class DocxBorderSide {
  final DocxBorder style;
  final DocxColor color;

  /// Border width in eighths of a point (4 = 0.5pt, 8 = 1pt).
  final int size;
  final int space;

  /// Theme color reference (e.g. 'accent1').
  final String? themeColor;

  /// Theme color tint (e.g. '66' for 40% lighter).
  final String? themeTint;

  /// Theme color shade (e.g. '80' for 20% darker).
  final String? themeShade;

  /// Raw XML value for border style if it doesn't match [DocxBorder] enum.
  final String? rawVal;

  const DocxBorderSide({
    this.style = DocxBorder.single,
    this.color = DocxColor.black,
    this.size = 4,
    this.space = 0,
    this.themeColor,
    this.themeTint,
    this.themeShade,
    this.rawVal,
  });

  const DocxBorderSide.none()
      : style = DocxBorder.none,
        color = DocxColor.auto,
        size = 0,
        space = 0,
        themeColor = null,
        themeTint = null,
        themeShade = null,
        rawVal = null;

  String get xmlStyle => rawVal ?? style.xmlValue;
}

// ============================================================
// FONT STYLING
// ============================================================

enum DocxFontWeight { normal, bold }

enum DocxFontStyle { normal, italic }

enum DocxTextDecoration { none, underline, strikethrough }

/// Highlight (background) colors for text.
enum DocxHighlight {
  none,
  yellow,
  green,
  cyan,
  magenta,
  blue,
  red,
  darkBlue,
  darkCyan,
  darkGreen,
  darkMagenta,
  darkRed,
  darkYellow,
  darkGray,
  lightGray,
  black,
  white,
}

// ============================================================
// PAGE & SECTION
// ============================================================

enum DocxPageOrientation { portrait, landscape }

enum DocxPageSize {
  custom,

  letter,
  legal,
  tabloid,
  statement,
  executive,
  folio,
  quarto,

  a3,
  a4,
  a5,
  a6,

  b4,
  b5,
  b6,

  ledger,
  note,

  envelope10,
  envelopeMonarch,
  envelopeDL,
  envelopeC5,
  envelopeB5,
}
extension DocxPageSizeExtension on DocxPageSize {
  /// Width in twips (1/1440 inch).
  int get widthTwips => switch (this) {
        DocxPageSize.letter => 12240,
        DocxPageSize.legal => 12240,
        DocxPageSize.tabloid => 15840,
        DocxPageSize.ledger => 24480,
        DocxPageSize.statement => 7920,
        DocxPageSize.executive => 10440,
        DocxPageSize.folio => 12240,
        DocxPageSize.quarto => 12249,
        DocxPageSize.note => 12240,
        DocxPageSize.a3 => 16838,
        DocxPageSize.a4 => 11906,
        DocxPageSize.a5 => 8391,
        DocxPageSize.a6 => 5953,
        DocxPageSize.b4 => 14174,
        DocxPageSize.b5 => 9979,
        DocxPageSize.b6 => 7087,
        DocxPageSize.envelope10 => 5580,
        DocxPageSize.envelopeMonarch => 5580,
        DocxPageSize.envelopeDL => 6237,
        DocxPageSize.envelopeC5 => 9184,
        DocxPageSize.envelopeB5 => 9979,
        DocxPageSize.custom => 12240,
      };

  /// Height in twips.
  int get heightTwips => switch (this) {
        DocxPageSize.letter => 15840,
        DocxPageSize.legal => 20160,
        DocxPageSize.tabloid => 24480,
        DocxPageSize.ledger => 15840,
        DocxPageSize.statement => 12240,
        DocxPageSize.executive => 15120,
        DocxPageSize.folio => 19440,
        DocxPageSize.quarto => 15120,
        DocxPageSize.note => 15840,
        DocxPageSize.a3 => 23811,
        DocxPageSize.a4 => 16838,
        DocxPageSize.a5 => 11906,
        DocxPageSize.a6 => 8391,
        DocxPageSize.b4 => 20072,
        DocxPageSize.b5 => 14174,
        DocxPageSize.b6 => 9979,
        DocxPageSize.envelope10 => 12780,
        DocxPageSize.envelopeMonarch => 10800,
        DocxPageSize.envelopeDL => 12474,
        DocxPageSize.envelopeC5 => 6492,
        DocxPageSize.envelopeB5 => 7087,
        DocxPageSize.custom => 15840,
      };
}

enum DocxSectionBreak { continuous, nextPage, evenPage, oddPage }

// ============================================================
// TABLE-SPECIFIC
// ============================================================

enum DocxVerticalAlign { top, center, bottom }

enum DocxWidthType { auto, dxa, pct }

// ============================================================
// HEADING LEVELS
// ============================================================

// ============================================================
// SCRIPT / LANGUAGE SUPPORT
// ============================================================

/// Scripts supported for advanced text rendering.
enum DocxScript {
  latin,
  arabic,
  hebrew,
  hindi,
  tamil,
  chinese,
  japanese,
  korean,
  thai,
  cyrillic,
  greek,
  georgian,
}

// ============================================================
// TYPOGRAPHY
// ============================================================

/// OpenType alternate glyph sets.
enum DocxAlternateGlyphs {
  none,
  alternateSet1,
  alternateSet2,
  alternateSet3,
  titlingAlternates,
  ornamentalForms,
  historicalForms,
  stylisticAlternates,
}

// ============================================================
// TABLE CELL DIRECTION
// ============================================================

/// Text direction for table cells.
enum DocxTextDirection {
  lrTb,  // Left-to-right, top-to-bottom (default)
  tbRl,  // Top-to-bottom, right-to-left (vertical CJK)
  btLr,  // Bottom-to-top, left-to-right
  lrTbV, // Vertical left-to-right
  tbRlV, // Vertical top-to-bottom right-to-left
  tbLrV, // Vertical top-to-bottom left-to-right
}

// ============================================================
// NEWSPAPER / LAYOUT MODES
// ============================================================

/// Document layout mode.
enum DocxLayoutMode {
  page,       // Standard paginated layout
  pageless,   // Continuous scroll without page breaks
  infiniteCanvas, // Free-form infinite canvas
  newspaper,  // Newspaper-style multi-column flow
}

// ============================================================
// CHART TYPES
// ============================================================

enum DocxChartType {
  pie,
  bar,
  line,
  scatter,
  area,
  combo,
  histogram,
  boxPlot,
  heatmap,
  violin,
}

// ============================================================
// COLLABORATION
// ============================================================

/// User presence state in collaborative editing.
enum DocxPresenceState { active, idle, offline }

// ============================================================
// VERSION CONTROL
// ============================================================

/// Type of a version control operation.
enum DocxVcsOperation { commit, branch, merge, revert, diff }

// ============================================================
// EQUATION / MATH
// ============================================================

/// Display mode for mathematical equations.
enum DocxEquationDisplay { inline, block }

/// Math element types.
enum DocxMathElementType {
  fraction,
  root,
  superscript,
  subscript,
  supSub,
  integral,
  summation,
  product,
  matrix,
  vector,
  limit,
  nary,
  radical,
  delimiter,
  group,
  phantom,
  accent,
  bar,
  border,
  box,
  eqArray,
  func,
  limLow,
  limUpp,
  run,
}

// ============================================================
// DIAGRAM TYPES
// ============================================================

enum DocxDiagramType {
  flowchart,
  uml,
  erDiagram,
  networkDiagram,
  coordinatePlane,
  graphPlot,
  functionPlot,
  geometryConstruction,
  chemicalStructure,
  circuitDiagram,
  biologicalDiagram,
  orgChart,
  timeline,
  processDiagram,
}

// ============================================================
// SMART ART / DIAGRAM LAYOUT
// ============================================================

enum DocxSmartArtLayout {
  orgChart,
  horizontalOrgChart,
  timeline,
  process,
  cycle,
  hierarchy,
  relationship,
  matrix,
  pyramid,
  list,
}

enum DocxHeadingLevel { h1, h2, h3, h4, h5, h6 }

extension DocxHeadingLevelExtension on DocxHeadingLevel {
  String get styleId => 'Heading${index + 1}';

  double get defaultFontSize {
    switch (this) {
      case DocxHeadingLevel.h1:
        return 24;
      case DocxHeadingLevel.h2:
        return 20;
      case DocxHeadingLevel.h3:
        return 16;
      case DocxHeadingLevel.h4:
        return 14;
      case DocxHeadingLevel.h5:
        return 12;
      case DocxHeadingLevel.h6:
        return 11;
    }
  }
}
