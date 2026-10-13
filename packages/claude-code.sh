#!/usr/bin/env bash
# Install Claude Code. Run it AFTER v2rayN is running with TUN (or with its proxy on 127.0.0.1:1081):
#   bash packages/claude-code.sh
# Direct connection first (TUN is on), then the v2rayN proxy as a fallback. Never installs half-way.
set -euo pipefail

PROXY_URL="${PROXY_URL:-http://127.0.0.1:10808}"     # v2rayN's local HTTP proxy (the one claude-xray in shellrc uses)
URL=https://claude.ai/install.sh

if command -v claude >/dev/null 2>&1 || [[ -x $HOME/.local/bin/claude ]]; then
  echo "Claude Code is already installed: $("${HOME}/.local/bin/claude" --version 2>/dev/null || claude --version)"
  exit 0
fi

reach() { curl -fsS --max-time 10 -o /dev/null "$@" "$URL"; }
curl_opts=()
if reach; then
  echo "==> $URL is reachable directly (TUN is up)"
elif reach -x "$PROXY_URL"; then
  echo "==> not reachable directly, using the v2rayN proxy $PROXY_URL"
  curl_opts=(-x "$PROXY_URL"); export HTTPS_PROXY=$PROXY_URL HTTP_PROXY=$PROXY_URL
else
  echo "!!  Cannot reach $URL, directly or through $PROXY_URL." >&2
  echo "!!  Start v2rayN first (TUN mode or system proxy), then run this again." >&2
  exit 1
fi

echo "==> Installing Claude Code"
curl -fsSL "${curl_opts[@]}" "$URL" | bash
echo
echo "Done. Open a new terminal (or: export PATH=\"\$HOME/.local/bin:\$PATH\"), then run:  claude"
