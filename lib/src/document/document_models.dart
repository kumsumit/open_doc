import 'dart:typed_data';

import 'package:flutter/material.dart';

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

class Collaborator {
  const Collaborator(this.name, this.status, this.color);

  final String name;
  final String status;
  final Color color;
}
