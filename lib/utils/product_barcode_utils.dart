class ProductBarcodeUtils {
  const ProductBarcodeUtils._();

  static String? normalizeUnknownProductBarcode(String rawBarcode) {
    final digits = digitsOnly(rawBarcode);

    if (digits.length == 13) return normalizeEan13Digits(digits);
    if (digits.length == 12) return normalizeUpcADigits(digits);
    if (digits.length == 8) {
      return normalizeEan8Digits(digits) ?? normalizeUpcEDigits(digits);
    }

    return null;
  }

  static String digitsOnly(String rawBarcode) {
    return rawBarcode.replaceAll(RegExp(r'\D'), '');
  }

  static String? normalizeEan13Digits(String digits) {
    if (digits.length != 13 || !hasValidGtinCheckDigit(digits)) return null;
    return digits;
  }

  static String? normalizeEan8Digits(String digits) {
    if (digits.length != 8 || !hasValidGtinCheckDigit(digits)) return null;
    return digits.padLeft(13, '0');
  }

  static String? normalizeUpcADigits(String digits) {
    if (digits.length == 13 && digits.startsWith('0')) {
      return hasValidGtinCheckDigit(digits) ? digits : null;
    }

    if (digits.length != 12 || !hasValidGtinCheckDigit(digits)) return null;
    return digits.padLeft(13, '0');
  }

  static String? normalizeUpcEDigits(String digits) {
    final upcA = expandUpcEToUpcA(digits);
    if (upcA == null || !hasValidGtinCheckDigit(upcA)) return null;
    return upcA.padLeft(13, '0');
  }

  static String? expandUpcEToUpcA(String digits) {
    if (digits.length != 8) return null;

    final numberSystem = digits[0];
    final code = digits.substring(1, 7);
    final checkDigit = digits[7];
    final last = code[5];

    if (numberSystem != '0' && numberSystem != '1') return null;

    late final String manufacturer;
    late final String product;

    if (last == '0' || last == '1' || last == '2') {
      manufacturer = '${code.substring(0, 2)}${last}00';
      product = '00${code.substring(2, 5)}';
    } else if (last == '3') {
      manufacturer = '${code.substring(0, 3)}00';
      product = '000${code.substring(3, 5)}';
    } else if (last == '4') {
      manufacturer = '${code.substring(0, 4)}0';
      product = '0000${code[4]}';
    } else {
      manufacturer = code.substring(0, 5);
      product = '0000$last';
    }

    return '$numberSystem$manufacturer$product$checkDigit';
  }

  static bool hasValidGtinCheckDigit(String digits) {
    if (digits.length < 8 || digits.length > 14) return false;
    if (RegExp(r'^(\d)\1+$').hasMatch(digits)) return false;

    final checkDigit = int.parse(digits[digits.length - 1]);
    var sum = 0;
    var useThree = true;

    for (var i = digits.length - 2; i >= 0; i--) {
      final digit = int.parse(digits[i]);
      sum += useThree ? digit * 3 : digit;
      useThree = !useThree;
    }

    final expectedCheckDigit = (10 - (sum % 10)) % 10;
    return checkDigit == expectedCheckDigit;
  }
}
