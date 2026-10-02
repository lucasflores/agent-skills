---
name: indico-dev-server
description: >-
  Start, stop, and health-check the Indico development stack (web server, Chainlit
  assistant widget, Celery worker). Use when the user asks to
  "start indico", "run the dev server", "launch the assistant", "check if indico
  is running", "kill indico", "restart indico", "start chainlit", "start celery",
  "health check", or anything about managing the local Indico development
  environment. Also applies when a task requires Indico to be running first
  (e.g. eval framework, DB insertion, manual QA).
---

# Indico Dev Server

Manage the local Indico development stack on macOS.

## Environment Layout

```
~/indico-assistant/
├── instance/
│   ├── env/                          # Indico venv (server, celery, plugins installed editable)
│   ├── indico.conf                   # Runtime config
│   ├── data/                         # Attachment archive, cache, logs (the DB references these files)
│   └── backups/                      # pg_dump snapshots + old env pip freeze
├── plugin/                           # indico_assistant plugin (git: lucasflores/indico-assistant)
│   └── chainlit_app/
│       ├── .venv/                    # Chainlit venv (isolated)
│       └── app_chnlit.py             # Chainlit entry point
└── eval/                             # indico-assistant-eval (EvalAtoms, runner, inserter, tracker)
    └── .venv/                        # Eval venv (uv)

~/zoom_bot_plugin/                    # Zoom bot plugin, installed editable into instance/env
```

Indico itself is installed from PyPI (currently 3.3.13); there is no Indico source checkout.

Three virtualenvs — do NOT mix them:

| Venv | Activate | Used for |
|---|---|---|
| Indico | `source ~/indico-assistant/instance/env/bin/activate` | `indico run`, `indico celery worker`, `indico db`, plugin tests |
| Chainlit | `source ~/indico-assistant/plugin/chainlit_app/.venv/bin/activate` | `chainlit run` |
| Eval | `source ~/indico-assistant/eval/.venv/bin/activate` | `indico-assistant-eval`, mlflow |

Key env vars. The **web server and the Celery worker need all of these on every start**. They are set in
one place, `scripts/stack-env.sh`, which both start blocks source:

```bash
source <skill-dir>/scripts/stack-env.sh
```

It exports `INDICO_CONFIG`, `ASSISTANT_NL2SQL_DATABASE_URI`, `CHAINLIT_AUTH_SECRET`,
`INDICO_ASSISTANT_CONNECTOR_KEY` and `VC_TEAMS_FAKE_GRAPH=1`, and unsets `PYTHONPATH`. It returns 1, and exports
nothing, if a secret file is missing or empty. Add a new required variable there, not to a start block.

What each one is for:

- **`CHAINLIT_AUTH_SECRET`**: the plugin's `chainlit_auth_secret` setting is empty, so Indico reads this env var.
  Without it on the web server, the chat panel gets 401s. It is read from
  `~/.config/indico-assistant/chainlit_auth.secret` (mode 600). This skill is published, so never write the value
  into it, and never echo it.
- **`INDICO_ASSISTANT_CONNECTOR_KEY`**: the GitHub connector (spec 023) is on, with a real app, and Lucas (user 1)
  is really connected. The key file `~/.config/indico-assistant/connector.key` is mode 600, and `stack-env.sh`
  reads it; never echo it, log it or write it into a file or a skill. Without it, GitHub breaks for connected
  users.
- **`VC_TEAMS_FAKE_GRAPH=1`**: Microsoft Graph is simulated, and the dev stack creates no real Teams meetings.
  Real mode, only when Lucas asks: drop the flag and `source ~/indico-assistant/instance/teams.env` (it sets
  `VC_TEAMS_CLIENT_ID`, `VC_TEAMS_CLIENT_SECRET` and `VC_TEAMS_TENANT_ID`). Then chat actions create real
  meetings on the tenant.
- **`ASSISTANT_NL2SQL_DATABASE_URI`**: without it, event-data questions fail with "The assistant cannot query
  the database: ASSISTANT_NL2SQL_DATABASE_URI is not set". The role and its row-security policies come from
  `indico assistant nl2sql-db-sql | psql -d indico -v ON_ERROR_STOP=1`. Re-run that after changing
  `available_tables.yaml`, and check it with `pytest tests/integration/nl2sql/test_readonly_role.py` in the plugin.

Chainlit needs only `INDICO_CONFIG` and `CHAINLIT_AUTH_SECRET`.

## Components

