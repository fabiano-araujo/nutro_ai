/// Esta é uma classe falsa para simular as APIs do dart:html
/// quando o código é compilado para plataformas não-web.
///
/// É usada apenas para compilação, essas implementações nunca serão chamadas
/// em ambiente não-web porque as chamadas são protegidas por kIsWeb.

class Blob {
  Blob(List<dynamic> content, [String? type]) {}
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) {
    return '';
  }

  static void revokeObjectUrl(String url) {}
}

class Window {
  void open(String url, String target) {}
}

Window window = Window();
