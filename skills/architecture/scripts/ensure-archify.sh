#!/usr/bin/env bash
set -euo pipefail

# CompNova deliberately pins Archify so diagrams do not change underneath an
# organization-wide workflow without review.
ARCHIFY_REPO_URL="${ARCHIFY_REPO_URL:-https://github.com/tt-a1i/archify.git}"
ARCHIFY_VERSION="${ARCHIFY_VERSION:-v2.16.0}"
ARCHIFY_REF="${ARCHIFY_REF:-c826e6c3a7abad19c0f3cd1ca57207d54b1ad8de}"

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is required to obtain the pinned Archify runtime." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "error: Node.js >=18 is required by Archify." >&2
  exit 1
fi

node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
if [[ "${node_major}" -lt 18 ]]; then
  echo "error: Node.js >=18 is required; found $(node --version)." >&2
  exit 1
fi

cache_root="${XDG_CACHE_HOME:-${HOME}/.cache}/compnova-agent-skills/archify"
runtime_dir="${cache_root}/${ARCHIFY_REF}"
runtime_skill="${runtime_dir}/SKILL.md"
runtime_cli="${runtime_dir}/bin/archify.mjs"

install_runtime() {
  local tmp_dir repo_dir staged actual_ref
  tmp_dir="$(mktemp -d)"
  repo_dir="${tmp_dir}/repo"
  staged="${cache_root}/.${ARCHIFY_REF}.tmp.$$"

  cleanup() {
    rm -rf "${tmp_dir}" "${staged}"
  }
  trap cleanup RETURN

  git init -q "${repo_dir}"
  git -C "${repo_dir}" remote add origin "${ARCHIFY_REPO_URL}"
  git -C "${repo_dir}" fetch -q --depth 1 origin "refs/tags/${ARCHIFY_VERSION}:refs/tags/${ARCHIFY_VERSION}"
  git -C "${repo_dir}" checkout -q --detach "${ARCHIFY_VERSION}"

  actual_ref="$(git -C "${repo_dir}" rev-parse HEAD)"
  if [[ "${actual_ref}" != "${ARCHIFY_REF}" ]]; then
    echo "error: Archify tag ${ARCHIFY_VERSION} resolved to ${actual_ref}, expected ${ARCHIFY_REF}." >&2
    exit 1
  fi

  if [[ ! -f "${repo_dir}/archify/SKILL.md" ]]; then
    echo "error: pinned Archify release does not contain archify/SKILL.md." >&2
    exit 1
  fi

  mkdir -p "${cache_root}"
  rm -rf "${staged}"
  mkdir -p "${staged}"
  cp -a "${repo_dir}/archify/." "${staged}/"

  rm -rf "${runtime_dir}"
  mv "${staged}" "${runtime_dir}"
}

if [[ ! -f "${runtime_skill}" || ! -f "${runtime_cli}" ]]; then
  install_runtime
fi

export ARCHIFY_UPDATE_CHECK_DISABLED=1

if ! node "${runtime_cli}" doctor >/dev/null; then
  echo "error: Archify ${ARCHIFY_VERSION} doctor check failed at ${runtime_dir}." >&2
  exit 1
fi

# stdout is intentionally only the resolved runtime path so agents/scripts can
# capture it with command substitution.
printf '%s\n' "${runtime_dir}"
