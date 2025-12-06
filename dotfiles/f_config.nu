# Nushell Config File
#
# version = "0.88.1"

# For more information on defining custom themes, see
# https://www.nushell.sh/book/coloring_and_theming.html
# And here is the theme collection
# https://github.com/nushell/nu_scripts/tree/main/themes
let dark_theme = {
    # color for nushell primitives
    separator: white
    leading_trailing_space_bg: { attr: n } # no fg, no bg, attr none effectively turns this off
    header: green_bold
    empty: blue
    # Closures can be used to choose colors for specific values.
    # The value (in this case, a bool) is piped into the closure.
    # eg) {|| if $in { 'light_cyan' } else { 'light_gray' } }
    bool: light_cyan
    int: white
    filesize: cyan
    duration: white
    date: purple
    range: white
    float: white
    string: white
    nothing: white
    binary: white
    cell-path: white
    row_index: green_bold
    record: white
    list: white
    block: white
    hints: dark_gray
    search_result: {bg: red fg: white}
    shape_and: purple_bold
    shape_binary: purple_bold
    shape_block: blue_bold
    shape_bool: light_cyan
    shape_closure: green_bold
    shape_custom: green
    shape_datetime: cyan_bold
    shape_directory: cyan
    shape_external: cyan
    shape_externalarg: green_bold
    shape_external_resolved: light_yellow_bold
    shape_filepath: cyan
    shape_flag: blue_bold
    shape_float: purple_bold
    # shapes are used to change the cli syntax highlighting
    shape_garbage: { fg: white bg: red attr: b}
    shape_globpattern: cyan_bold
    shape_int: purple_bold
    shape_internalcall: cyan_bold
    shape_keyword: cyan_bold
    shape_list: cyan_bold
    shape_literal: blue
    shape_match_pattern: green
    shape_matching_brackets: { attr: u }
    shape_nothing: light_cyan
    shape_operator: yellow
    shape_or: purple_bold
    shape_pipe: purple_bold
    shape_range: yellow_bold
    shape_record: cyan_bold
    shape_redirection: purple_bold
    shape_signature: green_bold
    shape_string: green
    shape_string_interpolation: cyan_bold
    shape_table: blue_bold
    shape_variable: purple
    shape_vardecl: purple
}

let light_theme = {
    # color for nushell primitives
    separator: dark_gray
    leading_trailing_space_bg: { attr: n } # no fg, no bg, attr none effectively turns this off
    header: green_bold
    empty: blue
    # Closures can be used to choose colors for specific values.
    # The value (in this case, a bool) is piped into the closure.
    # eg) {|| if $in { 'dark_cyan' } else { 'dark_gray' } }
    bool: dark_cyan
    int: dark_gray
    filesize: cyan_bold
    duration: dark_gray
    date: purple
    range: dark_gray
    float: dark_gray
    string: dark_gray
    nothing: dark_gray
    binary: dark_gray
    cell-path: dark_gray
    row_index: green_bold
    record: dark_gray
    list: dark_gray
    block: dark_gray
    hints: dark_gray
    search_result: {fg: white bg: red}
    shape_and: purple_bold
    shape_binary: purple_bold
    shape_block: blue_bold
    shape_bool: light_cyan
    shape_closure: green_bold
    shape_custom: green
    shape_datetime: cyan_bold
    shape_directory: cyan
    shape_external: cyan
    shape_externalarg: green_bold
    shape_external_resolved: light_purple_bold
    shape_filepath: cyan
    shape_flag: blue_bold
    shape_float: purple_bold
    # shapes are used to change the cli syntax highlighting
    shape_garbage: { fg: white bg: red attr: b}
    shape_globpattern: cyan_bold
    shape_int: purple_bold
    shape_internalcall: cyan_bold
    shape_keyword: cyan_bold
    shape_list: cyan_bold
    shape_literal: blue
    shape_match_pattern: green
    shape_matching_brackets: { attr: u }
    shape_nothing: light_cyan
    shape_operator: yellow
    shape_or: purple_bold
    shape_pipe: purple_bold
    shape_range: yellow_bold
    shape_record: cyan_bold
    shape_redirection: purple_bold
    shape_signature: green_bold
    shape_string: green
    shape_string_interpolation: cyan_bold
    shape_table: blue_bold
    shape_variable: purple
    shape_vardecl: purple
}

