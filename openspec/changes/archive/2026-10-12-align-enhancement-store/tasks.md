## 1. Mechanical rewrite

- [x] 1.1 Run `enh cite-rewrite --write` with the worklist and `--exclude openspec/changes/deploy-site/`; read at least 40 of its edits
- [x] 1.2 `task check` green, then commit `docs(openspec): cite enhancements by id and reason in archived changes`

## 2. Hand rewrite

- [x] 2.1 Clear the worklist by hand: each row rewritten by the rule, or left with a reason
- [x] 2.2 `enh cite-lint` reports 0 findings and a `cite-rewrite` dry run reports 0 edits
- [x] 2.3 `task check` green, then commit `docs(openspec): rewrite archived enhancement citations by hand`

## 3. Rules

- [x] 3.1 `openspec/config.yaml`: `references:`, the `Delivers` rule, the comment rule, the context line, the archive guidance; drop the `enhancement.yaml` rules
- [x] 3.2 Schema `docs-site-change` (`schema.yaml`, `templates/proposal.md`), `AGENTS.md`, `README.md`, `TODO.md`
- [x] 3.3 Land the durable decisions of design.md in `openspec/config.yaml` and `AGENTS.md`
- [x] 3.4 `openspec validate --all --strict --no-interactive` under 1.12.0 and 1.14.1, `task check` green, then commit `docs: point opmodel.dev at the enhancements store`

## 4. Review fixes

- [x] 4.1 Keep the README example link as it was; drop the requirement-number clause of the comment rule; describe the old citation form in words in archived text; replace old-layout entry paths and a bare decision number; cite one decision once in a table cell
- [x] 4.2 `task check` and `openspec validate align-enhancement-store --strict` green, then commit `docs: fix the review findings of the enhancement alignment`
