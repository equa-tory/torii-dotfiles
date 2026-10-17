#!/usr/bin/env bash
# Claude Code status line (github.com/daniel3303/ClaudeCodeStatusLine): clone it and set "statusLine" in
# ~/.claude/settings.json. install.sh runs it; run it by hand to repair or reinstall (bash packages/claude-statusline.sh).
# Other keys of settings.json stay as they are. Safe to run again. It is pinned to the version in use now (STATUSLINE_REF,
# a commit or branch; STATUSLINE_REF=main follows the latest).
set -euo pipefail

DIR="$HOME/.claude/statusline"; SET="$HOME/.claude/settings.json"
REF="${STATUSLINE_REF:-5da9695}"
for c in jq git curl; do command -v "$c" >/dev/null || { echo "$c is missing (pacman -S $c)" >&2; exit 1; }; done
mkdir -p "$HOME/.claude"
if [[ -d $DIR/.git ]]; then git -C "$DIR" fetch -q origin || echo "!!  could not reach GitHub, keeping what is there"
else git clone -q https://github.com/daniel3303/ClaudeCodeStatusLine "$DIR" || { echo "!!  clone failed, run again later" >&2; exit 0; }; fi
git -C "$DIR" checkout -q "$REF" 2>/dev/null || git -C "$DIR" checkout -q "origin/$REF" || echo "!!  could not switch to $REF"
chmod +x "$DIR/statusline.sh"

[[ -s $SET ]] || echo '{}' > "$SET"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
jq '.statusLine = {"type":"command","command":"~/.claude/statusline/statusline.sh"}' "$SET" > "$tmp" && cat "$tmp" > "$SET"
echo "Status line installed. Restart Claude Code."
