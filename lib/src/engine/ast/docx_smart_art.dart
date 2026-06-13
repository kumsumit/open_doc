import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_node.dart';

// ============================================================
// SMART ART (ORG CHARTS, TIMELINES, PROCESS DIAGRAMS)
// ============================================================

/// A node in a SmartArt diagram.
class DocxSmartArtNode {
  final String id;
  final String label;
  final String? sublabel;
  final List<DocxSmartArtNode> children;
  final String? fillColor;
  final String? textColor;

  const DocxSmartArtNode({
    required this.id,
    required this.label,
    this.sublabel,
    this.children = const [],
    this.fillColor,
    this.textColor,
  });
}

/// A SmartArt diagram block (org chart, timeline, process, etc.).
///
/// ```dart
/// DocxSmartArt(
///   layout: DocxSmartArtLayout.orgChart,
///   nodes: [
///     DocxSmartArtNode(id: 'ceo', label: 'CEO', children: [
///       DocxSmartArtNode(id: 'cto', label: 'CTO'),
///       DocxSmartArtNode(id: 'cfo', label: 'CFO'),
///     ]),
///   ],
/// )
/// ```
class DocxSmartArt extends DocxBlock {
  final DocxSmartArtLayout layout;
  final List<DocxSmartArtNode> nodes;
  final int width;
  final int height;
  final String? title;

  const DocxSmartArt({
    required this.layout,
    required this.nodes,
    this.width = 5486400,
    this.height = 3200400,
    this.title,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:drawing', nest: () {
          builder.element('wp:inline',
              namespaceUris: {
                'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
              },
              nest: () {
            builder.element('wp:extent', nest: () {
              builder.attribute('cx', width.toString());
              builder.attribute('cy', height.toString());
            });
            builder.element('a:graphic',
                namespaceUris: {
                  'a': 'http://schemas.openxmlformats.org/drawingml/2006/main'
                },
                nest: () {
              builder.element('a:graphicData', nest: () {
                builder.attribute(
                    'uri', 'http://schemas.openxmlformats.org/drawingml/2006/diagram');
                _buildDiagramData(builder);
              });
            });
          });
        });
      });
    });
  }

  void _buildDiagramData(XmlBuilder builder) {
    builder.element('dgm:relIds',
        namespaceUris: {
          'dgm': 'http://schemas.openxmlformats.org/drawingml/2006/diagram',
          'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        },
        nest: () {
      builder.attribute('r:dm', 'rId1');
      builder.attribute('r:lo', 'rId2');
      builder.attribute('r:qs', 'rId3');
      builder.attribute('r:cs', 'rId4');
    });
  }
}

// ============================================================
// ORG CHART
// ============================================================

/// Convenience constructor for org chart SmartArt.
class DocxOrgChart extends DocxSmartArt {
  const DocxOrgChart({
    required super.nodes,
    super.width,
    super.height,
    super.title,
    super.id,
  }) : super(layout: DocxSmartArtLayout.orgChart);
}

// ============================================================
// TIMELINE
// ============================================================

/// A single event on a timeline.
class DocxTimelineEvent {
  final String id;
  final String label;
  final String? date;
  final String? description;
  final String? fillColor;

  const DocxTimelineEvent({
    required this.id,
    required this.label,
    this.date,
    this.description,
    this.fillColor,
  });
}

/// A horizontal/vertical timeline diagram.
///
/// ```dart
/// DocxTimeline(
///   events: [
///     DocxTimelineEvent(id: 'e1', label: 'Founded', date: '2010'),
///     DocxTimelineEvent(id: 'e2', label: 'Series A', date: '2013'),
///   ],
/// )
/// ```
class DocxTimeline extends DocxBlock {
  final List<DocxTimelineEvent> events;
  final bool horizontal;
  final int width;
  final int height;

  const DocxTimeline({
    required this.events,
    this.horizontal = true,
    this.width = 5486400,
    this.height = 1200000,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    // Render timeline as a SmartArt diagram placeholder
    final smartArt = DocxSmartArt(
      layout: DocxSmartArtLayout.timeline,
      nodes: events
          .map((e) => DocxSmartArtNode(
                id: e.id,
                label: e.label,
                sublabel: e.date,
                fillColor: e.fillColor,
              ))
          .toList(),
      width: width,
      height: height,
    );
    smartArt.buildXml(builder);
  }
}

// ============================================================
// PROCESS DIAGRAM
// ============================================================

/// A single step in a process diagram.
class DocxProcessStep {
  final String id;
  final String label;
  final String? description;
  final String? fillColor;

  const DocxProcessStep({
    required this.id,
    required this.label,
    this.description,
    this.fillColor,
  });
}

/// A process / flow diagram (left-to-right steps with arrows).
///
/// ```dart
/// DocxProcessDiagram(
///   steps: [
///     DocxProcessStep(id: 's1', label: 'Plan'),
///     DocxProcessStep(id: 's2', label: 'Design'),
///     DocxProcessStep(id: 's3', label: 'Build'),
///   ],
/// )
/// ```
class DocxProcessDiagram extends DocxBlock {
  final List<DocxProcessStep> steps;
  final int width;
  final int height;

  const DocxProcessDiagram({
    required this.steps,
    this.width = 5486400,
    this.height = 800000,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    final smartArt = DocxSmartArt(
      layout: DocxSmartArtLayout.process,
      nodes: steps
          .map((s) => DocxSmartArtNode(
                id: s.id,
                label: s.label,
                sublabel: s.description,
                fillColor: s.fillColor,
              ))
          .toList(),
      width: width,
      height: height,
    );
    smartArt.buildXml(builder);
  }
}
