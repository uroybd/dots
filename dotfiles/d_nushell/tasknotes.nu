let TASKNOTE_API_ENDPOINT = "http://localhost:8888/api"

def tasknotes_open [] {
    let query = {
        "type": "group"
        "id": "root"
        "conjunction": "and"
        "children": [
            {
                "type": "condition"
                "id": "not-archived"
                "property": "archived"
                "operator": "is-not-checked"
            }
            {
                "type": "condition"
                "id": "not-completed"
                "property": "status.isCompleted"
                "operator": "is-not-checked"
            }
        ]
        "sortKey": "due"
        "sortDirection": "asc"
        "groupKey": "none"
    }
    http post --content-type application/json $"($TASKNOTE_API_ENDPOINT)/tasks/query" --headers {Authorization: $"Bearer ($env.TASKNOTES_TOKEN)"} $query | get data.tasks
}

let status_colors = {
    "open": "blue_bold"
    "in-progress": "yellow_bold"
    "done": "green_bold"
}

let priority_colors = {
    "low": "green_bold"
    "normal": "yellow_bold"
    "high": "red_bold"
    "medium": "yellow_bold"
}

let status_icons = {
    "open": ""
    "in-progress": ""
    "done": ""
}

def tasknotes_format_task [task, idx?: int] {
    let status_color = $status_colors | get --optional $task.status | default "white_bold"
    let status_icon = $status_icons | get --optional $task.status | default "󰄮"
    if $idx != null {
        let status_icon = $"($idx) ($status_icon)"
    }
    let priority_color = $priority_colors | get --optional $task.priority | default "white_bold"
    let title = $"($status_icon) ($task.title)" | fill --width 60
    mut output = $"(ansi green_bold)($title) (ansi $status_color) ($task.status | str capitalize | fill -w 12) (ansi $priority_color) ($task.priority | str capitalize | fill -w 7)  "
    let due = $task | get --optional due
    let scheduled = $task | get --optional scheduled
    if $due != null {
        $output = $"($output) (ansi red_bold)󰨱 ($due | date humanize)"
    }
    if $scheduled != null {
        $output = $"($output) (ansi yellow_bold)󰃰 ($scheduled | date humanize)"
    }
    $"($output) (ansi reset)"
}

def tasknotes_format_task_minimal [task, idx?: int] {
    let status_color = $status_colors | get --optional $task.status | default "white_bold"
    let status_icon = $status_icons | get --optional $task.status | default "󰄮"
    if $idx != null {
        let status_icon = $"($idx) ($status_icon)"
    }
    let priority_color = $priority_colors | get --optional $task.priority | default "white_bold"
    mut title = $task.title
    if ($title | str length) > 37 {
        $title = ($title | str substring 0..37 | str trim -c " ") + "..."
    }
    mut output = $"(ansi $status_color)($status_icon) (ansi $priority_color)($title)" | fill --width 40
    let due = $task | get --optional due
    let scheduled = $task | get --optional scheduled
    if $due != null {
        $output = $"($output) (ansi red_bold)󰨱 (diff_from_now $due)"
    }
    if $scheduled != null {
        $output = $"($output) (ansi yellow_bold)󰃰 (diff_from_now $scheduled)"
    }
    $"($output) (ansi reset)"
}

def tasknotes_print_task_minimal [task, idx?: int] {
    tasknotes_format_task_minimal $task $idx | print
}

def tasknotes_print_task [task, idx?: int] {
    tasknotes_format_task $task $idx | print
}

def "tn create" [--subtask(-s), ...inp] {
    let input_str = $inp | str join " "
    mut taskDef = (
        http post --content-type application/json $"($TASKNOTE_API_ENDPOINT)/nlp/parse" {text : $input_str}
        | get data.taskData
    )
    if $subtask {
        let tasks = tasknotes_open
        let selected_task = (
            $tasks
            | input list -d {|t| tasknotes_format_task $t} "Select a parent task for the subtask: "
        )
        if $selected_task != null {
            $taskDef.projects = [$"[[($selected_task.id)]]"]
        } else {
            print "No parent task selected, creating a normal task instead."
        }
    }
    http post --content-type application/json $"($TASKNOTE_API_ENDPOINT)/tasks" --headers {Authorization: $"Bearer ($env.TASKNOTES_TOKEN)"} $taskDef | get data | each {|t| tasknotes_print_task $t}
}

def "tn queue" [] {
    let tasks = tasknotes_open | take 5
    for item in $tasks {
        tasknotes_print_task_minimal $item
    }
}

def "tn open" [--data(-d)] {
    let tasks = tasknotes_open
    if $data {
        return $tasks
    }
    for item in $tasks {
        tasknotes_print_task $item
    }
}

def "tn" [] {
    tn open
}

def "tn all" [--data(-d)] {
    let tasks = http get $"($TASKNOTE_API_ENDPOINT)/tasks" --headers {Authorization: $"Bearer ($env.TASKNOTES_TOKEN)"} | get data.tasks
    if $data {
        return $tasks
    }
    for item in $tasks {
        tasknotes_print_task $item
    }
}

def "tn move" [] {
    let tasks = tasknotes_open
    let selected_task = (
        $tasks
        | input list -d {|t| tasknotes_format_task $t} "Select a task to move: "
    )
    let new_status = (
        ["open", "in-progress", "done"]
        | input list -d {|e| $"(ansi ($status_colors | get $e))($status_icons | get $e) ($e | str capitalize)(ansi reset)"} "Enter the new status: "
    )
    let path = $"($TASKNOTE_API_ENDPOINT)/tasks/($selected_task | get id | url encode --all)"
    http put --content-type application/json $path --headers {Authorization: $"Bearer ($env.TASKNOTES_TOKEN)"} {status: $new_status} | get data | each {|t| tasknotes_print_task $t}
}

def "tn go" [] {
    let tasks = (tn open --data)
    let selected_task = (
        $tasks
        | input list -d {|t| tasknotes_format_task $t} "Select a task to open in Obsidian: "
    )
    ^open -a "Obsidian.app" $"obsidian://open?vault=The%20Codex&file=($selected_task.path | url encode --all)"
}
