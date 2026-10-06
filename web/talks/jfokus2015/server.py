import os
import sys
from SimpleHTTPServer import SimpleHTTPRequestHandler
import BaseHTTPServer


class RestrictedHTTPRequestHandler(SimpleHTTPRequestHandler):
    """SimpleHTTPRequestHandler that refuses to serve files outside cwd."""

    def translate_path(self, path):
        translated = SimpleHTTPRequestHandler.translate_path(self, path)
        base = os.path.abspath(os.getcwd())
        if os.path.commonprefix([os.path.abspath(translated), base]) != base:
            return base
        return translated


def test(HandlerClass=RestrictedHTTPRequestHandler,
         ServerClass=BaseHTTPServer.HTTPServer):

    protocol = "HTTP/1.0"
    host = ''
    port = 8000
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if ':' in arg:
            host, port = arg.split(':')
            port = int(port)
        else:
            try:
                port = int(sys.argv[1])
            except:
                host = sys.argv[1]

    server_address = (host, port)

    HandlerClass.protocol_version = protocol
    httpd = ServerClass(server_address, HandlerClass)

    sa = httpd.socket.getsockname()
    print "Serving HTTP on", sa[0], "port", sa[1], "..."
    httpd.serve_forever()


if __name__ == "__main__":
    test()