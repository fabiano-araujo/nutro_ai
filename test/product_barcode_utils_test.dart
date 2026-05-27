import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/product_barcode_utils.dart';

void main() {
  group('ProductBarcodeUtils', () {
    test('keeps valid EAN-13 as GTIN-13', () {
      expect(
        ProductBarcodeUtils.normalizeEan13Digits('0041570054161'),
        '0041570054161',
      );
      expect(
        ProductBarcodeUtils.normalizeEan13Digits('7897517209223'),
        '7897517209223',
      );
    });

    test('converts UPC-A to GTIN-13', () {
      expect(
        ProductBarcodeUtils.normalizeUpcADigits('041570054161'),
        '0041570054161',
      );
    });

    test('converts EAN-8 to GTIN-13', () {
      expect(
        ProductBarcodeUtils.normalizeEan8Digits('96385074'),
        '0000096385074',
      );
    });

    test('expands UPC-E to UPC-A and then GTIN-13', () {
      expect(
        ProductBarcodeUtils.expandUpcEToUpcA('01234565'),
        '012345000065',
      );
      expect(
        ProductBarcodeUtils.normalizeUpcEDigits('01234565'),
        '0012345000065',
      );
    });

    test('rejects invalid check digits', () {
      expect(
        ProductBarcodeUtils.normalizeUnknownProductBarcode('0041570054162'),
        isNull,
      );
      expect(
        ProductBarcodeUtils.normalizeUnknownProductBarcode('041570054162'),
        isNull,
      );
    });
  });
}
