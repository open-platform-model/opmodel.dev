"""Shared helpers for the browser checks (shots.py, a11y.py, search.py).

They run in the QA image (site/tests/browser/Dockerfile) with the repo at
/work/repo and no network: the built site/public/ is served on a loopback
port inside the container, and nothing is published to the host.
"""

import functools
import http.server
import json
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


def versions():
    """The versions of the build, [(name, is_default)] in weight order, from
    public/build-stamp.json (its "versions" key, which scripts/gen-stamp.sh
    writes from site/versions.conf); the default version alone if it has none."""
    stamp = json.loads((PUBLIC / "build-stamp.json").read_text())
    listed = [(name, bool(v.get("default"))) for name, v in stamp.get("versions", {}).items()]
    return listed or [(default_version(), True)]


def enhancement_pages():
    """The Enhancements section's pages the checks open, when the build has
    the section (public/enhancements/): the section page, the graph, a draft
    entry, its decisions document and an archived (delivered) entry, chosen
    by the status banner each page carries. [] without the section."""
    root = PUBLIC / "enhancements"
    if not (root / "index.html").is_file():
        return []
    pages = ["/enhancements/"]
    if (root / "graph" / "index.html").is_file():
        pages.append("/enhancements/graph/")
    entries = sorted(p for p in root.iterdir() if p.is_dir() and re.fullmatch(r"[0-9]{4}", p.name))

    def status(entry):
        m = re.search(r'data-status="?([a-z]+)', (entry / "index.html").read_text(errors="ignore"))
        return m.group(1) if m else ""

    draft = next((e for e in entries if status(e) == "draft"), None)
    closed = next((e for e in entries if status(e) == "delivered"), None)
    if draft:
        pages += [f"/enhancements/{draft.name}/", f"/enhancements/{draft.name}/decisions/"]
    if closed:
        pages.append(f"/enhancements/{closed.name}/")
    return pages


def wait_for_diagrams(page, timeout=30000):
    """Waits until every Mermaid diagram on the page has rendered (Hextra's
    script draws them after DOMContentLoaded, so networkidle can come first);
    returns at once on a page without one."""
    page.wait_for_function(
        "() => [...document.querySelectorAll('pre.mermaid')].every(e => e.dataset.processed && e.querySelector('svg'))",
        timeout=timeout,
    )


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
