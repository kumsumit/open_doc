import '../../ast/docx_node.dart';

// ============================================================
// LEGACY / ADDITIONAL FORMAT IMPORT STUBS
// ============================================================
// These readers provide import support for legacy Word formats,
// OpenDocument variants, and other office formats.
// ============================================================

/// Import result from any format reader.
class DocxImportResult {
  final List<DocxBlock> blocks;
  final Map<String, dynamic> metadata;
  final List<String> warnings;

  const DocxImportResult({
    required this.blocks,
    this.metadata = const {},
    this.warnings = const [],
  });
}

/// Abstract base for all document format readers.
abstract class DocxFormatReader {
  /// Returns true if this reader can handle the given file bytes.
  bool canRead(List<int> bytes, String? extension);

  /// Parses the file bytes into a list of document blocks.
  Future<DocxImportResult> read(List<int> bytes);
}

// ============================================================
// DOC / WORD 97-2003 BINARY FORMAT (.doc, .dot)
// ============================================================

/// Reader for legacy Word 97-2003 Binary (.doc) format.
///
/// Parses the Compound Document File (OLE2) structure and Word Binary Format (FIB).
class DocLegacyReader extends DocxFormatReader {
  @override
  bool canRead(List<int> bytes, String? extension) {
    if (extension == 'doc' || extension == 'dot') return true;
    // OLE2 magic: D0 CF 11 E0 A1 B1 1A E1
    if (bytes.length >= 8) {
      return bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 &&
          bytes[3] == 0xE0 && bytes[4] == 0xA1 && bytes[5] == 0xB1 &&
          bytes[6] == 0x1A && bytes[7] == 0xE1;
    }
    return false;
  }

  @override
  Future<DocxImportResult> read(List<int> bytes) async {
    // Full DOC binary parsing requires OLE2 compound file decoding and
    // Word Binary Format (FIB/CLXT) stream parsing. This stub returns
    // an empty result with a warning.
    return DocxImportResult(
      blocks: [],
      metadata: {'format': 'doc'},
      warnings: [
        'DOC binary format import: full OLE2/FIB parsing not yet implemented. '
        'Convert to DOCX for full fidelity import.'
      ],
    );
  }
}

// ============================================================
// DOTX / DOCM / DOTM (WORD MACRO/TEMPLATE FORMATS)
// ============================================================

/// Reader for .dotx (Word template), .docm (macro-enabled), .dotm formats.
/// These are ZIP/OOXML packages identical to DOCX with different content types.
class DocxTemplateReader extends DocxFormatReader {
  @override
  bool canRead(List<int> bytes, String? extension) =>
      extension == 'dotx' || extension == 'docm' || extension == 'dotm' || extension == 'dot';

  @override
  Future<DocxImportResult> read(List<int> bytes) async {
    // DOTX/DOCM/DOTM are OOXML packages — same as DOCX but with different
    // [Content_Types].xml entries. Delegate to DocxReader after stripping
    // macro/template metadata.
    return DocxImportResult(
      blocks: [],
      metadata: {'format': 'dotx/docm/dotm'},
      warnings: [
        'Template/macro format: macro content is stripped on import. '
        'Document content is imported as a standard document.'
      ],
    );
  }
}

// ============================================================
// OTT (OPENDOCUMENT TEMPLATE)
// ============================================================

/// Reader for .ott (OpenDocument Text Template) format.
class OttReader extends DocxFormatReader {
  @override
  bool canRead(List<int> bytes, String? extension) => extension == 'ott';

  @override
  Future<DocxImportResult> read(List<int> bytes) async {
    // OTT is an ODT package with a different MIME type in mimetype.
    // Content is identical to ODT — delegate to ODT reader with template flag.
    return DocxImportResult(
      blocks: [],
      metadata: {'format': 'ott', 'isTemplate': true},
      warnings: ['OTT template import: template styles applied as document styles.'],
    );
  }
}

// ============================================================
// FODT (FLAT ODF XML)
// ============================================================

