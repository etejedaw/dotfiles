#!/usr/bin/env bash
# Hook SessionStart de Claude Code: dentro de herdr añade al contexto las instrucciones para delegar
# tareas sencillas en instancias con haiku o sonnet. Fuera de herdr, o en una de esas instancias, no hace nada.

[[ ${HERDR_ENV:-} == 1 && -z ${CLAUDE_HERDR_WORKER:-} ]] || exit 0
cat "$(dirname "${BASH_SOURCE[0]}")/herdr-orchestrator.md"
printf '\nCaller pane: %s (tab %s)\n' "${HERDR_PANE_ID:-}" "${HERDR_TAB_ID:-}"
