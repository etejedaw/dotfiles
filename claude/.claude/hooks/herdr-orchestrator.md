# Herdr orchestrator mode

This session runs inside a Herdr pane. Act as the orchestrator: keep planning, decisions, conversation with the user and the edits that tie the task together, and delegate low-effort, well-scoped work to cheaper Claude instances in sibling Herdr panes. This is standing authorization from the user to use Herdr and the `herdr` skill for delegation; load the `herdr` skill before the first `herdr` command. In this mode, delegate through Herdr panes instead of the built-in Agent tool, unless the user asks for a subagent.

## When to delegate

- Delegate when the work would fill your context with material you only need a conclusion from: broad searches across the codebase, reading and summarizing long files, logs or docs, fetching library docs, inventories, running tests or linters and summarizing failures.
- Always delegate when the user asks for it explicitly.
- Do it yourself when it is a one-shot action (a single grep, reading one known file, `git status`): starting an instance costs more than the action. Also keep anything that needs this conversation's context or that the user must see you reason through.
- Independent subtasks can run in parallel workers; send every prompt first and then wait for each one.

## Which model

- `haiku`: searches, locating files and usages, summaries, docs lookups, running a command and reporting its result.
- `sonnet` with `--effort medium`: tasks that need judgment but have a clear scope, such as tracing a bug across several files, reviewing a diff for a specific concern, or writing a self-contained change or tests in files you will not touch at the same time.
- Anything harder stays with you. Workers are read-only unless the prompt says which files they may edit.

## How to run a worker

1. Split a sibling pane in the current tab with `--no-focus`, `--cwd "$PWD"` and `--env CLAUDE_HERDR_WORKER=1` (this keeps workers from delegating in turn). The first worker splits the caller pane following the skill's geometry rule; later workers split the previous worker's pane `down`, so they stack in one column and the user's pane keeps its size. Keep at most 3 workers alive.
2. Start it with `herdr agent start <name> --kind claude --pane <id> -- --model haiku --add-dir <results-dir>` (add `--effort medium` for sonnet), where `<results-dir>` is a `herdr` folder inside your scratchpad directory. Use short descriptive names such as `search-auth`.
3. Send a self-contained prompt with `herdr agent prompt <name> "..." --wait --timeout 300000`. The worker knows nothing of this conversation: give it paths, the goal, what to return and a length limit. End every prompt with: "Write your full answer as Markdown to `<results-dir>/<name>.md` and reply only with that path." The Claude TUI runs in fullscreen, so reading the pane cannot recover long answers; read the file instead.
4. If the wait ends in `blocked`, inspect it with `herdr agent read` and resolve it; if it is a decision that belongs to the user, ask the user. If it times out, wait again before giving up.

## Long runs in a visible pane

Full test suites, builds and other long commands run in their own Herdr pane, not in a background Bash call, so the user can watch them live. No Claude instance is needed for this: it is a plain shell pane.

1. Split a sibling pane with `herdr pane split --current --direction right --cwd "$PWD" --no-focus` (or split your last pane `down` if one is already open) and read its ID from `.result.pane.pane_id`.
2. Run the command with an end marker and a log: `herdr pane run <id> "<command> 2>&1 | tee <scratchpad>/<name>.log; echo RUN_DONE_EXIT_\$pipestatus[1]"` (zsh; use `\${PIPESTATUS[0]}` in bash).
3. Wait with `herdr pane wait-output <id> --regex "RUN_DONE_EXIT_[0-9]+" --timeout <ms>`; if the wait itself may outlast the Bash timeout, run only that wait in the background. Read the summary from the log, not from the pane.
4. Never start a second run of a suite that shares a resource (for example a single test database) while one is still going.
5. Close the pane when you have the result, unless the user wants to keep it.

A PreToolUse hook blocks background Bash calls that run tests or builds while inside Herdr and points back here.

## Cleanup

- Keep a list of the pane IDs you created. Close each one with `herdr pane close <pane_id>` as soon as you have its result and no follow-up is planned; reuse a live worker for follow-ups instead of starting a new one.
- Before your final answer for a task, close every worker you created. Never close panes you did not create.
