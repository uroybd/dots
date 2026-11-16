#!/usr/bin/env bash
# Installs the Claude Code plugins one Claude setup should have. Settings are not tracked in this repo, so each setup's
# plugin set lives here. Run it as a post action of that setup's CLAUDE.md package:
#
#   ./scripts/setup_claude_plugins.sh personal   # ~/.claude
#   ./scripts/setup_claude_plugins.sh fulflld    # ~/.claude-fulflld
#
# Each plugin is <plugin>@<marketplace>, plus :<owner/repo> when that marketplace lives on GitHub and has to be added
# first (the official marketplace comes with Claude Code). It only adds what is missing, so it is safe to run again.

set -euo pipefail

PAPERTHIN="paperthin@paperthin:LilMGenius/paperthin"

case "${1:-}" in
  personal)
    CONFIG_DIR="$HOME/.claude"
    PLUGINS=(
      typescript-lsp@claude-plugins-official
      rust-analyzer-lsp@claude-plugins-official
      gopls-lsp@claude-plugins-official
      lua-lsp@claude-plugins-official
      pyright-lsp@claude-plugins-official
      "$PAPERTHIN"
    )
    ;;
  fulflld)
    CONFIG_DIR="$HOME/.claude-fulflld"
    PLUGINS=(
      typescript-lsp@claude-plugins-official
      pyright-lsp@claude-plugins-official
      rust-analyzer-lsp@claude-plugins-official
      "$PAPERTHIN"
    )
    ;;
  *)
    echo "usage: $0 personal|fulflld" >&2
    exit 1
    ;;
esac

command -v claude >/dev/null || { echo "[WARN] claude is not installed; skipping plugin setup for $CONFIG_DIR." >&2; exit 0; }
command -v jq >/dev/null || { echo "[ERROR] jq is not installed." >&2; exit 1; }

# The default setup keeps its state in ~/.claude.json, outside ~/.claude; setting CLAUDE_CONFIG_DIR to ~/.claude would
# make claude look for ~/.claude/.claude.json instead. So set it only for the other setups.
if [ "$CONFIG_DIR" = "$HOME/.claude" ]; then
  unset CLAUDE_CONFIG_DIR
else
  export CLAUDE_CONFIG_DIR="$CONFIG_DIR"
fi

known_markets="$(claude plugin marketplace list --json | jq -r '.[].name')"
installed="$(claude plugin list --json | jq -r '.[].id')"

for spec in "${PLUGINS[@]}"; do
  plugin="${spec%%:*}"
  market="${plugin#*@}"
  repo=""
  [ "$spec" != "$plugin" ] && repo="${spec#*:}"

  if [ -n "$repo" ] && ! grep -qxF "$market" <<<"$known_markets"; then
    echo "[INFO] Adding marketplace $market ($repo) to $CONFIG_DIR"
    claude plugin marketplace add "$repo"
    known_markets+=$'\n'"$market"
  fi

  grep -qxF "$plugin" <<<"$installed" && continue
  echo "[INFO] Installing plugin $plugin into $CONFIG_DIR"
  claude plugin install "$plugin" || echo "[WARN] Could not install $plugin; install it by hand." >&2
done
echo "[INFO] Claude plugins are set up for $CONFIG_DIR."
