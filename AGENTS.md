# AGENTS.md — dsh-maestro-ci

Reusable GitHub Actions for the Maestro suite. See `README.md` for workflow contracts (`node-plugin.yml`, `node-release.yml`).

- `scripts/rehearse.sh` — local CI rehearsal (clone + frozen install + build + test + lib contract + publish dry-run)
- Callers pin a full SHA of `master` in their `.github/workflows/ci.yml`.

Public repo hygiene: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `CODEOWNERS`, PR/issue templates — see `docs/PUBLIC_REPO_CHECKLIST.md` at meta root.

- **Always request approval before merge or release:** never merge a PR/MR or publish a release (`git tag`/`pnpm publish`/`gh release`) without an explicit human approval — request review (`gh pr ready` / `gh pr request-review` / ask in chat) and wait for `APPROVED`.
