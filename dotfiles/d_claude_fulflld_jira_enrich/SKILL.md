---
name: jira-enrich
description: Rewrite existing Jira tickets in the FUL project into well-formed ones (clear summary, full description with acceptance criteria, story points), from the tickets plus any brief, doc or instructions the user points at, and update them after approval. Use when the user asks to enrich, flesh out, clean up, groom or refine tickets, or to fill in their descriptions or story points.
---

# Enrich Jira tickets

Tickets are in the FUL project on `$JIRA_HOST`, worked with jira-cli (`jira`). `$JIRA_API_TOKEN` and `$JIRA_HOST` are in the environment, and `jira me` prints the user's login.

## Input

The `fulbot enrich` nushell command starts this skill with:

- a `Settings:` line: `offset` (headroom in percent) and `codebase` (`yes` or `no`);
- each ticket under a `=== KEY ===` header: its Story Points, child tickets, description and recent comments;
- `## Instructions`: the user's extra instructions, or `None.`

When the skill is used directly instead, take the tickets and instructions from the conversation, and fetch each ticket with `jira issue view KEY --plain --comments 5`.

Follow the instructions. When they point at files, briefs or links, read those first, because they are the main source for the rewrite.

With `codebase=yes`, the current directory is the codebase the tickets change. Read the code each ticket touches before writing anything, and ground the description and size in what you find: the files and places that change, patterns to reuse, tests to add or update. Otherwise, explore the current directory only when the instructions point at files in it.

## What to work out per ticket

- **Summary**: keep it unless it is unclear or wrong. Short and imperative, with no product prefix.
- **Description**, in Markdown (jira-cli converts it): the context or problem, what to do (scope, and approach where it is known), what is out of scope when that helps, and a "Done when" checklist of acceptance criteria. Keep every fact, link, decision and name from the current description and comments: rewrite and add, never drop. Don't invent requirements. Anything you can't ground in the ticket, the instructions, the files or the code goes under "Open questions".
- **Story points**, by the [jira-story-points skill](../jira-story-points/SKILL.md), with the `offset` setting as the headroom.

## Before changing anything

Show one table, a row per ticket:

| Ticket | Summary (old → new, or same) | Points (old → new, raw → padded) | What changes in the description, in one line |

Then show each new description in full under its ticket key. Ask which tickets to apply. Take the user's edits, and show the result again if it changed much. Nothing goes to Jira until the user approves it, and only the tickets they approve.

## Applying

```bash
jira issue edit KEY --no-input -s "Summary" -b "$(cat <<'EOF'
Description in Markdown
EOF
)" --custom story-points=N
```

Pass only the fields that change, and check the points and summary took as the jira-story-points skill says. Report each ticket as `KEY: what changed` with its link `$JIRA_HOST/browse/KEY`, and report any failure exactly as it happened.
