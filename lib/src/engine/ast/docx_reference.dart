import 'package:xml/xml.dart';

import 'docx_node.dart';

/// Reference citation styles.
enum DocxReferenceStyle { apa, mla, chicago, ieee, vancouver, custom }

/// A cross-document or cross-section reference (inline).
///
/// ```dart
/// DocxReference(
///   label: 'Figure 1',
///   targetId: 'fig-1',
///   type: DocxReferenceType.figure,
/// )
/// ```
class DocxReference extends DocxInline {
  /// Human-readable label displayed in the document.
  final String label;

  /// Target element ID (bookmark, figure, table, section, equation).
  final String targetId;

  /// Type of reference.
  final DocxReferenceType type;

  const DocxReference({
    required this.label,
    required this.targetId,
    this.type = DocxReferenceType.bookmark,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:fldSimple', nest: () {
      final fieldType = switch (type) {
        DocxReferenceType.figure => 'REF',
        DocxReferenceType.table => 'REF',
        DocxReferenceType.equation => 'REF',
        DocxReferenceType.section => 'SECTIONPAGES',
        DocxReferenceType.bookmark => 'REF',
        DocxReferenceType.heading => 'REF',
      };
      builder.attribute('w:instr', ' $fieldType $targetId \\h ');
      builder.element('w:r', nest: () {
        builder.element('w:t', nest: () {
          builder.text(label);
        });
      });
    });
  }
}

/// Type of document reference.
enum DocxReferenceType {
  figure,
  table,
  equation,
  section,
  bookmark,
  heading,
}

/// A bibliographic citation entry (used in bibliography section).
///
/// ```dart
/// DocxCitationEntry(
///   id: 'smith2023',
///   style: DocxReferenceStyle.apa,
///   authors: ['Smith, J.', 'Doe, A.'],
///   title: 'A Study on Document Editors',
///   year: 2023,
///   journal: 'Journal of Software Engineering',
///   volume: '15',
///   pages: '23-45',
/// )
/// ```
class DocxCitationEntry {
  final String id;
  final DocxReferenceStyle style;
  final List<String> authors;
  final String title;
  final int? year;
  final String? journal;
  final String? publisher;
  final String? volume;
  final String? issue;
  final String? pages;
  final String? doi;
  final String? url;
  final String? isbn;

  const DocxCitationEntry({
    required this.id,
    this.style = DocxReferenceStyle.apa,
    this.authors = const [],
    required this.title,
    this.year,
    this.journal,
    this.publisher,
    this.volume,
    this.issue,
    this.pages,
    this.doi,
    this.url,
    this.isbn,
  });

  /// Formats the citation according to the chosen style.
  String format() {
    switch (style) {
      case DocxReferenceStyle.apa:
        return _formatApa();
      case DocxReferenceStyle.mla:
        return _formatMla();
      case DocxReferenceStyle.chicago:
        return _formatChicago();
      case DocxReferenceStyle.ieee:
        return _formatIeee();
      case DocxReferenceStyle.vancouver:
        return _formatVancouver();
      case DocxReferenceStyle.custom:
        return title;
    }
  }

  String _formatApa() {
    final authorsStr = authors.join(', ');
    final yearStr = year != null ? '($year)' : '';
    final journalStr = journal != null ? '. $journal' : '';
    final volStr = volume != null ? ', $volume' : '';
    final pagesStr = pages != null ? ', $pages' : '';
    return '$authorsStr $yearStr. $title$journalStr$volStr$pagesStr.';
  }

  String _formatMla() {
    final authorsStr = authors.isNotEmpty ? '${authors.first}.' : '';
    final yearStr = year != null ? '$year' : 'n.d.';
    return '$authorsStr "$title." ${journal ?? publisher ?? ''}, $yearStr.';
  }

  String _formatChicago() {
    final authorsStr = authors.join(', ');
    final yearStr = year != null ? '$year' : '';
    return '$authorsStr. "$title." ${journal ?? ''} $volume ($yearStr): $pages.';
  }

  String _formatIeee() {
    final authorsStr = authors.join(', ');
    final yearStr = year != null ? ', $year' : '';
    return '$authorsStr, "$title," ${journal ?? ''}$yearStr.';
  }

  String _formatVancouver() {
    final authorsStr = authors.join(', ');
    final yearStr = year != null ? ' $year' : '';
    return '$authorsStr. $title. ${journal ?? ''}.$yearStr;$volume:$pages.';
  }
}

/// An inline citation reference (e.g. "[1]", "(Smith, 2023)").
class DocxCitation extends DocxInline {
  /// Citation entry IDs being referenced.
  final List<String> entryIds;

  /// Citation style to render.
  final DocxReferenceStyle style;

  const DocxCitation({
    required this.entryIds,
    this.style = DocxReferenceStyle.apa,
    super.id,
  });

  @override
  void accept(DocxVisitor visitor) => visitor.visitText(this);

  @override
  void buildXml(XmlBuilder builder) {
    builder.element('w:r', nest: () {
      builder.element('w:t', nest: () {
        builder.text('[${entryIds.join(', ')}]');
      });
    });
  }
}
