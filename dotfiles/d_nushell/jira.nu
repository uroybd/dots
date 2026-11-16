def "jira issue assignme" [issue?: string] {
    let me = (jira me)
    match $issue {
        null => {
            let issue = (input "Enter the issue ID to assign to yourself: ")
            match $issue {
                null => {
                    print "No issue ID provided."
                }
                _ => {
                    jira issue assign $issue $me
                }
            }
        }
        _ => {
            jira issue assign $issue $me
        }
    }
}

def "jira me issues" --wrapped [...rest] {
    let me = (jira me)
    ^jira issue list --assignee $me ...$rest
}

def "jira me queue" --wrapped [...rest] {
    let me = (jira me)
    ^jira issue list -s~Done --assignee $me ...$rest
}

# Search issues over the Jira REST API (v2, so descriptions come back as plain text), following pagination.
# jira-cli can't expose the changelog or most fields, hence the direct call.
def jira-rest-search [jql: string, fields: string, --expand: string = ""] {
    let auth = $"((jira me)):($env.JIRA_API_TOKEN)"
    mut issues = []
    mut token = ""
    loop {
        let params = [
            --data-urlencode $"jql=($jql)"
            --data-urlencode $"fields=($fields)"
            --data-urlencode "maxResults=100"
        ]
        | append (if ($expand | is-empty) { [] } else { [--data-urlencode $"expand=($expand)"] })
        | append (if ($token | is-empty) { [] } else { [--data-urlencode $"nextPageToken=($token)"] })
        let resp = ^curl -s -G -u $auth $"($env.JIRA_HOST)/rest/api/2/search/jql" ...$params | from json
        if ($resp | get -o issues) == null {
            error make {msg: $"Jira search failed: ($resp | to json -r)"}
        }
        $issues = ($issues | append $resp.issues)
        if ($resp | get -o isLast | default true) { break }
        $token = $resp.nextPageToken
    }
    $issues
}

# Workflow order, used to tell forward moves from backward ones.
# Statuses not listed here are treated as forward moves and sorted last.
const JIRA_STATUS_ORDER = ["to do", "in progress", "code review", "product review", "done"]

def jira-status-rank [status: string] {
    let idx = ($JIRA_STATUS_ORDER | enumerate | where item == ($status | str lowercase))
    if ($idx | is-empty) { 99 } else { $idx | first | get index }
}

# Markdown list of my tickets that moved forward in status recently, e.g. for posting to Slack.
# Grouped by epic, one line per ticket:
#   - EPIC-KEY: Epic Name
#       - Ticket summary, Old Status -> New Status, <link>
# Backward moves are ignored. Bare URLs so Slack unfurls them as Jira chips. Multiple transitions
# in the window collapse into first-from -> last-to.
# Usage: jira me changed [--since 3day]
def 'jira me changed' [--since(-S): duration = 1day] {
    let me = (jira me)
    let cutoff = (date now) - $since
    let jql = $"assignee = \"($me)\" AND status CHANGED AFTER \"($cutoff | format date '%Y/%m/%d %H:%M')\""
    let issues = (jira-rest-search $jql "summary,parent" --expand changelog)
    let forward = (
        $issues
        | each {|issue|
            let moves = (
                $issue.changelog.histories
                | where {|h| ($h.created | into datetime) > $cutoff }
                | sort-by created
                | each {|h| $h.items | where field == "status" }
                | flatten
            )
            if ($moves | is-empty) { null } else {
                let from = ($moves | first | get fromString)
                let to = ($moves | last | get toString)
                # skip tickets that bounced back or moved backward
                if (jira-status-rank $from) != 99 and (jira-status-rank $to) != 99 and (jira-status-rank $to) <= (jira-status-rank $from) {
                    null
                } else {
                    let parent = ($issue.fields | get -o parent)
                    let epic = if ($parent | get -o fields.issuetype.name) == "Epic" { $"($parent.key): ($parent.fields.summary)" } else { "No epic" }
                    {
                        key: $issue.key
                        summary: $issue.fields.summary
                        epic: $epic
                        from: $from
                        to: $to
                        rank: (jira-status-rank $to)
                    }
                }
            }
        }
        | compact
    )
    if ($forward | is-empty) {
        print $"No forward status changes in the last ($since)."
        return
    }
    let out = (
        $forward
        | sort-by rank key
        | group-by --to-table epic
        | sort-by {|g| if $g.epic == "No epic" { "~" } else { $g.epic } }
        | each {|g|
            let items = (
                $g.items
                | each {|i| $"    - ($i.summary), ($i.from) -> ($i.to), (jira-ticket-to-url $i.key)" }
                | str join "\n"
            )
            $"- ($g.epic)\n($items)"
        }
        | str join "\n"
    )
    print $out
}

