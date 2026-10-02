# Source this (don't run it) before starting the Indico web server or the Celery worker:
#   source <skill-dir>/scripts/stack-env.sh
# Exports the variables both need on every start, and unsets PYTHONPATH so the main checkout runs.
# Secrets are read from mode-600 files and never printed. Returns 1 if a secret file is missing or
# empty, so a start never goes ahead with an empty secret.
for f in ~/.config/indico-assistant/chainlit_auth.secret ~/.config/indico-assistant/connector.key; do
  [ -s "$f" ] || { echo "stack-env: $f is missing or empty" >&2; return 1; }
done
export INDICO_CONFIG="$HOME/indico-assistant/instance/indico.conf"
export ASSISTANT_NL2SQL_DATABASE_URI='postgresql://indico_assistant_ro@/indico'  # NL2SQL read-only role
export CHAINLIT_AUTH_SECRET="$(cat ~/.config/indico-assistant/chainlit_auth.secret)"
export INDICO_ASSISTANT_CONNECTOR_KEY="$(cat ~/.config/indico-assistant/connector.key)"
export VC_TEAMS_FAKE_GRAPH=1  # Teams in fake mode; real mode only when Lucas asks (see SKILL.md)
unset PYTHONPATH              # a live window from a worktree exports it after sourcing this
