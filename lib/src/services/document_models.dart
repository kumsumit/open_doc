import 'dart:typed_data';

import 'package:flutter/material.dart';

enum DocumentEditMode {
  markdown('Markdown editor', Icons.code_outlined),
  wysiwyg('WYSIWYG editor', Icons.edit_document),
  docxVisual('DOCX visual editor', Icons.dashboard_customize_outlined),
  docxRoundTrip('DOCX round-trip', Icons.description_outlined),
  docxView('DOCX viewer', Icons.visibility_outlined);

  const DocumentEditMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum OoxmlVisualBlockType { paragraph, table, partText }

enum OoxmlTextAlign { left, center, right, justify }

enum WysiwygBlockType {
  title('Title'),
  heading('Heading'),
  paragraph('Paragraph'),
  quote('Quote'),
  bulletList('Bullet'),
  orderedList('Numbered'),
  checklist('Checklist');

  const WysiwygBlockType(this.label);

  final String label;
}

class WysiwygBlock {
  const WysiwygBlock({
    required this.id,
    required this.type,
    required this.text,
    this.checked = false,
  });

  factory WysiwygBlock.fromJson(Map<String, Object?> json) {
    return WysiwygBlock(
      id: json['id'] is String ? json['id'] as String : _newWysiwygBlockId(),
      type: _enumByName(
        WysiwygBlockType.values,
        json['type'],
        WysiwygBlockType.paragraph,
      ),
      text: json['text'] is String ? json['text'] as String : '',
      checked: json['checked'] == true,
    );
  }

  final String id;
  final WysiwygBlockType type;
  final String text;
  final bool checked;

  WysiwygBlock copyWith({WysiwygBlockType? type, String? text, bool? checked}) {
    return WysiwygBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      checked: checked ?? this.checked,
    );
  }

  Map<String, Object?> toJson() {
    return {'id': id, 'type': type.name, 'text': text, 'checked': checked};
  }
}

class WysiwygDocumentCodec {
  const WysiwygDocumentCodec._();

