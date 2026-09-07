#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

[[ $# -eq 2 ]] || die "usage: $0 OWNER/REPO ISSUE_NUMBER"

REPO="$1"
ISSUE_NUMBER="$2"

[[ "$REPO" == "$ORG/"* ]] || die "repository must belong to $ORG"

issue_json="$(
  gh issue view "$ISSUE_NUMBER" \
    --repo "$REPO" \
    --json number,title,state,body,url,labels
)"

state="$(jq -r '.state' <<<"$issue_json")"
[[ "$state" == "OPEN" ]] || die "issue #$ISSUE_NUMBER is not open"

has_label="$(
  jq --arg label "$LABEL" \
    '[.labels[].name] | index($label) != null' \
    <<<"$issue_json"
)"

[[ "$has_label" == "true" ]] || die "issue #$ISSUE_NUMBER does not have required label '$LABEL'"

repo_name="${REPO#*/}"
repo_dir="$WORKSPACE_ROOT/$repo_name"

if [[ ! -d "$repo_dir/.git" ]]; then
  echo "Cloning $REPO..."
  gh repo clone "$REPO" "$repo_dir"
fi

git -C "$repo_dir" remote set-url origin "https://github.com/$REPO.git"

default_branch="$(
  gh repo view "$REPO" \
    --json defaultBranchRef \
    --jq '.defaultBranchRef.name'
)"

[[ -n "$default_branch" ]] || die "could not determine default branch"

git -C "$repo_dir" fetch origin "$default_branch"

if [[ -n "$(git -C "$repo_dir" status --porcelain)" ]]; then
  die "base repository has local changes: $repo_dir"
fi

title="$(jq -r '.title' <<<"$issue_json")"
slug="$(slugify "$title")"

branch="agent/issue-${ISSUE_NUMBER}-${slug}"
worktree="$WORKTREE_ROOT/${repo_name}-issue-${ISSUE_NUMBER}"

if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$branch"; then
  die "local branch already exists: $branch"
fi

if git -C "$repo_dir" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
  die "remote branch already exists: $branch"
fi

if [[ -e "$worktree" ]]; then
  die "worktree already exists: $worktree"
fi

git -C "$repo_dir" worktree add \
  -b "$branch" \
  "$worktree" \
  "origin/$default_branch"

cat > "$worktree/.agent-issue.json" <<EOF
{
  "repository": $(jq -Rn --arg v "$REPO" '$v'),
  "issue_number": $ISSUE_NUMBER,
  "issue_title": $(jq -Rn --arg v "$title" '$v'),
  "issue_url": $(jq -r '.url | @json' <<<"$issue_json"),
  "default_branch": $(jq -Rn --arg v "$default_branch" '$v'),
  "branch": $(jq -Rn --arg v "$branch" '$v')
}
EOF

cat > "$worktree/.agent-issue.md" <<EOF
# GitHub Issue #$ISSUE_NUMBER

Repository: $REPO
URL: $(jq -r '.url' <<<"$issue_json)

## Title

$title

## Body

$(jq -r '.body // ""' <<<"$issue_json")
EOF

echo "WORKTREE=$worktree"
echo "BRANCH=$branch"
echo "DEFAULT_BRANCH=$default_branch"
echo "ISSUE_FILE=$worktree/.agent-issue.md"
