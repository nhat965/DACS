"""Serve the Flutter build and proxy API requests to the local FastAPI app.

This keeps browser traffic on one origin, which makes a temporary public
tunnel work without exposing MySQL or weakening the backend CORS policy.
"""

from __future__ import annotations

import argparse
import http.client
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_WEB_ROOT = PROJECT_ROOT / "apps" / "web" / "build" / "web"
HOP_BY_HOP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
}
MAX_REQUEST_BYTES = 20 * 1024 * 1024


class LumiShareHandler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    web_root: Path
    backend_host: str
    backend_port: int

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.web_root), **kwargs)

    def _static_file(self) -> Path | None:
        path = unquote(urlsplit(self.path).path)
        if path == "/":
            return self.web_root / "index.html"
        candidate = (self.web_root / path.lstrip("/")).resolve()
        try:
            candidate.relative_to(self.web_root)
        except ValueError:
            return None
        return candidate if candidate.is_file() else None

    def _serve_or_proxy(self, *, head_only: bool = False) -> None:
        if self._static_file() is not None:
            if head_only:
                super().do_HEAD()
            else:
                super().do_GET()
            return
        self._proxy_request(head_only=head_only)

    def _proxy_request(self, *, head_only: bool = False) -> None:
        content_length = int(self.headers.get("Content-Length", "0") or 0)
        if content_length > MAX_REQUEST_BYTES:
            self.send_error(413, "Request body is too large")
            return

        body = self.rfile.read(content_length) if content_length else None
        headers = {
            name: value
            for name, value in self.headers.items()
            if name.lower() not in HOP_BY_HOP_HEADERS
            and name.lower() not in {"host", "content-length"}
        }
        headers["Host"] = f"{self.backend_host}:{self.backend_port}"
        headers["X-Forwarded-Host"] = self.headers.get("Host", "")
        headers["X-Forwarded-Proto"] = self.headers.get(
            "X-Forwarded-Proto", "http"
        )
        if body is not None:
            headers["Content-Length"] = str(len(body))

        connection = http.client.HTTPConnection(
            self.backend_host,
            self.backend_port,
            timeout=30,
        )
        try:
            connection.request(self.command, self.path, body=body, headers=headers)
            response = connection.getresponse()
            payload = b"" if head_only else response.read()
            self.send_response(response.status, response.reason)
            for name, value in response.getheaders():
                if name.lower() in HOP_BY_HOP_HEADERS or name.lower() == "content-length":
                    continue
                self.send_header(name, value)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            if payload:
                self.wfile.write(payload)
        except (ConnectionError, TimeoutError, OSError) as error:
            self.send_error(502, f"FastAPI is unavailable: {error}")
        finally:
            connection.close()

    def do_GET(self) -> None:  # noqa: N802
        self._serve_or_proxy()

    def do_HEAD(self) -> None:  # noqa: N802
        self._serve_or_proxy(head_only=True)

    def do_POST(self) -> None:  # noqa: N802
        self._proxy_request()

    def do_PUT(self) -> None:  # noqa: N802
        self._proxy_request()

    def do_PATCH(self) -> None:  # noqa: N802
        self._proxy_request()

    def do_DELETE(self) -> None:  # noqa: N802
        self._proxy_request()

    def do_OPTIONS(self) -> None:  # noqa: N802
        self._proxy_request()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument(
        "--web-root",
        type=Path,
        default=Path(os.getenv("LUMI_WEB_ROOT", DEFAULT_WEB_ROOT)),
    )
    parser.add_argument("--backend-host", default="127.0.0.1")
    parser.add_argument("--backend-port", type=int, default=8001)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    web_root = args.web_root.resolve()
    index_file = web_root / "index.html"
    if not index_file.is_file():
        raise SystemExit(f"Flutter build was not found: {index_file}")

    LumiShareHandler.web_root = web_root
    LumiShareHandler.backend_host = args.backend_host
    LumiShareHandler.backend_port = args.backend_port

    server = ThreadingHTTPServer((args.host, args.port), LumiShareHandler)
    print(
        f"Lumi share server: http://{args.host}:{args.port} "
        f"-> API http://{args.backend_host}:{args.backend_port}",
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
