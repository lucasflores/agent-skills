---
name: dev-stack-update
description: "Update a repo that was previously set up with dev-stack when new artifacts, modules, or pipeline changes land in a newer CLI version. Use when the user says 'update dev-stack', 'sync dev-stack to the latest version', 'upgrade the pipeline', 'add a new dev-stack module', 'a new module was added to dev-stack', 'dev-stack has new artifacts I need', or 'my dev-stack is out of date'. Handles module version diffs, deprecated module migration (e.g. speckit → apm), new-default-module opt-in, conflict resolution, and safe rollback."
argument-hint: "Optional: '--modules <name1,name2>' to target specific modules, or 'rollback' to undo the last update."
---

# Dev-Stack Update

Brings an already-initialized repository up to date with the current dev-stack CLI version. Covers module version bumps, newly added default modules, deprecated module removal, pipeline artifact regeneration, and safe rollback when things go wrong.

## When to Use

- `dev-stack.toml` already exists and `dev-stack --json status` reports stale module versions
- A new module was added to dev-stack and you want to install it into an existing repo
- A module was deprecated (e.g., `speckit` → `apm`) and the manifest needs cleaning
- The pipeline script (`scripts/hooks/pre-commit`), hook templates, or CI workflows changed
- Hook checksums in `dev-stack --json hooks status` show `modified: true` (drift detected)
- `infra-sync` stage warns about template drift on commit

## Expected Output

- `dev-stack.toml` manifest with all module versions bumped to current
- Regenerated managed artifacts for updated modules
- `dev-stack --json status` reporting `healthy: true` for every module
- A new rollback tag (`dev-stack/rollback/<timestamp>`) in case you need to revert
- First post-update commit passes all hard-gate pipeline stages without `--no-verify`

---

## Procedure

### Step 0 — Assess Current State

Before touching anything, capture a baseline:

```bash
# Confirm dev-stack is initialized
cat dev-stack.toml   # must exist; if absent, run dev-stack init instead

# See what the CLI considers stale
dev-stack --json status

# Check hook health — look for modified: true entries
dev-stack --json hooks status

# Preview the full update diff without writing anything
dev-stack --dry-run update
```

The dry-run output includes:
- `modules_added` — new modules in `DEFAULT_GREENFIELD_MODULES` not yet in the manifest
- `modules_updated` — modules whose version in the manifest is lower than the CLI's current version
- `modules_removed` — modules deprecated since last init (e.g., `speckit`)
- `conflicts` — existing files that will need resolution

> If `modules_updated` and `modules_added` are both empty and no deprecated modules are flagged, everything is already current (`status: noop`). Stop here.

---

### Step 1 — Upgrade the dev-stack CLI itself (if needed)

The `dev-stack update` command updates the **repo's artifacts** to match the **installed CLI version**. Make sure the CLI itself is current first:

```bash
# If installed from wheel (pre-PyPI)
cd /path/to/dev-stack-source
uv build
uv tool upgrade dev-stack --reinstall-package dev-stack
# — or —
uv tool install --force ./dist/dev_stack-<version>-py3-none-any.whl

# Once on PyPI
uv tool upgrade dev-stack

# Verify
dev-stack --version
```

---

### Step 2 — Run the Update

```bash
cd /path/to/your-repo

# Standard update — updates all modules listed in dev-stack.toml to current versions
dev-stack update
```

**What happens automatically:**
1. Reads `dev-stack.toml` to determine installed module versions
2. Computes a `ModuleDelta` (added / updated / removed / unchanged) by diffing manifest versions against CLI's current versions
3. **New default modules** — if any `DEFAULT_GREENFIELD_MODULES` are absent from the manifest, the CLI prompts interactively: `Install 'docker'? [y/N]`. New modules are NEVER auto-installed without confirmation.
4. **Deprecated modules** (e.g., `speckit`) — emits a migration notice, marks the entry as `deprecated: true` in `dev-stack.toml`, and excludes it from installation. No files are deleted.
5. Creates a new rollback tag before touching anything
6. Writes `.dev-stack/update-in-progress` marker for crash safety (removed on success)
7. Calls `module.update()` for each updated module (re-renders managed templates)
8. Calls `module.install(force=True)` for each newly added module
9. Bumps `last_updated` and module versions in `dev-stack.toml`

---

### Step 3 — Selective Module Update (Optional)

To update or add only specific modules without touching the rest:

```bash
# Update only the hooks and vcs_hooks modules
dev-stack update --modules hooks,vcs_hooks

# Add a net-new module to an existing repo
dev-stack update --modules docker

# Add apm after migrating away from deprecated speckit
dev-stack update --modules apm
```

Module dependencies are resolved automatically — adding `sphinx_docs` will also ensure `uv_project` is present.

---

### Step 4 — Handle Conflicts

When updated artifacts collide with locally modified files, the CLI prompts interactively:

```
.pre-commit-config.yaml already exists.
  [a] Accept proposed (overwrite with new template)
  [s] Skip (keep current, skip this file)
  [m] Merge (open diff in $EDITOR)
Choice:
```

