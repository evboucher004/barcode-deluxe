import 'package:barcode_gen/barcode_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectBarcode', () {
    test('EAN-8 with valid checksum', () {
      expect(detectBarcode('96385074').label, 'EAN-8');
    });
    test('UPC-A with valid checksum', () {
      expect(detectBarcode('036000291452').label, 'UPC-A');
    });
    test('EAN-13 with valid checksum', () {
      expect(detectBarcode('4006381333931').label, 'EAN-13');
    });
    test('ISBN detected via 978 prefix', () {
      expect(detectBarcode('9780306406157').label, 'EAN-13 (ISBN)');
    });
    test('ITF-14 with valid checksum', () {
      expect(detectBarcode('15400141288763').label, 'ITF-14');
    });
    test('12 digits with bad checksum falls back to ITF', () {
      expect(detectBarcode('036000291453').label, 'ITF');
    });
    test('odd-length digits fall back to Code 128', () {
      expect(detectBarcode('12345').label, 'Code 128');
    });
    test('short ASCII text is Code 128', () {
      expect(detectBarcode('HELLO-123').label, 'Code 128');
    });
    test('URL falls back to QR (too long for Code 128 limit)', () {
      expect(
        detectBarcode(
                'https://example.com/some/very/long/path?query=value&x=12345')
            .label,
        'QR Code',
      );
    });
    test('unicode falls back to QR', () {
      expect(detectBarcode('héllo wörld').label, 'QR Code');
    });
  });
}
