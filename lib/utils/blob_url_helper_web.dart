// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<Uint8List> readObjectUrlBytes(String objectUrl) async {
  final request =
      await html.HttpRequest.request(objectUrl, responseType: 'arraybuffer');
  final response = request.response;

  if (response is ByteBuffer) {
    return Uint8List.view(response);
  }

  if (response is Uint8List) {
    return response;
  }

  throw StateError(
      'Unexpected object URL response type: ${response.runtimeType}');
}

void revokeObjectUrl(String objectUrl) {
  html.Url.revokeObjectUrl(objectUrl);
}
