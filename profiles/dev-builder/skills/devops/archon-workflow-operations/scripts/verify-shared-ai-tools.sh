#!/usr/bin/env bash
set -uo pipefail

failures=0
check() {
  local label="$1"
  shift
  printf '\n== %s ==\n' "$label"
  if "$@"; then
    printf 'PASS: %s\n' "$label"
  else
    printf 'FAIL: %s\n' "$label"
    failures=$((failures + 1))
  fi
}

printf 'identity: uid=%s gid=%s home=%s\n' "$(id -u)" "$(id -g)" "${HOME:-unset}"
printf 'path: %s\n' "$PATH"

check "shared root mounted" test -d /opt/ai-tools
check "shared context mounted" test -d /opt/ai-context/ProductivityCenter
check "claude wrapper selected" sh -c 'test "$(command -v claude)" = /opt/ai-tools/bin/claude'
check "codex wrapper selected" sh -c 'test "$(command -v codex)" = /opt/ai-tools/bin/codex'
check "gh wrapper selected" sh -c 'test "$(command -v gh)" = /opt/ai-tools/bin/gh'
check "claude authenticated" /opt/ai-tools/bin/claude auth status
check "codex authenticated" /opt/ai-tools/bin/codex login status
check "github authenticated" /opt/ai-tools/bin/gh auth status

if [[ -n "${SHARED_AI_TOOLS_GITHUB_REPO:-}" ]]; then
  check "GitHub repository accessible" /opt/ai-tools/bin/gh repo view "$SHARED_AI_TOOLS_GITHUB_REPO" --json nameWithOwner,defaultBranchRef,url
fi

printf '\nfailures=%d\n' "$failures"
exit "$failures"
