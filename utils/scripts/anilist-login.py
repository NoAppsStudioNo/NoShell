#!/usr/bin/env python3
# AniList login for services/AnimeHeaven.qml. Usage: anilist-login.py <authorize url>
# Opens the AniList approve page and prints the access token once AniList redirects back to http://127.0.0.1:8765/.
# The token is in the URL #fragment, which browsers never send, so the redirect page posts it back to /token.
import sys
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

PAGE = b"""<!doctype html><meta charset="utf-8"><title>AniList login</title>
<body style="font: 18px sans-serif; text-align: center; margin-top: 20vh"><p id="m">Logging in...</p><script>
const ok = location.hash.includes("access_token");
fetch("/token?" + location.hash.slice(1)).then(() => m.textContent = ok ? "Logged in, you can close this tab." : "Login cancelled.");
</script>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/token":
            print(parse_qs(url.query).get("access_token", [""])[0], flush=True)
            self.server.done = True
            self.send_response(204)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(PAGE)

    def log_message(self, *args):
        pass


server = HTTPServer(("127.0.0.1", 8765), Handler)
server.done = False
server.timeout = 5
webbrowser.open(sys.argv[1])
deadline = time.time() + 300
while not server.done and time.time() < deadline:
    server.handle_request()
