# Design: reference-tab

## Keep the URLs, split the tree

Reference could move to a top-level `/reference/` section. That changes the dialect's link form and 15 links in five source repos, and the cli and opm-operator pages go live only with a release of each. Keeping `/docs/reference/` and splitting the sidebar gives the reader the same tab with none of that. The breadcrumb still reads Documentation > Reference, which is accurate.

## Durable decisions

- Reference is its own tab: its pages keep `/docs/reference/` URLs, the sidebar shows the Reference tree apart, and the navbar marks only Reference current there. Recorded in `README.md` (Page design).
- `navbar-link.html` is an override copy, pinned in `overrides.sha256`.
