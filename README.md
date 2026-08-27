# ddtcorex/dsh-maestro-ci

Reusable GitHub Actions workflows for the Maestro suite. Callers live in
each repo as a thin `.github/workflows/ci.yml`; fix or extend pipelines
here once and every repo picks it up on its next run.

## Workflows

### node-plugin.yml

CI for every Node plugin package (`packages/dsh-maestro-*`, `maestro-skills`,
`dsh-maestro-meta`). Steps: frozen-lockfile install → build → optional client
bundle → test → flat-`lib/index.js` contract → publish dry-run.

Inputs (all optional): `node-version` (22), `pnpm-version` (11),
`run-build` (true), `run-client-build` (false), `require-lib-index` (true).

Caller template:

```yaml
name: CI
on:
  push:
    branches: [master]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  verify:
    uses: ddtcorex/dsh-maestro-ci/.github/workflows/node-plugin.yml@main
```

Special cases:

- **Patch-only bundle** (`dsh-maestro-meta`, no lib): pass
  `run-build: false` and `require-lib-index: false`.
- **Client bundle** (`dsh-maestro-mobile`, `dsh-maestro-config`): pass
  `run-client-build: true`.

## Versioning

Callers currently pin `@main`. Once the workflows stabilize, tighten callers
to a full commit SHA so pipeline changes are reviewed per-repo.
