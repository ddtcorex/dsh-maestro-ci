#!/usr/bin/env bash
# Publish every @ddtcorex package to npm in dependency order.
# Publishes from FRESH clones of origin/master|main — never from a shared
# working checkout (other sessions may hold unpushed local commits).
#
# Usage: NPM_TOKEN=... scripts/publish-all.sh [pkg ...]
#   no args = full ordered batch; args = subset names (config-lib, remote, ...)
set -euo pipefail

OWNER="${OWNER:-ddtcorex}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

declare -A REPO=(
  [config-lib]=dsh-maestro-config-lib [config]=dsh-maestro-config
  [remote]=dsh-maestro-remote         [review]=dsh-maestro-review
  [notifier]=dsh-maestro-notifier     [guard]=dsh-maestro-guard
  [observe]=dsh-maestro-observe       [memory]=dsh-maestro-memory
  [mobile]=dsh-maestro-mobile         [govard-pkg]=dsh-maestro-govard
  [meta]=dsh-maestro-meta             [skills]=maestro-skills
)
ORDER=(config-lib remote review notifier config guard observe memory mobile govard-pkg skills meta)

WANT=("$@")
[ ${#WANT[@]} -eq 0 ] && WANT=("${ORDER[@]}")

for key in "${WANT[@]}"; do
  repo="${REPO[$key]}"
  branch="main"; [ "$repo" != dsh-maestro-ci ] && branch="master"
  # maestro-skills + dsh-maestro-* all use master; ci uses main (unused here)
  echo "=== $repo ==="
  git clone -q --depth 1 -b "$branch" "git@github.com:$OWNER/$repo.git" "$WORK/$repo"
  (
    cd "$WORK/$repo"
    pnpm publish --access public --no-git-checks
    name=$(python3 -c "import json;print(json.load(open('package.json'))['name'])")
    ver=$(python3 -c "import json;print(json.load(open('package.json'))['version'])")
    npm view "$name@$ver" version >/dev/null && echo "  ✓ $name@$ver verified on registry"
    tarball=$(npm pack --silent "$name@$ver" 2>/dev/null || true)
    [ -n "$tarball" ] && { tar -tzf "$tarball" >/dev/null; grep -rl '"link:\|"file:' <<<"$(tar -xzOf "$tarball" package/package.json)" && { echo "  ✗ BAD specifiers"; exit 1; } || echo "  ✓ manifest specifiers clean"; rm -f "$tarball"; }
  )
done
echo ""
echo "ALL DONE: ${WANT[*]}"
