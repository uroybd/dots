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

def 'jira sprint current' [] {
  return (jira sprint list --state=active --columns=ID --table --plain | detect columns | get 0.ID)
}

def 'jira sprint add' --wrapped [sprint_id?: string, ...issues: string] {
  ^jira sprint add ($sprint_id | default (jira sprint current)) ...$issues
}

def 'jira me sprint' --wrapped [...rest] {
  ^jira sprint list --current --assignee (jira me) --columns TYPE,KEY,SUMMARY,STATUS,PRIORITY,REPORTER ...$rest
}

def create-branch-name [key, summary] {
  let task_name = ($summary | str replace -a -r '\W+' "-" | str trim -c "-" | str lowercase)
  let branch_name = $"($key)_roy_($task_name)"
  let branch_name = ($branch_name | str substring 0..50 | str trim -c "-") # limit branch name to 50 characters
  return $branch_name
}

def 'jira me issues create' --wrapped [--no-sprint (-x), --git-branch-init (-g), ...rest] {
  let task_type = (["Task", "Bug", "Story", "Feature Request"] | input list "Issue Type")
  let summary = (input "Summary: ")
  let response = (^jira issue create --assignee (jira me) --raw --no-input -s $summary -t $task_type ...$rest)
  let key = ($response | from json | get key)
  print $"Issue created with key: ($key)"
  if not $no_sprint {
    ^jira sprint add (jira sprint current) $key
    print "...and added to current sprint"
  }
  if $git_branch_init {
    let branch_name = (create-branch-name $key $summary)
    print $"Creating git branch: ($branch_name)"
    git switch main; git pull
    ^git switch -c $branch_name
  }
}

def 'jira issues branch create' [key] {
  let vals = (^jira issue view --raw $key | from json | get key fields.summary)
  let summary = ($vals | get 1)
  let key = ($vals | get 0)
  let branch_name = (create-branch-name $key $summary)
  print $"Creating git branch: ($branch_name)"
  git switch main; git pull
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

def 'jira issues branch review' [--create-pr (-p)] {
  # Get the current branch name
  let current_branch = (git branch --show-current)
  if ($current_branch | str starts-with "FUL-") {
    let ticket = (get-ticket-from-branch)
    ^jira issue move $ticket "Code Review"
    if $create_pr {
      gh pr create --fill-first
      print "Created PR successfully"
      let pr_body = (gh pr view --json body | from json | get body)
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
    let epics = (^jira epic list --table --plain --columns KEY,SUMMARY,STATUS --status "TO DO" --status "In Progress" --order-by STATUS --reverse --csv | from csv)
    let selected_epic = ($epics | input list -d {|it| $"($it.KEY) [($it.STATUS)]: ($it.SUMMARY)"} --fuzzy)
    jira epic add $selected_epic.KEY $ticket
    print $"Added ticket ($ticket) to epic ($selected_epic.KEY)"
  } else {
    print "Current branch is not a FUL- branch, cannot determine Jira ticket."
  }
}
