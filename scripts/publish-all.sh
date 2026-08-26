#!/usr/bin/env bash
# Publish every @ddtcorex package to npm in dependency order.
# Publishes from FRESH clones of origin/master — never from a shared working
# checkout (other sessions may hold unpushed local commits).
#
# CRITICAL: lib/ is a build artifact, not committed — every Node package must
# be installed + built INSIDE its fresh clone before `pnpm publish`, otherwise
# the tarball ships without code. Packages whose pnpm-workspace.yaml references
# ../dsh-maestro-config-lib get that sibling cloned+built next to them first,
# mirroring the CI sibling-ordering rule.
#
# Usage: scripts/publish-all.sh [pkg ...]
#   no args = full ordered batch; args = subset keys
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

clone() { # $1=repo -> $WORK/$1
  git clone -q --depth 1 -b master "git@github.com:$OWNER/$1.git" "$WORK/$1"
}

ensure_config_lib() {
  [ -f "$WORK/dsh-maestro-config-lib/package.json" ] && return
  echo "  (staging sibling dsh-maestro-config-lib)"
  clone dsh-maestro-config-lib
  (cd "$WORK/dsh-maestro-config-lib" && pnpm install --frozen-lockfile >/dev/null && pnpm run --if-present build >/dev/null)
}

publish_one() { # $1=key  $2="full"|"patch-only"
  local key="$1" mode="$2" repo="${REPO[$1]}"
  echo "=== $repo ($mode) ==="
  clone "$repo"
  cd "$WORK/$repo"
  if [ "$mode" = full ]; then
    grep -qs 'dsh-maestro-config-lib' pnpm-workspace.yaml && ensure_config_lib
    pnpm install --frozen-lockfile >/dev/null
    pnpm run --if-present build >/dev/null
    pnpm run --if-present build:client >/dev/null
  fi
  pnpm publish --access public --no-git-checks
  local name ver tarball
  name=$(python3 -c "import json;print(json.load(open('package.json'))['name'])")
  ver=$(python3 -c "import json;print(json.load(open('package.json'))['version'])")
  npm view "$name@$ver" version >/dev/null && echo "  ✓ $name@$ver on registry"
  npm pack "$name@$ver" --silent --pack-destination "$WORK" >/dev/null
  tarball=$(ls "$WORK"/*-"$ver".tgz 2>/dev/null | head -n 1)
  if [ -z "${tarball:-}" ] || [ ! -f "$tarball" ]; then echo "  ✗ tarball not found for $name@$ver (expected *-$ver.tgz in $WORK)"; ls -l "$WORK"/*.tgz 2>/dev/null || echo "  (no tgz in $WORK)"; exit 1; fi
  if tar -xzOf "$tarball" package/package.json | grep -q '"link:\|"file:'; then
    echo "  ✗ BAD specifiers in published manifest"; exit 1
  fi
  echo "  ✓ manifest specifiers clean"
}

WANT=("$@")
[ ${#WANT[@]} -eq 0 ] && WANT=("${ORDER[@]}")

for key in "${WANT[@]}"; do
  case "$key" in
    meta)    publish_one "$key" patch-only ;;
    *)       publish_one "$key" full ;;
  esac
done
echo ""
echo "ALL DONE: ${WANT[*]}"