# The skill whose "Story points" section is the estimating convention (scale, headroom), in the work Claude setup.
const STORY_POINT_SKILL = "~/.claude-fulflld/skills/jira-ticket/SKILL.md"

# A ticket's Story Points (customfield_10035, the field the board uses), or null when unset.
def jira-story-points [ticket: string] {
    let auth = $"((jira me)):($env.JIRA_API_TOKEN)"
    ^curl -s -u $auth $"($env.JIRA_HOST)/rest/api/2/issue/($ticket)?fields=customfield_10035"
    | from json
    | get -o fields.customfield_10035
    | if $in == null { null } else { $in | into int }
}

# The "Story points" section of the jira-ticket skill: the scale and headroom estimates follow.
def story-point-rules [] {
    let skill = (^cat ($STORY_POINT_SKILL | path expand) | split row "## 2. Story points")
    if ($skill | length) < 2 {
        error make {msg: $"No \"## 2. Story points\" section in ($STORY_POINT_SKILL)"}
    }
    $skill | get 1 | split row "\n## " | first
}

# Estimates for tickets from one Claude call (work setup), one row per ticket in the order given:
# {ticket, points, raw_days, padded_days, split, reason}. One call for the batch saves the per-call startup and, with
# --codebase, lets Claude read the code once for all of them (read-only, in the current directory). A ticket the answer
# misses is retried on its own; one that still gets no estimate is warned about on stderr and left out.
def story-point-estimates [tickets: list<string>, rules: string, --codebase(-c)] {
    let ticket_text = (
        $tickets | par-each --threads 4 {|t| $"=== ($t) ===\n(^jira issue view $t --plain --comments 5)" }
        | str join "\n\n"
    )
    let codebase_rules = if $codebase {
        "\nThe current directory is the codebase these tickets change. Before estimating, find and read the code each ticket would touch, using only Read, Grep and Glob, and change nothing. Size the work from what you find: how many places change, existing patterns to reuse, tests to add or update. Mention what you found in reason."
    } else { "" }
    let instructions = $"You estimate story points for Jira tickets, given on stdin, each under a === KEY === header. Estimate every ticket on its own merits, with the same scale for all. Follow these rules exactly, including the 20% headroom:

## Story points
($rules)
Answer only through the structured output, with one estimate per ticket. raw_days is the work before headroom, padded_days after it. If the padded work is bigger than 5 points, set split to true and points to 5.($codebase_rules)"

    let schema = {
        type: object
        properties: {
            estimates: {
                type: array
                items: {
                    type: object
                    properties: {
                        ticket: {type: string, enum: $tickets}
                        points: {type: integer, enum: [1 2 3 5]}
                        raw_days: {type: number}
                        padded_days: {type: number}
                        split: {type: boolean}
                        reason: {type: string, description: "One or two sentences on what drives the size."}
                    }
                    required: [ticket points raw_days padded_days split reason]
                }
            }
        }
        required: [estimates]
    }
    let tools = if $codebase { [Read Grep Glob] } else { [] }

    let got = try {
        $ticket_text
        | ai ask $"Estimate story points for ($tickets | str join ', ')." --setup fulflld --system $instructions --schema $schema --tools $tools --here=$codebase
        | get estimates
    } catch {|err|
        let msg = $"No estimate for ($tickets | str join ', '): ($err.msg)"
        if ($tickets | length) == 1 { error make {msg: $msg} }
        print -e $"[WARN] ($msg)"
        []
    }

    $tickets | each {|t|
        let found = ($got | where ticket == $t)
        if ($found | is-not-empty) {
            $found | first
        } else if ($tickets | length) > 1 {
            # missed by the batch: one more try on its own
            try { story-point-estimates [$t] $rules --codebase=$codebase | first } catch {|err|
                print -e $"[WARN] ($err.msg)"
                null
            }
        }
    } | compact
}