# The default config record. This is where much of your global configuration is setup.
$env.config = {
    show_banner: false # true or false to enable or disable the welcome banner at startup

    ls: {
        use_ls_colors: true # use the LS_COLORS environment variable to colorize output
        clickable_links: true # enable or disable clickable links. Your terminal has to support links.
    }

    rm: {
        always_trash: false # always act as if -t was given. Can be overridden with -p
    }

    table: {
        mode: none # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
        index_mode: always # "always" show indexes, "never" show indexes, "auto" = show indexes when a table has "index" column
        show_empty: true # show 'empty list' and 'empty record' placeholders for command output
        padding: { left: 1, right: 1 } # a left right padding of each column in a table
        trim: {
            methodology: wrapping # wrapping or truncating
            wrapping_try_keep_words: true # A strategy used by the 'wrapping' methodology
            truncating_suffix: "..." # A suffix used by the 'truncating' methodology
        }
        header_on_separator: false # show header text on separator/border line
        # abbreviated_row_count: 10 # limit data rows from top and bottom after reaching a set point
    }

    error_style: "fancy" # "fancy" or "plain" for screen reader-friendly error messages

    # datetime_format determines what a datetime rendered in the shell would look like.
    # Behavior without this configuration point will be to "humanize" the datetime display,
    # showing something like "a day ago."
    datetime_format: {
        # normal: '%a, %d %b %Y %H:%M:%S %z'    # shows up in displays of variables or other datetime's outside of tables
        # table: '%m/%d/%y %I:%M:%S%p'          # generally shows up in tabular outputs such as ls. commenting this out will change it to the default human readable datetime format
    }

    explore: {
        status_bar_background: {fg: "#1D1F21", bg: "#C4C9C6"},
        command_bar_text: {fg: "#C4C9C6"},
        highlight: {fg: "black", bg: "yellow"},
        status: {
            error: {fg: "white", bg: "red"},
            warn: {}
            info: {}
        },
        table: {
            split_line: {fg: "#404040"},
            selected_cell: {bg: light_blue},
            selected_row: {},
            selected_column: {},
        },
    }

    history: {
        max_size: 100_000 # Session has to be reloaded for this to take effect
        sync_on_enter: true # Enable to share history between multiple sessions, else you have to close the session to write history to file
        file_format: "plaintext" # "sqlite" or "plaintext"
        isolation: false # only available with sqlite file_format. true enables history isolation, false disables it. true will allow the history to be isolated to the current session using up/down arrows. false will allow the history to be shared across all sessions.
    }

    completions: {
        case_sensitive: false # set to true to enable case-sensitive completions
        quick: true    # set this to false to prevent auto-selecting completions when only one remains
        partial: true    # set this to false to prevent partial filling of the prompt
        algorithm: "prefix"    # prefix or fuzzy
        external: {
            enable: true # set to false to prevent nushell looking into $env.PATH to find more suggestions, `false` recommended for WSL users as this look up may be very slow
            max_results: 100 # setting it lower can improve completion performance at the cost of omitting some options
        }
    }
    
    filesize: {
      unit: "binary"
    }

    cursor_shape: {
        emacs: line # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (line is the default)
        vi_insert: block # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (block is the default)
        vi_normal: underscore # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (underscore is the default)
    }

    color_config: $dark_theme # if you want a more interesting theme, you can replace the empty record with `$dark_theme`, `$light_theme` or another custom record
    footer_mode: auto
    float_precision: 2 # the precision for displaying floats in tables
    buffer_editor: "" # command that will be used to edit the current line buffer with ctrl+o, if unset fallback to $env.EDITOR and $env.VISUAL
    use_ansi_coloring: true
    bracketed_paste: true # enable bracketed paste, currently useless on windows
    edit_mode: emacs # emacs, vi
    shell_integration: {} # enables terminal shell integration. Off by default, as some terminals have issues with this.
    render_right_prompt_on_last_line: false # true or false to enable or disable right prompt to be rendered on last line of the prompt.
    use_kitty_protocol: false # enables keyboard enhancement protocol implemented by kitty console, only if your terminal support this.
    highlight_resolved_externals: false # true enables highlighting of external commands in the repl resolved by which.

    hooks: {
        pre_prompt: [{ null }] # run before the prompt is shown
        pre_execution: [{ null }] # run before the repl input is run
        env_change: {
            PWD: [{ |before, after|
        let is_node_dir = [.nvmrc .node-version] | path exists | any { |it| $it }
        if ('FNM_DIR' in $env) and $is_node_dir {
          fnm use # Personally I prefer to use fnm --log-level=quiet use
        }
      }] # run if the PWD environment is different since the last repl input
        }
        display_output: "if (term size).columns >= 100 { table -e } else { table }" # run to display the output of a pipeline
        command_not_found: { null } # return an error message when a command is not found
    }

    menus: [
        # Configuration for default nushell menus
        # Note the lack of source parameter
        {
            name: completion_menu
            only_buffer_difference: false
            marker: "| "
            type: {
                layout: columnar
                columns: 4
                col_width: 20     # Optional value. If missing all the screen width is used to calculate column width
                col_padding: 2
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
        {
            name: history_menu
            only_buffer_difference: true
            marker: "? "
            type: {
                layout: list
                page_size: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
        {
            name: help_menu
            only_buffer_difference: true
            marker: "? "
            type: {
                layout: description
                columns: 4
                col_width: 20     # Optional value. If missing all the screen width is used to calculate column width
                col_padding: 2
                selection_rows: 4
                description_rows: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
    ]

    keybindings: [
        {
            name: completion_menu
            modifier: none
            keycode: tab
            mode: [emacs vi_normal vi_insert]
            event: {
                until: [
                    { send: menu name: completion_menu }
                    { send: menunext }
                    { edit: complete }
                ]
            }
        }
        {
            name: history_menu
            modifier: control
            keycode: char_r
            mode: [emacs, vi_insert, vi_normal]
            event: { send: menu name: history_menu }
        }
        {
            name: help_menu
            modifier: none
            keycode: f1
            mode: [emacs, vi_insert, vi_normal]
            event: { send: menu name: help_menu }
        }
        {
            name: completion_previous_menu
            modifier: shift
            keycode: backtab
            mode: [emacs, vi_normal, vi_insert]
            event: { send: menuprevious }
        }
        {
            name: next_page_menu
            modifier: control
            keycode: char_x
            mode: emacs
            event: { send: menupagenext }
        }
        {
            name: undo_or_previous_page_menu
            modifier: control
            keycode: char_z
            mode: emacs
            event: {
                until: [
                    { send: menupageprevious }
                    { edit: undo }
                ]
            }
        }
        {
            name: escape
            modifier: none
            keycode: escape
            mode: [emacs, vi_normal, vi_insert]
            event: { send: esc }    # NOTE: does not appear to work
        }
        {
            name: cancel_command
            modifier: control
            keycode: char_c
            mode: [emacs, vi_normal, vi_insert]
            event: { send: ctrlc }
        }
        {
            name: quit_shell
            modifier: control
            keycode: char_d
            mode: [emacs, vi_normal, vi_insert]
            event: { send: ctrld }
        }
        {
            name: clear_screen
            modifier: control
            keycode: char_l
            mode: [emacs, vi_normal, vi_insert]
            event: { send: clearscreen }
        }
        {
            name: search_history
            modifier: control
            keycode: char_q
            mode: [emacs, vi_normal, vi_insert]
            event: { send: searchhistory }
        }
        {
            name: open_command_editor
            modifier: control
            keycode: char_o
            mode: [emacs, vi_normal, vi_insert]
            event: { send: openeditor }
        }
        {
            name: move_up
            modifier: none
            keycode: up
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: menuup}
                    {send: up}
                ]
            }
        }
        {
            name: move_down
            modifier: none
            keycode: down
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: menudown}
                    {send: down}
                ]
            }
        }
        {
            name: move_left
            modifier: none
            keycode: left
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: menuleft}
                    {send: left}
                ]
            }
        }
        {
            name: move_right_or_take_history_hint
            modifier: none
            keycode: right
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: historyhintcomplete}
                    {send: menuright}
                    {send: right}
                ]
            }
        }
        {
            name: move_one_word_left
            modifier: control
            keycode: left
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movewordleft}
        }
        {
            name: move_one_word_right_or_take_history_hint
            modifier: control
            keycode: right
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: historyhintwordcomplete}
                    {edit: movewordright}
                ]
            }
        }
        {
            name: move_to_line_start
            modifier: none
            keycode: home
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movetolinestart}
        }
        {
            name: move_to_line_start
            modifier: control
            keycode: char_a
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movetolinestart}
        }
        {
            name: move_to_line_end_or_take_history_hint
            modifier: none
            keycode: end
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: historyhintcomplete}
                    {edit: movetolineend}
                ]
            }
        }
        {
            name: move_to_line_end_or_take_history_hint
            modifier: control
            keycode: char_e
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: historyhintcomplete}
                    {edit: movetolineend}
                ]
            }
        }
        {
            name: move_to_line_start
            modifier: control
            keycode: home
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movetolinestart}
        }
        {
            name: move_to_line_end
            modifier: control
            keycode: end
            mode: [emacs, vi_normal, vi_insert]
            event: {edit: movetolineend}
        }
        {
            name: move_up
            modifier: control
            keycode: char_p
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: menuup}
                    {send: up}
                ]
            }
        }
        {
            name: move_down
            modifier: control
            keycode: char_t
            mode: [emacs, vi_normal, vi_insert]
            event: {
                until: [
                    {send: menudown}
                    {send: down}
                ]
            }
        }
        {
            name: delete_one_character_backward
            modifier: none
            keycode: backspace
            mode: [emacs, vi_insert]
            event: {edit: backspace}
        }
        {
            name: delete_one_word_backward
            modifier: control
            keycode: backspace
            mode: [emacs, vi_insert]
            event: {edit: backspaceword}
        }
        {
            name: delete_one_character_forward
            modifier: none
            keycode: delete
            mode: [emacs, vi_insert]
            event: {edit: delete}
        }
        {
            name: delete_one_character_forward
            modifier: control
            keycode: delete
            mode: [emacs, vi_insert]
            event: {edit: delete}
        }
        {
            name: delete_one_character_forward
            modifier: control
            keycode: char_h
            mode: [emacs, vi_insert]
            event: {edit: backspace}
        }
        {
            name: delete_one_word_backward
            modifier: control
            keycode: char_w
            mode: [emacs, vi_insert]
            event: {edit: backspaceword}
        }
        {
            name: move_left
            modifier: none
            keycode: backspace
            mode: vi_normal
            event: {edit: moveleft}
        }
        {
            name: newline_or_run_command
            modifier: none
            keycode: enter
            mode: emacs
            event: {send: enter}
        }
        {
            name: move_left
            modifier: control
            keycode: char_b
            mode: emacs
            event: {
                until: [
                    {send: menuleft}
                    {send: left}
                ]
            }
        }
        {
            name: move_right_or_take_history_hint
            modifier: control
            keycode: char_f
            mode: emacs
            event: {
                until: [
                    {send: historyhintcomplete}
                    {send: menuright}
                    {send: right}
                ]
            }
        }
        {
            name: redo_change
            modifier: control
            keycode: char_g
            mode: emacs
            event: {edit: redo}
        }
        {
            name: undo_change
            modifier: control
            keycode: char_z
            mode: emacs
            event: {edit: undo}
        }
        {
            name: paste_before
            modifier: control
            keycode: char_y
            mode: emacs
            event: {edit: pastecutbufferbefore}
        }
        {
            name: cut_word_left
            modifier: control
            keycode: char_w
            mode: emacs
            event: {edit: cutwordleft}
        }
        {
            name: cut_line_to_end
            modifier: control
            keycode: char_k
            mode: emacs
            event: {edit: cuttoend}
        }
        {
            name: cut_line_from_start
            modifier: control
            keycode: char_u
            mode: emacs
            event: {edit: cutfromstart}
        }
        {
            name: swap_graphemes
            modifier: control
            keycode: char_t
            mode: emacs
            event: {edit: swapgraphemes}
        }
        {
            name: move_one_word_left
            modifier: alt
            keycode: left
            mode: emacs
            event: {edit: movewordleft}
        }
        {
            name: move_one_word_right_or_take_history_hint
            modifier: alt
            keycode: right
            mode: emacs
            event: {
                until: [
                    {send: historyhintwordcomplete}
                    {edit: movewordright}
                ]
            }
        }
        {
            name: move_one_word_left
            modifier: alt
            keycode: char_b
            mode: emacs
            event: {edit: movewordleft}
        }
        {
            name: move_one_word_right_or_take_history_hint
            modifier: alt
            keycode: char_f
            mode: emacs
            event: {
                until: [
                    {send: historyhintwordcomplete}
                    {edit: movewordright}
                ]
            }
        }
        {
            name: delete_one_word_forward
            modifier: alt
            keycode: delete
            mode: emacs
            event: {edit: deleteword}
        }
        {
            name: delete_one_word_backward
            modifier: alt
            keycode: backspace
            mode: emacs
            event: {edit: backspaceword}
        }
        {
            name: delete_one_word_backward
            modifier: alt
            keycode: char_m
            mode: emacs
            event: {edit: backspaceword}
        }
        {
            name: cut_word_to_right
            modifier: alt
            keycode: char_d
            mode: emacs
            event: {edit: cutwordright}
        }
        {
            name: upper_case_word
            modifier: alt
            keycode: char_u
            mode: emacs
            event: {edit: uppercaseword}
        }
        {
            name: lower_case_word
            modifier: alt
            keycode: char_l
            mode: emacs
            event: {edit: lowercaseword}
        }
        {
            name: capitalize_char
            modifier: alt
            keycode: char_c
            mode: emacs
            event: {edit: capitalizechar}
        }
    ]
}

