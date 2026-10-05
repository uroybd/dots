#!/usr/bin/env nu

# Taskwarrior on-add hook.
# If the new task is tagged "jira", create a Jira issue from its description (title)
# and details (body), and store the issue key in the `jira` UDA.
#
# Hook protocol: the new task arrives as one line of JSON on stdin; we must print the
# (possibly modified) task as one line of JSON on stdout. Extra lines are shown as feedback.
# This runs outside the interactive shell, so the wrappers from jira.nu are not
# available; we call the `jira` CLI directly.

# Taskwarrior passes api:, args:, command:, rc:, data:, version: as positional args; unused.
def main [...rest: string] {
    let task = open --raw /dev/stdin | from json

    let tags = $task | get -o tags | default []
    let needs_issue = ("jira" in $tags) and (($task | get -o jira | default "") | is-empty)

    if not $needs_issue {
        print ($task | to json -r)
        return
    }

    try {
        let me = ^jira me | str trim
        let body = $task | get -o details | default ""
        let args = [
            issue create
            --raw --no-input
            --assignee $me
            -t Task
            -s $task.description
        ] | append (if ($body | is-empty) { [] } else { [-b $body] })

        let key = ^jira ...$args | from json | get key

        print ($task | upsert jira $key | to json -r)
        print $"Created Jira issue ($key)"
    } catch { |err|
        # Never block adding the task; pass it through unchanged.
        print ($task | to json -r)
        print $"Jira issue creation failed: ($err.msg)"
    }
}
