#!/usr/bin/env bash
# Install the desktop Wi-Fi power policy and apply it without reconnecting.
# Run alone with: bash packages/wifi-latency.sh (asks for sudo if needed).
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$(readlink -f "$0")" "$@"
fi

PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
install -Dm644 "$PKG_DIR/wifi-latency.conf" /etc/NetworkManager/conf.d/90-torii-wifi-latency.conf

# Reload only configuration: do not restart NetworkManager or bounce the link.
if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager.service; then
  nmcli general reload conf
fi

# The default is used on the next connection activation. Apply the same policy
# to existing wireless interfaces now, without changing saved profile overrides.
if command -v iw >/dev/null 2>&1; then
  for radio in /sys/class/net/*/phy80211; do
    [[ -e $radio ]] || continue
    iface="$(basename "$(dirname "$radio")")"
    # Respect profiles explicitly choosing enable (3) or ignore (1).
    if command -v nmcli >/dev/null 2>&1; then
      uuid="$(nmcli -g GENERAL.CON-UUID device show "$iface" 2>/dev/null || true)"
      if [[ -n $uuid && $uuid != -- ]]; then
        policy="$(nmcli -g 802-11-wireless.powersave connection show uuid "$uuid" 2>/dev/null || true)"
        case "$policy" in 1*|3*) echo "Keeping explicit power policy for $iface"; continue ;; esac
      fi
    fi
    if iw dev "$iface" set power_save off; then
      iw dev "$iface" get power_save
    else
      echo "!!  $iface could not apply Wi-Fi power saving now; the default is saved for the next connection" >&2
    fi
  done
else
  echo "!!  Install iw to apply immediately; the default is saved for the next connection" >&2
fi
