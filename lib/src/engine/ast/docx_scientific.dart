import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_node.dart';

// ============================================================
// CHEMICAL FORMULA SUPPORT
// ============================================================

/// A chemical formula or reaction equation.
///
/// ```dart
/// DocxChemicalFormula(formula: 'H₂O')
/// DocxChemicalFormula(formula: 'CO₂')
/// DocxChemicalFormula.reaction(
///   reactants: ['CH₄', '2O₂'],
///   products: ['CO₂', '2H₂O'],
/// )
/// ```
class DocxChemicalFormula extends DocxInline {
  final String formula;
  final bool isReaction;
  final List<String> reactants;
  final List<String> products;
  final String? reactionType; // '→', '⇌', '+'

  const DocxChemicalFormula({
    required this.formula,
    this.isReaction = false,
    this.reactants = const [],
    this.products = const [],
    this.reactionType,
    super.id,
  });

  factory DocxChemicalFormula.reaction({
    required List<String> reactants,
    required List<String> products,
    String reactionType = '→',
  }) {
    final formula = '${reactants.join(' + ')} $reactionType ${products.join(' + ')}';
    return DocxChemicalFormula(
      formula: formula,
      isReaction: true,
      reactants: reactants,
      products: products,
      reactionType: reactionType,
    );
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:r', nest: () {
      builder.element('w:rPr', nest: () {});
      builder.element('w:t', nest: () {
        builder.attribute('xml:space', 'preserve');
        builder.text(formula);
      });
    });
  }
}

/// A chemical structure drawing (Ketcher/ChemDraw-style).
class DocxChemicalStructure extends DocxBlock {
  final String smiles;   // SMILES notation
  final String? molfile; // MDL Molfile V2000/V3000
  final String? inchi;   // InChI identifier
  final String? name;    // IUPAC name
  final int width;
  final int height;

  const DocxChemicalStructure({
    required this.smiles,
    this.molfile,
    this.inchi,
    this.name,
    this.width = 3000000,
    this.height = 2000000,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Chemical Structure: ${name ?? smiles}]');
        });
      });
    });
  }
}

// ============================================================
// SCIENTIFIC NOTATION / ISOTOPES
// ============================================================

/// An isotope notation (e.g. ¹⁴C, ²³⁸U).
class DocxIsotope extends DocxInline {
  final String element;
  final int massNumber;
  final int? atomicNumber;
  final int? charge;

  const DocxIsotope({
    required this.element,
    required this.massNumber,
    this.atomicNumber,
    this.charge,
    super.id,
  });

  String get displayText {
    final mass = _toSuperscript(massNumber.toString());
    final atomic = atomicNumber != null ? _toSubscript(atomicNumber.toString()) : '';
    final chg = charge != null
        ? (charge! > 0 ? _toSuperscript('+${charge!}') : _toSuperscript('${charge!}'))
        : '';
    return '$mass$atomic$element$chg';
  }

  String _toSuperscript(String s) {
    const map = {'0':'⁰','1':'¹','2':'²','3':'³','4':'⁴','5':'⁵','6':'⁶','7':'⁷','8':'⁸','9':'⁹','+':'⁺','-':'⁻'};
    return s.split('').map((c) => map[c] ?? c).join();
  }

  String _toSubscript(String s) {
    const map = {'0':'₀','1':'₁','2':'₂','3':'₃','4':'₄','5':'₅','6':'₆','7':'₇','8':'₈','9':'₉'};
    return s.split('').map((c) => map[c] ?? c).join();
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:r', nest: () {
      builder.element('w:t', nest: () {
        builder.text(displayText);
      });
    });
  }
}

// ============================================================
// PHYSICS SUPPORT
// ============================================================

/// A physical quantity with value, unit, and optional uncertainty.
///
/// ```dart
/// DocxPhysicalQuantity(value: 9.81, unit: 'm/s²', name: 'g')
/// DocxPhysicalQuantity(value: 3e8, unit: 'm/s', name: 'c', uncertainty: 0)
/// ```
class DocxPhysicalQuantity extends DocxInline {
  final double value;
  final String unit;
  final String? name;
  final double? uncertainty;
  final DocxUnitSystem unitSystem;

