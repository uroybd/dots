def 'gh pr reviewers add' [] {
  let users = (^gh api repos/{owner}/{repo}/collaborators | from json | get login)
  let selected_users = ($users | input list --multi --fuzzy)
  if ($selected_users | length) > 0 {
    ^gh pr edit --add-reviewer ($selected_users | str join ",")
  }
}

def 'gh pr reviewers remove' [] {
  let users = (^gh api repos/{owner}/{repo}/collaborators | from json | get login)
  let selected_users = ($users | input list --multi --fuzzy)
  if ($selected_users | length) > 0 {
    ^gh pr edit --remove-reviewer ($selected_users | str join ",")
  }
}
