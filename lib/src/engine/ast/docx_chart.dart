import 'package:xml/xml.dart';

import '../core/enums.dart';
import 'docx_node.dart';

// ============================================================
// CHART DATA MODEL
// ============================================================

/// A single data series in a chart.
class DocxChartSeries {
  final String name;
  final List<String> categories;
  final List<double> values;
  final String? color;

  const DocxChartSeries({
    required this.name,
    required this.categories,
    required this.values,
    this.color,
  });
}

/// Axis configuration for a chart.
class DocxChartAxis {
  final String? title;
  final double? min;
  final double? max;
  final bool logarithmic;
  final bool showGridLines;

  const DocxChartAxis({
    this.title,
    this.min,
    this.max,
    this.logarithmic = false,
    this.showGridLines = true,
  });
}

/// A chart embedded in the document.
///
/// ## Pie chart
/// ```dart
/// DocxChart.pie(
///   title: 'Market Share',
///   series: DocxChartSeries(
///     name: 'Q1',
///     categories: ['Product A', 'Product B', 'Product C'],
///     values: [45, 30, 25],
///   ),
/// )
/// ```
///
/// ## Bar chart
/// ```dart
/// DocxChart(
///   type: DocxChartType.bar,
///   title: 'Sales by Quarter',
///   series: [
///     DocxChartSeries(name: '2023', categories: ['Q1','Q2','Q3','Q4'], values: [10,15,12,18]),
///   ],
/// )
/// ```
class DocxChart extends DocxBlock {
  final DocxChartType type;
  final String? title;
  final List<DocxChartSeries> series;
  final DocxChartAxis? xAxis;
  final DocxChartAxis? yAxis;
  final bool showLegend;
  final bool showDataLabels;
  final int width;
  final int height;

  /// For combo charts: which series index uses a secondary (line) type.
  final List<int> secondarySeriesIndexes;

  const DocxChart({
    required this.type,
    this.title,
    this.series = const [],
    this.xAxis,
    this.yAxis,
    this.showLegend = true,
    this.showDataLabels = false,
    this.width = 4800000,
    this.height = 3000000,
    this.secondarySeriesIndexes = const [],
    super.id,
  });

  factory DocxChart.pie({
    String? title,
    required DocxChartSeries series,
    bool showDataLabels = true,
    int width = 4800000,
    int height = 3000000,
  }) =>
      DocxChart(
        type: DocxChartType.pie,
        title: title,
        series: [series],
        showDataLabels: showDataLabels,
        width: width,
        height: height,
      );

  factory DocxChart.bar({
    String? title,
    required List<DocxChartSeries> series,
    bool showLegend = true,
    int width = 4800000,
    int height = 3000000,
  }) =>
      DocxChart(
        type: DocxChartType.bar,
        title: title,
        series: series,
        showLegend: showLegend,
        width: width,
        height: height,
      );

  factory DocxChart.line({
    String? title,
    required List<DocxChartSeries> series,
    DocxChartAxis? xAxis,
    DocxChartAxis? yAxis,
    int width = 4800000,
    int height = 3000000,
  }) =>
      DocxChart(
        type: DocxChartType.line,
        title: title,
        series: series,
        xAxis: xAxis,
        yAxis: yAxis,
        width: width,
        height: height,
      );

  factory DocxChart.scatter({
    String? title,
    required List<DocxChartSeries> series,
    int width = 4800000,
    int height = 3000000,
  }) =>
      DocxChart(
        type: DocxChartType.scatter,
        title: title,
        series: series,
        width: width,
        height: height,
      );

  factory DocxChart.area({
    String? title,
    required List<DocxChartSeries> series,
    int width = 4800000,
    int height = 3000000,
  }) =>
      DocxChart(
        type: DocxChartType.area,
        title: title,
        series: series,
        width: width,
        height: height,
      );

  factory DocxChart.combo({
    String? title,
    required List<DocxChartSeries> series,
    List<int> secondarySeriesIndexes = const [],
    int width = 4800000,
    int height = 3000000,
  }) =>
      DocxChart(
        type: DocxChartType.combo,
        title: title,
        series: series,
        secondarySeriesIndexes: secondarySeriesIndexes,
        width: width,
        height: height,
      );

  factory DocxChart.histogram({
    String? title,
    required DocxChartSeries series,
    int width = 4800000,
    int height = 3000000,
  }) =>
      DocxChart(
        type: DocxChartType.histogram,
        title: title,
        series: [series],
        width: width,
        height: height,
      );

