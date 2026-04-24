---
name: dev-stack-install
description: "Install and fully configure dev-stack in any Python repo — greenfield or brownfield. Use when the user says 'install dev-stack', 'set up dev-stack', 'wire up the pre-commit pipeline', 'bootstrap this repo with dev-stack', or 'configure dev-stack here'. Produces a fully wired 9-stage pre-commit pipeline, all generated artifacts, and a passing first commit."
argument-hint: "Optional: 'greenfield' or 'brownfield' to skip detection, or a path to the target repo."
---

# Dev-Stack Install

Sets up dev-stack end-to-end in the current (or specified) repository, handling both greenfield (new) and brownfield (existing) projects with all known speedbumps pre-empted.

## When to Use

- User says "install dev-stack", "set up dev-stack for me", "wire up the pipeline", "bootstrap this repo"
- Any repo that lacks a `dev-stack.toml` manifest
- Reinitializing after partial failures (`dev-stack --force init`)

## Expected Output

- Fully wired pre-commit pipeline (9-stage: lint → typecheck → test → security → docs-api → docs-narrative → infra-sync → visualize → commit-message)
- All generated artifacts committed and tracked
- `dev-stack --json status` reporting `healthy: true` for every module
- First commit passes all hard-gate stages without `--no-verify`

---

## Procedure

### Step 0 — Preflight: Check Prerequisites

Verify before touching anything:

```bash
python3 --version   # must be 3.11+
uv --version        # must be present — install: curl -LsSf https://astral.sh/uv/install.sh | sh
git --version       # must be 2.30+
dev-stack --version # skip if not yet installed
```

**Agent detection** — dev-stack auto-detects in priority order: `claude` → `gh copilot` → `cursor`.
- If none available: set `export DEV_STACK_AGENT=none` so agent-dependent stages (docs-narrative, commit-message, visualize) are skipped gracefully rather than blocking.
- To pin a specific agent: `export DEV_STACK_AGENT=claude` (or `copilot`, `cursor`).

---

### Step 1 — Install the dev-stack CLI

> Skip if `dev-stack --version` already succeeds.

```bash
# Build from source (dev-stack source repo)
cd /path/to/dev-stack
uv build
uv tool install ./dist/dev_stack-0.1.0-py3-none-any.whl

# Verify it's on PATH
dev-stack --version
```

Once published to PyPI: `uv tool install dev-stack`.

---

### Step 2 — Detect Greenfield vs Brownfield

**Greenfield** — the target directory is empty OR contains only a bare `uv init --package` scaffold (default description `"Add your description here"`, no `[tool]` table, no root-level Python sources).

**Brownfield** — anything else: existing source code, `pyproject.toml` with custom content, any committed files.

> When uncertain, always run `dev-stack --dry-run init` first (Step 3B) to let the tool classify the repo.

---

### Step 3A — Greenfield Setup

```bash
# 1. Create and enter the project directory
mkdir my-project && cd my-project

# 2. Initialize git (dev-stack does this automatically, but be explicit)
git init

# 3. Run dev-stack init — installs all 8 default modules in resolved order:
#    uv_project → sphinx_docs → hooks → apm → vcs_hooks → ci-workflows → docker → visualization
dev-stack init
```

**What `dev-stack init` does automatically (greenfield)**:
- Runs `uv init --package --name <dir-name>` if no `pyproject.toml` exists
- Runs `uv sync --all-extras` (installs all optional deps: `dev`, `docs`)
- Writes `dev-stack.toml` manifest
- Installs `.pre-commit-config.yaml` and `scripts/hooks/pre-commit`
- Installs `.git/hooks/commit-msg` (conventional-commit linting) and `.git/hooks/pre-push` (branch naming + signing)
- Scaffolds `docs/conf.py`, `docs/index.rst`, `docs/Makefile`
- Writes `.understand-anything/` bootstrap
- Generates `.github/workflows/dev-stack-{tests,deploy,vuln-scan}.yml`
- Writes `Dockerfile`, `docker-compose.yml`, `.dockerignore`
- Writes `apm.yml` and runs `apm install` (MCP servers: context7, github, huggingface)
- Writes `.dev-stack/instructions.md` and injects into the detected agent config
- Writes `cliff.toml` for changelog generation
- Creates a rollback git tag (`dev-stack/rollback/<timestamp>`)
- Adds a managed `## DEV-STACK: GITIGNORE` section to `.gitignore`

