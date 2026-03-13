import 'dart:typed_data';

import 'blob_url_helper_stub.dart'
    if (dart.library.html) 'blob_url_helper_web.dart' as impl;

Future<Uint8List> readObjectUrlBytes(String objectUrl) {
  return impl.readObjectUrlBytes(objectUrl);
}

void revokeObjectUrl(String objectUrl) {
  impl.revokeObjectUrl(objectUrl);
}
