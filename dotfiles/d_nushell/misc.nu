def nuopen [arg, --raw(-r)] {
    if $raw { open -r $arg } else { open $arg }
}
alias open = ^open
alias neovide = ^open -a NeoVide.app
alias comm = cz c -a
alias neot = tmux split-window -bv -l 68% 'nvim ./'

alias ssscode = sss_code --fonts "Maple Mono=12" -n --radius 0 --padding-x 0 --padding-y 0

def "git syncus" [] {
    git switch main
    git pull
}

def cbr2cbz [arg] {
    let file_name = $arg | str replace cbr cbz
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

def tnvim [arg] {
    let p = $arg | path expand
    zellij action new-tab -l tnvim -c $p
}

# This function will take the argument as commit message and commit it first to the sub repositories, push them, and then commit it to the main repository
def dotcommit [...msg] {
    # concat args to create commit message
    let commit_message = $msg | str join " "
    print "Commiting in neovim submodule..."
    cd ./dotfiles/d_nvim/
    ./readme-gen.nu and echo "Generated README.md for nvim submodule"
    git add .
    if (git status --porcelain | length) > 0 {
        git commit -m $commit_message
        git push
    }
    cd ../../
    print "Commiting in dotfiles..."
    git add .
    if (git status --porcelain | length) > 0 {
        git commit -m $commit_message
        git push
    }
}

def dotpull [] {
    git pull --recurse-submodules
    cd ./dotfiles/d_nvim/
    git checkout main
    git pull
    cd ../../
}

def "qn" [...inp] {
    let content = $"\n#### (date now | format date "%+")\n($inp | str join ' ')\n"
    run-external obsidian append path=Scratchpad/Jot.md content=($content)
}

# Render a commit hash (piped in) as a grid of ANSI-colored blocks.
# Each hex character maps to one of the terminal theme's 16 ANSI colors,
# so equal hashes always look the same. --cols sets the blocks per row (default
# 8) and --block the string drawn for each cell (default "██"). --block may also
# be a comma-separated list, in which case the glyph is picked by the char's hex
# value (mod list length), just like the color. Since one ANSI color usually
# matches the terminal background, --bg names that color index and --bg-with the
# color drawn in its place (default: 0 -> 8). --offset left-pads every row with
# that many spaces.
def "commitart" [
    --cols: int = 8
    --block: string = "██"
    --bg: int = 0
    --bg-with: int = 8
    --offset: int = 0
] {
    let chars = $in | into string | split chars
    let blocks = $block | split row "," | each { str trim }
    let pad = 0..<$offset | each { " " } | str join

    mut out = ""
    mut i = 0
    for c in $chars {
        if ($i mod $cols) == 0 {
            $out = $out + $pad
        }
        let raw = $c | into int --radix 16
        let v = (if $raw == $bg { $bg_with } else { $raw })
        let glyph = $blocks | get ($raw mod ($blocks | length))
        $out = $out + (ansi -e $"38;5;($v)m") + $glyph + (ansi reset)
        $i = $i + 1
        if ($i mod $cols) == 0 {
            $out = $out + "\n"
        }
    }
    $out | str trim --right --char "\n"
}

def "commitart repo" [
    --cols: int = 8
    --block: string = "██"
    --bg: int = 0
    --bg-with: int = 8
    --offset: int = 0
] {

    # Return early if not in a git repository (git exits 128 here, so use complete)
    let check = do { git rev-parse --is-inside-work-tree } | complete
    if $check.exit_code != 0 or ($check.stdout | str trim) != "true" {
        return
    }
    git rev-parse HEAD | commitart --cols $cols --block $block --bg $bg --bg-with $bg_with --offset $offset
}
