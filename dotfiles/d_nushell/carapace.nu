$env.PATH = (
    $env.PATH
    | split row (char esep)
    | where { $in != "/Users/meghnaad/Library/Application Support/carapace/bin" }
    | prepend "/Users/meghnaad/Library/Application Support/carapace/bin"
)

def --env get-env [name] {
    $env | get $name
}
def --env set-env [name, value] { load-env { $name: $value } }
def --env unset-env [name] { hide-env $name }

let carapace_completer = {|place|
    load-env {
  	CARAPACE_SHELL_BUILTINS: (help commands | where category != "" | get name | each { split row " " | first } | uniq  | str join "\n")
  	CARAPACE_SHELL_FUNCTIONS: (help commands | where category == "" | get name | each { split row " " | first } | uniq  | str join "\n")
  }

    mut main_command = $place.command | first

    # if the current command is an alias, get it's expansion
    let expanded_alias = scope aliases | where name == ($place.command | first ) | get -o expansion
    if $expanded_alias != null {
        $main_command = ($expanded_alias | split row " " | first)
    }

    carapace $main_command nushell ...$place.command | from json
}

mut current = ($env | default {} config).config | default {} completions
$current.completions = ($current.completions | default {} external)
$current.completions.external = ($current.completions.external
| default true enable
# backwards compatible workaround for default, see nushell #15654
| upsert completer { if $in == null { $carapace_completer } else { $in } })

$env.config = $current
