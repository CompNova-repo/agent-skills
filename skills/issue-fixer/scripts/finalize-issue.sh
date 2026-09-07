#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

[[ $# -eq 1 ]] || die "usage: $0 WORKTREE_PATH"

WORKTREE="$(cd "$1" && pwd)"

[[ -d "$WORKTREE/.git" || -f "$WORKTREE/.git" ]] || die "not a git worktree"
[[ -f "$WORKTREE/.agent-issue.json" ]] || die "missing .agent-issue.json"

meta="$(cat "$WORKTREE/.agent-issue.json")"

REPO="$(jq -r '.repository' <<<"$meta")"
ISSUE_NUMBER="$(jq -r '.issue_number' <<<"$meta")"
ISSUE_TITLE="$(jq -r '.issue_title' <<<"$meta")"
DEFAULT_BRANCH="$(jq -r '.default_branch' <<<"$meta")"
BRANCH="$(jq -r '.branch' <<<"$meta")"

[[ "$REPO" == "$ORG/"* ]] || die "repository does not belong to $ORG"

issue_json="$(
  gh issue view "$ISSUE_NUMBER" \
    --repo "$REPO" \
    --json state,labels
)"

[[ "$(jq -r '.state' <<<"$issue_json")" == "OPEN" ]] || die "issue is no longer open"

has_label="$(
  jq --arg label "$LABEL" \
    '[.labels[].name] | index($label) != null' \
    <<<"$issue_json"
)"

[[ "$has_label" == "true" ]] || die "issue no longer has required label '$LABEL'"

current_branch="$(git -C "$WORKTREE" branch --show-current)"
[[ "$current_branch" == "$BRANCH" ]] || die "unexpected branch: $current_branch"

rm -f \
  "$WORKTREE/.agent-issue.json" \
  "$WORKTREE/.agent-issue.md"

if [[ -z "$(git -C "$WORKTREE" status --porcelain)" ]]; then
  die "no repository changes to commit"
fi

echo "===== Changes ====="
git -C "$WORKTREE" status --short

echo
echo "===== Diff summary ====="
git -C "$WORKTREE" diff --stat
git -C "$WORKTREE" diff --cached --stat

# Basic secret-file protection.
forbidden="$(
  git -C "$WORKTREE" status --porcelain \
    | awk '{print $2}' \
    | grep -E '(^|/)(\.env($|\.)|.*\.pem$|.*\.key$|id_rsa$|id_ed25519$)' \
    || true
)"

if [[ -n "$forbidden" ]]; then
  echo "$forbidden" >&2
  die "refusing to commit potentially sensitive files"
fi

git -C "$WORKTREE" add -A

git -C "$WORKTREE" commit \
  -m "fix: address issue #$ISSUE_NUMBER"

git -C "$WORKTREE" push -u origin "$BRANCH"

existing_pr="$(
  gh pr list \
    --repo "$REPO" \
    --head "$BRANCH" \
    --state open \
    --json url \
    --jq '.[0].url // empty'
)"

if [[ -n "$existing_pr" ]]; then
  echo "PR already exists: $existing_pr"
  exit 0
fi

pr_url="$(
  gh pr create \
    --repo "$REPO" \
    --base "$DEFAULT_BRANCH" \
    --head "$BRANCH" \
    --title "Fix #$ISSUE_NUMBER: $ISSUE_TITLE" \
    --body "$(cat <<EOF
## Summary

Implements the fix for #$ISSUE_NUMBER.

## Validation

Changes were implemented and validated by the local Claude Code issue-fixer workflow.

## Review

This pull request requires human review before merge.

Closes #$ISSUE_NUMBER
EOF
)"
)"

echo "PR_URL=$pr_url"
