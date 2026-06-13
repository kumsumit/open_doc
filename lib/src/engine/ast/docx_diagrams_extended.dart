// ============================================================
// EXTENDED DIAGRAMS: COORDINATE PLANE, FUNCTION PLOTTING,
// GEOMETRY CONSTRUCTIONS, CIRCUIT DIAGRAMS, BIOLOGICAL DIAGRAMS
// ============================================================

import 'package:xml/xml.dart';

import 'docx_node.dart';

// ============================================================
// COORDINATE PLANE
// ============================================================

/// A 2-D axis with range and tick configuration.
class DocxAxis {
  final double min;
  final double max;
  final double tickInterval;
  final String? label;
  final bool showGrid;
  final bool showArrow;

  const DocxAxis({
    required this.min,
    required this.max,
    this.tickInterval = 1.0,
    this.label,
    this.showGrid = true,
    this.showArrow = true,
  });
}

/// A point plotted on the coordinate plane.
class DocxPlotPoint {
  final double x;
  final double y;
  final String? label;
  final String color;

  const DocxPlotPoint({
    required this.x,
    required this.y,
    this.label,
    this.color = '000000',
  });
}

/// A coordinate plane with optional plotted points and lines.
class DocxCoordinatePlane extends DocxBlock {
  final DocxAxis xAxis;
  final DocxAxis yAxis;
  final List<DocxPlotPoint> points;
  final int widthEmu;
  final int heightEmu;
  final String? title;

  const DocxCoordinatePlane({
    required this.xAxis,
    required this.yAxis,
    this.points = const [],
    this.widthEmu = 3429000,
    this.heightEmu = 2286000,
    this.title,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Coordinate Plane: x(${xAxis.min}..${xAxis.max})'
              ' y(${yAxis.min}..${yAxis.max})'
              '${title != null ? " – $title" : ""}]');
        });
      });
    });
  }
}

// ============================================================
// FUNCTION / GRAPH PLOTTING
// ============================================================

/// A mathematical function to plot as a curve.
class DocxPlotFunction {
  final String expression; // e.g. 'sin(x)', 'x^2 + 1'
  final String color;
  final double strokeWidth;
  final String? label;

  const DocxPlotFunction({
    required this.expression,
    this.color = 'E84040',
    this.strokeWidth = 1.5,
    this.label,
  });

  /// Evaluate the function at x (simple cases only; full parser not included).
  double? evalAt(double x) {
    // Stub: cannot safely evaluate arbitrary expressions in pure Dart without
    // a math expression parser. Real implementation uses dart_eval or exprtk.
    return null;
  }
}

/// A graph that plots one or more functions over a shared coordinate plane.
class DocxFunctionPlot extends DocxBlock {
  final DocxAxis xAxis;
  final DocxAxis yAxis;
  final List<DocxPlotFunction> functions;
  final List<DocxPlotPoint> annotations;
  final int widthEmu;
  final int heightEmu;
  final String? title;

  const DocxFunctionPlot({
    required this.xAxis,
    required this.yAxis,
    required this.functions,
    this.annotations = const [],
    this.widthEmu = 3429000,
    this.heightEmu = 2286000,
    this.title,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    final funcList = functions.map((f) => f.expression).join(', ');
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Function Plot: $funcList'
              '${title != null ? " – $title" : ""}]');
        });
      });
    });
  }
}

// ============================================================
// GEOMETRY CONSTRUCTIONS
// ============================================================

/// Geometry primitive types.
enum DocxGeomPrimitiveType { point, line, segment, ray, circle, arc, polygon, angle }

/// A single geometric primitive in a construction.
class DocxGeomPrimitive {
  final String id;
  final DocxGeomPrimitiveType type;
  final List<DocxPlotPoint> points;
  final double? radius;
  final String color;
  final bool showLabel;
  final String? label;

  const DocxGeomPrimitive({
    required this.id,
    required this.type,
    required this.points,
    this.radius,
    this.color = '000000',
    this.showLabel = true,
    this.label,
  });
}

/// A geometry construction diagram (Euclidean constructions).
class DocxGeometryConstruction extends DocxBlock {
  final List<DocxGeomPrimitive> primitives;
  final DocxAxis xAxis;
  final DocxAxis yAxis;
  final int widthEmu;
  final int heightEmu;
  final String? title;

  const DocxGeometryConstruction({
    required this.primitives,
    required this.xAxis,
    required this.yAxis,
    this.widthEmu = 3429000,
    this.heightEmu = 3429000,
    this.title,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Geometry Construction: ${primitives.length} primitives'
              '${title != null ? " – $title" : ""}]');
        });
      });
    });
  }
}

// ============================================================
// CIRCUIT DIAGRAMS
// ============================================================

/// Types of electronic circuit components.
enum DocxCircuitComponentType {
  resistor, capacitor, inductor, diode, led, transistorNpn, transistorPnp,
  battery, voltageSource, currentSource, ground, wire, switch_, opAmp, gate,
}