The stack has 3 independently-launched components. Each runs in its own terminal.
Start them in the order listed (core → assistant → worker).

### 1. Indico Web Server (required)

```bash
source <skill-dir>/scripts/stack-env.sh
source ~/indico-assistant/instance/env/bin/activate
cd ~ && indico run -h 127.0.0.1 -q --enable-evalex
```

Listens on `http://127.0.0.1:8000` — browse there, NOT `localhost`. Verify with `curl -sf http://127.0.0.1:8000/`.
Plugin health: `curl -s http://127.0.0.1:8000/api/assistant/health`.

**Host must be 127.0.0.1 (same as Chainlit and `BASE_URL`):** `indico run -h localhost` makes Indico
accept only `http://localhost:8000`, and browsers treat localhost and 127.0.0.1 as different sites, so
Chainlit's SameSite=Lax login cookie (set on 127.0.0.1:8001) is not sent from a localhost page: the widget
shows "Could not reach the server" and chainlit.log says "Authentication failed in websocket connect".

### 2. Chainlit Assistant Widget

Uses its **own venv** — not the Indico env.

```bash
cd ~/indico-assistant/plugin/chainlit_app
source .venv/bin/activate
export INDICO_CONFIG='/Users/lucasflores/indico-assistant/instance/indico.conf'
export CHAINLIT_AUTH_SECRET="$(cat ~/.config/indico-assistant/chainlit_auth.secret)"
chainlit run app_chnlit.py --host 127.0.0.1 --port 8001 --debug
```

Listens on `http://127.0.0.1:8001`. Verify with `curl -sf http://127.0.0.1:8001/`.
Since spec 020 it is Chainlit's full app (2.12.0) in Indico's panel. Every request needs the session cookie:
the app sets `CHAINLIT_CUSTOM_AUTH=true` itself, and `curl -s http://127.0.0.1:8001/auth/config` shows
`"requireLogin":true`. Restart Chainlit after changing `.chainlit/config.toml`, and restart `indico run` after
changing the panel's JS or CSS (its version hash is cached).

### 3. Celery Worker (chat answers, background tasks, attachment indexing) — required for chat

```bash
source <skill-dir>/scripts/stack-env.sh
source ~/indico-assistant/instance/env/bin/activate
cd ~ && indico celery worker --pool=solo -Q celery,assistant,assistant_bulk,teams_notes
```

**Queues:** chat answers and confirmed chat-action plans run on `assistant`, and attachment indexing and the
nightly retention run on `assistant_bulk`. Teams meeting notes run on `teams_notes`. POST /api/assistant/chat
returns 202 + `job_id`, and the client polls `/api/assistant/chat/jobs/<job_id>`. Without a worker on
`assistant`, chat stays "pending" until Chainlit gives up (3 min).

**Restarts:** the worker does not reload code, so restart it after plugin changes.

## Operations

### Health Check

Run the bundled script to check all components at once:

```bash
bash <skill-dir>/scripts/health_check.sh          # all components
bash <skill-dir>/scripts/health_check.sh --indico  # just indico web
```

Flags: `--all`, `--indico`, `--chainlit`, `--celery`, `--postgres`, `--redis`. It exits 1 if any check fails.

### Calling Indico with curl

Logged-in requests need the session cookie. On this http instance it is named `indico_session_http`, not
`indico_session`: Indico adds `_http` when the instance is not on https. Mint a session for a user id (prints the
cookie value):

```bash
cd ~/indico-assistant/plugin
SID=$(INDICO_CONFIG=~/indico-assistant/instance/indico.conf ../instance/env/bin/python tests/browser/mint_session.py 1)
curl -s -b "indico_session_http=$SID" http://127.0.0.1:8000/api/assistant/health
```

### Starting the Full Stack

Open 3 terminals (or use background processes) and start components 1-3.

When launching via `run_in_terminal`, use `isBackground=true` for each component
since they are long-running processes. Example sequence:

1. Start Indico web server (background terminal)
2. Start Chainlit (background terminal)
3. Start Celery worker (background terminal)
4. Run health check (foreground, wait for output)

### Stopping Components

Kill by process pattern:

```bash
# Indico server
pkill -f 'indico run'

# Chainlit
pkill -f 'chainlit run'

# Celery worker
pkill -f 'celery.*worker'

# All at once
pkill -f 'indico run'; pkill -f 'chainlit run'; pkill -f 'celery.*worker'
```

### Restarting

Kill then start the target component. For full restart, kill all, then start in order.