  const DocxPhysicalQuantity({
    required this.value,
    required this.unit,
    this.name,
    this.uncertainty,
    this.unitSystem = DocxUnitSystem.si,
    super.id,
  });

  String get displayText {
    final v = _formatNumber(value);
    final u = unit.isNotEmpty ? ' $unit' : '';
    final err = uncertainty != null ? ' ± ${_formatNumber(uncertainty!)}' : '';
    return '$v$u$err';
  }

  String _formatNumber(double n) {
    if (n.abs() >= 1e6 || (n.abs() < 1e-3 && n != 0)) {
      return n.toStringAsExponential(3);
    }
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 3)
        .replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:r', nest: () {
      builder.element('w:t', nest: () {
        builder.attribute('xml:space', 'preserve');
        builder.text(displayText);
      });
    });
  }
}

enum DocxUnitSystem { si, imperial, cgs, natural }

/// Common SI units.
class DocxSiUnits {
  static const meter = 'm';
  static const kilogram = 'kg';
  static const second = 's';
  static const ampere = 'A';
  static const kelvin = 'K';
  static const mole = 'mol';
  static const candela = 'cd';
  static const newton = 'N';
  static const joule = 'J';
  static const watt = 'W';
  static const pascal = 'Pa';
  static const hertz = 'Hz';
  static const volt = 'V';
  static const ohm = 'Ω';
  static const farad = 'F';
  static const tesla = 'T';
}

/// Common imperial units.
class DocxImperialUnits {
  static const inch = 'in';
  static const foot = 'ft';
  static const yard = 'yd';
  static const mile = 'mi';
  static const pound = 'lb';
  static const ounce = 'oz';
  static const pint = 'pt';
  static const gallon = 'gal';
  static const fahrenheit = '°F';
}

// ============================================================
// ACADEMIC DIAGRAMS
// ============================================================

/// A generic diagram node for flowcharts, UML, ER, network diagrams.
class DocxDiagramNode {
  final String id;
  final String label;
  final DocxDiagramNodeShape shape;
  final double x;
  final double y;
  final double width;
  final double height;
  final String? fillColor;
  final String? textColor;
  final Map<String, String> attributes;

  const DocxDiagramNode({
    required this.id,
    required this.label,
    this.shape = DocxDiagramNodeShape.rectangle,
    this.x = 0,
    this.y = 0,
    this.width = 120,
    this.height = 60,
    this.fillColor,
    this.textColor,
    this.attributes = const {},
  });
}

enum DocxDiagramNodeShape {
  rectangle, roundedRectangle, diamond, ellipse, parallelogram,
  cylinder, cloud, actor, database, document, startEnd, process,
}

/// A connection between two diagram nodes.
class DocxDiagramEdge {
  final String id;
  final String sourceId;
  final String targetId;
  final String? label;
  final DocxEdgeType edgeType;
  final bool dashed;

  const DocxDiagramEdge({
    required this.id,
    required this.sourceId,
    required this.targetId,
    this.label,
    this.edgeType = DocxEdgeType.arrow,
    this.dashed = false,
  });
}

enum DocxEdgeType { arrow, doubleArrow, line, openArrow, diamond, circle }

/// A structured diagram (flowchart, UML, ER, network, coordinate plane, etc.).
///
/// ```dart
/// DocxDiagram(
///   type: DocxDiagramType.flowchart,
///   nodes: [
///     DocxDiagramNode(id: 'start', label: 'Start', shape: DocxDiagramNodeShape.startEnd),
///     DocxDiagramNode(id: 'process', label: 'Process Data'),
///   ],
///   edges: [DocxDiagramEdge(id: 'e1', sourceId: 'start', targetId: 'process')],
/// )
/// ```
class DocxDiagram extends DocxBlock {
  final DocxDiagramType type;
  final List<DocxDiagramNode> nodes;
  final List<DocxDiagramEdge> edges;
  final String? title;
  final int width;
  final int height;

