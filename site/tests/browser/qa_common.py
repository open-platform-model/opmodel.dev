"""Shared helpers for the browser checks (shots.py, a11y.py, search.py).

They run in the QA image (site/tests/browser/Dockerfile) with the repo at
/work/repo and no network: the built site/public/ is served on a loopback
port inside the container, and nothing is published to the host.
"""

import functools
import http.server
import pathlib
import re
import threading

SITE = pathlib.Path("/work/repo/site")
PUBLIC = SITE / "public"
AXE = "/opt/axe/axe.min.js"


class _Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def serve():
    """Serves site/public/ on 127.0.0.1 inside the container; returns the base URL."""
    handler = functools.partial(_Quiet, directory=str(PUBLIC))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return f"http://127.0.0.1:{server.server_address[1]}"


def default_version():
    """The version /latest/ points at, read from the build's public/_redirects."""
    text = (PUBLIC / "_redirects").read_text()
    m = re.search(r"^/latest/\* /([^/]+)/:splat ", text, re.M)
    if not m:
        raise SystemExit("public/_redirects names no /latest/ version")
    return m.group(1)


def new_page(browser, width, site_theme, os_scheme, phone=False):
    """A page with the site's theme switch set (Hextra's 'color-theme' key) and
    the OS colour scheme set separately, so the two can disagree."""
    ctx = browser.new_context(
        viewport={"width": width, "height": 844 if phone else 900},
        color_scheme=os_scheme,
        is_mobile=phone,
        has_touch=phone,
        device_scale_factor=1,
    )
    ctx.add_init_script(f"try {{ localStorage.setItem('color-theme', '{site_theme}') }} catch (e) {{}}")
    return ctx.new_page()


def slug(url):
    """/v1.0/docs/start/ -> v1.0_docs_start."""
    return url.strip("/").replace("/", "_") or "root"
