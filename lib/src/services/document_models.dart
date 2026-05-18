import 'dart:typed_data';

import 'package:flutter/material.dart';

enum DocumentEditMode {
  markdown('Markdown editor', Icons.code_outlined),
  docxVisual('DOCX visual editor', Icons.dashboard_customize_outlined),
  docxRoundTrip('DOCX round-trip', Icons.description_outlined),
  docxView('DOCX viewer', Icons.visibility_outlined);

  const DocumentEditMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum OoxmlVisualBlockType { paragraph, table }

enum OoxmlTextAlign { left, center, right, justify }

abstract class OoxmlVisualBlock {
  const OoxmlVisualBlock(this.type);

  final OoxmlVisualBlockType type;

  Map<String, Object?> toJson();
}

class OoxmlParagraphBlock extends OoxmlVisualBlock {
  const OoxmlParagraphBlock({
    required this.text,
    this.styleId,
    this.align = OoxmlTextAlign.left,
    this.pageBreakBefore = false,
  }) : super(OoxmlVisualBlockType.paragraph);

  factory OoxmlParagraphBlock.fromJson(Map<String, Object?> json) {
    return OoxmlParagraphBlock(
      text: json['text'] is String ? json['text'] as String : '',
      styleId: json['styleId'] is String ? json['styleId'] as String : null,
      align: _enumByName(
        OoxmlTextAlign.values,
        json['align'],
        OoxmlTextAlign.left,
      ),
      pageBreakBefore: json['pageBreakBefore'] == true,
    );
  }

  final String text;
  final String? styleId;
  final OoxmlTextAlign align;
  final bool pageBreakBefore;

  OoxmlParagraphBlock copyWith({
    String? text,
    String? styleId,
    OoxmlTextAlign? align,
    bool? pageBreakBefore,
  }) {
    return OoxmlParagraphBlock(
      text: text ?? this.text,
      styleId: styleId ?? this.styleId,
      align: align ?? this.align,
      pageBreakBefore: pageBreakBefore ?? this.pageBreakBefore,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'text': text,
      'styleId': styleId,
      'align': align.name,
      'pageBreakBefore': pageBreakBefore,
    };
  }
}

class OoxmlTableBlock extends OoxmlVisualBlock {
  const OoxmlTableBlock({required this.rows, this.hasHeader = true})
    : super(OoxmlVisualBlockType.table);

  factory OoxmlTableBlock.fromJson(Map<String, Object?> json) {
    final rawRows = json['rows'];
    return OoxmlTableBlock(
      rows: rawRows is List
          ? rawRows
                .whereType<List>()
                .map(
                  (row) => row
                      .map((cell) => cell is String ? cell : cell.toString())
                      .toList(),
                )
                .toList()
          : const [],
      hasHeader: json['hasHeader'] != false,
    );
  }

  final List<List<String>> rows;
  final bool hasHeader;

  OoxmlTableBlock copyWith({List<List<String>>? rows, bool? hasHeader}) {
    return OoxmlTableBlock(
      rows: rows ?? this.rows,
      hasHeader: hasHeader ?? this.hasHeader,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {'type': type.name, 'rows': rows, 'hasHeader': hasHeader};
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) {
    return fallback;
  }
  return values.where((value) => value.name == name).firstOrNull ?? fallback;
}

class DocumentVersion {
  const DocumentVersion(
    this.id,
    this.label,
    this.title,
    this.body,
    this.mediaBlocks,
    this.createdAt,
    this.wordCount,
  );

  final String id;
  final String label;
  final String title;
  final String body;
  final List<MediaBlock> mediaBlocks;
  final DateTime createdAt;
  final int wordCount;
}

enum MediaType {
  image('Image', Icons.image_outlined),
  video('Video', Icons.smart_display_outlined);

  const MediaType(this.label, this.icon);

  final String label;
  final IconData icon;

  List<String> get allowedExtensions {
    return switch (this) {
      MediaType.image => const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
      MediaType.video => const ['mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi'],
    };
  }
}

class MediaBlock {
  const MediaBlock({
    required this.id,
    required this.type,
    required this.source,
    required this.caption,
    required this.bytes,
  });

  final String id;
  final MediaType type;
  final String source;
  final String caption;
  final Uint8List? bytes;
}

class CustomFontFile {
  const CustomFontFile({
    required this.family,
    required this.source,
    required this.bytes,
  });

  final String family;
  final String source;
  final Uint8List bytes;
}

class Collaborator {
  const Collaborator(this.name, this.status, this.color);

  final String name;
  final String status;
  final Color color;
}