  const DocxDiagram({
    required this.type,
    this.nodes = const [],
    this.edges = const [],
    this.title,
    this.width = 5000000,
    this.height = 3000000,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Diagram: ${title ?? type.name}]');
        });
      });
    });
  }
}

// ============================================================
// ACADEMIC PUBLISHING FEATURES
// ============================================================

/// A journal article front matter section.
class DocxJournalFrontMatter extends DocxBlock {
  final String title;
  final List<String> authors;
  final String? abstractText;
  final List<String> keywords;
  final String? doi;
  final String? journal;
  final String? volume;
  final String? issue;
  final String? pages;
  final DateTime? submittedDate;
  final DateTime? acceptedDate;
  final DateTime? publishedDate;

  const DocxJournalFrontMatter({
    required this.title,
    required this.authors,
    this.abstractText,
    this.keywords = const [],
    this.doi,
    this.journal,
    this.volume,
    this.issue,
    this.pages,
    this.submittedDate,
    this.acceptedDate,
    this.publishedDate,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    // Title
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:pStyle', nest: () {
          builder.attribute('w:val', 'Title');
        });
        builder.element('w:jc', nest: () {
          builder.attribute('w:val', 'center');
        });
      });
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text(title);
        });
      });
    });
    // Authors
    if (authors.isNotEmpty) {
      builder.element('w:p', nest: () {
        builder.element('w:pPr', nest: () {
          builder.element('w:jc', nest: () {
            builder.attribute('w:val', 'center');
          });
        });
        builder.element('w:r', nest: () {
          builder.element('w:t', nest: () {
            builder.text(authors.join(', '));
          });
        });
      });
    }
    // Abstract
    if (abstractText != null) {
      builder.element('w:p', nest: () {
        builder.element('w:r', nest: () {
          builder.element('w:rPr', nest: () {
            builder.element('w:b');
          });
          builder.element('w:t', nest: () {
            builder.attribute('xml:space', 'preserve');
            builder.text('Abstract. ');
          });
        });
        builder.element('w:r', nest: () {
          builder.element('w:t', nest: () {
            builder.text(abstractText!);
          });
        });
      });
    }
    // Keywords
    if (keywords.isNotEmpty) {
      builder.element('w:p', nest: () {
        builder.element('w:r', nest: () {
          builder.element('w:rPr', nest: () {
            builder.element('w:i');
          });
          builder.element('w:t', nest: () {
            builder.text('Keywords: ${keywords.join(', ')}');
          });
        });
      });
    }
  }
}

/// A thesis/dissertation front matter.
class DocxThesisFrontMatter extends DocxBlock {
  final String title;
  final String author;
  final String? degree;
  final String? institution;
  final String? department;
  final int? year;
  final String? supervisorName;
  final String? abstractText;
  final List<String> acknowledgements;

  const DocxThesisFrontMatter({
    required this.title,
    required this.author,
    this.degree,
    this.institution,
    this.department,
    this.year,
    this.supervisorName,
    this.abstractText,
    this.acknowledgements = const [],
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:pStyle', nest: () {
          builder.attribute('w:val', 'Title');
        });
        builder.element('w:jc', nest: () {
          builder.attribute('w:val', 'center');
        });
      });
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text(title);
        });
      });
    });
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:jc', nest: () {
          builder.attribute('w:val', 'center');
        });
      });
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          final lines = [
            author,
            if (degree case final d?) d,
            if (institution case final inst?) inst,
            if (department case final dept?) dept,
            if (year case final y?) y.toString(),
          ];
          builder.text(lines.join('\n'));
        });
      });
    });
  }
}

/// A book front matter block (title page, copyright, dedication).
class DocxBookFrontMatter extends DocxBlock {
  final String title;
  final String? subtitle;
  final List<String> authors;
  final String? publisher;
  final int? year;
  final String? isbn;
  final String? edition;
  final String? dedication;
  final String? copyrightNotice;

