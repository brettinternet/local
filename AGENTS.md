# Agents

- Run `mise install` and `task init` to install tools and Git hooks.
- Use existing `task` targets; run the smallest check that covers the change.
- Before committing, stage intended files and run `task check:staged`.
- Keep `.env`, `config/`, and `certs/` machine-local; tracked examples use reserved names.
- Do not start the shared broker from a worktree.
- Use `gh` for GitHub operations. Do not push or open a PR unless asked.
