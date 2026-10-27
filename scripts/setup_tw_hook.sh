#!/usr/bin/env bash
# Installs meghnaad-hook (the Lua hooks script of Meghnaad, as hooks for the real `task`) and links it into task's hooks.
#
# It downloads the build for this machine from the latest GitHub release of uroybd/Meghnaad into task's hooks directory
# (no clone, no Rust; d_task ignores it there, so a deploy does not clean it away) and runs `meghnaad-hook install` on
# the hooks.lua that d_task puts in ~/.config/task. Run it as a post action of d_task; it is safe to run again: it only
# downloads when there is a newer release, and re-links when hooks.lua defines other hooks.
#
# Overrides (environment): MEGHNAAD_HOOK_VERSION=v0.6.34 pins a release; TW_CONFIG, TW_DATA, TW_HOOKS_DIR and BIN_DIR move
# the places below.

set -euo pipefail

REPO="uroybd/Meghnaad"
TW_CONFIG="${TW_CONFIG:-$HOME/.config/task}"
TW_DATA="${TW_DATA:-$HOME/.task}"                    # data.location in unix.rc
TW_HOOKS_DIR="${TW_HOOKS_DIR:-$TW_CONFIG/hooks}"     # hooks.location in unix.rc
BIN_DIR="${BIN_DIR:-$TW_HOOKS_DIR}"                  # not an on-* name, so task never runs it by itself
SCRIPT="$TW_CONFIG/hooks.lua"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/meghnaad-hook"
BIN="$BIN_DIR/meghnaad-hook"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
die() { echo "[ERROR] $*" >&2; exit 1; }

# The release build for this machine: the target triple in the asset's name.
target() {
    case "$(uname -s)-$(uname -m)" in
        Darwin-arm64) echo "aarch64-apple-darwin" ;;
        Darwin-x86_64) echo "x86_64-apple-darwin" ;;
        Linux-aarch64 | Linux-arm64) echo "aarch64-unknown-linux-gnu" ;;
        Linux-x86_64) echo "x86_64-unknown-linux-gnu" ;;
        *) die "No meghnaad-hook build for $(uname -s) $(uname -m)." ;;
    esac
}

# The tag of the latest release, from where github.com sends /releases/latest (no API, no jq).
latest_tag() {
    local url
    url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")" || return 1
    echo "${url##*/}"
}

download() {
    local tag="$1" tmp name
    name="meghnaad-hook-${tag#v}-$(target)"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    curl -fsSL -o "$tmp/$name.tar.gz" "https://github.com/$REPO/releases/download/$tag/$name.tar.gz" ||
        { warn "Could not download $name.tar.gz from release $tag."; return 1; }
    tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
    mkdir -p "$BIN_DIR" "$STATE_DIR"
    # Copied beside the target and moved over it, so a running hook never sees half a file.
    cp "$tmp/$name/meghnaad-hook" "$BIN.new"
    chmod +x "$BIN.new"
    mv -f "$BIN.new" "$BIN"
    echo "$tag" >"$STATE_DIR/version"
    info "Installed meghnaad-hook $tag in $BIN_DIR."
}

[ -f "$SCRIPT" ] || { warn "No hooks script at $SCRIPT (d_task provides it); nothing to set up."; exit 0; }

# 1. The program: the pinned or latest release, unless that is already what is installed.
tag="${MEGHNAAD_HOOK_VERSION:-}"
[ -n "$tag" ] || tag="$(latest_tag)" || tag=""
installed="$(cat "$STATE_DIR/version" 2>/dev/null || true)"
if [ -z "$tag" ]; then
    [ -x "$BIN" ] || die "Could not find the latest release of $REPO, and meghnaad-hook is not installed."
    warn "Could not reach GitHub; keeping the installed meghnaad-hook ${installed:-(unknown version)}."
elif [ "$tag" = "$installed" ] && [ -x "$BIN" ]; then
    info "meghnaad-hook $tag is already installed."
else
    download "$tag" || [ -x "$BIN" ] || die "meghnaad-hook could not be installed."
fi

# 2. The hooks script has to load before anything is linked.
"$BIN" check "$SCRIPT" || die "$SCRIPT does not load; no hooks were linked."

# 3. Link the hooks it defines where task looks for them (hooks.location is in an included file, which the program does
#    not read, so it is given here), and ~/.task/hooks.lua -> the script, which is where a hook looks for it.
"$BIN" install "$SCRIPT" --data "$TW_DATA" --hooks "$TW_HOOKS_DIR"

# A release from before --hooks would have linked them under the data directory instead.
if [ -n "$(find "$TW_DATA/hooks" -name '*.meghnaad' 2>/dev/null)" ] && [ -z "$(find "$TW_HOOKS_DIR" -name '*.meghnaad' 2>/dev/null)" ]; then
    die "This meghnaad-hook is too old (it has no --hooks); run again once a newer release is out."
fi

# Hooks of other kinds in the same directory keep running beside it.
others="$(find "$TW_HOOKS_DIR" -maxdepth 1 \( -type f -o -type l \) -name 'on-*' ! -name '*.meghnaad' ! -name '*.dotrbak' 2>/dev/null || true)"
if [ -n "$others" ]; then
    warn "Other hooks in $TW_HOOKS_DIR still run alongside the Lua ones:"
    echo "$others" | sed 's/^/         /' >&2
fi
