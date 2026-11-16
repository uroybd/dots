---
name: jira-ticket
description: Create Jira tickets in the FUL project with jira-cli, with story points, type and description. Use when the user asks to create, file or open Jira tickets, turn a list of work into tickets, or create a self-assigned ticket.
---

# Jira ticket creation

Tickets go to the FUL project on `$JIRA_HOST` (board "FUL board", id 378) through jira-cli (`jira`). `$JIRA_API_TOKEN` and `$JIRA_HOST` are already in the environment, and `jira me` prints the user's login.

## 1. Draft first, create after approval

Creating tickets is visible to the team, so never create before the user approves. Show a draft table for every ticket:

| # | Type | Title | Points | Assignee / sprint | Description (short) |

- **Type**: one of `Task`, `Bug`, `Story`, `Feature Request` (the same choices as the user's own create command). Use `Bug` for defects, `Story` for user-facing features, `Task` otherwise, unless the user says otherwise.
- **Title**: short and imperative, with no product prefix unless the user asks for one.
- **Points**: always a number, sized with 20% headroom, see below.
- **Description**: a problem statement and "done when" acceptance criteria, in Markdown (jira-cli converts it).

Apply the user's edits, then create every approved ticket.

## 2. Story points

The board estimates with **Story Points** (`customfield_10035`, jira-cli name `story-points`). Do not use "Story point estimate" (`customfield_10016`). The value must be numeric, one of:

| Points | Size | Work |
|---|---|---|
| 1 | small | ≤ 1 day |
| 2 | medium | 1–2 days |
| 3 | large | 2–5 days |
| 5 | xlarge | 1–2 weeks |

**Keep 20% headroom.** Estimate the work first, add 20% for review, testing and the unexpected, then pick the size that fits the padded figure. For example, 1.8 days of work becomes about 2.2 days, which is 3 points, not 2. Work that only fits a size without the headroom goes to the next size up. In the draft, give the raw and padded estimates beside the points (`1.8d → 2.2d`), so the user can see why the size was chosen.

Anything bigger than 5 after the headroom should be split into several tickets, or made an epic with child tickets. Suggest the split in the draft.

## 3. Create

### Self-assigned tickets

When the user says the ticket is self-assigned, "assign to me" or "for me", follow their `jira me issues create` nushell command (defined in `~/Library/Application Support/nushell/jira.nu`). That command prompts for type and summary interactively, so it can't run from a non-interactive shell. Run the same steps directly instead:

```bash
key=$(jira issue create --no-input --raw \
  --assignee "$(jira me)" \
  -t "Task" -s "Title here" \
  -b "$(cat <<'EOF'
Description in Markdown
EOF
)" \
  --custom story-points=2 | python3 -c 'import json,sys; print(json.load(sys.stdin)["key"])')

sprint=$(jira sprint list --state active --table --plain --columns ID | sed -n 2p)
jira sprint add "$sprint" "$key"
```

- The ticket is added to the current active sprint, the same as the nushell command's default. Skip `jira sprint add` only when the user says no sprint (the command's `--no-sprint`/`-x`).
- When the user also wants a branch (the command's `-g`), the branch name is `<KEY>_roy_<summary slug>`, where the slug is the summary lowercased with non-word runs turned into `-`, and the whole name is cut to 50 characters with trailing `-` trimmed. Create it from an up-to-date `main`: `git switch main && git pull && git switch -c <branch>`.

### Other tickets

Use the same `jira issue create` call without `--assignee`, and don't add the ticket to a sprint unless the user asks.

### Optional fields

- Epic or parent: `-P FUL-123`
- Labels: `-l label` (repeatable)
- Priority: `-y High`

## 4. Verify and report

After creating, check that the points were set, because a wrong custom-field name fails silently:

```bash
curl -s -u "$(jira me):$JIRA_API_TOKEN" "$JIRA_HOST/rest/api/2/issue/$key?fields=customfield_10035,assignee,summary"
```

If `customfield_10035` is null, set it with `jira issue edit "$key" --no-input --custom story-points=N` and check again.

Report each ticket as `KEY: Title (N pts)` with its link `$JIRA_HOST/browse/KEY`. Say which ones went into the sprint, and report any failure exactly as it happened.
