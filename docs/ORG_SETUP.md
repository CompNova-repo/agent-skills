# CompNova organization setup

This repository is the central source of truth for CompNova Agent Skills. GitHub does not automatically inject a Claude Code skill into every repository in an organization, so consumers use either the `skills` CLI or the reusable workflow in this repository.

## Required organization secret

Create one GitHub Actions organization secret:

```text
MINIMAX_API_KEY
```

Set it to the MiniMax Token Plan key and grant access to the CompNova repositories that are allowed to generate diagrams.

Recommended GitHub UI path:

```text
CompNova-repo organization
  -> Settings
  -> Secrets and variables
  -> Actions
  -> New organization secret
```

Name it exactly `MINIMAX_API_KEY`.

Do not put the key in repository files, workflow YAML, issue bodies, prompts, or committed `.env` files.

## Option A: install the skill in a repository

From the target repository:

```bash
npx -y skills add CompNova-repo/agent-skills \
  --skill architecture \
  --agent claude-code \
  --copy \
  --yes
```

This creates a project-level Claude Code skill. Start a new Claude Code session after installation.

## Option B: call the central GitHub Actions workflow

Copy `examples/caller-workflow.yml` from this repository into the target repository as:

```text
.github/workflows/architecture.yml
```

No Archify source needs to be copied into the target repository.

The target repository can then run **Architecture Diagram** from the Actions UI, including from the GitHub iOS app or a mobile browser.

The caller uses:

```yaml
uses: CompNova-repo/agent-skills/.github/workflows/architecture.yml@main
```

and inherits the organization `MINIMAX_API_KEY` secret.

## What runs where

The target repository's GitHub-hosted runner:

1. checks out the target repository with read-only GitHub permissions;
2. installs Node.js and Claude Code;
3. installs the central CompNova `architecture` skill globally for that runner;
4. obtains the pinned Archify runtime;
5. validates the Archify installation;
6. calls Claude Code through MiniMax's Anthropic-compatible endpoint using `MiniMax-M3`;
7. requires both Archify JSON and HTML output;
8. fails if the agent changes repository files outside the requested output directory; and
9. uploads the generated diagram as an Actions artifact.

The generated diagram is not committed automatically.

## MiniMax configuration used

```text
ANTHROPIC_BASE_URL=https://api.minimax.io/anthropic
ANTHROPIC_AUTH_TOKEN=<MINIMAX_API_KEY>
ANTHROPIC_MODEL=MiniMax-M3
ANTHROPIC_DEFAULT_SONNET_MODEL=MiniMax-M3
ANTHROPIC_DEFAULT_OPUS_MODEL=MiniMax-M3
ANTHROPIC_DEFAULT_HAIKU_MODEL=MiniMax-M3
```

The Token Plan key itself is never stored in this repository.

## Archify pin

CompNova currently pins:

```text
release: v2.16.0
commit:  c826e6c3a7abad19c0f3cd1ca57207d54b1ad8de
```

The bootstrap script verifies that the release tag resolves to that exact commit before copying the `archify/` skill runtime into the runner/user cache.

## Updating Archify

1. Review the new upstream Archify release and release notes.
2. Resolve the release tag to its immutable commit SHA.
3. Update `ARCHIFY_VERSION` and `ARCHIFY_REF` in `skills/architecture/scripts/ensure-archify.sh`.
4. Update the version metadata in `skills/architecture/SKILL.md` and `README.md`.
5. Run `node bin/archify.mjs doctor` through the bootstrap script.
6. Generate at least one description-only architecture diagram.
7. Generate at least one repository-backed architecture diagram.
8. Merge only after both validate and deliver successfully.

Do not make the bootstrap track `main` or an unpinned `latest` release.

## Access model

The central `agent-skills` repository can remain the single maintained copy while individual repositories consume it. If this repository is kept public, the reusable workflow still rejects callers whose `github.repository_owner` is not `CompNova-repo`, but the skill source itself is public. If CompNova wants the skill implementation private, change the repository visibility and ensure consuming runners have authenticated access.