# Story points for tickets, guessed by Claude (work setup) by the jira-ticket skill's convention: 1, 2, 3 or 5.
# Tickets come as arguments, comma-separated lists, or piped in (one per line, or a list), in any mix, and are all
# estimated in one Claude call. One ticket prints only its number; several give a table of ticket and points, in the
# order given. A ticket that should be split instead says 5 and warns on stderr; one that can't be estimated warns and
# is left out of the table (a lone ticket errors instead).
# --codebase: run from the repo the tickets target; Claude reads the code they would touch (read-only) to size them.
# --explain: the whole estimate (raw and padded days, split, reason) instead of only the points.
# --epic: also estimate the epic's child tickets that aren't done (several epics: comma-separated). With it, giving
#         tickets is optional.
# --update: also set each ticket's Story Points to its guess, asking for each (on stderr); --yes skips the questions.
# --json: a JSON object keyed by ticket, however many there are: {"FUL-1": 3}, or with --explain
#         {"FUL-1": {points, raw_days, padded_days, split, reason}}.
# Usage: fulbot guess story-point FUL-1 FUL-2,FUL-3 [--epic FUL-100] [--codebase] [--explain] [--json] [--update [--yes]]
#        "FUL-1\nFUL-2" | fulbot guess story-point
def 'fulbot guess story-point' [
    ...tickets: string, --epic(-E): string, --codebase(-c), --explain(-e), --json(-j), --update(-u), --yes(-y)
] {
    let piped = $in
    let piped = if $piped == null { [] } else if ($piped | describe) == "string" { [$piped] } else { $piped }
    let from_epic = if $epic == null { [] } else {
        let epics = ($epic | split row -r '[,\s]+' | where {|e| $e != "" } | str uppercase)
        let children = (
            jira-rest-search $"parent in \(($epics | str join ', ')\) AND statusCategory != Done ORDER BY key" "summary"
            | get key
        )
        if ($children | is-empty) {
            print -e $"[WARN] No open tickets under ($epics | str join ', ')."
        }
        $children
    }
    let tickets = (
        $tickets | append $piped | append $from_epic
        | each {|t| $t | into string | split row -r '[,\s]+' } | flatten
        | where {|t| $t != "" } | str uppercase | uniq
    )
    if ($tickets | is-empty) {
        error make {msg: "No tickets given. Pass them as arguments (FUL-1 FUL-2 or FUL-1,FUL-2), pipe them in, or give --epic."}
    }
    let estimates = (story-point-estimates $tickets (story-point-rules) --codebase=$codebase)

    for e in ($estimates | where split) {
        print -e $"[WARN] ($e.ticket) is bigger than 5 points \(($e.padded_days)d padded\); consider splitting it."
    }
    if $update {
        for e in $estimates { jira-story-points-set $e.ticket $e --yes=$yes }
    }

    if $json {
        return (
            $estimates
            | reduce --fold {} {|e, acc| $acc | insert $e.ticket (if $explain { $e | reject ticket } else { $e.points }) }
            | to json
        )
    }
    let out = if $explain { $estimates } else { $estimates | select ticket points }
    if ($tickets | length) == 1 {
        if $explain { $out | first | reject ticket } else { $out | first | get points }
    } else { $out }
}

# Sets a ticket's Story Points to an estimate from `fulbot guess story-point`, asking first unless --yes, then checks it
# took (a wrong custom-field name fails silently).
def jira-story-points-set [ticket: string, estimate: record, --yes(-y)] {
    let current = (jira-story-points $ticket)
    if $current == $estimate.points {
        print -e $"[INFO] ($ticket) already has ($current) story points."
        return
    }
    if not $yes {
        print -e $"($ticket): ($current | default 'unset') -> ($estimate.points) story points \(($estimate.raw_days)d → ($estimate.padded_days)d\)"
        print -e $"  ($estimate.reason)"
        let answer = (try { input "Update the ticket? [y/N] " } catch {
            print -e "[WARN] No terminal to ask on; pass --yes to update without asking."
            "n"
        })
        if ($answer | str lowercase) not-in [y yes] {
            print -e $"[INFO] ($ticket) left at ($current | default 'unset')."
            return
        }
    }
    ^jira issue edit $ticket --no-input --custom $"story-points=($estimate.points)" | ignore
    let after = (jira-story-points $ticket)
    if $after != $estimate.points {
        error make {msg: $"($ticket) Story Points are ($after | default 'unset') after the update, not ($estimate.points)."}
    }
    print -e $"[INFO] ($ticket) story points: ($current | default 'unset') -> ($after)."
}

def 'jira sprint current' [] {
    return (
        jira sprint list --state=active --columns=ID --table --plain
        | detect columns
        | get 0.ID
    )
}

def 'jira sprint add' --wrapped [sprint_id?: string, ...issues: string] {
    ^jira sprint add ($sprint_id | default (jira sprint current)) ...$issues
}

