#!/usr/bin/env nu

# Taskwarrior on-modify hook.
# When the status of a task linked to Jira (has the `jira` UDA) changes, move the
# Jira issue to the matching state. Completing a task moves the issue to "Code Review"
# and, if the current git branch is the issue's FUL- branch, opens a PR for it
# (same flow as `jira issues branch review -p` in jira.nu).
#
# Taskwarrior runs hooks in the caller's working directory, so "current branch" is the
# branch of the repo the `task` command was run from.
#
# Hook protocol: stdin has two lines of JSON (original task, modified task); we must
# print the modified task as one line of JSON on stdout. Extra lines are shown as feedback.
# This runs outside the interactive shell, so we call the `jira` CLI directly.

# Jira state to move to, keyed by "<old status> -> <new status>".
# Transitions not listed here are ignored.
const TRANSITIONS = {
    "pending -> completed": "Code Review"
    "waiting -> completed": "Code Review"
    "completed -> pending": "TO DO"
}

# Open a PR for `key` if the current branch is its FUL- branch. Returns feedback lines.
def create-pr [key: string] {
    let branch = git branch --show-current | complete
    if $branch.exit_code != 0 {
        return
    }
    let branch = $branch.stdout | str trim
    if not ($branch | str starts-with "FUL-") {
        return
    }

    # Branches are named <KEY>_<user>_<summary>; only act on the task's own ticket.
    let branch_key = $branch | split row "_" | get 0
    if $branch_key != $key {
        print $"Current branch is for ($branch_key), not ($key); skipping PR."
        return
    }

    let existing = ^gh pr view --json url | complete
    if $existing.exit_code == 0 {
        print $"PR already exists: ($existing.stdout | from json | get url)"
        return
    }

    let created = ^gh pr create --fill-first | complete
    if $created.exit_code != 0 {
        print $"PR creation failed: ($created.stderr | str trim)"
        return
    }
    let url = $created.stdout | str trim | lines | last
    print $"Created PR: ($url)"

    let body = ^gh pr view --json body | from json | get body
    let ticket_url = $"($env.JIRA_HOST)/browse/($key)"
    let edited = ^gh pr edit --body $"TICKET: ($ticket_url)\n\n($body)" | complete
    if $edited.exit_code == 0 {
        print "Added ticket link to the PR"
    } else {
        print $"Could not add ticket link to the PR: ($edited.stderr | str trim)"
    }
}

# Taskwarrior passes api:, args:, command:, rc:, data:, version: as positional args; unused.
def main [...rest: string] {
    let lines = open --raw /dev/stdin | lines
    let old = $lines | get 0 | from json
    let new = $lines | get 1 | from json

    # Always hand the modified task back unchanged.
    print ($new | to json -r)

    let key = $new | get -o jira | default ""
    if ($key | is-empty) {
        return
    }

    let transition = $"($old.status) -> ($new.status)"
    let state = $TRANSITIONS | get -o $transition
    if $state == null {
        return
    }

    let res = ^jira issue move $key $state | complete
    if $res.exit_code == 0 {
        print $"Moved Jira issue ($key) to '($state)'"
    } else {
        # Never block the modification; just report.
        print $"Jira move of ($key) to '($state)' failed: ($res.stderr | str trim)"
    }

    if $new.status == "completed" {
        try { create-pr $key } catch { |err| print $"PR step failed: ($err.msg)" }
    }
}
