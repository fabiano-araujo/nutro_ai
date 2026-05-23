import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutro_ai/utils/media_picker_helper.dart';

void main() {
  test('optimizeImageForUpload resizes large photos before upload', () {
    final source = img.Image(width: 2400, height: 1800);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(
          x,
          y,
          (x * 13 + y * 7) & 0xff,
          (x * 3 + y * 17) & 0xff,
          (x * 19 + y * 5) & 0xff,
        );
      }
    }

    final sourceBytes = Uint8List.fromList(img.encodeJpg(source, quality: 95));
    final optimizedBytes =
        MediaPickerHelper.optimizeImageForUpload(sourceBytes);
    final optimizedImage = img.decodeImage(optimizedBytes);

    expect(optimizedImage, isNotNull);
    expect(
      math.max(optimizedImage!.width, optimizedImage.height),
      lessThanOrEqualTo(MediaPickerHelper.maxUploadImageDimension),
    );
    expect(
      optimizedBytes.length,
      lessThanOrEqualTo(MediaPickerHelper.targetMaxUploadImageBytes),
    );
  });
}
