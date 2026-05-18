import 'dart:io';
import 'dart:typed_data';

import 'file_loader.dart';

class FileLoaderImpl implements FileLoader {
  /// Validates path to prevent directory traversal attacks
  String _validatePath(String path) {
    // Check for obvious traversal attempts
    if (path.contains('..') || path.contains('../') || path.contains('..\\')) {
      throw ArgumentError('Path contains directory traversal: $path');
    }

    // Check for absolute paths that might be problematic
    if (path.startsWith('/') || path.contains(':\\') || path.contains('://')) {
      // Allow absolute paths but log a warning
      // In a real security-conscious app, you might want to restrict this
    }

    return path;
  }

  @override
  Future<Uint8List?> loadBytes(String path) async {
    final validatedPath = _validatePath(path);

    String decodedPath;
    try {
      decodedPath = Uri.decodeFull(validatedPath);
    } catch (e) {
      decodedPath = validatedPath;
    }
    final file = File(decodedPath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<bool> exists(String path) async {
    final validatedPath = _validatePath(path);

    String decodedPath;
    try {
      decodedPath = Uri.decodeFull(validatedPath);
    } catch (e) {
      decodedPath = validatedPath;
    }
    return await File(decodedPath).exists();
  }
}

FileLoader getFileLoader() => FileLoaderImpl();
