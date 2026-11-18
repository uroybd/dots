---
name: jira-story-points
description: The FUL board's story point convention (scale, headroom, the field to set and how to check it) and how to estimate tickets by it. Use when estimating, sizing or pointing Jira tickets, or setting their story points.
---

# Story points

The board estimates with **Story Points** (`customfield_10035`, jira-cli name `story-points`). Do not use "Story point estimate" (`customfield_10016`). The value must be numeric, one of:

| Points | Size | Work |
|---|---|---|
| 1 | small | ≤ 1 day |
| 2 | medium | 1–2 days |
| 3 | large | 2–5 days |
| 5 | xlarge | 1–2 weeks |

The `fulbot` nushell commands size with the same table (`STORY_POINT_SIZES` in `jira.nu`), so change both together.

## Sizing

1. Estimate the working days the work itself takes (a week is 5), on its own merits and on the same footing as the other tickets in the batch.
2. **Add headroom**, 20% unless the user or the command gives another `offset`, for review, testing and the unexpected.
3. Take the smallest size the padded figure fits. For example, 1.8 days of work becomes about 2.2 days, which is 3 points, not 2. Work that only fits a size without the headroom goes to the next size up.

Show the raw and padded estimates beside the points (`1.8d → 2.2d`), so the user can see why the size was chosen. Anything bigger than 5 after the headroom should be split into several tickets, or made an epic with child tickets. Suggest the split instead of setting a number.

When the current directory is the codebase the tickets change and the user or the command asks you to use it, find and read the code each ticket would touch before estimating, and change nothing. Size the work from what you find: how many places change, existing patterns to reuse, tests to add or update.

## Raw estimates only

`fulbot guess story-point` asks with `raw only`: the tickets come on stdin, each under a `=== KEY ===` header, and it adds the headroom and works out the points itself. Give one estimate per ticket, through the structured output only:

- `raw_days`: step 1 alone, with no headroom, buffer or padding;
- `reason`: one or two sentences on what drives the size, mentioning what you found in the code when you read it.

## Setting and checking

```bash
jira issue edit KEY --no-input --custom story-points=N
```

A wrong custom-field name fails silently, so check every change took:

```bash
curl -s -u "$(jira me):$JIRA_API_TOKEN" "$JIRA_HOST/rest/api/2/issue/KEY?fields=customfield_10035,summary"
```

If `customfield_10035` is null or wrong, set it again and check again.