  static List<WysiwygBlock> fromMarkdown(String markdown) {
    final lines = markdown.split('\n');
    final blocks = <WysiwygBlock>[];
    final paragraph = StringBuffer();

    void flushParagraph() {
      final text = paragraph.toString().trim();
      if (text.isNotEmpty) {
        blocks.add(_block(WysiwygBlockType.paragraph, text));
      }
      paragraph.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('# ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.title, trimmed.substring(2)));
      } else if (trimmed.startsWith('## ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.heading, trimmed.substring(3)));
      } else if (trimmed.startsWith('> ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.quote, trimmed.substring(2)));
      } else if (trimmed.startsWith('- [x] ') ||
          trimmed.startsWith('* [x] ') ||
          trimmed.startsWith('- [ ] ') ||
          trimmed.startsWith('* [ ] ')) {
        flushParagraph();
        blocks.add(
          _block(
            WysiwygBlockType.checklist,
            trimmed.substring(6),
            checked: trimmed.substring(2, 5).toLowerCase() == '[x]',
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        blocks.add(_block(WysiwygBlockType.bulletList, trimmed.substring(2)));
      } else {
        final ordered = RegExp(r'^\d+\.\s+').firstMatch(trimmed);
        if (ordered != null) {
          flushParagraph();
          blocks.add(
            _block(
              WysiwygBlockType.orderedList,
              trimmed.substring(ordered.end),
            ),
          );
        } else {
          if (paragraph.isNotEmpty) {
            paragraph.write(' ');
          }
          paragraph.write(trimmed);
        }
      }
    }
    flushParagraph();
    return blocks.isEmpty ? [_block(WysiwygBlockType.paragraph, '')] : blocks;
  }

  static String toMarkdown(List<WysiwygBlock> blocks) {
    final orderedIndex = <int>[1];
    return blocks
        .map((block) {
          final text = block.text.trimRight();
          return switch (block.type) {
            WysiwygBlockType.title => '# $text',
            WysiwygBlockType.heading => '## $text',
            WysiwygBlockType.quote => '> $text',
            WysiwygBlockType.bulletList => '- $text',
            WysiwygBlockType.orderedList => '${orderedIndex[0]++}. $text',
            WysiwygBlockType.checklist =>
              '- [${block.checked ? 'x' : ' '}] $text',
            WysiwygBlockType.paragraph => text,
          };
        })
        .join('\n\n');
  }

  static List<Object?> toQuillDeltaJson(List<WysiwygBlock> blocks) {
    final ops = <Object?>[];
    for (final block in blocks) {
      final text = block.text.isEmpty ? ' ' : block.text;
      ops.add({'insert': text});
      final attrs = <String, Object?>{};
      switch (block.type) {
        case WysiwygBlockType.title:
          attrs['header'] = 1;
        case WysiwygBlockType.heading:
          attrs['header'] = 2;
        case WysiwygBlockType.quote:
          attrs['blockquote'] = true;
        case WysiwygBlockType.bulletList:
          attrs['list'] = 'bullet';
        case WysiwygBlockType.orderedList:
          attrs['list'] = 'ordered';
        case WysiwygBlockType.checklist:
          attrs['list'] = block.checked ? 'checked' : 'unchecked';
        case WysiwygBlockType.paragraph:
          break;
      }
      ops.add(
        attrs.isEmpty
            ? {'insert': '\n'}
            : {'insert': '\n', 'attributes': attrs},
      );
    }
    return ops;
  }

  static List<WysiwygBlock> fromQuillDeltaJson(List<Object?> deltaJson) {
    final blocks = <WysiwygBlock>[];
    final buffer = StringBuffer();
    Map<String, Object?> lineAttributes = const {};

    void flush() {
      final text = buffer.toString();
      buffer.clear();
      if (text.isEmpty && lineAttributes.isEmpty) {
        return;
      }
      blocks.add(
        _block(
          _typeFromQuillAttributes(lineAttributes),
          text.trimRight(),
          checked: lineAttributes['list'] == 'checked',
        ),
      );
      lineAttributes = const {};
    }

    for (final rawOp in deltaJson) {
      if (rawOp is! Map) {
        continue;
      }
      final attributes = rawOp['attributes'];
      if (attributes is Map) {
        lineAttributes = attributes.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      final insert = rawOp['insert'];
      if (insert is! String) {
        continue;
      }
      final parts = insert.split('\n');
      for (var index = 0; index < parts.length; index += 1) {
        if (index > 0) {
          flush();
        }
        buffer.write(parts[index]);
      }
    }
    flush();
    return blocks.isEmpty ? [_block(WysiwygBlockType.paragraph, '')] : blocks;
  }

  static WysiwygBlock _block(
    WysiwygBlockType type,
    String text, {
    bool checked = false,
  }) {
    return WysiwygBlock(
      id: _newWysiwygBlockId(),
      type: type,
      text: text,
      checked: checked,
    );
  }

  static WysiwygBlockType _typeFromQuillAttributes(
    Map<String, Object?> attributes,
  ) {
    if (attributes['header'] == 1) {
      return WysiwygBlockType.title;
    }
    if (attributes['header'] == 2) {
      return WysiwygBlockType.heading;
    }
    if (attributes['blockquote'] == true) {
      return WysiwygBlockType.quote;
    }
    return switch (attributes['list']) {
      'bullet' => WysiwygBlockType.bulletList,
      'ordered' => WysiwygBlockType.orderedList,
      'checked' || 'unchecked' => WysiwygBlockType.checklist,
      _ => WysiwygBlockType.paragraph,
    };
  }
}

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

class OoxmlPartTextBlock extends OoxmlVisualBlock {
  const OoxmlPartTextBlock({
    required this.partPath,
    required this.paragraphIndex,
    required this.label,
    required this.text,
  }) : super(OoxmlVisualBlockType.partText);

  factory OoxmlPartTextBlock.fromJson(Map<String, Object?> json) {
    return OoxmlPartTextBlock(
      partPath: json['partPath'] is String ? json['partPath'] as String : '',
      paragraphIndex: json['paragraphIndex'] is int
          ? json['paragraphIndex'] as int
          : 0,
      label: json['label'] is String ? json['label'] as String : 'OOXML part',
      text: json['text'] is String ? json['text'] as String : '',
    );
  }

  final String partPath;
  final int paragraphIndex;
  final String label;
  final String text;

  OoxmlPartTextBlock copyWith({String? text}) {
    return OoxmlPartTextBlock(
      partPath: partPath,
      paragraphIndex: paragraphIndex,
      label: label,
      text: text ?? this.text,
    );
  }

  @override
  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'partPath': partPath,
      'paragraphIndex': paragraphIndex,
      'label': label,
      'text': text,
    };
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) {
    return fallback;
  }
  return values.where((value) => value.name == name).firstOrNull ?? fallback;
}

String _newWysiwygBlockId() => DateTime.now().microsecondsSinceEpoch.toString();

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
