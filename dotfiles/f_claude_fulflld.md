@~/.config/claude-shared/CLAUDE.md

# Jira ticket workflow

The user manages tickets with nushell helpers in `~/Repos/Personal/dots/dotfiles/d_nushell/jira.nu` (and `tasks.nu`). Run them through `nu -l -c '<command>'` so the config loads.

1. **Start a ticket:** `nu -l -c 'jira issues branch create FUL-XXXX'`. It switches to `main`, pulls, and creates the branch `FUL-XXXX_roy_<slugified-summary>` (50 chars max). Don't name ticket branches by hand.
2. **Work on it** as usual (repo CLAUDE.md rules for tests, formatting, and commits).
3. **Open the PR:** push the branch (`git push -u origin HEAD`), then run `nu -l -c 'jira issues branch review -p'`. It moves the ticket to "Code Review", runs `gh pr create --fill-first`, and adds the ticket link to the top of the PR body. Then add more description with `gh pr edit --body ...`, keeping the `TICKET: ...` line first.

Useful lookups: `jira epic list <EPIC> -s~Done --plain` (open tickets in an epic), `jira issue view FUL-XXXX --plain`.
