import 'package:barcode/barcode.dart';

/// Result of auto-detection: the chosen barcode plus a human-readable label.
class DetectionResult {
  final Barcode barcode;
  final String label;
  const DetectionResult(this.barcode, this.label);
}

/// Detects the most appropriate barcode symbology for [input].
///
/// Heuristics (checked in order):
/// 1. 8 digits with valid EAN checksum      -> EAN-8
/// 2. 12 digits with valid UPC-A checksum   -> UPC-A
/// 3. 13 digits with valid EAN-13 checksum  -> EAN-13 (ISBN if 978/979 prefix)
/// 4. 14 digits with valid ITF-14 checksum  -> ITF-14
/// 5. Digits only, even length              -> ITF (interleaved 2 of 5)
/// 6. Code 128-compatible ASCII, <= 48 chars -> Code 128
/// 7. Anything else (URLs, long text, unicode) -> QR code
DetectionResult detectBarcode(String raw) {
  final input = raw.trim();
  final digitsOnly = RegExp(r'^\d+$').hasMatch(input);

  if (digitsOnly) {
    switch (input.length) {
      case 8:
        if (_validEanChecksum(input)) {
          return DetectionResult(Barcode.ean8(), 'EAN-8');
        }
        break;
      case 12:
        if (_validEanChecksum(input)) {
          return DetectionResult(Barcode.upcA(), 'UPC-A');
        }
        break;
      case 13:
        if (_validEanChecksum(input)) {
          final isIsbn =
              input.startsWith('978') || input.startsWith('979');
          return DetectionResult(
              Barcode.ean13(), isIsbn ? 'EAN-13 (ISBN)' : 'EAN-13');
        }
        break;
      case 14:
        if (_validEanChecksum(input)) {
          return DetectionResult(Barcode.itf14(), 'ITF-14');
        }
        break;
    }
    // Digits with no/failed retail checksum: ITF needs an even digit count.
    if (input.length.isEven && input.length >= 4 && input.length <= 30) {
      return DetectionResult(Barcode.itf(), 'ITF');
    }
  }

  // Code 128 handles the full printable ASCII range compactly.
  final isAscii = RegExp(r'^[\x20-\x7E]+$').hasMatch(input);
  if (isAscii && input.length <= 48) {
    return DetectionResult(Barcode.code128(), 'Code 128');
  }

  // Fallback: QR handles unicode and long payloads.
  return DetectionResult(Barcode.qrCode(), 'QR Code');
}

/// All symbologies the user can manually switch to.
final Map<String, Barcode> allSymbologies = {
  'QR Code': Barcode.qrCode(),
  'Code 128': Barcode.code128(),
  'Code 39': Barcode.code39(),
  'EAN-13': Barcode.ean13(),
  'EAN-8': Barcode.ean8(),
  'UPC-A': Barcode.upcA(),
  'ITF': Barcode.itf(),
  'ITF-14': Barcode.itf14(),
  'Data Matrix': Barcode.dataMatrix(),
  'PDF417': Barcode.pdf417(),
};

/// Validates the standard GS1 mod-10 check digit used by
/// EAN-8, UPC-A, EAN-13 and ITF-14 (weights 3/1 alternating from the right).
bool _validEanChecksum(String digits) {
  var sum = 0;
  // Rightmost digit is the check digit; weight alternates 3,1,3,1... moving
  // left from the digit just before it.
  for (var i = 0; i < digits.length - 1; i++) {
    final d = int.parse(digits[digits.length - 2 - i]);
    sum += d * (i.isEven ? 3 : 1);
  }
  final check = (10 - (sum % 10)) % 10;
  return check == int.parse(digits[digits.length - 1]);
}
