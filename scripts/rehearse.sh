#!/usr/bin/env bash
# Rehearse the shared node-plugin CI for one caller repo — fully local.
#
# Replicates .github/workflows/node-plugin.yml step-by-step inside a sandbox:
#   fresh clone of the caller branch -> sibling clones (same layout rules)
#   -> frozen install -> build (+client) -> test -> flat lib contract
#   -> publish dry-run. Catches stale lockfiles, missing/broken siblings,
#   pnpm-version conflicts and red suites BEFORE anything is pushed.
#
# Usage: rehearse.sh <caller-repo-dir> [more dirs...]

set -uo pipefail

META_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# dsh-maestro-ci lives at <meta-root>/dsh-maestro-ci; callers live elsewhere.
if [ ! -d "$META_ROOT/packages" ]; then
  META_ROOT="/home/kai/Work/htdocs/maestro-harness"
fi

failures=0

rehearse_one() {
  local REPO_DIR="$1"
  local NAME; NAME="$(basename "$REPO_DIR")"
  echo ""
  echo "═══════════════════════════════════"
  echo "  REHEARSE $NAME"
  echo "═══════════════════════════════════"

  local CI_FILE="$REPO_DIR/.github/workflows/ci.yml"
  if [ ! -f "$CI_FILE" ]; then echo "✗ no ci.yml"; failures=$((failures+1)); return; fi

  # ---- parse caller inputs ----
  local IN; IN=$(python3 - "$CI_FILE" <<'PY'
import sys, re
s=open(sys.argv[1]).read()
m=re.search(r'with:\n((?:\s{6,}.*\n)+)', s)
out={}
if m:
    block=m.group(1)
    km=re.search(r'run-build:\s*(\S+)',block); out['run-build']=km.group(1) if km else 'true'
    kc=re.search(r'run-client-build:\s*(\S+)',block); out['run-client-build']=kc.group(1) if kc else 'false'
    kr=re.search(r'require-lib-index:\s*(\S+)',block); out['require-lib-index']=kr.group(1) if kr else 'true'
    kv=re.search(r'pnpm-version:\s*"([^"]*)"',block); out['pnpm-version']=kv.group(1) if kv else ''
    ks=re.search(r'sibling-repos:\s*\|?\n((?:\s{8,}.*\n)+)',block)
    out['siblings']='\n'.join(l.strip() for l in ks.group(1).strip().splitlines()) if ks else ''
    kq=re.search(r'sibling-repos:\s*"([^"]+)"',block)
    if kq: out['siblings']=kq.group(1)
print(repr(out))
PY
)
  eval "declare -A IN=$IN"

  # ---- static check: pnpm version conflict (mirrors pnpm/action-setup v4) ----
  local HAS_PM=0
  grep -q '"packageManager"' "$REPO_DIR/package.json" && HAS_PM=1
  if [ "$HAS_PM" = 1 ] && [ -n "${IN[pnpm-version]}" ]; then
    echo "✗ STATIC: package.json pins packageManager while ci.yml passes pnpm-version — pnpm/action-setup rejects both. Pass pnpm-version: \"\" instead."
    failures=$((failures+1)); return
  fi

  # ---- sandbox: clone caller branch + siblings in CI-like layout ----
  local SB; SB=$(mktemp -d /tmp/rehearse.XXXXXX)
  trap 'rm -rf "$SB"' RETURN
  local BR; BR=$(git -C "$REPO_DIR" branch --show-current)
  git clone -q --no-hardlinks --branch "$BR" "$REPO_DIR" "$SB/repo" || { echo "✗ clone caller"; failures=$((failures+1)); return; }

  if [ -n "${IN[siblings]:-}" ]; then
    while read -r repo ref target; do
      [ -z "$repo" ] && continue
      if [ -z "$ref" ] && [ "${repo#*@}" != "$repo" ]; then ref="${repo##*@}"; repo="${repo%%@*}"; fi
      ref="${ref:-master}"
      local src=""
      for cand in "$META_ROOT/packages/$repo" "$META_ROOT/$repo"; do
        [ -d "$cand/.git" ] && { src="$cand"; break; }
      done
      if [ -z "$src" ]; then echo "✗ sibling $repo không tìm thấy checkout local"; failures=$((failures+1)); return; fi
      local dest="$SB/${target:-$repo}"
      mkdir -p "$(dirname "$dest")"
      git clone -q --no-hardlinks --branch master "$src" "$dest" || { echo "✗ clone sibling $repo"; failures=$((failures+1)); return; }
      echo "  sibling: $repo@$ref -> ${dest#$SB/}"
      (cd "$dest" && pnpm install --frozen-lockfile >/dev/null 2>&1 && pnpm build >/dev/null 2>&1) \
        || { echo "✗ sibling $repo install/build"; failures=$((failures+1)); return; }
    done <<< "${IN[siblings]}"
  fi

  # ---- the actual pipeline ----
  cd "$SB/repo"
  local step; step="pnpm install --frozen-lockfile"
  echo "→ $step"
  pnpm install --frozen-lockfile >/tmp/rh-$NAME-install.log 2>&1 \
    || { echo "✗ $step (tail: $(grep -oE 'ERR_[A-Z_]+' /tmp/rh-$NAME-install.log | head -1))"; failures=$((failures+1)); return; }

  if [ "${IN[run-build]:-true}" = "true" ]; then
    step="pnpm build"; echo "→ $step"
    pnpm build >/tmp/rh-$NAME-build.log 2>&1 \
      || { echo "✗ $step ($(tail -2 /tmp/rh-$NAME-build.log | head -1 | cut -c1-100))"; failures=$((failures+1)); return; }
  fi

  if [ "${IN[run-client-build]:-false}" = "true" ]; then
    step="pnpm run build:client"; echo "→ $step"
    pnpm run build:client >/tmp/rh-$NAME-client.log 2>&1 \
      || { echo "✗ $step"; failures=$((failures+1)); return; }
  fi

  step="pnpm test"; echo "→ $step"
  pnpm test >/tmp/rh-$NAME-test.log 2>&1 \
    || { echo "✗ $step ($(grep -oE 'Tests[^$]*failed.*|FAIL[^$]*' /tmp/rh-$NAME-test.log | head -1 | cut -c1-80))"; failures=$((failures+1)); return; }

  if [ "${IN[require-lib-index]:-true}" = "true" ]; then
    step="test -f lib/index.js"; echo "→ $step"
    [ -f lib/index.js ] || { echo "✗ flat lib/index.js MISSING"; failures=$((failures+1)); return; }
  fi

  step="pnpm publish --dry-run"; echo "→ $step"
  pnpm publish --dry-run --access public --no-git-checks >/tmp/rh-$NAME-pub.log 2>&1 \
    || { echo "✗ $step"; failures=$((failures+1)); return; }
  if grep -qE 'link:|file:' /tmp/rh-$NAME-pub.log; then :; fi

  echo "✓ $NAME PASS"
}

for d in "$@"; do
  rehearse_one "$(cd "$d" && pwd)"
done

echo ""
echo "═══════ KẾT QUẢ: $failures repo FAIL ═══════"
exit $((failures > 0))
