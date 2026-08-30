

def todotxt-parse-title [task: string] {
  $task
    | str trim
    | str replace --regex '^x\s+' ''                 # completion marker
    | str replace --regex '^\([A-Z]\)\s+' ''         # priority
    | str replace --regex '^\d{4}-\d{2}-\d{2}\s+' '' # completion / creation date
    | str replace --regex '^\d{4}-\d{2}-\d{2}\s+' '' # creation date (completed tasks)
    | split row --regex '\s+'
    | where $it != ''
    | where $it !~ '^\([A-Z]\)$'  # stray priority token
    | where $it !~ '^[+@]\S+'    # +projects and @contexts
    | where $it !~ '^\S+:\S+$'   # key:value attributes (due:, t:, pri:, ...)
    | str join ' '
    | str trim
}

let todotxt_priority_colors = {
  "A": "rb",
  "B": "yb",
  "C": "gb",
  "D": "bb",
  "E": "mb",
  "F": "cb",
  "G": "wb",
}

def todotxt-render-task [task: record] {
  mut color = "wb"
  if ($task.priority != null) {
    $color = ($todotxt_priority_colors | get ($task.priority | str uppercase) | default "wb")
  }
  mut title = $"($task.n). (todotxt-parse-title $task.raw)"
  if ($title | str length) > 40 {
    $title = ($title | str substring 0..40 | str trim -c " ") + "..."
  }
  if ($task.rec != null) {
    $title = $"($title) (ansi gb)(ansi $color)(ansi reset)"
  }
  if ($task.due != null) {
    $title = $"($title) (ansi $color)@($task.due)(ansi reset)"
  }
  print $"  (ansi $color)($title)(ansi reset)"
}

def "tuxedo queue" [count?: int, --pad] {
  let threshold = (date now) + 7day
  mut tasks = tuxedo ls --json
                | from json
                | where {|$x| $x.done == false and ($x.due == null or ($x.due | into datetime --format "%Y-%m-%d") <= $threshold)}
                | sort-by {|$x| ($x.priority | default "Z") + ($x.due | default "9999-12-31") + ($x.created | default ("9999-12-31" | into datetime --format "%Y-%m-%d"))}

  if $count != null {
    $tasks = ($tasks | first $count)
  }
  for $task in $tasks {
    todotxt-render-task $task
  }
  # print blank lines to match total 5 lines of output
  if ($pad and $count != null) {
    let remaining = $count - ($tasks | length)
    for $i in 0..$remaining {
      print ""
    }
  }
}
