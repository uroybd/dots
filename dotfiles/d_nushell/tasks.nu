# Whether `token` can be part of a task filter (id, id range, uuid, +tag/-tag or attribute:value).
def is-filter-token [token: string] {
    $token =~ '^(\d+(-\d+)?|[0-9a-f]{8}(-[0-9a-f]{4}){0,4}|[+-]\w+|\w+:\S*)$'
}

# `task create-branch <id>`: create and switch to a git branch for a single task, off a fresh main.
# Named like the jira tooling (`<KEY>_roy_<summary>`, see `create-branch-name` in jira.nu) when the task
# has a `jira` key; otherwise just the slugified description.
def task-create-branch [filter: list<string>] {
    if ($filter | length) != 1 {
        error make {msg: "Give exactly one task id or uuid."}
    }
    let tasks = ^task rc.hooks=off rc.verbose=nothing ...$filter export | from json
    if ($tasks | length) != 1 {
        error make {msg: $"Expected exactly one matching task, found ($tasks | length)."}
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
          if ($rest | first | default "") == "create-branch" {
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
        error make {msg: "Give a task filter (ids, uuids, tags...); refusing to import everything."}
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

# Taskwarrior tag for a Jira issue type; unlisted types get their slugified name.
const JIRA_TYPE_TAGS = {
    "bug": "bugfix"
    "story": "feature"
    "feature request": "feature"
    "task": "task"
    "epic": "epic"
    "sub-task": "subtask"
}

def jira-type-tag [type: string] {
    let name = $type | str lowercase
    $JIRA_TYPE_TAGS | get -o $name | default ($name | str replace -a -r '\W+' "-" | str trim -c "-")
}

# Create taskwarrior tasks from Jira issues. The reverse of `jira tw import`.
# Usage: jira tw pull [--dry-run] <KEY>...
#        jira tw pull [--dry-run] --mine [--sprint]
#   e.g. `jira tw pull FUL-3560 FUL-3569`, `jira tw pull --mine -s`
# Each task gets: description = summary, `jira` UDA = key, `details` UDA = Jira description,
# project = key prefix (FUL), due = Jira due date, and the tags +jira plus one for the issue type
# (Bug -> +bugfix, Story/Feature Request -> +feature, Task -> +task, Epic -> +epic, Sub-task -> +subtask).
# --mine pulls my issues that are not done; --sprint limits that to open sprints.
# Issues that already have a task (any status except deleted) are skipped, as are done issues.
def "jira tw pull" [--mine(-m), --sprint(-s), --dry-run(-n), ...keys: string] {
    if ($keys | is-empty) and not $mine {
        error make {msg: "Give issue keys, or --mine."}
    }
    if (not ($keys | is-empty)) and $mine {
        error make {msg: "Give issue keys or --mine, not both."}
    }
    if $sprint and not $mine {
        error make {msg: "--sprint only applies together with --mine."}
    }
    let keys = $keys | each { str uppercase }
    let bad = $keys | where {|k| $k !~ '^[A-Z][A-Z0-9]*-\d+$' }
    if not ($bad | is-empty) {
        error make {msg: $"Not Jira issue keys: ($bad | str join ', ')"}
    }

    let jql = if $mine {
        let base = $"assignee = \"((^jira me | str trim))\" AND statusCategory != Done"
        if $sprint { $"($base) AND sprint in openSprints\(\)" } else { $base }
    } else {
        $"key in \(($keys | str join ',')\)"
    }

    with-env { AWS_ENDPOINT_URL: "{{ TW_BUCKET }}" } {
        if not $dry_run { ^task sync o> /dev/null }

        # Hooks are off while reading so only real tasks are listed.
        let existing = (
            ^task rc.hooks=off rc.verbose=nothing jira.any: export
            | from json
            | where status != deleted
            | get jira
        )

        let issues = jira-rest-search $jql "summary,issuetype,status,duedate,description"
        let found = $issues | get key
        for k in ($keys | where {|k| $k not-in $found }) {
            print -e $"(ansi red_bold)($k) not found in Jira.(ansi reset)"
        }

        let added = $issues | each {|issue|
            let f = $issue.fields
            if $issue.key in $existing {
                print $"Skipping ($issue.key): already has a task."
                return null
            }
            if ($f.status.statusCategory.key == "done") {
                print $"Skipping ($issue.key): already done in Jira."
                return null
            }
            let type_tag = jira-type-tag $f.issuetype.name
            let details = $f.description? | default "" | str trim
            let attrs = [
                $"jira:($issue.key)"
                $"project:($issue.key | split row '-' | first)"
                "+jira"
                $"+($type_tag)"
            ]
            | append (if $f.duedate? == null { [] } else { [$"due:($f.duedate)"] })
            | append (if ($details | is-empty) { [] } else { [$"details:($details)"] })

            if $dry_run {
                print $"Would add ($issue.key) [+($type_tag)]: ($f.summary)"
            } else {
                # Hooks stay on so the usual auto-tagging applies; the on-add jira hook ignores
                # tasks that already have a key. `--` keeps the summary from being parsed as filters.
                let res = ^task rc.verbose=nothing rc.confirmation=no add ...$attrs -- $f.summary | complete
                if $res.exit_code != 0 {
                    print -e $"(ansi red_bold)Failed to add ($issue.key):(ansi reset) ($res.stderr | str trim)"
                    return null
                }
                print $"Added ($issue.key) [+($type_tag)]: ($f.summary)"
            }
            { jira: $issue.key, type: $type_tag, description: $f.summary }
        } | compact

        if not $dry_run { ^task sync o> /dev/null }
        $added
    }
}


def mt [...rest] {
  with-env { AWS_ENDPOINT_URL: "{{ TW_BUCKET }}" } {
    ^meghnaad-tui ...$rest
  }
}
