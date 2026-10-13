#!/usr/bin/env bash
# Claude Code status line (github.com/daniel3303/ClaudeCodeStatusLine): clone it and set "statusLine" in
# ~/.claude/settings.json. NOT run by install.sh: run it by hand (bash packages/claude-statusline.sh). Other keys of settings.json stay as they are. Safe to run again (it just pulls).
set -euo pipefail

DIR="$HOME/.claude/statusline"; SET="$HOME/.claude/settings.json"
command -v jq >/dev/null || { echo "jq is missing (pacman -S jq)" >&2; exit 1; }
mkdir -p "$HOME/.claude"
if [[ -d $DIR/.git ]]; then git -C "$DIR" pull --ff-only -q || echo "!!  could not update the status line"
else git clone -q https://github.com/daniel3303/ClaudeCodeStatusLine "$DIR" || { echo "!!  clone failed, run again later" >&2; exit 0; }; fi
chmod +x "$DIR/statusline.sh"

[[ -s $SET ]] || echo '{}' > "$SET"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
jq '.statusLine = {"type":"command","command":"~/.claude/statusline/statusline.sh"}' "$SET" > "$tmp" && cat "$tmp" > "$SET"
echo "Status line installed. Restart Claude Code."