  const DocxBookFrontMatter({
    required this.title,
    this.subtitle,
    this.authors = const [],
    this.publisher,
    this.year,
    this.isbn,
    this.edition,
    this.dedication,
    this.copyrightNotice,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:pStyle', nest: () {
          builder.attribute('w:val', 'Title');
        });
        builder.element('w:jc', nest: () {
          builder.attribute('w:val', 'center');
        });
      });
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text(title);
        });
      });
    });
    if (subtitle != null) {
      builder.element('w:p', nest: () {
        builder.element('w:pPr', nest: () {
          builder.element('w:pStyle', nest: () {
            builder.attribute('w:val', 'Subtitle');
          });
          builder.element('w:jc', nest: () {
            builder.attribute('w:val', 'center');
          });
        });
        builder.element('w:r', nest: () {
          builder.element('w:t', nest: () {
            builder.text(subtitle!);
          });
        });
      });
    }
    if (copyrightNotice != null) {
      builder.element('w:p', nest: () {
        builder.element('w:r', nest: () {
          builder.element('w:t', nest: () {
            builder.text(copyrightNotice!);
          });
        });
      });
    }
  }
}

/// List of figures section (academic publishing).
class DocxListOfFigures extends DocxBlock {
  final String title;
  final List<DocxFigureEntry> entries;

  const DocxListOfFigures({
    this.title = 'List of Figures',
    this.entries = const [],
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:pStyle', nest: () {
          builder.attribute('w:val', 'Heading1');
        });
      });
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text(title);
        });
      });
    });
    for (final entry in entries) {
      builder.element('w:p', nest: () {
        builder.element('w:r', nest: () {
          builder.element('w:t', nest: () {
            builder.text('Figure ${entry.number}: ${entry.caption}');
          });
        });
        builder.element('w:r', nest: () {
          builder.element('w:tab');
          builder.element('w:t', nest: () {
            builder.text(entry.page.toString());
          });
        });
      });
    }
  }
}

/// List of tables section.
class DocxListOfTables extends DocxBlock {
  final String title;
  final List<DocxFigureEntry> entries;

  const DocxListOfTables({
    this.title = 'List of Tables',
    this.entries = const [],
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:pStyle', nest: () {
          builder.attribute('w:val', 'Heading1');
        });
      });
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text(title);
        });
      });
    });
    for (final entry in entries) {
      builder.element('w:p', nest: () {
        builder.element('w:r', nest: () {
          builder.element('w:t', nest: () {
            builder.text('Table ${entry.number}: ${entry.caption}');
          });
        });
      });
    }
  }
}

class DocxFigureEntry {
  final int number;
  final String caption;
  final int page;
  const DocxFigureEntry({
    required this.number,
    required this.caption,
    required this.page,
  });
}

/// A glossary block.
class DocxGlossary extends DocxBlock {
  final String title;
  final List<DocxGlossaryEntry> entries;

  const DocxGlossary({
    this.title = 'Glossary',
    this.entries = const [],
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:pStyle', nest: () {
          builder.attribute('w:val', 'Heading1');
        });
      });
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text(title);
        });
      });
    });
    final sorted = List.of(entries)..sort((a, b) => a.term.compareTo(b.term));
    for (final entry in sorted) {
      builder.element('w:p', nest: () {
        builder.element('w:r', nest: () {
          builder.element('w:rPr', nest: () {
            builder.element('w:b');
          });
          builder.element('w:t', nest: () {
            builder.attribute('xml:space', 'preserve');
            builder.text('${entry.term}: ');
          });
        });
        builder.element('w:r', nest: () {
          builder.element('w:t', nest: () {
            builder.text(entry.definition);
          });
        });
      });
    }
  }
}

class DocxGlossaryEntry {
  final String term;
  final String definition;
  final String? abbreviation;
  const DocxGlossaryEntry({
    required this.term,
    required this.definition,
    this.abbreviation,
  });
}

/// An appendix section.
class DocxAppendix extends DocxBlock {
  final String label;
  final String title;
  final List<DocxBlock> children;

  const DocxAppendix({
    required this.label,
    required this.title,
    this.children = const [],
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:pPr', nest: () {
        builder.element('w:pStyle', nest: () {
          builder.attribute('w:val', 'Heading1');
        });
      });
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('Appendix $label: $title');
        });
      });
    });
    for (final child in children) {
      child.buildXml(builder);
    }
  }
}
