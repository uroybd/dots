# Dots

A personal dotfiles management repository using [dotr](https://github.com/jl-n/dotr) for managing development environment configurations across macOS systems.

## Overview

This repository contains configuration files and setup scripts for various development tools and applications, organized as packages that can be selectively installed and managed through dotr.

## Managed Applications

### Terminal & Shell
- **Nushell** - Modern shell with structured data pipelines
- **Starship** - Cross-shell prompt customization
- **Zellij** - Terminal workspace manager with layouts
- **Ghostty** - Terminal emulator with Maple Mono font

### Development Tools
- **Neovim** - Highly customized text editor with LSP, plugins, and extras
- **Git** - Version control with delta for diffs
- **Jira CLI** - Command-line interface for Jira

### Utilities
- **Atuin** - Shell history management
- **Yazi** - Terminal file manager
- **AeroSpace** - Tiling window manager for macOS

## Structure

- `config.toml` - Main dotr configuration defining packages and profiles
- `dotfiles/` - Source configurations for all managed applications
  - `d_*` - Directory-based configurations (e.g., `d_nvim`, `d_zellij`)
  - `f_*` - Individual file configurations (e.g., `f_gitconfig`, `f_config_nu`)

## Usage

Install packages using dotr with the `mac` profile:

```bash
dotr install mac
```

Install individual packages:

```bash
dotr install <package-name>
```

## Features

- Automated dependency management between packages
- Pre-installation actions for package managers (Homebrew)
- Post-installation setup scripts
- Platform-specific configurations (macOS)
- Package skip flags for selective installation

## Requirements

- macOS
- Homebrew package manager
- [dotr](https://github.com/jl-n/dotr) dotfiles manager