  @override
  void accept(DocxVisitor visitor) => visitor.visitParagraph(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:p', nest: () {
      builder.element('w:r', nest: () {
        builder.element('w:drawing', nest: () {
          _buildDrawingXml(builder);
        });
      });
    });
  }

  void _buildDrawingXml(XmlBuilder builder) {
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
              'uri', 'http://schemas.openxmlformats.org/drawingml/2006/chart');
          builder.element('c:chart',
              namespaceUris: {
                'c': 'http://schemas.openxmlformats.org/drawingml/2006/chart',
                'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
              },
              nest: () {
            builder.attribute('r:id', 'rId${id ?? 'chart1'}');
          });
        });
      });
    });
  }

  /// Generates the chart XML content (for the chart part).
  String buildChartXml() {
    final xmlBuilder = XmlBuilder();
    xmlBuilder.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    xmlBuilder.element('c:chartSpace',
        namespaceUris: {
          'c': 'http://schemas.openxmlformats.org/drawingml/2006/chart',
          'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
          'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
        },
        nest: () {
      if (title != null) {
        xmlBuilder.element('c:title', nest: () {
          xmlBuilder.element('c:tx', nest: () {
            xmlBuilder.element('c:rich', nest: () {
              xmlBuilder.element('a:p', nest: () {
                xmlBuilder.element('a:r', nest: () {
                  xmlBuilder.element('a:t', nest: () {
                    xmlBuilder.text(title!);
                  });
                });
              });
            });
          });
        });
      }
      xmlBuilder.element('c:chart', nest: () {
        xmlBuilder.element('c:plotArea', nest: () {
          _buildPlotArea(xmlBuilder);
        });
        if (showLegend) {
          xmlBuilder.element('c:legend', nest: () {
            xmlBuilder.element('c:legendPos', nest: () {
              xmlBuilder.attribute('val', 'b');
            });
          });
        }
      });
    });
    return xmlBuilder.buildDocument().toXmlString(pretty: true);
  }

  void _buildPlotArea(XmlBuilder b) {
    final chartTag = _chartElementTag();
    b.element(chartTag, nest: () {
      for (int i = 0; i < series.length; i++) {
        _buildSeries(b, series[i], i);
      }
    });
  }

  String _chartElementTag() => switch (type) {
        DocxChartType.pie => 'c:pieChart',
        DocxChartType.bar => 'c:barChart',
        DocxChartType.line => 'c:lineChart',
        DocxChartType.scatter => 'c:scatterChart',
        DocxChartType.area => 'c:areaChart',
        DocxChartType.combo => 'c:barChart',
        DocxChartType.histogram => 'c:barChart',
        DocxChartType.boxPlot => 'c:barChart',
        DocxChartType.heatmap => 'c:barChart',
        DocxChartType.violin => 'c:lineChart',
      };

  void _buildSeries(XmlBuilder b, DocxChartSeries s, int idx) {
    b.element('c:ser', nest: () {
      b.element('c:idx', nest: () => b.attribute('val', idx.toString()));
      b.element('c:order', nest: () => b.attribute('val', idx.toString()));
      b.element('c:tx', nest: () {
        b.element('c:strRef', nest: () {
          b.element('c:v', nest: () => b.text(s.name));
        });
      });
      if (s.categories.isNotEmpty) {
        b.element('c:cat', nest: () {
          b.element('c:strRef', nest: () {
            b.element('c:strCache', nest: () {
              b.element('c:ptCount', nest: () {
                b.attribute('val', s.categories.length.toString());
              });
              for (int i = 0; i < s.categories.length; i++) {
                b.element('c:pt', nest: () {
                  b.attribute('idx', i.toString());
                  b.element('c:v', nest: () => b.text(s.categories[i]));
                });
              }
            });
          });
        });
      }
      b.element('c:val', nest: () {
        b.element('c:numRef', nest: () {
          b.element('c:numCache', nest: () {
            b.element('c:ptCount', nest: () {
              b.attribute('val', s.values.length.toString());
            });
            for (int i = 0; i < s.values.length; i++) {
              b.element('c:pt', nest: () {
                b.attribute('idx', i.toString());
                b.element('c:v', nest: () => b.text(s.values[i].toString()));
              });
            }
          });
        });
      });
      if (showDataLabels) {
        b.element('c:dLbls', nest: () {
          b.element('c:showVal', nest: () => b.attribute('val', '1'));
        });
      }
    });
  }
}