def 'jira me sprint' --wrapped [...rest] {
    ^jira sprint list --current --assignee (jira me) --columns TYPE,KEY,SUMMARY,STATUS,PRIORITY,REPORTER ...$rest
}

def create-branch-name [key, summary] {
    let task_name = (
        $summary
        | str replace -a -r '\W+' "-"
        | str trim -c "-"
        | str lowercase
    )
    let branch_name = $"($key)_roy_($task_name)"
    let branch_name = ($branch_name | str substring 0..50 | str trim -c "-") # limit branch name to 50 characters
    return $branch_name
}

def 'jira me issues create' --wrapped [--no-sprint(-x), --git-branch-init(-g), ...rest] {
    let task_type = ["Task", "Bug", "Story", "Feature Request"] | input list "Issue Type"
    let summary = (input "Summary: ")
    let response = (
        ^jira issue create --assignee (jira me) --raw --no-input -s $summary -t $task_type ...$rest
    )
    let key = $response | from json | get key
    print $"Issue created with key: ($key)"
    if not $no_sprint {
        ^jira sprint add (jira sprint current) $key
        print "...and added to current sprint"
    }
    if $git_branch_init {
        let branch_name = (create-branch-name $key $summary)
        print $"Creating git branch: ($branch_name)"
        git switch main
        git pull
        ^git switch -c $branch_name
    }
}

def 'jira issues branch create' [key] {
    let vals = (^jira issue view --raw $key | from json | get key fields.summary)
    let summary = $vals | get 1
    let key = $vals | get 0
    let branch_name = (create-branch-name $key $summary)
    print $"Creating git branch: ($branch_name)"
    git switch main
    git pull
    ^git switch -c $branch_name
}

def get-ticket-from-branch [] {
    let current_branch = (git branch --show-current)
    if ($current_branch | str starts-with "FUL-") {
        return ($current_branch | split row "_" | get 0)
    } else {
        return ""
    }
}

def jira-ticket-to-url [ticket: string] {
    return $"($env.JIRA_HOST)/browse/($ticket)"
}

def 'jira issues branch review' [--create-pr(-p)] {

    # Get the current branch name
    let current_branch = (git branch --show-current)
    if ($current_branch | str starts-with "FUL-") {
        let ticket = (get-ticket-from-branch)
        ^jira issue move $ticket "Code Review"
        if $create_pr {
            gh pr create --fill-first
            print "Created PR successfully"
            let pr_body = gh pr view --json body | from json | get body
            let ticket_url = (jira-ticket-to-url $ticket)
            let updated_body = $"TICKET: ($ticket_url)\n\n($pr_body)"
            gh pr edit --body $updated_body
            print "Updated Ticket link in the PR"
        }
    } else {
        print "Current branch is not a FUL- branch, skipping Jira issue move."
    }
}

def 'jira issues branch view' [] {
    let ticket = (get-ticket-from-branch)
    if $ticket != "" {
        ^jira issue view $ticket
    } else {
        print "Current branch is not a FUL- branch, cannot determine Jira ticket."
    }
}

def 'jira issues branch epic' [] {
    let ticket = (get-ticket-from-branch)
    if $ticket != "" {
        let epics = (
            ^jira epic list --table --plain --columns KEY,SUMMARY,STATUS --status "TO DO" --status "In Progress" --order-by STATUS --reverse --csv
            | from csv
        )
        let selected_epic = (
            $epics
            | input list -d {|it| $"($it.KEY) [($it.STATUS)]: ($it.SUMMARY)"} --fuzzy
        )
        jira epic add $selected_epic.KEY $ticket
        print $"Added ticket ($ticket) to epic ($selected_epic.KEY)"
    } else {
        print "Current branch is not a FUL- branch, cannot determine Jira ticket."
    }
}

def 'jira me issues top' [] {
    let issues = jira me issues -s~Done --columns KEY,SUMMARY,STATUS --paginate 5 --csv | from csv
    for $issue in $issues {
        let color = match $issue.STATUS {
            "TO DO" => "yb"
            "In Progress" => "bb"
            "Code Review" => "gb"
            "Product Review" => "pd"
            Done => "gd"
            _ => "wb"
        }
        mut title = $issue.SUMMARY
        if ($title | str length) > 44 {
            $title = ($title | str substring 0..44) + "..."
        }
        print $"  (ansi $color)($issue.KEY): ($title)(ansi reset)"
    }
}
