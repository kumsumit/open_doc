/// docx_creator - A developer-first DOCX generation library
///
/// Create professional Word documents with a fluent API:
/// ```dart
/// import 'package:docx_creator/docx.dart';
///
/// final doc = docx()
///   .h1('Title')
///   .p('Content')
///   .build();
///
/// await DocxExporter().exportToFile(doc, 'output.docx');
/// ```
library;

export 'ast/docx_background_image.dart';
export 'ast/docx_block.dart';
export 'ast/docx_drawing.dart';
export 'ast/docx_drop_cap.dart';
export 'ast/docx_footnote.dart';
export 'ast/docx_image.dart';
export 'ast/docx_inline.dart';
export 'ast/docx_list.dart';
// AST
export 'ast/docx_node.dart';
export 'ast/docx_section.dart';
export 'ast/docx_section_break.dart';
export 'ast/docx_table.dart';
// Builder
export 'builder/docx_document_builder.dart';
export 'core/defaults.dart';
// Core
export 'core/enums.dart';
export 'core/exceptions.dart';
export 'core/measurements.dart';
export 'core/xml_extension.dart';
// Editor
export 'editor/element_tree.dart';
// Exporters
export 'exporters/docx_exporter.dart';
export 'exporters/html_exporter.dart';
export 'exporters/pdf/pdf_exporter.dart';
// Parsers
export 'parsers/html_parser.dart';
export 'parsers/markdown_parser.dart';
export 'reader/docx_reader/docx_reader.dart';
export 'reader/docx_reader/handlers/font_reader.dart';
export 'reader/docx_reader/handlers/relationship_manager.dart';
export 'reader/docx_reader/models/docx_font.dart';
export 'reader/docx_reader/models/docx_relationship.dart';
export 'reader/docx_reader/models/docx_style.dart';
// Reader Models
export 'reader/docx_reader/models/docx_theme.dart';
export 'reader/docx_reader/models/resolved_style.dart';
export 'reader/docx_reader/parsers/block_parser.dart';
export 'reader/docx_reader/parsers/inline_parser.dart';
export 'reader/docx_reader/parsers/numbering_parser.dart';
export 'reader/docx_reader/parsers/section_parser.dart';
export 'reader/docx_reader/parsers/style_parser.dart';
export 'reader/docx_reader/parsers/table_parser.dart';
export 'reader/docx_reader/reader_context/reader_context.dart';
export 'reader/pdf_reader/pdf_reader.dart';
// Utilities
export 'utils/content_types_generator.dart';
export 'utils/docx_id_generator.dart';
export 'utils/docx_validator.dart';
export 'utils/xml_utils.dart' hide DocxIdGenerator;