**Non-interactive / JSON mode** — conflicts auto-resolve to overwrite:
```bash
dev-stack --json update          # auto-overwrites all pending conflicts
dev-stack --force update         # same but human-readable output
```

**Recommended for hooks files** — always accept proposed (`a`). Hook templates are checksum-tracked; a locally modified hook will keep firing `modified: true` in `hooks status` until overwritten.

**Recommended for `pyproject.toml`** — use merge (`m`) to review changes before accepting.

---

### Step 5 — Post-Update Validation

```bash
# Module health
dev-stack --json status   # all modules: healthy: true

# Hook integrity
dev-stack --json hooks status   # no modified: true entries

# Pipeline smoke test
dev-stack --json pipeline run --force   # stages 1-5 must pass

# Infra-sync drift check (stage 7)
dev-stack --json pipeline run --stage infra-sync   # should report no drift
```

---

### Step 6 — Commit the Updated Artifacts

```bash
git add -A
git commit -m "chore: update dev-stack artifacts to vX.Y.Z"
```

The pre-commit pipeline will run. All hard-gate stages (1–5) must pass. If they don't, see the speedbumps section below.

---

## Deprecated Module Migration

### `speckit` → `apm`

The `speckit` module was removed. Agent/MCP dependencies are now managed by `apm`.

```bash
# 1. Update to mark speckit deprecated and install apm
dev-stack update --modules apm

# 2. Set up the .specify/ directory (one-time, replaces speckit scaffolding)
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
specify init --here --ai copilot
```

The `apm` module manages MCP servers (`context7`, `github`, `huggingface`) via `apm.yml`. The `speckit` entry in `dev-stack.toml` is marked `deprecated = true` but not deleted.

---

## Known Speedbumps & Fixes

### "dev-stack.toml not found"
`dev-stack update` requires an initialized repo. Run `dev-stack init` first.

### "A previous dev-stack update did not complete"
The `.dev-stack/update-in-progress` marker exists from a crashed update.
```bash
# Option A: Roll back to the pre-update state, then retry
dev-stack rollback
dev-stack update

# Option B: Confirm and continue from where it left off
dev-stack update   # answers "Continue anyway? [y/N]" with y
```

### "No modules require updates" (unexpected)
The manifest versions already match the CLI. Either the CLI was not upgraded, or the repo is truly current.
```bash
dev-stack --version        # confirm CLI version
cat dev-stack.toml         # compare [modules.*] versions by hand
dev-stack --dry-run update # authoritative diff
```

### Hook checksums still show `modified: true` after update
A locally edited hook was skipped during conflict resolution. Force-overwrite:
```bash
dev-stack update --modules hooks,vcs_hooks --force
dev-stack --json hooks status   # should now show modified: false
```

### `uv sync` fails after adding `uv_project` module
```bash
uv sync --extra dev --extra docs   # explicit extras
# — or if optional extras are broken —
uv sync
```

### Pipeline stage failures after update

| Failing stage | Likely cause | Fix |
|--------------|-------------|-----|
| `lint` | Ruff rules tightened in new template | `ruff check --fix . && ruff format .` |
| `typecheck` | mypy config updated | Review new `[tool.mypy]` section in `pyproject.toml` |
| `security` | New `detect-secrets` plugin or `pip-audit` findings | Review findings; update `.secrets.baseline` with `detect-secrets scan > .secrets.baseline` |
| `docs-api` | Sphinx conf updated | Check `docs/conf.py` diff; for brownfield `strict_docs = false` should already be set |
| `infra-sync` | Drift from skipped conflict | Re-run `dev-stack update --force` for affected module |

### New module install fails mid-update (partial state)
```bash
dev-stack rollback             # restore pre-update state
dev-stack update --dry-run     # confirm what will be applied
dev-stack update               # retry from clean state
```

### Deprecated module warning keeps appearing
The deprecated entry remains in `dev-stack.toml` with `deprecated = true`. It is safe to leave as-is — it will not be re-installed. The warning only appears when explicitly named in `--modules`.

---

## Key Behavioral Differences: `update` vs `init --force`

| Behavior | `dev-stack update` | `dev-stack init --force` |
|----------|--------------------|--------------------------|
| Scope | Only modules with version delta | All modules |
| New default modules | Prompts user (opt-in) | Installs all defaults |
| Rollback tag | Always created | Created on first init |
| `brownfield-init` marker | Not written | Written for brownfield repos |
| Deprecated module handling | Marks deprecated, skips | Not applicable |
| Safe for CI/automation | Yes (auto-overwrites conflicts) | Risky (overwrites everything) |

Prefer `update` for routine maintenance. Use `init --force` only for a full re-scaffold.

---

## Rollback

Every `update` run creates a rollback tag before making changes:

```bash
# List available rollback points
git tag -l 'dev-stack/rollback/*'

# Restore to the most recent rollback (undoes last update)
dev-stack rollback

# Restore to a specific rollback point
dev-stack rollback --ref dev-stack/rollback/20260423T120000Z
```

Rollback restores all managed files to their pre-update state and removes intermediate rollback tags. The manifest's `rollback_ref` is cleared after a successful rollback.