/// A single circuit component placed on a schematic.
class DocxCircuitComponent {
  final String id;
  final DocxCircuitComponentType type;
  final double x;
  final double y;
  final double rotation; // degrees
  final String? label;
  final String? value; // e.g. '10kΩ', '100µF'
  final String color;

  const DocxCircuitComponent({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.label,
    this.value,
    this.color = '000000',
  });
}

/// A wire connecting two points in a circuit.
class DocxCircuitWire {
  final String fromComponentId;
  final String toComponentId;
  final List<DocxPlotPoint> waypoints; // intermediate routing points

  const DocxCircuitWire({
    required this.fromComponentId,
    required this.toComponentId,
    this.waypoints = const [],
  });
}

/// A circuit schematic diagram.
class DocxCircuitDiagram extends DocxBlock {
  final List<DocxCircuitComponent> components;
  final List<DocxCircuitWire> wires;
  final int widthEmu;
  final int heightEmu;
  final String? title;

  const DocxCircuitDiagram({
    required this.components,
    required this.wires,
    this.widthEmu = 4572000,
    this.heightEmu = 3429000,
    this.title,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Circuit Diagram: ${components.length} components,'
              ' ${wires.length} wires'
              '${title != null ? " – $title" : ""}]');
        });
      });
    });
  }
}

// ============================================================
// BIOLOGICAL DIAGRAMS
// ============================================================

/// Categories of biological diagrams.
enum DocxBioDiagramType {
  animalCell, plantCell, bacterialCell, mitosis, meiosis,
  foodChain, foodWeb, ecologyPyramid, dnaHelix, proteinFolding,
  phylogeneticTree, bodySystem, organSystem,
}

/// A labelled component within a biological diagram.
class DocxBioComponent {
  final String id;
  final String name;
  final double x;
  final double y;
  final double width;
  final double height;
  final String fillColor;
  final String strokeColor;
  final String? description;

  const DocxBioComponent({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.fillColor = 'FFFFFF',
    this.strokeColor = '000000',
    this.description,
  });
}

/// A biological diagram (cell, organism, ecosystem, DNA, etc.)
class DocxBiologicalDiagram extends DocxBlock {
  final DocxBioDiagramType diagramType;
  final List<DocxBioComponent> components;
  final int widthEmu;
  final int heightEmu;
  final String? title;
  final String? caption;

  const DocxBiologicalDiagram({
    required this.diagramType,
    required this.components,
    this.widthEmu = 3429000,
    this.heightEmu = 3429000,
    this.title,
    this.caption,
    super.id,
  });

  factory DocxBiologicalDiagram.animalCell({String? title}) =>
      DocxBiologicalDiagram(
        diagramType: DocxBioDiagramType.animalCell,
        title: title ?? 'Animal Cell',
        components: const [
          DocxBioComponent(id: 'nucleus', name: 'Nucleus',
              x: 120, y: 100, width: 80, height: 70, fillColor: 'FFD700'),
          DocxBioComponent(id: 'mitochondria', name: 'Mitochondria',
              x: 220, y: 80, width: 60, height: 35, fillColor: 'FF8C00'),
          DocxBioComponent(id: 'er', name: 'Endoplasmic Reticulum',
              x: 80, y: 160, width: 100, height: 40, fillColor: 'ADD8E6'),
          DocxBioComponent(id: 'golgi', name: 'Golgi Apparatus',
              x: 200, y: 160, width: 70, height: 50, fillColor: 'FFB6C1'),
          DocxBioComponent(id: 'membrane', name: 'Cell Membrane',
              x: 20, y: 20, width: 300, height: 260, fillColor: 'F0F0F0'),
        ],
      );

  factory DocxBiologicalDiagram.plantCell({String? title}) =>
      DocxBiologicalDiagram(
        diagramType: DocxBioDiagramType.plantCell,
        title: title ?? 'Plant Cell',
        components: const [
          DocxBioComponent(id: 'cell_wall', name: 'Cell Wall',
              x: 10, y: 10, width: 320, height: 280, fillColor: 'D2B48C'),
          DocxBioComponent(id: 'chloroplast', name: 'Chloroplast',
              x: 40, y: 40, width: 70, height: 45, fillColor: '228B22'),
          DocxBioComponent(id: 'vacuole', name: 'Central Vacuole',
              x: 110, y: 80, width: 140, height: 140, fillColor: 'E0F0FF'),
          DocxBioComponent(id: 'nucleus', name: 'Nucleus',
              x: 60, y: 130, width: 70, height: 60, fillColor: 'FFD700'),
        ],
      );

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text('[Biological Diagram: ${diagramType.name}'
              ' (${components.length} components)'
              '${title != null ? " – $title" : ""}]');
        });
      });
    });
    if (caption != null) {
      builder.element('w:p', nest: () {
        builder.element('w:pPr', nest: () {
          builder.element('w:pStyle', nest: () {
            builder.attribute('w:val', 'Caption');
          });
        });
        builder.element('w:r', nest: () {
          builder.element('w:t', nest: () => builder.text(caption!));
        });
      });
    }
  }
}
