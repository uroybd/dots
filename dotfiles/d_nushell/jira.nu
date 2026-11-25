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
            --data-urlencode
            $"jql=($jql)"
            --data-urlencode
            $"fields=($fields)"
            --data-urlencode
            "maxResults=100"
        ]
        | append (
            if ($expand | is-empty) { [] } else { [--data-urlencode $"expand=($expand)"] }
        )
        | append (
            if ($token | is-empty) { [] } else { [--data-urlencode $"nextPageToken=($token)"] }
        )
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
    let idx = $JIRA_STATUS_ORDER | enumerate | where item == ($status | str lowercase)
    if ($idx | is-empty) {
        99
    } else {
        $idx | first | get index
    }
}

# Markdown list of my tickets that moved forward in status recently, e.g. for posting to Slack.
# Grouped by epic, epics numbered and tickets numbered from 1 again beneath each:
#   1. EPIC-KEY: Epic Name
#       1. Ticket summary, Old Status -> New Status, <link>
# The 4-space indent keeps tickets nested under two-digit epic numbers too.
# Epics are never listed as tickets; one shows only as the heading over its own tickets that made the list.
# Backward moves are ignored. Bare URLs so Slack unfurls them as Jira chips. Multiple transitions
# in the window collapse into first-from -> last-to.
# --in-progress also lists tickets now In Progress, Code Review or Product Review that did not move forward in the
# window, as
#       1. Ticket summary, Code Review, <link>
# Usage: jira me changed [--since 3day] [--in-progress]
def 'jira me changed' [--since(-S): duration = 1day, --in-progress(-i)] {
    let open_statuses = ["In Progress", "Code Review", "Product Review"]
    let me = (jira me)
    let cutoff = (date now) - $since
    let changed = $"status CHANGED AFTER \"($cutoff | format date '%Y/%m/%d %H:%M')\""
    let open_jql = ($open_statuses | each {|st| $"\"($st)\"" } | str join ", ")
    let filter = if $in_progress { $"\(($changed) OR status IN \(($open_jql)\)\)" } else { $changed }
    let jql = $"assignee = \"($me)\" AND ($filter)"
    let issues = (jira-rest-search $jql "summary,parent,status,issuetype" --expand changelog)
    let forward = (
        $issues
        # epics only appear as headings, over the tickets beneath them that made the list
        | where {|issue| ($issue.fields | get -o issuetype.name) != "Epic" }
        | each {|issue|
            let moves = (
                $issue.changelog.histories
                | where {|h| ($h.created | into datetime) > $cutoff }
                | sort-by created
                | each {|h| $h.items | where field == "status" }
                | flatten
            )
            let move = if ($moves | is-empty) { null } else {
                let from = $moves | first | get fromString
                let to = $moves | last | get toString
                # skip tickets that bounced back or moved backward
                if (jira-status-rank $from) != 99 and (jira-status-rank $to) != 99 and (jira-status-rank $to) <= (jira-status-rank $from) {
                    null
                } else {
                    {from: $from, to: $to}
                }
            }
            let status = $issue.fields.status.name
            let move = if $move == null and $in_progress and ($status | str lowercase) in ($open_statuses | str lowercase) {
                {from: null, to: $status}
            } else { $move }
            if $move == null { null } else {
                let parent = $issue.fields | get -o parent
                let epic = if ($parent | get -o fields.issuetype.name) == "Epic" { $"($parent.key): ($parent.fields.summary)" } else { "No epic" }
                {
                    key: $issue.key
                    summary: $issue.fields.summary
                    epic: $epic
                    from: $move.from
                    to: $move.to
                    rank: (jira-status-rank $move.to)
                }
            }
        }
        | compact
    )
    if ($forward | is-empty) {
        let extra = if $in_progress { " and nothing in progress or review" } else { "" }
        print -e $"No forward status changes in the last ($since)($extra)."
        return
    }
    let out = (
        $forward
        | sort-by rank key
        | group-by --to-table epic
        | sort-by {|g| if $g.epic == "No epic" { "~" } else { $g.epic } }
        | enumerate
        | each {|e|
            let g = $e.item
            let items = (
                $g.items
                | enumerate
                | each {|t|
                    let i = $t.item
                    let status = if $i.from == null { $i.to } else { $"($i.from) -> ($i.to)" }
                    $"    ($t.index + 1). ($i.summary), ($status), (jira-ticket-to-url $i.key)"
                }
                | str join "\n"
            )
            $"($e.index + 1). ($g.epic)\n($items)"
        }
        | str join "\n"
    )
    $out
}

