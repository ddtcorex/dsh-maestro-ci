# AGENTS.md — dsh-maestro-ci

Reusable GitHub Actions for the Maestro suite. See `README.md` for workflow contracts (`node-plugin.yml`, `node-release.yml`).

- `scripts/rehearse.sh` — local CI rehearsal (clone + frozen install + build + test + lib contract + publish dry-run)
- Callers pin a full SHA of `main` in their `.github/workflows/ci.yml`.

Public repo hygiene: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `CODEOWNERS`, PR/issue templates — see `docs/PUBLIC_REPO_CHECKLIST.md` at meta root.
