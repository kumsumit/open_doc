import 'package:flutter/services.dart';

/// Loads embedded fonts from DOCX files.
class EmbeddedFontLoader {
  static final Map<String, bool> _loadedFonts = {};

  /// Check if the provided data appears to be a valid font file.
  ///
  /// Performs basic validation by checking common font file signatures.
  static bool _isValidFontData(Uint8List data) {
    if (data.isEmpty || data.length < 4) return false;

    // Check for common font signatures
    final signature = data.sublist(0, 4);

    // TrueType/OpenType (.ttf, .otf)
    if (_matchesSignature(signature, [0x00, 0x01, 0x00, 0x00]) || // TTF
        _matchesSignature(signature, [0x4F, 0x54, 0x54, 0x4F]) || // OTTO (OpenType)
        _matchesSignature(signature, [0x77, 0x4F, 0x46, 0x46])) {  // wOFF
      return true;
    }

    // Embedded OpenType (.eot) - check first few bytes
    if (data.length >= 36) {
      final eotSignature = data.sublist(34, 36);
      if (_matchesSignature(eotSignature, [0x4C, 0x50])) {
        return true;
      }
    }

    return false;
  }

  static bool _matchesSignature(Uint8List data, List<int> signature) {
    if (data.length != signature.length) return false;
    for (int i = 0; i < data.length; i++) {
      if (data[i] != signature[i]) return false;
    }
    return true;
  }

  /// Load an embedded font for use in the document.
  ///
  /// DOCX files may contain obfuscated fonts (per OOXML spec).
  /// This method handles deobfuscation if necessary.
  static Future<void> loadFont(
    String familyName,
    Uint8List fontData, {
    String? obfuscationKey,
  }) async {
    // Skip if already loaded
    if (_loadedFonts.containsKey(familyName)) return;

    // Basic font format validation
    if (!_isValidFontData(fontData)) {
      _loadedFonts[familyName] = false;
      return;
    }

    Uint8List fontBytes = fontData;

    // Handle obfuscated fonts (OOXML uses GUID-based XOR for first 32 bytes)
    if (obfuscationKey != null && obfuscationKey.isNotEmpty) {
      fontBytes = _deobfuscateFont(fontData, obfuscationKey);
    }

    try {
      // Load font using FontLoader
      final fontLoader = FontLoader(familyName);
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();
      _loadedFonts[familyName] = true;
    } catch (e) {
      // Font loading failed - likely invalid font data
      _loadedFonts[familyName] = false;
    }
  }

  /// Check if a font family has been loaded.
  static bool isFontLoaded(String familyName) {
    return _loadedFonts[familyName] ?? false;
  }

  /// Clear loaded fonts cache.
  static void clearCache() {
    _loadedFonts.clear();
  }

  /// Deobfuscate a font using the OOXML algorithm.
  ///
  /// OOXML fonts are obfuscated by XOR-ing the first 32 bytes
  /// with a key derived from the GUID.
  static Uint8List _deobfuscateFont(Uint8List data, String guidKey) {
    if (data.length < 32) return data;

    final key = _parseGuidToBytes(guidKey);
    if (key.isEmpty) return data;

    final result = Uint8List.fromList(data);

    // XOR first 32 bytes with the key
    for (int i = 0; i < 32; i++) {
      result[i] = data[i] ^ key[i % key.length];
    }

    return result;
  }

  /// Parse a GUID string to bytes for deobfuscation.
  static Uint8List _parseGuidToBytes(String guid) {
    // Remove hyphens and braces from GUID
    final cleanGuid = guid
        .replaceAll('-', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .toUpperCase();

    if (cleanGuid.length != 32) return Uint8List(0);

    // Parse hex string to bytes (Big Endian initial parse)
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      final hex = cleanGuid.substring(i * 2, i * 2 + 2);
      bytes[i] = int.parse(hex, radix: 16);
    }

    // Apply Little Endian swapping for the first 3 components (Data1, Data2, Data3)
    // as per Microsoft GUID spec used in OOXML obfuscation.
    // GUID Structure: {D1-D2-D3-D4-D5}
    // D1 (4 bytes): Swap
    _swap(bytes, 0, 3);
    _swap(bytes, 1, 2);
    // D2 (2 bytes): Swap
    _swap(bytes, 4, 5);
    // D3 (2 bytes): Swap
    _swap(bytes, 6, 7);
    // D4, D5 (8 bytes): Keep Big Endian

    return bytes;
  }

  static void _swap(Uint8List list, int i, int j) {
    final temp = list[i];
    list[i] = list[j];
    list[j] = temp;
  }
}