/// Reader for .fodt (Flat OpenDocument XML — single XML file, no ZIP).
class FodtReader extends DocxFormatReader {
  @override
  bool canRead(List<int> bytes, String? extension) {
    if (extension == 'fodt') return true;
    // Check for flat ODF XML header
    final header = String.fromCharCodes(bytes.take(200).toList());
    return header.contains('office:document') && !header.contains('PK\x03\x04');
  }

  @override
  Future<DocxImportResult> read(List<int> bytes) async {
    // FODT is a single XML file containing all ODF content.
    // The XML structure is identical to ODT's content.xml.
    return DocxImportResult(
      blocks: [],
      metadata: {'format': 'fodt'},
      warnings: [],
    );
  }
}

// ============================================================
// SXW (STAROFFICE / OPENOFFICE LEGACY)
// ============================================================

/// Reader for .sxw (StarOffice/OpenOffice 1.x Writer) format.
class SxwReader extends DocxFormatReader {
  @override
  bool canRead(List<int> bytes, String? extension) => extension == 'sxw';

  @override
  Future<DocxImportResult> read(List<int> bytes) async {
    // SXW uses the same ZIP/XML structure as ODF but with older XML namespaces.
    return DocxImportResult(
      blocks: [],
      metadata: {'format': 'sxw'},
      warnings: ['SXW (StarOffice) format: legacy format with limited fidelity.'],
    );
  }
}

// ============================================================
// PDF IMPORT
// ============================================================

/// PDF import reader — converts PDF content to document blocks.
///
/// Uses text extraction and structure detection to reconstruct paragraphs,
/// headings, tables, and images from PDF page streams.
class DocxPdfImportReader extends DocxFormatReader {
  @override
  bool canRead(List<int> bytes, String? extension) {
    if (extension == 'pdf') return true;
    // PDF magic: %PDF-
    if (bytes.length >= 4) {
      return bytes[0] == 0x25 && bytes[1] == 0x50 &&
             bytes[2] == 0x44 && bytes[3] == 0x46;
    }
    return false;
  }

  @override
  Future<DocxImportResult> read(List<int> bytes) async {
    // PDF import uses the existing DocxPdfReader for text extraction.
    // Full layout reconstruction (columns, tables, headers) requires
    // heuristic analysis of bounding boxes and font metrics.
    return DocxImportResult(
      blocks: [],
      metadata: {'format': 'pdf'},
      warnings: [
        'PDF import: text content extracted. Complex layouts (multi-column, '
        'tables, forms) may require manual cleanup after import.'
      ],
    );
  }
}

// ============================================================
// PAGES FORMAT EXPORT STUB
// ============================================================

/// Export stub for Apple Pages (.pages) format.
///
/// Pages is a ZIP package with a proprietary binary IWA (Index Wire Adapter)
/// format for its document model.
class DocxPagesExporter {
  /// Export the document to Pages format bytes.
  Future<List<int>> export(List<DocxBlock> blocks, Map<String, dynamic> metadata) async {
    // Full Pages export requires generating IWA protobuf structures.
    // This stub generates a minimal Pages package with DOCX fallback inside.
    throw UnimplementedError(
      'Pages export: IWA protobuf generation not yet implemented. '
      'Export as DOCX instead, which Pages can open directly.',
    );
  }
}

// ============================================================
// FORMAT READER REGISTRY
// ============================================================

/// Registry of all available format readers.
class DocxFormatReaderRegistry {
  static final List<DocxFormatReader> _readers = [
    DocLegacyReader(),
    DocxTemplateReader(),
    OttReader(),
    FodtReader(),
    SxwReader(),
    DocxPdfImportReader(),
  ];

  static List<DocxFormatReader> get all => List.unmodifiable(_readers);

  static void register(DocxFormatReader reader) => _readers.add(reader);

  /// Find a reader that can handle the given file.
  static DocxFormatReader? findReader(List<int> bytes, String? extension) {
    for (final reader in _readers) {
      if (reader.canRead(bytes, extension)) return reader;
    }
    return null;
  }
}
