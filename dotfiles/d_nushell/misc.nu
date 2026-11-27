alias nuopen = open
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

const DOT_SUBMODULES = ["d_nvim" "d_claude"]

# Stage everything in the current repo, then commit and push if anything changed
def dot-commit-push [message: string] {
    git add .
    if (git status --porcelain | is-not-empty) {
        git commit -m $message
        git push
    }
}

# Commit with the arguments as the message in each submodule and push, then do the same in the main repository
def dotcommit [...msg] {
    let commit_message = $msg | str join " "
    for sub in $DOT_SUBMODULES {
        print $"Committing in ($sub) submodule..."
        do {
            cd $"./dotfiles/($sub)/"
            if $sub == "d_nvim" {
                ./readme-gen.nu
                print "Generated README.md for nvim submodule"
            }
            dot-commit-push $commit_message
        }
    }
    print "Committing in dotfiles...\nChecking for leaked secrets..."
    dotr scan --staged
    dot-commit-push $commit_message
}

def dotpull [] {
    git pull --recurse-submodules
    git submodule update --init
    for sub in $DOT_SUBMODULES {
        do {
            cd $"./dotfiles/($sub)/"
            git checkout main
            git pull
        }
    }
}

def "qn" [...inp] {
    let content = $"\n#### (date now | format date "%+")\n($inp | str join ' ')\n"
    run-external obsidian append path=Scratchpad/Jot.md content=($content)
}

def diff_from_now [dateinput] {
    let target_date = $dateinput | into datetime
    mut diff = $target_date - (date now) | into record | reject -o second millisecond microsecond | into duration | into string | split row " " | first
    # If diff ends with sec, then ignore it and return "0min"
    if $diff == null or $diff == "0sec" {
        echo "0min"
    } else {
        echo $diff
    }
}