def nuopen [arg, --raw (-r)] { if $raw { open -r $arg } else { open $arg } }
alias open = ^open
alias neovide = ^open -a NeoVide.app

source ~/.nu/contrib/nu_scripts/custom-completions/git/git-completions.nu
source ~/.nu/contrib/nu_scripts/custom-completions/cargo/cargo-completions.nu
source ~/.nu/contrib/nu_scripts/custom-completions/pdm/pdm-completions.nu
source ~/.nu/contrib/nu_scripts/custom-completions/rustup/rustup-completions.nu
source ~/.nu/contrib/nu_scripts/custom-completions/yarn/yarn-v4-completions.nu
source ~/.nu/contrib/nu_scripts/custom-completions/vscode/vscode-completions.nu
use ~/.cache/starship/init.nu

source ~/.local/share/atuin/init.nu


if not (which fnm | is-empty) {
  ^fnm env --json | from json | load-env
  $env.PATH = ($env.PATH | split row (char esep) | prepend $"($env.FNM_MULTISHELL_PATH)/bin")
}


alias comm = cz c -a
alias neot = tmux split-window -bv -l 68% 'nvim ./'

def ssscode [path: string, title: string] {
  ^sss_code --fonts "Maple Mono=12" -n -o ./output.png --radius 0 --padding-x 0 --padding-y 0 --window-title=$title $path
}

