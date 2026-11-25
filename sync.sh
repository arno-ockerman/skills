#!/usr/bin/env bash
# Sync the skills in ./skills/ with every agent home that loads them.
# The repo (github.com/arno-ockerman/skills) is the source of truth.
#
#   ./sync.sh status            what differs between the repo and each home
#   ./sync.sh install           repo -> every home (overwrites tracked skills only)
#   ./sync.sh collect [name..]  a home -> repo (adopt edits made in place,
#                               or adopt a new skill by name)
#
# Only skills that live in ./skills/ are ever written to a home. Vendor
# directories (Claude `synced/`, Codex `.system/`, plugin caches) are never touched.
#
# Targets (agent homes under /opt/ai-tools/config):
#   - Claude Code:  claude/home/.claude/skills
#   - Codex:        codex/home/.codex/skills
#   - OpenCode:     xdg/opencode/skills  (global ~/.config/opencode/skills)
#   - Pi:           pi/<container>/agent/skills  (one per container)
# Antigravity is a T3 Code driver (currently disabled, not installed), so it
# loads skills through T3 Code, not a directory we write here.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
SRC="$REPO/skills"
CONFIG="${AI_TOOLS_CONFIG:-/opt/ai-tools/config}"
CLAUDE_SKILLS="${CLAUDE_SKILLS_DIR:-$CONFIG/claude/home/.claude/skills}"
CODEX_SKILLS="${CODEX_SKILLS_DIR:-$CONFIG/codex/home/.codex/skills}"
OPENCODE_SKILLS="${OPENCODE_SKILLS_DIR:-$CONFIG/xdg/opencode/skills}"
PI_SKILLS="${PI_SKILLS_DIR:-}"

# Pi keeps a separate agent dir per container (t3code/archon/default). Discover
# every container that has an agent dir rather than hard-coding the list.
declare -a PI_TARGETS=()
if [ -n "$PI_SKILLS" ]; then
  # Explicit single override (or colon-separated list).
  IFS=':' read -ra PI_TARGETS <<< "$PI_SKILLS"
else
  for d in "$CONFIG"/pi/*/agent; do
    [ -d "$d" ] && PI_TARGETS+=("$d/skills")
  done
fi

TARGETS=("$CLAUDE_SKILLS" "$CODEX_SKILLS" "$OPENCODE_SKILLS" "${PI_TARGETS[@]}")
SKIP_RE='^(synced|\.system|\..*)$'

tracked() { find "$SRC" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort; }

status() {
  local rc=0
  for t in "${TARGETS[@]}"; do
    echo "== $t"
    if [ ! -d "$t" ]; then echo "   (missing)"; continue; fi
    for s in $(tracked); do
      if [ ! -d "$t/$s" ]; then echo "   missing   $s"; rc=1
      elif diff -rq "$SRC/$s" "$t/$s" >/dev/null; then echo "   in sync   $s"
      else echo "   DIFFERS   $s"; rc=1; fi
    done
    for d in "$t"/*/ "$t"/.*/; do
      [ -d "$d" ] || continue
      n="$(basename "$d")"
      [[ "$n" =~ $SKIP_RE || "$n" == "." || "$n" == ".." ]] && continue
      [ -d "$SRC/$n" ] || echo "   untracked $n   (./sync.sh collect $n to adopt)"
    done
  done
  return $rc
}

install() {
  for t in "${TARGETS[@]}"; do
    mkdir -p "$t"
    for s in $(tracked); do
      rm -rf "${t:?}/$s"
      cp -r "$SRC/$s" "$t/$s"
    done
    echo "installed $(tracked | wc -l) skills -> $t"
  done
}

collect() {
  local from="$CLAUDE_SKILLS" names=("$@")
  [ ${#names[@]} -gt 0 ] || mapfile -t names < <(tracked)
  for s in "${names[@]}"; do
    local src=""
    for t in "${TARGETS[@]}"; do [ -d "$t/$s" ] && { src="$t/$s"; break; }; done
    [ -n "$src" ] || { echo "skip $s (not found in any home)"; continue; }
    rm -rf "${SRC:?}/$s"
    cp -r "$src" "$SRC/$s"
    echo "collected $s <- $src"
  done
  echo "review with: git -C $REPO diff --stat"
}

case "${1:-status}" in
  status)  status ;;
  install) install ;;
  collect) shift; collect "$@" ;;
  *) echo "usage: $0 {status|install|collect [name..]}" >&2; exit 2 ;;
esac
