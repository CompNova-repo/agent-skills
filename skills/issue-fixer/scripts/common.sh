#!/usr/bin/env bash
set -euo pipefail

ORG="${ORG:-CompNova-repo}"
LABEL="${LABEL:-agent-fix}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/compnova}"
WORKTREE_ROOT="${WORKTREE_ROOT:-$WORKSPACE_ROOT/worktrees}"

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_cmd gh
require_cmd git
require_cmd jq

mkdir -p "$WORKSPACE_ROOT"
mkdir -p "$WORKTREE_ROOT"

gh auth status >/dev/null 2>&1 || die "GitHub CLI is not authenticated. Run: gh auth login"

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-48
}