```bash
# 4. (Optional but recommended) Scaffold the .specify/ spec-driven directory
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git  # one-time
specify init --here --ai copilot

# 5. Commit everything — the first commit passes all hard-gate hooks cleanly
git add -A
git commit -m "chore: initial dev-stack setup"

# 6. Validate
dev-stack --json status
dev-stack --json pipeline run --force   # runs all 9 stages; stages 1-5 must pass
dev-stack --json hooks status           # verify commit-msg and pre-push checksums
```

---

### Step 3B — Brownfield Setup

```bash
cd /path/to/existing-repo

# 1. Preview — never modify without dry-run first
dev-stack --dry-run init
```

Inspect the output:
- `mode: brownfield` confirms conflict detection is active
- `conflicts` lists files that already exist — each will be resolved interactively
- `new_files` lists what will be created fresh

```bash
# 2. Apply — interactive conflict resolution for each collision
dev-stack init
```

**Interactive conflict prompts** (one per conflicting file):
- `[a] Accept proposed` — wraps existing content in marker-delimited managed section
- `[s] Skip` — keeps current file untouched
- `[m] Merge` — opens diff in `$EDITOR` for manual merge

**Automatic brownfield behaviors** (no prompts needed):
- Sets `[tool.dev-stack.pipeline] strict_docs = false` in `pyproject.toml` so pre-existing Sphinx warnings are non-fatal
- Creates `.dev-stack/brownfield-init` marker — the first commit auto-runs `ruff format .` to reformat pre-existing code; subsequent commits are hard-gated normally
- Detects `requirements.txt` and offers to merge dependencies into `pyproject.toml [project.dependencies]` via `uv add`
- Detects root-level Python packages and recommends migrating to `src/` layout

```bash
# 3. (Optional) Spec scaffold
specify init --here --ai copilot

# 4. First commit — brownfield-init marker triggers auto-format pass; this commit passes cleanly
git add -A
git commit -m "chore: initial dev-stack setup"

# 5. Validate
dev-stack --json status
dev-stack --json pipeline run --force
dev-stack --json hooks status
```

---

### Step 4 — Post-Install Validation Checklist

Run these in order; surface any failures before declaring success:

| Check | Command | Expected |
|-------|---------|----------|
| CLI responds | `dev-stack --help` | All 12 commands listed, no errors |
| Modules healthy | `dev-stack --json status` | `healthy: true` for every module |
| Pipeline passes | `dev-stack --json pipeline run --force` | Stages 1–5 exit cleanly |
| Hooks installed | `dev-stack --json hooks status` | `commit-msg` + `pre-push` with valid checksums |
| Config present | `grep 'tool.dev-stack' pyproject.toml` | hooks, branch, signing sections exist |
| Rollback available | `git tag -l 'dev-stack/rollback/*'` | At least one tag |
| Visualization | `dev-stack --json visualize` | `status: pass` (or `status: no-artifacts` if graph not yet generated) |

---

## Known Speedbumps & Fixes

### "Repository already has dev-stack.toml"
`dev-stack init` exits with `GENERAL_ERROR` if already initialized and `--force` is not passed.
```bash
dev-stack --force init   # reinitialize, overwriting managed files
# — or —
dev-stack update         # re-apply modules from existing manifest
```

