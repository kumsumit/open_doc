import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class ImportedDocument {
  const ImportedDocument({required this.text, required this.formatLabel});

  final String text;
  final String formatLabel;
}

class DocumentImportService {
  const DocumentImportService();

  ImportedDocument parse(Uint8List bytes, String fileName) {
    final extension = fileExtension(fileName);
    return switch (extension) {
      'docx' => ImportedDocument(
        text: _extractDocxText(bytes),
        formatLabel: 'DOCX',
      ),
      'txt' || 'md' || 'markdown' => ImportedDocument(
        text: _decodeText(bytes),
        formatLabel: extension == 'txt' ? 'text' : 'Markdown',
      ),
      'rtf' => ImportedDocument(
        text: _stripRtf(_decodeText(bytes)),
        formatLabel: 'RTF',
      ),
      'html' || 'htm' => ImportedDocument(
        text: _stripHtml(_decodeText(bytes)),
        formatLabel: 'HTML',
      ),
      'csv' => ImportedDocument(
        text: _csvToReadableText(_decodeText(bytes)),
        formatLabel: 'CSV',
      ),
      _ => throw FormatException('Unsupported file type: .$extension'),
    };
  }

  String titleFromFileName(String fileName) {
    final baseName = fileName.split(RegExp(r'[/\\]')).last;
    final withoutExtension = baseName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return withoutExtension.trim().isEmpty
        ? 'Imported document'
        : withoutExtension;
  }

  String fileExtension(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index == -1 || index == fileName.length - 1) {
      return '';
    }
    return fileName.substring(index + 1).toLowerCase();
  }

  String _extractDocxText(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final documentFile = archive.files
        .where((file) => file.name == 'word/document.xml')
        .firstOrNull;
    if (documentFile == null) {
      throw const FormatException(
        'This DOCX file has no readable document body.',
      );
    }

    final document = XmlDocument.parse(utf8.decode(documentFile.content));
    final body = document.descendants.whereType<XmlElement>().firstWhere(
      (element) => element.name.local == 'body',
      orElse: () => document.rootElement,
    );
    final blocks = <String>[];

    for (final child in body.childElements) {
      switch (child.name.local) {
        case 'p':
          final text = _extractDocxParagraphText(child);
          if (text.trim().isNotEmpty) {
            blocks.add(text);
          }
        case 'tbl':
          final table = _extractDocxTableText(child);
          if (table.trim().isNotEmpty) {
            blocks.add(table);
          }
      }
    }

    return blocks.join('\n\n');
  }

  String _extractDocxParagraphText(XmlElement paragraph) {
    final buffer = StringBuffer();
    for (final node in paragraph.descendants.whereType<XmlElement>()) {
      switch (node.name.local) {
        case 't':
          buffer.write(node.innerText);
        case 'tab':
          buffer.write('\t');
        case 'br':
          buffer.write('\n');
      }
    }
    return buffer.toString().trimRight();
  }

  String _extractDocxTableText(XmlElement table) {
    final rows = <List<String>>[];
    for (final row in table.childElements.where(
      (element) => element.name.local == 'tr',
    )) {
      final cells = row.childElements
          .where((element) => element.name.local == 'tc')
          .map((cell) {
            final paragraphs = cell.childElements
                .where((element) => element.name.local == 'p')
                .map(_extractDocxParagraphText)
                .where((text) => text.trim().isNotEmpty)
                .map((text) => text.trim())
                .toList();
            return paragraphs.join(' ');
          })
          .toList();
      if (cells.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(cells);
      }
    }
    return _rowsToMarkdownTable(rows);
  }

  String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  String _stripHtml(String value) {
    return value
        .replaceAllMapped(
          RegExp(
            r'<\s*table\b[^>]*>.*?</\s*table\s*>',
            caseSensitive: false,
            dotAll: true,
          ),
          (match) => '\n${_extractHtmlTableText(match.group(0) ?? '')}\n',
        )
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</\s*(p|div|h[1-6]|li|tr)\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _extractHtmlTableText(String table) {
    final rows =
        RegExp(
              r'<\s*tr\b[^>]*>(.*?)</\s*tr\s*>',
              caseSensitive: false,
              dotAll: true,
            )
            .allMatches(table)
            .map((rowMatch) {
              final rowHtml = rowMatch.group(1) ?? '';
              return RegExp(
                    r'<\s*(td|th)\b[^>]*>(.*?)</\s*\1\s*>',
                    caseSensitive: false,
                    dotAll: true,
                  )
                  .allMatches(rowHtml)
                  .map((cellMatch) => _stripHtml(cellMatch.group(2) ?? ''))
                  .toList();
            })
            .where((row) => row.any((cell) => cell.trim().isNotEmpty))
            .toList();
    return _rowsToMarkdownTable(rows);
  }

  String _stripRtf(String value) {
    return value
        .replaceAll(RegExp(r'\\par[d]?'), '\n')
        .replaceAll(RegExp(r'\\tab'), '\t')
        .replaceAll(RegExp(r"\\'[0-9a-fA-F]{2}"), '')
        .replaceAll(RegExp(r'\\[a-zA-Z]+\d* ?'), '')
        .replaceAll(RegExp(r'[{}]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _csvToReadableText(String value) {
    final rows = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_parseCsvLine)
        .toList();
    return _rowsToMarkdownTable(rows);
  }

  List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var quoted = false;

    for (var index = 0; index < line.length; index += 1) {
      final char = line[index];
      if (char == '"') {
        final isEscapedQuote =
            quoted && index + 1 < line.length && line[index + 1] == '"';
        if (isEscapedQuote) {
          buffer.write('"');
          index += 1;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        cells.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    cells.add(buffer.toString().trim());
    return cells;
  }

  String _rowsToMarkdownTable(List<List<String>> rows) {
    if (rows.isEmpty) {
      return '';
    }

    final columnCount = rows.fold<int>(
      0,
      (count, row) => math.max(count, row.length),
    );
    if (columnCount == 0) {
      return '';
    }

    final normalizedRows = rows
        .map(
          (row) => List<String>.generate(
            columnCount,
            (index) =>
                index < row.length ? _escapeMarkdownTableCell(row[index]) : '',
          ),
        )
        .toList();
    final header = normalizedRows.first;
    final bodyRows = normalizedRows.length == 1
        ? <List<String>>[List.filled(columnCount, '')]
        : normalizedRows.skip(1);

    return [
      _formatMarkdownTableRow(header),
      _formatMarkdownTableRow(List.filled(columnCount, '---')),
      for (final row in bodyRows) _formatMarkdownTableRow(row),
    ].join('\n');
  }

  String _formatMarkdownTableRow(Iterable<String> cells) {
    return '| ${cells.join(' | ')} |';
  }

  String _escapeMarkdownTableCell(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').replaceAll('|', r'\|').trim();
  }
}
