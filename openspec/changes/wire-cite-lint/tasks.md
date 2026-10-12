## 1. Comment rule

- [ ] 1.1 `task cite-lint` in `Taskfile.yml` at the pinned tool commit; 0 findings with no exclude
- [ ] 1.2 `Cite lint` job in `.github/workflows/site.yml`; `task ci:lint` green
- [ ] 1.3 `task check` green, then commit `ci: run the comment rule locally and in CI`

## 2. OpenSpec CLI and durable decisions check

- [ ] 2.1 Move the CLI pin to 1.14.1 in `site.yml`, `Taskfile.yml`, `openspec/config.yaml`, `README.md`; `openspec validate --all --strict --no-interactive` green
- [ ] 2.2 `.tasks/openspec-check.sh` and its test script; `openspec:check` runs both
- [ ] 2.3 `task check` green, then commit `ci(deps): move the OpenSpec CLI pin to 1.14.1` and `ci: check the durable decisions of every active change`

## 3. Durable decisions

- [ ] 3.1 Land the decisions of design.md in `AGENTS.md` and `README.md`
- [ ] 3.2 `task check` green, then commit `docs: list task cite-lint, the Cite lint job and the durable decisions check`
