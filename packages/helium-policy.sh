#!/usr/bin/env bash
# Let torii-theme color the Helium browser through a managed policy (BrowserThemeColor).
# Needs root once: /etc/chromium/policies/managed/torii-theme.json -> ~/.local/state/torii/theme/helium-policy.json
# The browser profile is never touched. Side effect of ANY managed policy: Helium shows "managed by your
# organization" and turns off DNS-over-HTTPS. Undo with:  sudo rm /etc/chromium/policies/managed/torii-theme.json
set -euo pipefail

target="${TORII_STATE:-$HOME/.local/state/torii}/theme/helium-policy.json"
dir=/etc/chromium/policies/managed

${SUDO:-sudo} install -d -m 755 "$dir"
${SUDO:-sudo} ln -sfn "$target" "$dir/torii-theme.json"
echo "linked $dir/torii-theme.json -> $target"