### `uv` not found
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.cargo/env   # or restart shell
```

### `uv sync --all-extras` fails
Happens when optional extras (`docs`, `dev`) have unresolvable deps.
```bash
uv sync --extra dev --extra docs   # retry with explicit extras
# — or —
uv sync                            # bare sync, skip optional extras
```

### No coding agent detected
```bash
export DEV_STACK_AGENT=none    # skip agent stages entirely
# — or install one of:
# claude: https://claude.ai/cli
# gh copilot: gh extension install github/gh-copilot
# cursor: https://cursor.sh
```

### `apm install` fails (APM module)
The APM module requires the Microsoft `apm` CLI. If absent, install it, then:
```bash
dev-stack --force init --modules apm   # retry just the APM module
```

### Root-level packages detected (brownfield)
Dev-stack warns but does not block. Migrate manually for proper `uv`/`mypy` integration:
```bash
mkdir -p src/
mv my_package/ src/my_package/
# Update pyproject.toml [tool.setuptools.packages.find] or [project] paths
```

### `requirements.txt` migration skipped (non-interactive/JSON mode)
```bash
uv add $(cat requirements.txt | grep -v '#' | grep -v '-e' | grep -v '://' | tr '\n' ' ')
```

### Visualization reports `status: stale` or `status: no-artifacts`
The `visualize` stage requires committed `.understand-anything/knowledge-graph.json`. Generate it first:
1. Open the repo in VS Code with the Understand-Anything / GitHub Copilot plugin
2. Run the graph generation workflow
3. Commit the resulting `.understand-anything/knowledge-graph.json`
4. Re-run `dev-stack --json visualize`

### Pre-push hook rejects branch name
Configure allowed patterns in `pyproject.toml`:
```toml
[tool.dev-stack.branch]
pattern = "^(main|master|develop|feature/.+|bugfix/.+|hotfix/.+|release/.+|\\d{3}-.+)$"
exempt = ["main", "master"]
```

### `commit-msg` hook rejects commit message
Dev-stack enforces [Conventional Commits](https://www.conventionalcommits.org/). Format:
```
<type>(<optional-scope>): <description>

# Valid types: feat, fix, chore, docs, style, refactor, perf, test, build, ci, revert
```

### Rollback tag missing (no initial commit)
Dev-stack calls `_ensure_initial_commit` automatically before tagging. If the repo has no commits and `git add -A && git commit` fails, create a manual initial commit first:
```bash
git commit --allow-empty -m "chore: initial commit"
dev-stack init
```

---

## Module Reference

| Module | Key Assets | Skip When |
|--------|-----------|-----------|
| `uv_project` | `pyproject.toml`, `.python-version`, `tests/` scaffold | Non-Python repo |
| `sphinx_docs` | `docs/conf.py`, `docs/index.rst`, `docs/Makefile` | Docs not needed |
| `hooks` | `.pre-commit-config.yaml`, `scripts/hooks/pre-commit` | Always include |
| `apm` | `apm.yml`, `apm.lock.yaml`, MCP servers | APM CLI absent |
| `vcs_hooks` | `.git/hooks/commit-msg`, `.git/hooks/pre-push`, `cliff.toml`, `.dev-stack/instructions.md` | Always include |
| `ci-workflows` | `.github/workflows/dev-stack-{tests,deploy,vuln-scan}.yml` | No GitHub Actions |
| `docker` | `Dockerfile`, `docker-compose.yml`, `.dockerignore` | No containerization |
| `visualization` | `.understand-anything/` bootstrap | No graph workflow |

Install a subset:
```bash
dev-stack init --modules hooks,vcs_hooks,uv_project
```

---

## Environment Variables

| Variable | Effect |
|----------|--------|
| `DEV_STACK_AGENT=none` | Skip all agent-dependent pipeline stages |
| `DEV_STACK_AGENT=claude\|copilot\|cursor` | Override auto-detection |
| `GITHUB_TOKEN` | Required by APM github MCP server |
| `HF_TOKEN` | Required by APM huggingface MCP server |
