#!/usr/bin/env bash

[[ ${HERDR_ENV:-} == 1 && -z ${CLAUDE_HERDR_WORKER:-} ]] || exit 0

payload=$(cat)
[[ $(jq -r '.tool_input.run_in_background // false' <<<"$payload") == true ]] || exit 0
command=$(jq -r '.tool_input.command // ""' <<<"$payload")

# Coincide con "npm run test", "pnpm build", "yarn typecheck", "ng test", "vitest", "node --test", "jest", "playwright test"
long_run_pattern='(^|[[:space:];&|(])((npm|pnpm|yarn|bun)([[:space:]]+run)?[[:space:]]+(test|build|typecheck)([:[:space:]]|$)|ng[[:space:]]+(test|build)|vitest|node[[:space:]]+--test|jest([[:space:]]|$)|playwright[[:space:]]+test)'
grep -Eq "$long_run_pattern" <<<"$command" || exit 0

jq -n '{
	hookSpecificOutput: {
		hookEventName: "PreToolUse",
		permissionDecision: "deny",
		permissionDecisionReason: "Inside Herdr, tests and builds run in a visible pane so the user can watch them: split a pane with `herdr pane split --no-focus`, start the command with `herdr pane run` (tee to a log in the scratchpad and echo an end marker) and wait with `herdr pane wait-output`. See \"Long runs in a visible pane\" in the Herdr orchestrator instructions."
	}
}'
