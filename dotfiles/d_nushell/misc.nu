def nuopen [arg, --raw (-r)] { if $raw { open -r $arg } else { open $arg } }
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
  cd ./dotfiles/nvim/
  git checkout main
  git pull
  cd ../../
}


def "qn" [...inp] {
  let content = $"\n#### (date now | format date "%+")\n($inp | str join ' ')\n"
  run-external obsidian append path=Scratchpad/Jot.md content=($content)
}


