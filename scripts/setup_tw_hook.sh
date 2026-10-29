#!/usr/bin/env bash
# Links the hooks that hooks.lua defines (d_task puts it in ~/.config/task) into task's hooks directory, with
# `meghnaad-hook install`. The program itself comes from the d_task pre_actions (brew install uroybd/tap/meghnaad-hook).
# Run it as a post action of d_task; it is safe to run again, and it has to run again once hooks.lua defines another hook.
#
# Overrides (environment): TW_CONFIG, TW_DATA and TW_HOOKS_DIR move the places below.

set -euo pipefail

TW_CONFIG="${TW_CONFIG:-$HOME/.config/task}"
TW_DATA="${TW_DATA:-$HOME/.task}"                # data.location in unix.rc
TW_HOOKS_DIR="${TW_HOOKS_DIR:-$TW_CONFIG/hooks}" # hooks.location in unix.rc
SCRIPT="$TW_CONFIG/hooks.lua"

[ -f "$SCRIPT" ] || { echo "[WARN] No hooks script at $SCRIPT (d_task provides it); nothing to set up." >&2; exit 0; }
command -v meghnaad-hook >/dev/null || { echo "[ERROR] meghnaad-hook is not installed (brew install uroybd/tap/meghnaad-hook)." >&2; exit 1; }

meghnaad-hook install "$SCRIPT" --data "$TW_DATA" --hooks "$TW_HOOKS_DIR"
