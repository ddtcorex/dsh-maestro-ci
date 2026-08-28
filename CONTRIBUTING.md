# Contributing to dsh-maestro-ci

Thank you for contributing to **dsh-maestro-ci** (`ddtcorex/dsh-maestro-ci`) — reusable GitHub Actions workflows for the Maestro suite. Callers live in each repo as a thin `.github/workflows/ci.yml`; fix or extend pipelines here once and every repo picks it up on its next run.

## Getting Started

1. **Fork and clone** `github.com/ddtcorex/dsh-maestro-ci`.
2. This repo is **CI-only** (no `package.json`, no `lib/` build). Workflows live in `.github/workflows/`:
   - `node-plugin.yml` — CI for every Node plugin package (`packages/dsh-maestro-*`, `maestro-skills`, `dsh-maestro-meta`)
   - `node-release.yml` — tag-triggered publish (`pnpm publish --access public` + GitHub Release)
3. Edit workflows with care — every caller pins a full commit SHA of `main`, so changes here affect all repos on next SHA bump.
4. Local rehearsal before pushing is mandatory:

   ```bash
   ./scripts/rehearse.sh /path/to/caller-repo
   ```

   Clones the caller branch + siblings into a CI-like sandbox and runs the exact pipeline (frozen install → build → test → lib contract → publish dry-run). See `scripts/rehearse.sh --help` for options.

## Superpowers 3-Phase Workflow (AGENTS.md)

Every change to this repository **MUST** follow the Superpowers skill workflow defined in `AGENTS.md`, in order:

1. **brainstorming** — explore intent, requirements, and design before writing code. Record the outcome in the PR description.
2. **writing-plans** — turn the approved design into a task-by-task plan with exact test and implementation sketches. Plans are transient working files — delete them once the batch ships.
3. **executing-plans** — implement task by task with strict **TDD** where applicable: write a failing test first, verify RED, implement, verify GREEN, then commit that task before starting the next. Do not commit while tests are red.

Do not skip ahead to implementation and do not bundle multiple TDD tasks into one commit during `executing-plans`. Describe durable outcomes in the PR body instead of committing dated spec/plan files.

## Branch Naming

Never commit directly to `main`. Start a feature branch per work session:

- `fix/<topic>` — bug fixes
- `feat/<topic>` — new features / new workflows
- `docs/<topic>` — documentation-only changes

Rebase (not merge) when the base moves: `git fetch origin && git rebase origin/main`.

## Conventional Commits

All commit subjects **must** follow [Conventional Commits](https://www.conventionalcommits.org/) in imperative mood:

```
<type>(<scope>): <subject>

<body — why, not what>

Refs: #<issue>
```

- **Types (closed list):** `feat` `fix` `docs` `chore` `refactor` `perf` `test` `build` `ci` `revert`
- **Scope:** optional — e.g. `feat(release):`, `fix(rehearse):`, `docs(readme):`
- **Subject:** imperative, lowercase first word, ≤ 72 chars, no trailing period
- **Body:** explain *why* and trade-offs when non-trivial
- **Breaking changes:** `feat!: <subject>` plus a `BREAKING CHANGE:` footer

One TDD task = one commit while executing a plan; squash at merge time if the history reads better squashed.

## Validation

Run these before opening a PR (match depth to risk):

```bash
# YAML syntax
yamllint .github/workflows/*.yml   # or: cat .github/workflows/node-plugin.yml | head
bash -n scripts/rehearse.sh
bash -n scripts/publish-all.sh

# Rehearse against a real caller (catches frozen-lockfile, sibling ordering, pnpm version)
./scripts/rehearse.sh <workspace-root>/packages/dsh-maestro-memory
./scripts/rehearse.sh <workspace-root>/dsh-maestro-meta
```

Do not claim verified/done/clean without having actually run the checks — be ready to paste exact command output in the PR.

## Pull Requests

1. Push your branch and open a PR into `main`.
2. Fill out `.github/PULL_REQUEST_TEMPLATE.md` (Summary, Why, Changes, Validation, Linked Issues).
3. Link the PR to the plan that produced it when the Superpowers workflow was used.
4. After merging, callers must bump their pinned SHA to the new `main` commit to pick up the fix.

## Package Visibility

This repo is **CI-only** (no `package.json`). No `private` field applies. All caller repos that *do* have a `package.json` are public (`"private": false` — field omitted, defaults to public). Publishing for those repos uses `pnpm publish --access public`.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](./CODE_OF_CONDUCT.md). By participating, you agree to its terms.

## Questions or Security Reports

- General questions: open a GitHub Discussion or issue.
- Contact maintainer: [kaido4492@gmail.com](mailto:kaido4492@gmail.com)
- Security vulnerabilities: use GitHub's private advisory reporting at `https://github.com/ddtcorex/dsh-maestro-ci/security/advisories` — do not file a public issue.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](./LICENSE).
