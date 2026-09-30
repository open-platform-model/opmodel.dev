## Why

After `port-site-to-hugo-hextra` (A) merges, the Hugo site still wears Hextra's favicons (`favicon.ico`, the PNG set and `site.webmanifest` named "Hextra") and, at most, the prototype's placeholders: a stacked-layers glyph drawn with 70% and 45% opacity strokes, and an Open Graph card on the default skin's blue and orange gradients, which the neutral skin dropped. A shared link or a browser tab should show OPM, not a theme demo. Supervisor ruling O8 creates this change: a monochrome text wordmark and a simple SVG mark in the neutral skin, a favicon set and the OG image, drawn by an agent for the owner's review.

## What Changes

- **Mark.** One original SVG mark on a 24-unit grid, in one ink at full opacity. It is drawn twice with the same path data: `#0a0a0a` for the light theme and `#fafafa` for the dark theme. The navbar shows it through Hextra's `params.navbar.logo` keys, so no layout changes.
- **Wordmark.** The site title stays live text, typeset in `site/assets/css/opm/brand.css` (Geist, weight and tracking). It is not an image file.
- **Favicon set.** Every file Hextra's `favicons.html` links, plus the two icons its `site.webmanifest` names, is replaced by a same-named file in `site/static/`. The files are `favicon.svg` (the mark on a dark tile, drawn by hand), then `favicon.ico`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png`, `android-chrome-192x192.png` and `android-chrome-512x512.png`, all generated from the mark, plus a hand-written `site.webmanifest`. No theme file is copied or overridden.
- **Open Graph image.** `site/static/images/og-default.png` (1200x630): monochrome, with the mark, the site title and the site description. `params.images` points at it.
- **Tools.** `site/tools/og-card.{py,html}` renders the card, and `site/tools/favicons.py` renders the PNG and ICO files. Both run in the QA image that `task qa` already builds, offline, through two new tasks, `brand:og` and `brand:favicons`. Their output is committed. The site build never runs them.
- **README and AGENTS.md.** A `## Brand marks` heading in `README.md` records where the marks live and how to regenerate the files. `AGENTS.md` lists the two `brand:*` tasks with its other commands, and says their output is never hand-edited.

Nothing is **BREAKING**: no page URL, version or dialect rule changes.

## Before / After

**Before** (A's merged `main` as planned; section 1 records the actual state)

```text
site/
  config/_default/hugo.toml
    [params]
      images = ['/images/og-default.png']          # prototype placeholder, if A ported it
      [params.navbar.logo]                         # prototype placeholder keys, if A ported them
        path = 'images/opm-mark.svg'
        dark = 'images/opm-mark-dark.svg'
  static/
    favicon.svg                                    # prototype placeholder, if ported
    images/{opm-mark.svg,opm-mark-dark.svg,og-default.png}   # placeholders, if ported
  themes/hextra/static/
    favicon.ico favicon.svg favicon-16x16.png favicon-32x32.png
    apple-touch-icon.png android-chrome-192x192.png android-chrome-512x512.png
    site.webmanifest                               # "name": "Hextra"; published as the site's own
Taskfile.yml                                       # no brand:* tasks
```

**After**

```text
site/
  config/_default/hugo.toml
    [params]
      images = ['/images/og-default.png']
      [params.navbar]
        displayLogo = true
        displayTitle = true
        [params.navbar.logo]
          path = 'images/opm-mark.svg'
          dark = 'images/opm-mark-dark.svg'
          width = 24
          height = 24
  assets/css/opm/brand.css                         # the wordmark: live text, typeset
  static/
    favicon.svg                                    # drawn: the mark on a dark tile
    favicon.ico                                    # generated: 16, 32 and 48 px frames
    favicon-16x16.png favicon-32x32.png            # generated
    apple-touch-icon.png                           # generated: 180 px, opaque
    android-chrome-192x192.png android-chrome-512x512.png   # generated, opaque
    site.webmanifest                               # "name": "Open Platform Model", "short_name": "OPM"
    images/
      opm-mark.svg opm-mark-dark.svg               # drawn: one path set, two inks
      og-default.png                               # generated: 1200x630
  tools/
    favicons.py                                    # favicon.svg and opm-mark-dark.svg -> PNG and ICO files
    og-card.py og-card.html                        # -> images/og-default.png
Taskfile.yml
  brand:favicons                                   # QA image, --network none
  brand:og                                         # QA image, --network none
README.md
  ## Brand marks
AGENTS.md
  Build And Dev Commands: brand:favicons, brand:og   # regenerate, never hand-edit
```

## Impact

- **Touches.**
  - `site/static/{favicon.ico,favicon.svg,favicon-16x16.png,favicon-32x32.png,apple-touch-icon.png,android-chrome-192x192.png,android-chrome-512x512.png,site.webmanifest}`.
  - `site/static/images/{opm-mark.svg,opm-mark-dark.svg,og-default.png}`.
  - `site/tools/{og-card.py,og-card.html,favicons.py}`.
  - `site/config/_default/hugo.toml`: the `[params.navbar]` logo keys, plus `params.images` (and `params.description` only if A left it out).
  - `site/assets/css/opm/brand.css`.
  - `Taskfile.yml`: the `brand:og` and `brand:favicons` tasks only.
  - `README.md`: one `## Brand marks` heading.
  - `AGENTS.md`: the two `brand:*` task lines under Build And Dev Commands, and `site/tools/` in the Repository Layout tree if that tree lists `site/` subdirectories.
  - The migration plan's list for this change names only `site/tools/og-card.*`, `brand:og` and `[params.navbar.logo]`. `site/tools/favicons.py`, `brand:favicons`, `params.images` and the `AGENTS.md` lines are added so the favicon set can be regenerated from the mark and agents learn how. They are flagged for the supervisor to accept.
- **Must not edit.** `site/layouts/_partials/navbar-title.html` and `banner.html` (owned by B), any file under `site/themes/hextra/`, `site/overrides.sha256`, `site/scripts/*`, and the QA image's `site/tests/browser/Dockerfile`.
- **Build inputs.** The build gains static files only: no mount, no source repo, no pinned tool, and no theme override. The QA image is reused as it is.
- **Published URLs.** The same root-level favicon and manifest URLs Hextra publishes today, now with OPM content, plus `/images/opm-mark.svg`, `/images/opm-mark-dark.svg` and `/images/og-default.png`. Static files publish once at the root, so every version's pages share them. The version set (`v1.0`, beta) is unchanged, and 0021:OQ15 is not touched.
- **Source repos.** None. No `docs/site` page, front matter or link changes.
- **Depends on.**
  - Starts when A (`port-site-to-hugo-hextra`) is merged; builds read the supervisor's `site-src` worktrees.
  - Merges when verify is green, after E (`add-site-ci`), and after the owner has approved the marks. The supervisor merges.

## Enhancement

None. Site presentation, which covers theme, styling and so these marks, is an explicit non-goal of enhancement 0018 (its README, "Explicit non-goals"). The marks and the OG image are site-owned static files, not page images. 0018:D14 keeps images out of source pages, and this change adds none there.
