#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

gh search issues \
  --owner "$ORG" \
  --state open \
  --label "$LABEL" \
  --limit 100 \
  --json repository,number,title,url,labels \
  | jq '
      map({
        repo: .repository.nameWithOwner,
        number: .number,
        title: .title,
        url: .url,
        labels: [.labels[].name]
      })
    '
