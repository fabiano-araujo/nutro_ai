from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os


os.chdir(r"C:\Users\Fabiano\AndroidStudioProjects\nutro_ia\build\web")


class NoCacheHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


ThreadingHTTPServer(("127.0.0.1", 51603), NoCacheHandler).serve_forever()