def "git syncus" [] {
  git switch upstream-main
  git pull
  git switch main
  git rebase upstream-main
  git push
}

def cbr2cbz [arg] {
    let file_name  = $arg | str replace cbr cbz
    let output = $"(pwd)/($file_name)"
    echo $output
    # unrar cbr to ./temp
    unrar x $arg ./temp/
    # zip ./temp to cbz
    cd ./temp
    ^zip -r $output ./* -x "*.DS_Store" -x "__MACOSX"
    # remove ./temp
    cd ../
    rm -rf ./temp
}


def get_cl_tasks [] {
  let USER_ID = ($env.CLICK_UP_TOKEN | split row "_" | get 1)
  let tasks = (http get --raw --headers [Authorization $env.CLICK_UP_TOKEN] $"https://api.clickup.com/api/v2/team/($env.CLICK_UP_TEAM)/task?substasks=true&statuses[]=to%20do&statuses[]=in%20progress&assignees[]=($USER_ID)" | from json | get tasks | each {|t| {id: $t.id, name: $"($t.name) [($t.project.name)]"}})
  return $tasks
}


def cltm [] {
  let existing = (http get --raw --headers [Authorization $env.CLICK_UP_TOKEN] $"https://api.clickup.com/api/v2/team/($env.CLICK_UP_TEAM)/time_entries/current" | from json | get data)
  if ($existing != null) {
    if ($existing.task == null) {
      print "Stopping timer"
    } else {
      print $"A timer is already running for the task ($existing.task.name)"
    }
    let should_stop = (["yes", "no"] | input list "Do you want to stop the timer?")
    if $should_stop == "yes" {
      print "Stopping the timer..."
      http post --raw --content-type application/json --headers [Authorization $env.CLICK_UP_TOKEN] $"https://api.clickup.com/api/v2/team/($env.CLICK_UP_TEAM)/time_entries/stop" {}
    }
    return
  }
  let current_branch = (git branch --show-current)
  print $"Current Branch: $current_branch"
  mut task_id = ""
  # Check if branch name starts with 'CU-'
  if ($current_branch | str starts-with "CU-") {
    $task_id = ($current_branch | split row "_" | get 0 | split row "-" | get 1)
    let change_cond = (["no", "yes"] | input list $"Task ID Detected: ($task_id), Change?")
    if $change_cond == "yes" {
      let tasks = (get_cl_tasks)
      let selected_task = ($tasks | input list -d name "Enter your Task ID: ")
      $task_id = $selected_task.id
    }
  } else {
    let tasks = (get_cl_tasks)
    let selected_task = ($tasks | input list -d name "Enter your Task ID: ")
    $task_id = $selected_task.id
  }
  print $"Starting ClickUp Timer of ($task_id)..."
  let url = $"https://api.clickup.com/api/v2/team/($env.CLICK_UP_TEAM)/time_entries/start"
  http post --raw --content-type application/json --headers [Authorization $env.CLICK_UP_TOKEN] $url { "tid": $task_id, billable: false }
}

def tnvim [arg] {
  let p = ($arg | path expand)
  zellij action new-tab -l tnvim -c $p
}

# This function will take the argument as commit message and commit it first to the sub repositories, push them, and then commit it to the main repository
def dotcommit [...msg] {
  # concat args to create commit message
  let commit_message = ($msg | str join " ")
  print "Commiting in neovim submodule..."
  cd ./dotfiles/d_nvim/
  git add *
  if (git status --porcelain | length) > 0 {
  git commit -m $commit_message
  git push 
  }
  cd ../../
  print "Commiting in dotfiles..."
  git add *
  if (git status --porcelain | length) > 0 {
  git commit -m $commit_message
  git push 
  }
}

def dotpull [] {
  git pull --recurse-submodules
  cd ./dotfiles/nvim/
  git checkout main
  git pull
  cd ../../
}

def reviewpr [prnum] {
  git fetch upstream $"pull/($prnum)/head:pr-($prnum)"
  git checkout $"pr-($prnum)"
}

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
  let task_name = ($summary | str replace -a -r '\W+' "-" | str trim -c "-" | str downcase)
  let branch_name = $"($key)_($task_name)"
  let branch_name = ($branch_name | str substring 0..50) # limit branch name to 50 characters
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
    git switch upstream-main; git pull; git switch main; git rebase upstream-main; git push
    ^git switch -c $branch_name
  }
}

def 'jira issues branch create' [key] {
  let vals = (^jira issue view --raw $key | from json | get key fields.summary)
  let summary = ($vals | get 1)
  let key = ($vals | get 0)
  let branch_name = (create-branch-name $key $summary)
  print $"Creating git branch: ($branch_name)"
  git switch upstream-main; git pull; git switch main; git rebase upstream-main; git push
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
  return $"https://fulflld.atlassian.net/browse/($ticket)"
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
