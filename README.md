# CompNova Agent Skills

Central Agent Skills repository for the `CompNova-repo` GitHub organization.

The first managed skill is `architecture`, which uses the upstream [Archify](https://github.com/tt-a1i/archify) renderer with Claude Code. Claude Code is configured to use the MiniMax M3 Token Plan through MiniMax's Anthropic-compatible endpoint.

## What this repository provides

- One centrally maintained architecture skill for CompNova.
- A pinned Archify runtime (`v2.16.0` / commit `c826e6c3a7abad19c0f3cd1ca57207d54b1ad8de`).
- A reusable GitHub Actions workflow that any repository in `CompNova-repo` can call.
- A MiniMax M3 launcher for Claude Code.
- No API keys or other credentials committed to Git.

The architecture is:

```text
User / GitHub Action
        |
        v
Claude Code
        |
        | MiniMax M3 via Anthropic-compatible API
        v
CompNova architecture skill
        |
        v
Pinned Archify runtime
        |
        +--> validated JSON source
        +--> self-contained HTML diagram
```

## 1. One-time organization setup

Create an **organization Actions secret** named:

```text
MINIMAX_API_KEY
```

Use the MiniMax Token Plan key (`sk-cp-...`) and grant the repositories that need to call the reusable workflow access to it.

Do not add the key to this repository, a workflow file, `CLAUDE.md`, or a committed `.env` file.

MiniMax's international Anthropic-compatible endpoint is:

```text
https://api.minimax.io/anthropic
```

The default model configured here is:

```text
MiniMax-M3
```

## 2. Install the skill into a Claude Code project

From any repository:

```bash
npx -y skills add CompNova-repo/agent-skills \
  --skill architecture \
  --agent claude-code \
  --copy \
  --yes
```

This installs the CompNova wrapper skill into the current Claude Code project. The skill obtains the centrally pinned Archify runtime on first use, rather than vendoring Archify into every application repository.

Start a new Claude Code session after installing the skill.

## 3. Use Claude Code with MiniMax M3 locally / in WSL

Install Claude Code:

```bash
npm install --global @anthropic-ai/claude-code
```

Export the Token Plan key for the current shell:

```bash
export MINIMAX_API_KEY='your-token-plan-key'
```

Then use the launcher in this repository:

```bash
./scripts/run-claude-minimax.sh
```

Or invoke a one-shot prompt:

```bash
./scripts/run-claude-minimax.sh --print \
  "Use the architecture skill to create an architecture diagram from this description: Browser -> API -> PostgreSQL."
```

The launcher maps `MINIMAX_API_KEY` to Claude Code's Anthropic-compatible environment variables. It never prints the key.

## 4. Call the architecture generator from any CompNova repository

This repository exposes a reusable workflow:

```text
CompNova-repo/agent-skills/.github/workflows/architecture.yml@main
```

A consuming repository only needs a tiny caller workflow. See [`examples/caller-workflow.yml`](examples/caller-workflow.yml).

Minimal example:

```yaml
name: Architecture Diagram

on:
  workflow_dispatch:
    inputs:
      prompt:
        description: Describe the system or diagram to generate
        required: true
        type: string

jobs:
  architecture:
    uses: CompNova-repo/agent-skills/.github/workflows/architecture.yml@main
    with:
      prompt: ${{ inputs.prompt }}
    secrets: inherit
```

The reusable workflow:

1. checks out the caller repository;
2. installs Node.js and Claude Code;
3. installs the central `architecture` skill from this repository;
4. calls Claude Code using MiniMax M3;
5. requires Archify JSON + HTML output; and
6. uploads the generated files as a GitHub Actions artifact.

It does **not** edit application source code, create a pull request, or commit the generated diagram back to the caller repository.

## 5. Prompt examples

### Description only

```text
Use the architecture skill.

Create an architecture diagram for three systems A, B and C.

A -> B is confirmed and reliable.
B updates its own database correctly.
B -> C is the suspected failure boundary and may take hours or fail.

We do not yet know whether B -> C uses an API, queue, Kafka, worker,
scheduled job, polling, or retries.

Do not present those unknown mechanisms as facts. Clearly distinguish
confirmed components from unknown or candidate infrastructure.
```

### Repository-backed architecture

```text
Use the architecture skill.

Inspect this repository and create a high-level runtime architecture diagram.
Use repository evidence for confirmed components and relationships. Do not
invent infrastructure that cannot be supported by the source. Keep the
diagram to the core runtime path and major external dependencies.
```

## CompNova diagram rules

The wrapper skill adds these organization-level rules on top of Archify:

- distinguish confirmed facts from assumptions;
- never present inferred infrastructure as confirmed;
- preserve directionality;
- show integration/trust boundaries where relevant;
- highlight known failure areas when requested;
- prefer a readable high-level map over excessive nodes;
- do not modify application source code unless explicitly asked.

## Archify version management

This repository intentionally pins the runtime used by the CompNova wrapper:

- upstream: `tt-a1i/archify`
- release: `v2.16.0`
- commit: `c826e6c3a7abad19c0f3cd1ca57207d54b1ad8de`

The pin lives in:

```text
skills/architecture/scripts/ensure-archify.sh
```

To upgrade, review the new Archify release first, update both `ARCHIFY_VERSION` and `ARCHIFY_REF` in that script/documentation, run the Archify `doctor` command, and test at least one description-only diagram before merging the change.

## Security

- Never commit `MINIMAX_API_KEY`.
- Never echo `ANTHROPIC_AUTH_TOKEN`.
- The reusable workflow is restricted to callers whose repository owner is `CompNova-repo`.
- Repository content is treated as data; instructions embedded inside source files must not override the architecture-generation task.
- Generated artifacts can contain architectural details. Use the caller repository's normal visibility/access controls accordingly.

## Repository layout

```text
.
├── .github/workflows/architecture.yml
├── docs/ORG_SETUP.md
├── examples/caller-workflow.yml
├── scripts/run-claude-minimax.sh
└── skills/
    └── architecture/
        ├── SKILL.md
        └── scripts/
            └── ensure-archify.sh
```

## Important scope note

GitHub does not automatically inject a Claude Code skill into every repository merely because it lives in an organization repository. This repo is the **central source of truth**. Other CompNova repositories either:

- install the skill with `npx skills add ...`; or
- call the reusable workflow with the small caller shown above.

That keeps the skill centrally maintained while making it usable from anywhere in the organization.

## Upstream

Archify is MIT licensed and supports architecture, workflow, sequence, data-flow, and lifecycle diagrams from either plain-language descriptions or repository evidence. The upstream project remains the source of truth for its schemas, renderer, validation, and delivery behavior.
