# Dotfiles

My utterly useless dotfiles. The neovim config is fancy though. ;)

## Usage

This dotfiles are maintained by [Dotdrop](https://dotdrop.readthedocs.io/en/latest/). I've created profiles based on OS type I'm going to use (only MACOS is available for now).

To start using, clone the repository recursively:

```sh
git clone --recursive https://github.com/uroybd/dots.git
```

Then run dotdrop install:

```sh
dotdrop install
```

## Profiles

### MAC

The default profile is for Mac. It consists of the following:
- **gitconfig**: Three gitconfig files to provide a smooth git workflow, with [Delta](https://dandavison.github.io/delta/introduction.html) for diffing.
- **nu** and **nu-env**: [Nushell](https://www.nushell.sh/) and Nushell environment variables.
- **starship**: [A fancy prompt written in Rust](https://starship.rs/).
- **atuin**: [A command line history manager](https://atuin.sh/).
- **ssh**: SSH keys and configurations in a separate private repository.
- **nvim**: The [Neovim](https://neovim.io/) config, also available a separate public repository.
- **tmux**: [Tmux](https://github.com/tmux/tmux) configuration.
- **fonts**: Local font directory.
- **alacritty**: [Alacritty](https://alacritty.org/) configuration.
- **aerospace**: [Aerospace](https://nikitabobko.github.io/AeroSpace/guide)(A i3-like tiling window manager for MacOS) configuration.