# A ticket's Story Points (customfield_10035, the field the board uses), or null when unset.
def jira-story-points [ticket: string] {
    let auth = $"((jira me)):($env.JIRA_API_TOKEN)"
    ^curl -s -u $auth $"($env.JIRA_HOST)/rest/api/2/issue/($ticket)?fields=customfield_10035"
    | from json
    | get -o fields.customfield_10035
    | if $in == null { null } else { $in | into int }
}

# Story point sizes by the most working days each holds (a week is 5), as in the jira-story-points skill's table:
# 1 is up to 1 day, 2 is 1-2 days, 3 is 2-5 days, 5 is 1-2 weeks. Keep the two in step.
const STORY_POINT_SIZES = [[points, max_days]; [1, 1] [2, 2] [3, 5] [5, 10]]

# Sizes work of `days` working days: adds `offset` percent of headroom, then takes the smallest size the padded work
# fits. Past the largest size it says 5 with split true, since the ticket should be split.
def story-point-size [days: number, offset: number] {
    let padded = $days * (1 + $offset / 100) | math round --precision 2
    let fits = $STORY_POINT_SIZES | where max_days >= $padded
    {
        points: (
            if ($fits | is-empty) {
                $STORY_POINT_SIZES | last | get points
            } else {
                $fits | first | get points
            }
        )
        raw_days: $days
        offset: $offset
        padded_days: $padded
        split: ($fits | is-empty)
    }
}

# Story points for work of DAYS working days, after adding --offset percent of headroom (20 by default, the
# jira-story-points skill's convention). Prints the points; --explain gives the padded days and whether to split too.
# Usage: fulbot story-point calc 1.8            # 1.8d -> 2.16d -> 3
#        fulbot story-point calc 4 --offset 30 --explain
def 'fulbot story-point calc' [days: number, --offset(-o): number = 20, --explain(-e)] {
    let size = (story-point-size $days $offset)
    if $explain { $size } else { $size.points }
}

# Work estimates for tickets from one Claude call (work setup), one row per ticket in the order given:
# {ticket, raw_days, reason}, raw_days being the work without headroom (story-point-size adds that and sizes it). Claude
# estimates by the jira-story-points skill. One call for the batch saves the per-call startup and, with --codebase, lets Claude read the code once for all of them (read-only, in the current directory). A ticket the answer
# misses is retried on its own; one that still gets no estimate is warned about on stderr and left out.
def story-point-estimates [tickets: list<string>, --codebase(-c)] {
    let ticket_text = (
        $tickets | par-each --threads 4 {|t| $"=== ($t) ===\n(^jira issue view $t --plain --comments 5 | ansi strip)" }
        | str join "\n\n"
    )
    let schema = {
        type: object
        properties: {
            estimates: {
                type: array
                items: {
                    type: object
                    properties: {
                        ticket: {type: string, enum: $tickets}
                        raw_days: {
                            type: number
                            exclusiveMinimum: 0
                            description: "Working days of work, without headroom."
                        }
                        reason: {
                            type: string
                            description: "One or two sentences on what drives the size."
                        }
                    }
                    required: [ticket raw_days reason]
                }
            }
        }
        required: [estimates]
    }
    let tools = if $codebase { [Read Grep Glob] } else { [] }
    let codebase_note = if $codebase { " Use the codebase in the current directory." } else { "" }

    let got = try {
        $ticket_text
        | ai ask $"/jira-story-points raw only, for ($tickets | str join ', ').($codebase_note)" --setup fulflld --schema $schema --tools $tools --here=$codebase
        | get estimates
    } catch {|err|
        let msg = $"No estimate for ($tickets | str join ', '): ($err.msg)"
        if ($tickets | length) == 1 { error make {msg: $msg} }
        print -e $"[WARN] ($msg)"
        []
    }

    $tickets | each {|t|
        let found = $got | where ticket == $t
        if ($found | is-not-empty) {
            $found | first
        } else if ($tickets | length) > 1 {
            # missed by the batch: one more try on its own
            try { story-point-estimates [$t] --codebase=$codebase | first } catch {|err|
                print -e $"[WARN] ($err.msg)"
                null
            }
        }
    } | compact
}

