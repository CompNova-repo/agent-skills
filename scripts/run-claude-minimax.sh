#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "error: Claude Code is not installed. Run: npm install --global @anthropic-ai/claude-code" >&2
  exit 1
fi

if [[ -z "${MINIMAX_API_KEY:-}" ]]; then
  echo "error: MINIMAX_API_KEY is not set." >&2
  exit 1
fi

MINIMAX_MODEL="${MINIMAX_MODEL:-MiniMax-M3}"

export ANTHROPIC_BASE_URL="${MINIMAX_ANTHROPIC_BASE_URL:-https://api.minimax.io/anthropic}"
export ANTHROPIC_AUTH_TOKEN="${MINIMAX_API_KEY}"
export ANTHROPIC_MODEL="${MINIMAX_MODEL}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="${MINIMAX_MODEL}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="${MINIMAX_MODEL}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="${MINIMAX_MODEL}"
export API_TIMEOUT_MS="${API_TIMEOUT_MS:-3000000}"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}"
export ARCHIFY_UPDATE_CHECK_DISABLED="${ARCHIFY_UPDATE_CHECK_DISABLED:-1}"

exec claude --model "${MINIMAX_MODEL}" "$@"
