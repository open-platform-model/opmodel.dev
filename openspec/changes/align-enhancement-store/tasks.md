## 1. Mechanical rewrite

- [ ] 1.1 Run `enh cite-rewrite --write` with the worklist and `--exclude openspec/changes/deploy-site/`; read at least 40 of its edits
- [ ] 1.2 `task check` green, then commit `docs(openspec): cite enhancements by id and reason in archived changes`

## 2. Hand rewrite

- [ ] 2.1 Clear the worklist by hand: each row rewritten by the rule, or left with a reason
- [ ] 2.2 `enh cite-lint` reports 0 findings and a `cite-rewrite` dry run reports 0 edits
- [ ] 2.3 `task check` green, then commit `docs(openspec): rewrite archived enhancement citations by hand`

## 3. Rules

- [ ] 3.1 `openspec/config.yaml`: `references:`, the `Delivers` rule, the comment rule, the context line, the archive guidance; drop the `enhancement.yaml` rules
- [ ] 3.2 Schema `docs-site-change` (`schema.yaml`, `templates/proposal.md`), `AGENTS.md`, `README.md`, `TODO.md`
- [ ] 3.3 Land the durable decisions of design.md in `openspec/config.yaml` and `AGENTS.md`
- [ ] 3.4 `openspec validate --all --strict --no-interactive` under 1.12.0 and 1.14.1, `task check` green, then commit `docs: point opmodel.dev at the enhancements store`
