# Whether `token` can be part of a task filter (id, id range, uuid, +tag/-tag or attribute:value).
def is-filter-token [token: string] {
    $token =~ '^(\d+(-\d+)?|[0-9a-f]{8}(-[0-9a-f]{4}){0,4}|[+-]\w+|\w+:\S*)$'
}

# `task fail <filter>`: mark the matching tasks `outcome:failed`, then delete them.
# Matches are resolved to uuids first, since deleting a task frees its id.
def task-fail [filter: list<string>] {
    if ($filter | is-empty) {
        error make { msg: "Give a task filter (ids, uuids, tags...); refusing to fail everything." }
    }
    let uuids = ^task ...$filter export | from json | get uuid
    if ($uuids | is-empty) {
        print -e "No matching tasks."
        return
    }
    for uuid in $uuids {
        ^task rc.confirmation=off $uuid modify outcome:failed
        ^task rc.confirmation=off $uuid delete
    }
}

# `task create-branch <id>`: create and switch to a git branch for a single task, off a fresh main.
# Named like the jira tooling (`<KEY>_roy_<summary>`, see `create-branch-name` in jira.nu) when the task
# has a `jira` key; otherwise just the slugified description.
def task-create-branch [filter: list<string>] {
    if ($filter | length) != 1 {
        error make { msg: "Give exactly one task id or uuid." }
    }
    let tasks = ^task rc.hooks=off rc.verbose=nothing ...$filter export | from json
    if ($tasks | length) != 1 {
        error make { msg: $"Expected exactly one matching task, found ($tasks | length)." }
    }
    let t = $tasks | first
    let key = $t | get -o jira | default ""
    let branch_name = if ($key | is-empty) {
        $t.description
        | str replace -a -r '\W+' "-"
        | str trim -c "-"
        | str lowercase
        | str substring 0..50
        | str trim -c "-"
    } else {
        create-branch-name $key $t.description
    }
    print $"Creating git branch: ($branch_name)"
    ^git switch main
    ^git pull
    ^git switch -c $branch_name
}

# Use the external (carapace) completer; a custom command is otherwise completed from its signature only.
@complete external
def --wrapped task [...rest] {
    with-env { AWS_ENDPOINT_URL: "{{ TW_BUCKET }}" } {
        # An explicit `task sync` is just run as-is, without the pre/post sync.
        if $rest == ["sync"] {
            ^task sync
            return
        }
        ^task sync o> /dev/null
        try {
          # `fail` is not a taskwarrior command: accept `task fail <filter>` and `task <filter> fail`.
          if ($rest | first | default "") == "fail" {
            task-fail ($rest | skip 1)
          } else if ($rest | last | default "") == "fail" and ($rest | drop 1 | all { is-filter-token $in }) {
            task-fail ($rest | drop 1)
          } else if ($rest | first | default "") == "create-branch" {
            task-create-branch ($rest | skip 1)
          } else if ($rest | last | default "") == "create-branch" and ($rest | drop 1 | all { is-filter-token $in }) {
            task-create-branch ($rest | drop 1)
          } else {
            ^task ...$rest
          }
        } catch { |err|
          print -e $"(ansi red_bold)Error executing task command:(ansi reset)\n($err)"
        }
        ^task sync o> /dev/null
    }
}

# Create Jira issues for existing taskwarrior tasks, store the key in their `jira` UDA and tag them +jira.
# Usage: jira tw import [--epic <EPIC-KEY>] <taskid>...
#   e.g. `jira tw import 5`, `jira tw import -e FUL-12 5 7` or `jira tw import +work` (any task filter)
# With --epic, each created issue is also added to that epic.
# Tasks that already have a jira key (or are completed/deleted) are skipped.
def "jira tw import" [--epic(-e): string, ...filter: string] {
    if ($filter | is-empty) {
        error make { msg: "Give a task filter (ids, uuids, tags...); refusing to import everything." }
    }

    with-env { AWS_ENDPOINT_URL: "{{ TW_BUCKET }}" } {
        ^task sync o> /dev/null

        # Hooks are off so the on-add/on-modify jira hooks don't interfere.
        let tw = [rc.hooks=off rc.verbose=nothing rc.confirmation=no]
        let tasks = ^task ...$tw ...$filter export | from json
        let todo = $tasks | where {|t|
            ($t.status in [pending waiting]) and (($t | get -o jira | default "") | is-empty)
        }

        let skipped = ($tasks | length) - ($todo | length)
        if $skipped > 0 {
            print $"Skipping ($skipped) task\(s\) that are already linked or not open."
        }

        let me = ^jira me | str trim
        let imported = $todo | each {|t|
            let body = $t | get -o details | default ""
            let args = [issue create --raw --no-input --assignee $me -t Task -s $t.description]
                | append (if ($body | is-empty) { [] } else { [-b $body] })
            let res = ^jira ...$args | complete
            if $res.exit_code != 0 {
                print -e $"(ansi red_bold)Failed to create issue for '($t.description)':(ansi reset) ($res.stderr | str trim)"
                return null
            }
            let key = $res.stdout | from json | get key
            ^task ...$tw $t.uuid modify $"jira:($key)" +jira o> /dev/null
            print $"Created ($key) for '($t.description)'"
            if $epic != null {
                let added = ^jira epic add $epic $key | complete
                if $added.exit_code == 0 {
                    print $"  added ($key) to epic ($epic)"
                } else {
                    print -e $"(ansi red_bold)  could not add ($key) to epic ($epic):(ansi reset) ($added.stderr | str trim)"
                }
            }
            { id: $t.id, jira: $key, description: $t.description }
        } | compact

        ^task sync o> /dev/null
        $imported
    }
}