# Tickets for the fulbot commands, from arguments, piped input (one per line, or a list) and --epic (the open child
# tickets of each comma-separated epic), in any mix: split on commas and spaces, uppercased, deduplicated, in order.
# Errors when none are left.
def fulbot-tickets [tickets: list<string>, piped: any, --epic: string] {
    let piped = if $piped == null { [] } else if ($piped | describe) == "string" { [$piped] } else { $piped }
    let from_epic = if $epic == null { [] } else {
        let epics = (
            $epic
            | split row -r '[,\s]+'
            | where {|e| $e != "" }
            | str uppercase
        )
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
        error make {
            msg: "No tickets given. Pass them as arguments (FUL-1 FUL-2 or FUL-1,FUL-2), pipe them in, or give --epic."
        }
    }
    $tickets
}

# Story points for tickets by the jira-story-points skill's convention: 1, 2, 3 or 5. Claude (work setup) estimates the work
# in days; --offset percent of headroom (20 by default) is added to that, and the padded days give the points.
# Tickets come as arguments, comma-separated lists, or piped in (one per line, or a list), in any mix, and are all
# estimated in one Claude call. One ticket prints only its number; several give a table of ticket and points, in the
# order given. A ticket that should be split instead says 5 and warns on stderr; one that can't be estimated warns and
# is left out of the table (a lone ticket errors instead).
# --codebase: run from the repo the tickets target; Claude reads the code they would touch (read-only) to size them.
# --offset: headroom in percent added to Claude's raw days before sizing (default 20, the skill's convention).
#           --for-tzia is another name for it; give only one.
# --explain: the whole estimate (raw days, offset, padded days, split, reason) instead of only the points.
# --epic: also estimate the epic's child tickets that aren't done (several epics: comma-separated). With it, giving
#         tickets is optional.
# --update: also set each ticket's Story Points to its guess, asking for each (on stderr); --yes skips the questions.
# --json: a JSON object keyed by ticket, however many there are: {"FUL-1": 3}, or with --explain
#         {"FUL-1": {points, raw_days, offset, padded_days, split, reason}}.
# Usage: fulbot guess story-point FUL-1 FUL-2,FUL-3 [--epic FUL-100] [--offset 20] [--codebase] [--explain] [--json]
#                                 [--update [--yes]]
#        "FUL-1\nFUL-2" | fulbot guess story-point
def 'fulbot guess story-point' [
    --epic(-E): string
    --offset(-o): number
    --for-tzia: number
    --codebase(-c)
    --explain(-e)
    --json(-j)
    --update(-u)
    --yes(-y)
    ...tickets: string
] {
    if $offset != null and $for_tzia != null {
        error make {msg: "--for-tzia is another name for --offset; give only one."}
    }
    let offset = ($offset | default $for_tzia | default 20)
    let tickets = (fulbot-tickets $tickets $in --epic $epic)
    let estimates = (
        story-point-estimates $tickets --codebase=$codebase
        | each {|e| {ticket: $e.ticket} | merge (story-point-size $e.raw_days $offset) | insert reason $e.reason }
    )

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
    let out = if $explain {
        $estimates
    } else {
        $estimates | select ticket points
    }
    if ($tickets | length) == 1 {
        if $explain {
            $out | first | reject ticket
        } else {
            $out | first | get points
        }
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
        error make {
            msg: $"($ticket) Story Points are ($after | default 'unset') after the update, not ($estimate.points)."
        }
    }
    print -e $"[INFO] ($ticket) story points: ($current | default 'unset') -> ($after)."
}

# What a fulbot session starts from: each ticket under a === KEY === header with its Story Points, jira-cli view
# (description and the last 5 comments) and child tickets, then the user's instructions.
def fulbot-session-prompt [tickets: list<string>, message?: string] {
    let children = (
        jira-rest-search $"parent in \(($tickets | str join ', ')\) ORDER BY key" "summary,status,issuetype,parent,customfield_10035"
        | each {|c|
            {
                parent: $c.fields.parent.key
                line: $"- ($c.key) [($c.fields.issuetype.name), ($c.fields.status.name), ($c.fields.customfield_10035? | default 'unset') pts]: ($c.fields.summary)"
            }
        }
    )
    let ticket_text = (
        $tickets
        | par-each --keep-order --threads 4 {|t|
            let kids = $children | where parent == $t | get line
            let kids = if ($kids | is-empty) { "none" } else { "\n" + ($kids | str join "\n") }
            $"=== ($t) ===\nStory Points: ((jira-story-points $t) | default 'unset')\nChild tickets: ($kids)\n(^jira issue view $t --plain --comments 5 | ansi strip)"
        }
        | str join "\n\n"
    )
    let message = if ($message | is-empty) { "None." } else { $message }
    $"Tickets: ($tickets | str join ', ')\n\n($ticket_text)\n\n## Instructions\n($message)"
}

