---
name: jira-ticktify
description: Break Jira tickets in the FUL project into child tickets (sub-tasks, or tickets under an epic) that are meaningful slices of work rather than micro tickets, and create them after approval. Use when the user asks to split, break down or decompose tickets, or to add sub-tasks or child tickets.
---

# Break tickets into child tickets

Tickets are in the FUL project on `$JIRA_HOST`, worked with jira-cli (`jira`). `$JIRA_API_TOKEN` and `$JIRA_HOST` are in the environment, and `jira me` prints the user's login.

## Input

The `fulbot ticktify` nushell command starts this skill with:

- a `Settings:` line: `offset` (headroom in percent), `min-days` (the least work one child may hold, 1 when not given) and `codebase` (`yes` or `no`);
- each parent ticket under a `=== KEY ===` header: its Story Points, existing child tickets, description and recent comments;
- `## Instructions`: the user's extra instructions, or `None.`

When the skill is used directly instead, take the tickets and instructions from the conversation, fetch each ticket with `jira issue view KEY --plain --comments 5`, and list existing children with `jira issue list -q "parent = KEY" --plain`.

Follow the instructions. When they point at files, briefs or links, read those first.

With `codebase=yes`, the current directory is the codebase the tickets change. Read the code each ticket touches and slice along what you find. Otherwise, explore the current directory only when the instructions point at files in it.

## Why, and how small

The team's process wants work tracked in smaller tickets than the user writes. Tickets that are too small are noise to the user and to everyone reading the board, so the job is the fewest children that make the work trackable. Never split for its own sake. Every child must:

- be a coherent slice that delivers something checkable on its own: a component, an endpoint, a migration, a screen or flow, an integration. Slice along the work, not along its steps.
- hold at least `min-days` of work before headroom, so 1 point at the very least and usually 2 or 3.
- carry its own tests, review fixes and docs. Never make separate tickets for writing tests, code review, opening a PR, QA hand-off, deploying, or "investigate", unless the investigation is days of work with a written outcome.
- have a short imperative title and a Markdown description: what this slice covers, and a "Done when" checklist.
- not repeat an existing child ticket.

Together, the children cover the parent's remaining scope. Say what, if anything, stays on the parent. Let the work decide the count, usually 2 to 4. A parent whose remaining work is under twice `min-days`, or that is already split well, gets no children: say so rather than padding.

## Types and fields

- **Parent is an Epic**: children are `Task`, `Story` or `Bug`, chosen as in the [jira-ticket skill](../jira-ticket/SKILL.md), and created with `-P PARENT`.
- **Any other parent**: children are sub-tasks. The project's sub-task type is the one with `"subtask": true` in `curl -s -u "$(jira me):$JIRA_API_TOKEN" "$JIRA_HOST/rest/api/2/issue/createmeta/FUL/issuetypes"`. Create them with `-t <that name> -P PARENT`.
- **Assignee**: the parent's (`-a`), or none when the parent has none.
- **Sprint**: sub-tasks follow their parent's sprint. Don't add epic children to a sprint unless the user asks.
- **Story points**, by the [jira-story-points skill](../jira-story-points/SKILL.md), with the `offset` setting as the headroom. Leave the parent's own Story Points alone unless the user asks.

## Before creating anything

Show one table per parent, with the children's total against the parent's points:

| # | Type | Title | Points (raw → padded) | Done when, short |

Then show each description in full. Ask which to create, and take the user's edits. Nothing is created until the user approves it.

## Creating

```bash
jira issue create --no-input --raw -t TYPE -P PARENT -s "Title" -b "$(cat <<'EOF'
Description in Markdown
EOF
)" --custom story-points=N -a ASSIGNEE
```

Read the new key from the JSON it prints, and check each one's points took as the jira-story-points skill says. When the field can't be set on a sub-task, say so once and carry on. Report each child as `KEY: Title (N pts)` under its parent, with its link `$JIRA_HOST/browse/KEY`, and report any failure exactly as it happened.
