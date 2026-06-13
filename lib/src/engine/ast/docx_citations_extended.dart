// ============================================================
// CITATION EXTENSIONS: BibTeX, CSL, Zotero, Mendeley
// ============================================================

import 'docx_reference.dart';

// ============================================================
// BIBTEX
// ============================================================

/// BibTeX entry types.
enum DocxBibTexEntryType {
  article, book, booklet, conference, inBook, inCollection, inProceedings,
  manual, mastersThesis, misc, phdThesis, proceedings, techReport, unpublished,
}

/// A BibTeX bibliographic entry.
class DocxBibTexEntry {
  final String citeKey;
  final DocxBibTexEntryType type;
  final Map<String, String> fields;

  const DocxBibTexEntry({
    required this.citeKey,
    required this.type,
    this.fields = const {},
  });

  String get title => fields['title'] ?? '';
  String get author => fields['author'] ?? '';
  String get year => fields['year'] ?? '';
  String get journal => fields['journal'] ?? '';
  String get publisher => fields['publisher'] ?? '';
  String get volume => fields['volume'] ?? '';
  String get pages => fields['pages'] ?? '';
  String get doi => fields['doi'] ?? '';
  String get url => fields['url'] ?? '';

  /// Serialise to BibTeX format string.
  String toBibTex() {
    final typeName = type.name;
    final sb = StringBuffer('@$typeName{$citeKey,\n');
    for (final entry in fields.entries) {
      sb.writeln('  ${entry.key} = {${entry.value}},');
    }
    sb.write('}');
    return sb.toString();
  }

  /// Parse a BibTeX string into a list of entries.
  static List<DocxBibTexEntry> parseAll(String bibtex) {
    final entries = <DocxBibTexEntry>[];
    final entryRe = RegExp(
        r'@(\w+)\s*\{\s*(\w+)\s*,([^@]*)\}',
        dotAll: true);
    for (final m in entryRe.allMatches(bibtex)) {
      final typeName = m.group(1)!.toLowerCase();
      final key = m.group(2)!;
      final body = m.group(3)!;
      final type = DocxBibTexEntryType.values.firstWhere(
        (t) => t.name == typeName,
        orElse: () => DocxBibTexEntryType.misc,
      );
      final fields = <String, String>{};
      final fieldRe = RegExp(r'(\w+)\s*=\s*\{([^}]*)\}');
      for (final fm in fieldRe.allMatches(body)) {
        fields[fm.group(1)!] = fm.group(2)!;
      }
      entries.add(DocxBibTexEntry(citeKey: key, type: type, fields: fields));
    }
    return entries;
  }

  /// Convert to a [DocxCitationEntry] for use in the document model.
  DocxCitationEntry toCitationEntry({
    DocxReferenceStyle style = DocxReferenceStyle.apa,
  }) {
    return DocxCitationEntry(
      id: citeKey,
      style: style,
      authors: author.split(' and ').map((a) => a.trim()).toList(),
      title: title,
      year: int.tryParse(year),
      journal: journal.isNotEmpty ? journal : null,
      publisher: publisher.isNotEmpty ? publisher : null,
      volume: volume.isNotEmpty ? volume : null,
      pages: pages.isNotEmpty ? pages : null,
      doi: doi.isNotEmpty ? doi : null,
      url: url.isNotEmpty ? url : null,
    );
  }
}

// ============================================================
// CSL (CITATION STYLE LANGUAGE)
// ============================================================

/// A CSL variable map — matches the CSL data model.
typedef DocxCslVariables = Map<String, dynamic>;

/// A CSL citation item referencing a bibliography entry.
class DocxCslCitationItem {
  final String id;
  final int? locator;
  final String? locatorType; // 'page', 'chapter', 'verse', etc.

  const DocxCslCitationItem({
    required this.id,
    this.locator,
    this.locatorType,
  });
}