# Rewrites tickets into well-formed ones in an interactive Claude session (work setup): a clear summary, a full
# description and story points, from the tickets themselves plus whatever --message points at (a work brief, a doc, a
# file path, extra instructions). Claude shows what changes on which ticket and updates Jira only after you approve,
# so the session stays open for edits and questions. What Claude does is the jira-enrich skill
# (dotfiles/d_claude_fulflld_jira_enrich); this command gathers the tickets and starts it.
# Tickets come as in `fulbot guess story-point`: arguments, comma-separated lists, piped in, or --epic.
# --message: extra instructions for Claude, passed on verbatim (e.g. "Use the brief in ~/work/brief.md").
# --codebase: run from the repo the tickets target; Claude reads the code they touch.
# --offset: headroom in percent added to the raw days before sizing (default 20).
# Usage: fulbot enrich FUL-1 FUL-2,FUL-3 [--epic FUL-100] [-m "See ~/work/brief.md"] [--codebase] [--offset 20]
def 'fulbot enrich' [
    --epic(-E): string
    --message(-m): string
    --offset(-o): number = 20
    --codebase(-c)
    ...tickets: string
] {
    let tickets = (fulbot-tickets $tickets $in --epic $epic)
    let settings = $"offset=($offset), codebase=(if $codebase { 'yes' } else { 'no' })"
    ai session $"/jira-enrich Settings: ($settings)\n\n(fulbot-session-prompt $tickets $message)" --setup fulflld
}

