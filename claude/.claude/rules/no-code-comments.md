# Code without comments

When you write or modify code, **do not add comments**. This applies to every language and every kind of comment: line comments, block comments, JSDoc/docstrings, TODOs, section headers and comments that narrate what the code does.

This rule takes precedence over any project instruction (CLAUDE.md, skills, repo style guides) that allows or suggests commenting. If a project guide says "comment only what is not obvious", the result is still: zero comments.

Instead of commenting, make the code self-explanatory: descriptive names for variables, functions and resources, and named helper functions instead of annotated blocks. If something needs explaining, put it in your reply to the user, in the commit message or in the PR description, not in the file.

## Exceptions

- Functional directives that the compiler, linter or runtime interprets: `// eslint-disable-next-line`, `// @ts-expect-error`, `# type: ignore`, `# noqa`, pragmas, shebangs, license headers required by the project.
- Non-trivial regular expressions: a one-line comment stating what the pattern accepts or showing a sample input that matches. Give the pattern a descriptive name first; the comment complements the name, it does not replace it. Does not apply to simple patterns like `^\s+` or `\d+`, and does not extend to other "complex" code.
- Comments that already exist in the code: do not delete them in passing, unless the user asks or your change makes them obsolete.
- When the user explicitly asks for comments or documentation in the code.
