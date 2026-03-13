import 'dart:typed_data';

Future<Uint8List> readObjectUrlBytes(String objectUrl) {
  throw UnsupportedError('Blob URL is only available on web');
}

void revokeObjectUrl(String objectUrl) {}