# Breaks tickets into child tickets in an interactive Claude session (work setup), for a process that wants work
# tracked in smaller pieces. The pieces are kept meaningful, not micro: each is at least --min-days of real work with
# its own acceptance criteria, there are as few as the work allows, and a ticket too small to split gets none. Claude
# shows the draft and creates tickets only after you approve. What Claude does is the jira-ticktify skill
# (dotfiles/d_claude_fulflld_jira_ticktify); this command gathers the tickets and starts it.
# An epic gets regular tickets under it; any other ticket gets sub-tasks. Children take the parent's assignee.
# Tickets come as in `fulbot guess story-point`: arguments, comma-separated lists, piped in, or --epic (whose open
# children are then each split; to split the epic itself, pass its key as a ticket).
# --message: extra instructions for Claude, passed on verbatim (e.g. "Split by the phases in ~/work/brief.md").
# --min-days: the least working days of work one child may hold, before headroom (default 1).
# --codebase: run from the repo the tickets target; Claude reads the code to slice along it.
# --offset: headroom in percent added to the raw days before sizing (default 20).
# Usage: fulbot ticktify FUL-1 FUL-2,FUL-3 [--epic FUL-100] [-m "..."] [--min-days 1] [--codebase] [--offset 20]
def 'fulbot ticktify' [
    --epic(-E): string
    --message(-m): string
    --min-days(-d): number = 1
    --offset(-o): number = 20
    --codebase(-c)
    ...tickets: string
] {
    let tickets = (fulbot-tickets $tickets $in --epic $epic)
    let settings = $"offset=($offset), min-days=($min_days), codebase=(if $codebase { 'yes' } else { 'no' })"
    ai session $"/jira-ticktify Settings: ($settings)\n\n(fulbot-session-prompt $tickets $message)" --setup fulflld
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

# Moves the branch's ticket to Code Review; with -p also opens the PR with a TICKET: line on top.
# A PR body piped in goes right after the TICKET: line and the PR is created in one call
# (`$body | nu -l --stdin -c '$in | jira issues branch review -p'`; nu only hands stdin to the script, hence `$in |`).
# Without one the first commit's body is used.
def 'jira issues branch review' [--create-pr(-p)]: [nothing -> nothing, string -> nothing] {
    let piped_body = ($in | default "" | into string | str trim)

    # Get the current branch name
    let current_branch = (git branch --show-current)
    if ($current_branch | str starts-with "FUL-") {
        let ticket = (get-ticket-from-branch)
        ^jira issue move $ticket "Code Review"
        if $create_pr {
            let ticket_line = $"TICKET: (jira-ticket-to-url $ticket)"
            if $piped_body != "" {
                # --body overrides the body from --fill-first; the title still comes from the first commit.
                gh pr create --fill-first --body $"($ticket_line)\n\n($piped_body)"
                print "Created PR with the ticket link and the piped body"
            } else {
                gh pr create --fill-first
                print "Created PR successfully"
                let pr_body = gh pr view --json body | from json | get body
                gh pr edit --body $"($ticket_line)\n\n($pr_body)"
                print "Updated Ticket link in the PR"
            }
        } else if $piped_body != "" {
            print -e "[WARN] A PR body was piped in without -p; it was ignored."
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

# Drafts piped text as you in a Slack channel (name, or "#name") or a direct message (@username), through the Slack connector
# of the fulflld Claude setup, so you can review and send it from Slack; --post sends it instead. Returns the
# message's or draft's link when Slack gives one. --post shows the message and asks first (on stderr) unless --yes.
# The text goes out as-is, so Markdown lists from `jira me changed` stay lists. A # prefix needs quotes: unquoted, it
# starts a nushell comment.
# The connector reaches one workspace, the one it was signed in to (in /mcp under the fulflld setup).
# Usage: jira me changed | fulbot slack post team-updates                # draft in a channel
#        jira me changed | fulbot slack post @roy --post [--yes]          # send as a DM
#        jira me changed | fulbot slack post @me                          # draft in your DM with yourself
def 'fulbot slack post' [target: string, --post(-p), --yes(-y)] {
    let text = ($in | default "" | into string | str trim)
    if ($text | is-empty) {
        error make {msg: "Nothing to post; pipe the message in."}
    }
    let kind = if ($target | str starts-with "@") { "user" } else { "channel" }
    let name = ($target | str trim --left --char "#" | str trim --left --char "@")
    if $post and not $yes {
        print -e $"To ($target):\n($text)\n"
        let answer = (try { input "Post it? [y/N] " } catch {
            print -e "[WARN] No terminal to ask on; pass --yes to post without asking."
            "n"
        })
        if ($answer | str lowercase) not-in [y yes] {
            print -e "[INFO] Not posted."
            return
        }
    }
    let action = if $post {
        "Send the stdin text as a message"
    } else {
        "Save the stdin text as a draft message (do NOT send it)"
    }
    let where = if $kind == "channel" {
        $"in the Slack channel named ($name)"
    } else if $name == "me" {
        "in my direct message with myself; get my user ID from my own profile and use it as the channel"
    } else {
        $"in my direct message with the Slack user whose username or display name is ($name); use their user ID as the channel"
    }
    # Only the lookup and the one write asked for; never the other of draft and send.
    let tools = [
        (
            if $kind == "channel" { "mcp__claude_ai_Slack__slack_search_channels" }
            else if $name == "me" { "mcp__claude_ai_Slack__slack_read_user_profile" }
            else { "mcp__claude_ai_Slack__slack_search_users" }
        )
        (if $post { "mcp__claude_ai_Slack__slack_send_message" } else { "mcp__claude_ai_Slack__slack_send_message_draft" })
    ]
    let result = (
        $text
        | ai ask $"($action) ($where)." --setup fulflld --mcp $tools --system (
            "You make one Slack message or draft and do nothing else. Use the stdin text exactly as given: same "
            + "words, line breaks, list markers and indentation; no greeting, summary or edits. Write only to the "
            + "channel or person asked for: if there is no exact match, several people match, or you cannot write "
            + "there, write nowhere and say so. Report what happened."
        ) --schema {
            type: object
            properties: {
                done: {type: boolean, description: "Whether the message was sent, or the draft saved, as asked"}
                link: {type: string, description: "Link to the message or draft, or empty"}
                error: {type: string, description: "Why it was not done, or empty"}
            }
            required: [done link error]
        }
    )
    let what = if $post { "Not posted" } else { "No draft saved" }
    if not $result.done {
        error make {msg: $"($what) for ($target): ($result.error)"}
    }
    if not $post { print -e $"[INFO] Draft saved for ($target); review and send it from Slack." }
    $result.link
}
