def --wrapped task [...rest] {
    with-env { AWS_ENDPOINT_URL: "{{ TW_BUCKET }}" } {
        # An explicit `task sync` is just run as-is, without the pre/post sync.
        if $rest == ["sync"] {
            ^task sync
            return
        }
        ^task sync o> /dev/null
        try {
          ^task ...$rest
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