/// A CSL bibliography entry with variables in the standard CSL data model.
class DocxCslEntry {
  final String id;
  final String type; // 'article-journal', 'book', 'chapter', etc.
  final DocxCslVariables variables;

  const DocxCslEntry({
    required this.id,
    required this.type,
    this.variables = const {},
  });

  String get title => variables['title'] as String? ?? '';
  List<String> get authorNames {
    final authors = variables['author'] as List? ?? [];
    return authors
        .cast<Map>()
        .map((a) => '${a['given'] ?? ''} ${a['family'] ?? ''}'.trim())
        .toList();
  }

  int? get issued {
    final issued = variables['issued'] as Map?;
    final parts = issued?['date-parts'] as List?;
    return parts != null && parts.isNotEmpty && (parts.first as List).isNotEmpty
        ? (parts.first as List).first as int?
        : null;
  }

  /// Render citation in the given style.
  String render(DocxReferenceStyle style) {
    final entry = DocxCitationEntry(
      id: id,
      style: style,
      authors: authorNames,
      title: title,
      year: issued,
      journal: variables['container-title'] as String?,
      volume: variables['volume'] as String?,
      issue: variables['issue'] as String?,
      pages: variables['page'] as String?,
      doi: variables['DOI'] as String?,
      url: variables['URL'] as String?,
    );
    return entry.format();
  }
}

/// A simple CSL processor that renders citations and bibliographies.
class DocxCslProcessor {
  final List<DocxCslEntry> library;
  final DocxReferenceStyle defaultStyle;

  const DocxCslProcessor({
    required this.library,
    this.defaultStyle = DocxReferenceStyle.apa,
  });

  /// Render an inline citation for a list of items.
  String renderCitation(List<DocxCslCitationItem> items) {
    final parts = <String>[];
    for (final item in items) {
      final entry = library.cast<DocxCslEntry?>().firstWhere(
            (e) => e?.id == item.id,
            orElse: () => null,
          );
      if (entry != null) parts.add(entry.render(defaultStyle));
    }
    return parts.join('; ');
  }

  /// Render a full bibliography sorted alphabetically by first author.
  List<String> renderBibliography() {
    final sorted = [...library]
      ..sort((a, b) {
        final aName = a.authorNames.isNotEmpty ? a.authorNames.first : '';
        final bName = b.authorNames.isNotEmpty ? b.authorNames.first : '';
        return aName.compareTo(bName);
      });
    return sorted.map((e) => e.render(defaultStyle)).toList();
  }
}

// ============================================================
// ZOTERO INTEGRATION
// ============================================================

/// A Zotero library item (subset of the Zotero API item schema).
class DocxZoteroItem {
  final String key;
  final String itemType; // 'journalArticle', 'book', 'webpage', etc.
  final String title;
  final List<String> authors;
  final int? year;
  final String? publication;
  final String? doi;
  final String? url;
  final String? abstractNote;
  final List<String> tags;

  const DocxZoteroItem({
    required this.key,
    required this.itemType,
    required this.title,
    this.authors = const [],
    this.year,
    this.publication,
    this.doi,
    this.url,
    this.abstractNote,
    this.tags = const [],
  });

  factory DocxZoteroItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final creators = (data['creators'] as List? ?? []).cast<Map<String, dynamic>>();
    final names = creators.map((c) {
      final last = c['lastName'] ?? '';
      final first = c['firstName'] ?? '';
      return '$last, $first'.trim().replaceAll(RegExp(r',\s*$'), '');
    }).toList();
    final dateStr = data['date'] as String? ?? '';
    final yearMatch = RegExp(r'\d{4}').firstMatch(dateStr);
    return DocxZoteroItem(
      key: json['key'] as String? ?? data['key'] as String? ?? '',
      itemType: data['itemType'] as String? ?? 'misc',
      title: data['title'] as String? ?? '',
      authors: names,
      year: yearMatch != null ? int.tryParse(yearMatch.group(0)!) : null,
      publication: data['publicationTitle'] as String?,
      doi: data['DOI'] as String?,
      url: data['url'] as String?,
      abstractNote: data['abstractNote'] as String?,
      tags: (data['tags'] as List? ?? [])
          .cast<Map>()
          .map((t) => t['tag'] as String? ?? '')
          .toList(),
    );
  }

  DocxCitationEntry toCitationEntry({
    DocxReferenceStyle style = DocxReferenceStyle.apa,
  }) =>
      DocxCitationEntry(
        id: key,
        style: style,
        authors: authors,
        title: title,
        year: year,
        journal: publication,
        doi: doi,
        url: url,
      );
}

