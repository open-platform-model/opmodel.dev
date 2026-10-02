# Tasks: reference-tab

## 1. Tab

- [x] 1.1 `site/layouts/_partials/sidebar.html`: Reference tree on reference pages, left out of the docs tree and the mobile duplicate check.
- [x] 1.2 `site/layouts/_partials/navbar-link.html`: override copy, Docs not current under `docs/reference/`; pinned in `site/overrides.sha256`.
- [x] 1.3 `site/layouts/_partials/opm/section-children.html`: the docs home's cards leave out Reference.

## 2. Pages

- [x] 2.1 Rewrite `site/content/docs/reference/{_index.md,cli/_index.md,definitions/_index.md}` without the v0 content.

## 3. Checks

- [x] 3.1 `check-pages.sh` writes `nav-order-reference.txt`; `test-site.sh` asserts both trees.
- [x] 3.2 `shots.py` screenshots the Reference home.
- [x] 3.3 `task check`, `task test:site` and `task qa` pass; screenshots read in light, dark and phone.
- [x] 3.4 `README.md` records the tab.
