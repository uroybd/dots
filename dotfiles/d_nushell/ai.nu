# One-shot Claude calls for pipelines: data in on stdin, an answer (text, or data shaped by a schema) out.

# Claude setups by name: the config folder each uses. personal is Claude's default (~/.claude, with its state in
# ~/.claude.json), so it leaves CLAUDE_CONFIG_DIR unset; pointing that at ~/.claude makes claude look for
# ~/.claude/.claude.json instead.
const AI_SETUPS = {personal: null, fulflld: "~/.claude-fulflld"}

# The environment a Claude setup (AI_SETUPS) runs under: its CLAUDE_CONFIG_DIR, or nothing for personal.
def ai-setup-env [setup: string] {
    if $setup not-in $AI_SETUPS {
        error make {msg: $"Unknown Claude setup '($setup)'; known: ($AI_SETUPS | columns | str join ', ')"}
    }
    let config_dir = ($AI_SETUPS | get $setup)
    if $config_dir == null { {} } else { {CLAUDE_CONFIG_DIR: ($config_dir | path expand)} }
}

# Asks Claude once, without a session, and returns its answer: the text, or with --schema the structured output as
# data (always that shape). Piped input is passed on stdin. Errors when there is no answer, with Claude's message.
#   --setup     which Claude setup (AI_SETUPS) to run under; its CLAUDE.md, plugins and login apply
#   --system    instructions appended to Claude's system prompt
#   --schema    a JSON Schema (as a record) the answer must match
#   --tools     the tools it may use, all allowed without asking (e.g. [Read Grep Glob]); none by default
#   --mcp       connector (MCP) tools or whole servers it may use without asking (e.g. [mcp__claude_ai_Slack]); with
#               it, claude waits for connectors to load first, since in -p mode they load in the background and the
#               answer can come before their tools exist
#   --here      run in the current directory, so its project instructions and files are in reach; otherwise a temp
#               directory, so nothing about where you are leaks in
#   --model, --effort   passed on to claude
# Usage: open notes.md | ai ask "Summarize this" --model haiku
#        jira issue view FUL-1 --plain | ai ask "Estimate it" --schema {type: object, ...} --setup fulflld
def 'ai ask' [
    prompt: string
    --setup(-s): string = "personal"
    --system: string
    --schema: record
    --tools: list<string> = []
    --mcp: list<string> = []
    --here
    --model: string
    --effort: string
] {
    let input = $in
    ai-setup-env $setup | ignore
    let config_dir = ($AI_SETUPS | get $setup)
    let args = (
        [-p $prompt --no-session-persistence --output-format json]
        | append (if ($tools | is-empty) { [--tools ""] } else { [--tools ($tools | str join ",")] })
        | append (if ($tools ++ $mcp | is-empty) { [] } else { [--allowedTools ($tools ++ $mcp | str join ",")] })
        | append (if $system == null { [] } else { [--append-system-prompt $system] })
        | append (if $schema == null { [] } else { [--json-schema ($schema | to json -r)] })
        | append (if $model == null { [] } else { [--model $model] })
        | append (if $effort == null { [] } else { [--effort $effort] })
    )
    let workdir = if $here { $env.PWD } else { $env.TMPDIR? | default "/tmp" }

    let env_vars = (ai-setup-env $setup) | merge (if ($mcp | is-empty) { {} } else { {MCP_CONNECTION_NONBLOCKING: "0"} })
    let run = (
        with-env $env_vars {
            # personal must not inherit a CLAUDE_CONFIG_DIR from the calling shell either
            if $config_dir == null { hide-env -i CLAUDE_CONFIG_DIR }
            cd $workdir
            $input | ^claude ...$args | complete
        }
    )
    let resp = (try { $run.stdout | from json } catch { {is_error: true, result: ($run.stderr | str trim)} })
    let answer = if $schema == null { $resp | get -o result } else { $resp | get -o structured_output }
    if ($resp | get -o is_error | default false) or $answer == null {
        error make {msg: $"Claude gave no answer: ($resp | get -o result | default 'no result')"}
    }
    $answer
}

# Starts an interactive Claude session in the current directory, opening with `prompt`, and returns when it ends. For
# work that needs a conversation, such as approving changes before they are made.
#   --setup     which Claude setup (AI_SETUPS) to run under
#   --system    instructions appended to Claude's system prompt
#   --model, --effort   passed on to claude
# Usage: ai session "Review FUL-1 with me" --setup fulflld --system "You review Jira tickets."
def 'ai session' [
    prompt: string
    --setup(-s): string = "personal"
    --system: string
    --model: string
    --effort: string
] {
    let env_vars = (ai-setup-env $setup)
    let args = (
        [$prompt]
        | append (if $system == null { [] } else { [--append-system-prompt $system] })
        | append (if $model == null { [] } else { [--model $model] })
        | append (if $effort == null { [] } else { [--effort $effort] })
    )
    with-env $env_vars {
        if ($AI_SETUPS | get $setup) == null { hide-env -i CLAUDE_CONFIG_DIR }
        ^claude ...$args
    }
}
