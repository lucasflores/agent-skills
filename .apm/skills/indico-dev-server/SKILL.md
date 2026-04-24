---
name: indico-dev-server
description: >-
  Start, stop, and health-check the Indico development stack (web server, Chainlit
  assistant widget, Celery worker, webpack watcher). Use when the user asks to
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
~/dev2/indico/
├── env/                              # Indico venv (server, celery, webpack)
├── src/
│   ├── indico/indico.conf            # Runtime config
│   └── bin/maintenance/
│       └── build-assets.py           # Webpack builder
└── plugins_lucas/
    └── indico_assistant_plugin/
        ├── .venv/                    # Plugin venv (eval, mlflow, dev)
        └── chainlit_app/
            ├── .venv/               # Chainlit venv (isolated)
            └── app_chnlit.py        # Chainlit entry point

~/indico_assistant_plugin_demo/       # Eval framework + demo data
└── eval/                             # Eval atoms, runner, inserter, tracker
```

Three virtualenvs — do NOT mix them:

| Venv | Activate | Used for |
|---|---|---|
| Indico | `source ~/dev2/indico/env/bin/activate` | `indico run`, `indico celery worker`, `build-assets.py` |
| Chainlit | `source ~/dev2/indico/plugins_lucas/indico_assistant_plugin/chainlit_app/.venv/bin/activate` | `chainlit run` |
| Plugin/Eval | `source ~/dev2/indico/plugins_lucas/indico_assistant_plugin/.venv/bin/activate` | `python run_eval.py`, mlflow, dev tools |

Key env vars (export before running any component):

```bash
export INDICO_CONFIG='/Users/lucasflores/dev2/indico/src/indico/indico.conf'
export CHAINLIT_AUTH_SECRET='395e54f529e6d9d14467b21d1d5ed738fcaaf36ddf23fe43a8d8f89f9895894f'
```

## Components

The stack has 4 independently-launched components. Each runs in its own terminal.
Start them in the order listed (infrastructure → core → assistants → workers).

### 1. Webpack Watcher (optional)

Only needed when actively changing JS/SCSS assets. Safe to skip.

```bash
cd ~/dev2/indico/src
source ~/dev2/indico/env/bin/activate
./bin/maintenance/build-assets.py indico --dev --watch
```

### 2. Indico Web Server (required)

```bash
export INDICO_CONFIG='/Users/lucasflores/dev2/indico/src/indico/indico.conf'
source ~/dev2/indico/env/bin/activate
indico run -h localhost -q --enable-evalex
```

Listens on `http://localhost:8000`. Verify with `curl -sf http://localhost:8000/`.

### 3. Chainlit Assistant Widget

Uses its **own venv** — not the Indico env.

```bash
cd ~/dev2/indico/plugins_lucas/indico_assistant_plugin/chainlit_app
source .venv/bin/activate
export INDICO_CONFIG='/Users/lucasflores/dev2/indico/src/indico/indico.conf'
export CHAINLIT_AUTH_SECRET='395e54f529e6d9d14467b21d1d5ed738fcaaf36ddf23fe43a8d8f89f9895894f'
chainlit run app_chnlit.py --host 127.0.0.1 --port 8001 --debug
```

Listens on `http://127.0.0.1:8001`. Verify with `curl -sf http://127.0.0.1:8001/`.

### 4. Celery Worker (background tasks / attachment indexing)

```bash
source ~/dev2/indico/env/bin/activate
export INDICO_CONFIG='/Users/lucasflores/dev2/indico/src/indico/indico.conf'
indico celery worker --pool=solo
```

## Operations

### Health Check

Run the bundled script to check all components at once:

```bash
bash <skill-dir>/scripts/health_check.sh          # all components
bash <skill-dir>/scripts/health_check.sh --indico  # just indico web
```

Flags: `--all`, `--indico`, `--chainlit`, `--celery`, `--webpack`, `--postgres`, `--redis`.

### Starting the Full Stack

Open 3-4 terminals (or use background processes) and start components 2-4.
Webpack watcher (1) only if changing front-end assets.

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

# Webpack watcher
pkill -f 'build-assets.*--watch'

# All at once
pkill -f 'indico run'; pkill -f 'chainlit run'; pkill -f 'celery.*worker'; pkill -f 'build-assets.*--watch'
```

### Restarting

Kill then start the target component. For full restart, kill all, then start in order.

### Prerequisites Check

Before first start, verify infrastructure:

```bash
pg_isready          # PostgreSQL must be running
redis-cli ping      # Redis must return PONG
```

If down on macOS (Homebrew): `brew services start postgresql` / `brew services start redis`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `indico: command not found` | Activate venv: `source ~/dev2/indico/env/bin/activate` |
| `RuntimeError: Working outside of application context` | Ensure `INDICO_CONFIG` is exported |
| Port 8000 already in use | `lsof -i :8000` then kill the PID |
| Port 8001 already in use | `lsof -i :8001` then kill the PID |
| Chainlit JWT errors | Verify `CHAINLIT_AUTH_SECRET` matches the plugin settings |
| Celery connection refused | Check Redis is running: `redis-cli ping` |

## Eval / MLflow Workflow

The evaluation framework lives at `~/indico_assistant_plugin_demo/` and uses the
**Plugin/Eval venv** (`indico_assistant_plugin/.venv`).

### First-Time Setup

```bash
cd ~/dev2/indico/plugins_lucas/indico_assistant_plugin
source .venv/bin/activate
pip install mlflow>=2.12.0 "sqlalchemy>=2.0" pyyaml
```

The plugin must also be on `PYTHONPATH` (or use `--plugin-path`):

```bash
export INDICO_PLUGIN_PATH=~/dev2/indico/plugins_lucas/indico_assistant_plugin
```

### Running Evaluations

```bash
cd ~/indico_assistant_plugin_demo
source ~/dev2/indico/plugins_lucas/indico_assistant_plugin/.venv/bin/activate

# Dry run (no DB, no LLM)
python run_eval.py --dry-run

# Live run (Indico + PostgreSQL must be up)
python run_eval.py \
    --db-url postgresql://lucasflores@localhost/indico \
    --llm-api-key $HF_TOKEN \
    --plugin-path ~/dev2/indico/plugins_lucas/indico_assistant_plugin \
    --tag nightly
```

### Viewing MLflow Results

```bash
cd ~/indico_assistant_plugin_demo
mlflow ui   # opens http://127.0.0.1:5000
```

### Cleanup Only

Remove all `__eval__` tagged events without running a new suite:

```bash
python run_eval.py --cleanup-only \
    --db-url postgresql://lucasflores@localhost/indico
```