After any restart, check that each process has the variables it needs. The command below prints the names of
the ones set to a non-empty value, the code path and `PYTHONPATH`, never a secret's value. The bracketed first
letters keep `pgrep` from matching the shell running the loop. The `case` skips any shell that launched a
component (`zsh -c … chainlit run …`), whatever its path:

```bash
for p in $(pgrep -f "[i]ndico run|[c]elery.*worker|[c]hainlit run"); do
  case "$(ps -o comm= -p $p)" in *sh) continue;; esac
  env=$(ps eww -o command= -p $p | tr ' ' '\n')
  printf '%s %s cwd=%s PYTHONPATH=[%s] vars: %s\n' "$p" "$(ps -o command= -p $p | sed 's|.*/bin/||' | cut -c1-24)" \
    "$(lsof -a -p $p -d cwd -Fn | grep ^n | cut -c2-)" "$(echo "$env" | grep ^PYTHONPATH= | cut -c12-)" \
    "$(echo "$env" | grep -oE '^(CHAINLIT_AUTH_SECRET|INDICO_ASSISTANT_CONNECTOR_KEY|VC_TEAMS_FAKE_GRAPH|ASSISTANT_NL2SQL_DATABASE_URI)=.' | cut -d= -f1 | tr '\n' ' ')"
done
```

On the web server and the worker, expect all four names, an empty `PYTHONPATH`, and the main checkout on
`origin/main` (`git -C ~/indico-assistant/plugin fetch && git -C ~/indico-assistant/plugin status -sb`). A name
missing here is a variable that is unset or empty.

### Live checks from a worktree (the shared stack)

Other sessions use this stack. The plugin is installed editable from `~/indico-assistant/plugin`, so a feature
worktree (`~/indico-assistant/plugin-<x>`) is not what runs. To run a branch for a live window:

1. **Warn first.** Tell the other sessions on Indico before the window, and again after it (`ListAgents`, then
   `SendMessage`). Don't switch the stack while someone else's window is open. Run the variable check under
   "Restarting" first: a non-empty `PYTHONPATH` on the web server or the worker means a window is open. Never
   `grep` the raw `ps eww` output, which prints every variable's value, secrets included.
2. **Back up, then migrate.** A branch with a new migration needs a `pg_dump` first (see "Upgrading" below). Then
   run `PYTHONPATH=<worktree> indico db --plugin assistant upgrade`.
3. **Switch.** Start the web server and the worker as above, with `export PYTHONPATH=<worktree>` after
   `stack-env.sh` (which unsets it). It wins over the editable install. Chainlit: run it from
   `<worktree>/chainlit_app` with `~/indico-assistant/plugin/chainlit_app/.venv/bin/chainlit`, after copying
   `chainlit_app/.env` (it is gitignored) into the worktree.
4. **Restore.** Count what the rollback drops. Then, before restarting anything from main, roll back any
   migration main doesn't have yet, using the worktree's code: the revision exists only in the branch, so main's
   code cannot find it.
   `printf 'YES\n' | PYTHONPATH=<worktree> indico db --plugin assistant downgrade <previous>`.
   Restart all three from the main checkout: `stack-env.sh` unsets `PYTHONPATH`. Run the variable check above,
   and tell the other sessions.

Tests need no stack: `python -m pytest`, run from the worktree, imports the worktree's code.

### Prerequisites Check

Before first start, verify infrastructure:

```bash
pg_isready          # PostgreSQL (Homebrew, v14) must be running
redis-cli ping      # Redis must return PONG
```

If down on macOS (Homebrew): `brew services start postgresql` / `brew services start redis`.

### Upgrading Indico / Migrations

Back up first, then run core and plugin migrations:

```bash
pg_dump -Fc -d indico -f ~/indico-assistant/instance/backups/indico_$(date +%F-%H%M%S).dump  # time too: a second dump that day must not replace the first
source ~/indico-assistant/instance/env/bin/activate
export INDICO_CONFIG='/Users/lucasflores/indico-assistant/instance/indico.conf'
indico db upgrade
indico db --all-plugins upgrade
```

### Rebuilding the Indico venv

These pins are what the current env runs. It was rebuilt for arm64 after the move from an Intel Mac, where
newer torch / llvmlite / cryptography releases had no x86_64 wheels. Newer versions are untested here. Save
the working versions first, so a failed rebuild can be undone:

