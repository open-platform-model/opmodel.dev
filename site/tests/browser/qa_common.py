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


def direction_pages(version):
    """The pages of the version, in path order, that hold a direction note (a
    NOTE alert titled Direction, layouts/_markup/render-blockquote-alert.html)."""
    return ["/" + html.parent.relative_to(PUBLIC).as_posix() + "/"
            for html in sorted((PUBLIC / version).rglob("index.html"))
            if "pagefind" not in html.parts and "opm-direction" in html.read_text(errors="ignore")]


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


def _minor_key(name):
    major, minor = name.split(".")
    return (int(major), int(minor))


def catalog_segments():
    """The Catalogs section's segments, [(catalog, [segment, ...])], each
    catalog's minors newest first and edge last, read from public/catalogs/
    (a segment is a directory holding index.html whose name is MAJOR.MINOR or
    edge). [] without the section."""
    root = PUBLIC / "catalogs"
    if not (root / "index.html").is_file():
        return []
    out = []
    for cat in sorted(p for p in root.iterdir() if p.is_dir()):
        segs = [s.name for s in cat.iterdir() if s.is_dir() and (s / "index.html").is_file()]
        minors = sorted((s for s in segs if re.fullmatch(r"[0-9]+\.[0-9]+", s)), key=_minor_key, reverse=True)
        out.append((cat.name, minors + (["edge"] if "edge" in segs else [])))
    return out


def catalog_pages():
    """The Catalogs section's pages the checks open, when the build has the
    section (public/catalogs/): the /catalogs/ page, the first catalog's
    newest minor landing, a member page with a spec block (a cue code block)
    and a kind index there, the edge landing, and with a version history the
    member pages with the most badges and the longest "Changes in" list.
    [] without the section."""
    cats = catalog_segments()
    if not cats:
        return []
    name, segs = cats[0]
    pages = ["/catalogs/"]
    minors = [s for s in segs if s != "edge"]
    if minors:
        seg = PUBLIC / "catalogs" / name / minors[0]
        pages.append(f"/catalogs/{name}/{minors[0]}/")
        members = sorted(h for h in seg.glob("*/*/index.html") if "pagefind" not in h.parts)
        spec = next((h for h in members if "language-cue" in h.read_text(errors="ignore")), None)
        if spec:
            pages.append("/" + spec.parent.relative_to(PUBLIC).as_posix() + "/")
        kinds = sorted(d for d in seg.iterdir() if d.is_dir() and d.name != "pagefind" and (d / "index.html").is_file())
        if kinds:
            pages.append("/" + kinds[-1].relative_to(PUBLIC).as_posix() + "/")
    if "edge" in segs:
        pages.append(f"/catalogs/{name}/edge/")
    # With a version history (docs-kit C13): the member page with the most
    # badges (all three, where one has them) and the one with the longest
    # "Changes in" list. The kind index above already shows "Removed in"
    # where its segment removed a member.
    found = sorted(h for s in segs for h in (PUBLIC / "catalogs" / name / s).glob("*/*/index.html") if "pagefind" not in h.parts)
    texts = [(h, h.read_text(errors="ignore")) for h in found]
    with_badges = [(t.count("opm-history-badge"), h) for h, t in texts if "opm-history-badge" in t]
    with_list = [(t.count("<li><code>"), h) for h, t in texts if "Changes in" in t and "opm-history-link" in t]
    for picked in (max(with_badges, key=lambda x: x[0], default=None), max(with_list, key=lambda x: x[0], default=None)):
        if picked:
            url = "/" + picked[1].parent.relative_to(PUBLIC).as_posix() + "/"
            if url not in pages:
                pages.append(url)
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