/// Stub client for the Zotero Web API.
///
/// Real implementation: HTTP calls to `api.zotero.org`.
class DocxZoteroClient {
  final String userId;
  final String? apiKey;

  const DocxZoteroClient({required this.userId, this.apiKey});

  /// Fetch all items from a Zotero library (stub — returns empty list).
  Future<List<DocxZoteroItem>> fetchLibrary({int limit = 100}) async {
    // Real: GET https://api.zotero.org/users/$userId/items?limit=$limit
    return [];
  }

  /// Search items by query string (stub).
  Future<List<DocxZoteroItem>> search(String query) async {
    // Real: GET https://api.zotero.org/users/$userId/items?q=$query
    return [];
  }
}

// ============================================================
// MENDELEY INTEGRATION
// ============================================================

/// A Mendeley document entry (subset of the Mendeley API schema).
class DocxMendeleyDocument {
  final String id;
  final String type; // 'journal', 'book', 'conference_proceedings', etc.
  final String title;
  final List<String> authors;
  final int? year;
  final String? source; // journal/conference name
  final String? doi;
  final String? url;
  final String? abstractText;
  final List<String> keywords;

  const DocxMendeleyDocument({
    required this.id,
    required this.type,
    required this.title,
    this.authors = const [],
    this.year,
    this.source,
    this.doi,
    this.url,
    this.abstractText,
    this.keywords = const [],
  });

  factory DocxMendeleyDocument.fromJson(Map<String, dynamic> json) {
    final authorsList = (json['authors'] as List? ?? []).cast<Map<String, dynamic>>();
    final names = authorsList
        .map((a) => '${a['last_name'] ?? ''}, ${a['first_name'] ?? ''}'
            .trim().replaceAll(RegExp(r',\s*$'), ''))
        .toList();
    return DocxMendeleyDocument(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'misc',
      title: json['title'] as String? ?? '',
      authors: names,
      year: json['year'] as int?,
      source: json['source'] as String?,
      doi: json['doi'] as String?,
      url: json['websites'] is List
          ? ((json['websites'] as List).isNotEmpty
              ? (json['websites'] as List).first as String
              : null)
          : null,
      abstractText: json['abstract'] as String?,
      keywords: (json['keywords'] as List? ?? []).cast<String>(),
    );
  }

  DocxCitationEntry toCitationEntry({
    DocxReferenceStyle style = DocxReferenceStyle.apa,
  }) =>
      DocxCitationEntry(
        id: id,
        style: style,
        authors: authors,
        title: title,
        year: year,
        journal: source,
        doi: doi,
        url: url,
      );
}

/// Stub client for the Mendeley API.
class DocxMendeleyClient {
  final String? accessToken;

  const DocxMendeleyClient({this.accessToken});

  /// Fetch library documents (stub — returns empty list).
  Future<List<DocxMendeleyDocument>> fetchDocuments({int limit = 100}) async {
    // Real: GET https://api.mendeley.com/documents?limit=$limit
    return [];
  }

  /// Search documents by query (stub).
  Future<List<DocxMendeleyDocument>> search(String query) async {
    // Real: GET https://api.mendeley.com/search/catalog?query=$query
    return [];
  }
}