```bash
cd ~/indico-assistant/instance
uv pip freeze --python env/bin/python > backups/env-freeze-$(date +%F-%H%M%S).txt
uv venv --seed --python ~/.pyenv/versions/3.12.9/bin/python env
uv pip install --python env/bin/python \
  'indico==3.3.13' indico-plugin-payment-manual indico-plugin-payment-paypal indico-plugin-vc-zoom \
  'torch==2.2.2' 'numpy<2' 'sentence-transformers==4.0.1' 'transformers==4.50.3' \
  'llvmlite==0.44.0' 'numba==0.61.2' watchfiles \
  freezegun pytest-asyncio pytest-cov pytest-localserver pytest-mock pytest-redis pytest-snapshot responses \
  -e '../plugin[dev]' -e ~/zoom_bot_plugin
```

Chainlit venv: `uv pip install --python .venv/bin/python -r requirements.txt 'cryptography==50.0.0'`.

### Plugin Tests

```bash
cd ~/indico-assistant/plugin
INDICO_CONFIG=~/indico-assistant/instance/indico.conf \
  ../instance/env/bin/python -m pytest tests/unit tests/contract -q
```

Keep `--basetemp` short (the pyproject default `/tmp/pytest` is fine): Indico's
pytest-redis fixture fails if the Unix socket path exceeds 104 characters.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `indico: command not found` | Activate venv: `source ~/indico-assistant/instance/env/bin/activate` |
| `RuntimeError: Working outside of application context` | Ensure `INDICO_CONFIG` is exported |
| `ModuleNotFoundError: watchfiles` on `indico run` | `uv pip install --python ~/indico-assistant/instance/env/bin/python watchfiles` |
| `No module named 'freezegun'` when running pytest | Install the test deps listed under "Rebuilding the Indico venv" |
| `UnixSocketTooLong` in pytest | Use a short `--basetemp` (e.g. `/tmp/pytest`) |
| Port 8000 already in use | `lsof -i :8000` then kill the PID |
| Port 8001 already in use | `lsof -i :8001` then kill the PID |
| Chainlit JWT errors | Verify `CHAINLIT_AUTH_SECRET` matches the plugin settings |
| Chat panel gets 401s right after a restart | The web server was started without `CHAINLIT_AUTH_SECRET` (the plugin setting is empty) |
| GitHub broken for connected users | The web server or worker was started without `INDICO_ASSISTANT_CONNECTOR_KEY` |
| A chat action created a real Teams meeting | `VC_TEAMS_FAKE_GRAPH=1` was missing, and `teams.env` was loaded: restart in fake mode unless Lucas asked for real |
| Chat stays "pending", or notes are never made | The worker isn't on all four queues: `-Q celery,assistant,assistant_bulk,teams_notes` |
| Celery connection refused | Check Redis is running: `redis-cli ping` |

## Eval / MLflow Workflow

The evaluation framework lives at `~/indico-assistant/eval/` and has its **own
uv venv**. It imports the plugin's code directly (headless, no Flask).

### First-Time Setup

```bash
cd ~/indico-assistant/eval
uv sync --extra dev
```

The plugin path must be set explicitly (the built-in fallback path is wrong):

```bash
export INDICO_PLUGIN_PATH=~/indico-assistant/plugin
```

### Running Evaluations

```bash
cd ~/indico-assistant/eval
source .venv/bin/activate

# Dry run (no DB, no LLM)
indico-assistant-eval --dry-run

# Live run (Indico + PostgreSQL must be up)
indico-assistant-eval \
    --db-url postgresql://lucasflores@localhost/indico \
    --llm-provider openai \
    --llm-base-url https://router.huggingface.co/v1 \
    --llm-model meta-llama/Llama-3.3-70B-Instruct \
    --llm-api-key $HF_TOKEN \
    --plugin-path ~/indico-assistant/plugin \
    --tag nightly
```

Other flags: `--dimensions`, `--atoms-per-dim`, `--save-suite`, `--report`,
`--experiment`, `--tracking-uri`, `--schema-yaml`, `--no-cleanup`.

Known issue: fixture dates are anchored at 2026-04-02 while the plugin injects
the real current date into its prompts, so the `time_range` and
`cross_event_count` atoms fail regardless of model until the fixtures are re-anchored.

### Viewing MLflow Results

```bash
cd ~/indico-assistant/eval
.venv/bin/mlflow ui   # opens http://127.0.0.1:5000
```

### Cleanup Only

Remove all `__eval__` tagged events without running a new suite:

```bash
indico-assistant-eval --cleanup-only \
    --db-url postgresql://lucasflores@localhost/indico
```
