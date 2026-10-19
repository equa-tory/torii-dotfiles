#!/usr/bin/env bash
# Everything the Quickshell desktop needs that `stow` and the package lists do not do. Safe to run again.
# Run it after `stow .` (install.sh does):   bash packages/torii-setup.sh
#
#   TORII_SKIP_SYSTEM=1   skip the steps that need root or touch system settings (used for tests)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKIP_SYSTEM="${TORII_SKIP_SYSTEM:-0}"
SUDO="${SUDO-sudo}"; if [[ $EUID -eq 0 ]]; then SUDO=""; fi
say() { printf '\n==> %s\n' "$*"; }

say "Directories (real ones, never stow links: wallpapers you add must not land in the public repo)"
# an older layout had ~/Pictures stow-linked into the repo: make it a real directory, keep the files
if [[ -L $HOME/Pictures ]]; then
  tmp="$(mktemp -d)"
  cp -aL "$HOME/Pictures/." "$tmp/" 2>/dev/null || true
  rm "$HOME/Pictures"
  mkdir -p "$HOME/Pictures"
  cp -an "$tmp/." "$HOME/Pictures/"
  rm -rf "$tmp"
fi
mkdir -p "$HOME/Pictures/wallpapers" "$HOME/.local/state/torii" "$HOME/.cache/torii"

say "Default wallpapers (existing files are left alone)"
if [[ -d $REPO/wallpapers ]]; then
  cp -an "$REPO/wallpapers/." "$HOME/Pictures/wallpapers/"
fi

say "File manager (Dolphin: minimal sidebar, opens in Downloads)"
bash "$REPO/packages/dolphin.sh" || true

say "App manifests for the launcher (~/apps)"
bash "$REPO/packages/apps-sync.sh"

if [[ $SKIP_SYSTEM != 1 ]]; then
  say "Temporary passwordless sudo: reset at boot and shutdown (torii-sudo)"
  unit=$(cat <<'UNIT'
[Unit]
Description=Remove the temporary passwordless sudo rule made by torii-sudo

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/rm -f /etc/sudoers.d/90-torii-nopasswd
ExecStop=/usr/bin/rm -f /etc/sudoers.d/90-torii-nopasswd

[Install]
WantedBy=multi-user.target
UNIT
)
  if ! diff -q <(printf '%s\n' "$unit") /etc/systemd/system/torii-sudo-reset.service >/dev/null 2>&1; then
    printf '%s\n' "$unit" | $SUDO tee /etc/systemd/system/torii-sudo-reset.service >/dev/null
    $SUDO systemctl daemon-reload
  fi
  $SUDO systemctl enable torii-sudo-reset.service >/dev/null 2>&1 || echo "!!  could not enable torii-sudo-reset.service"

  # Wi-Fi + Ethernet together made boot wait ~18 s for "network online" (docker waits for it too); nothing at boot needs it
  $SUDO systemctl disable NetworkManager-wait-online.service >/dev/null 2>&1 || true

  # ntsync: the kernel's Windows-style synchronisation; Proton (GE) uses it when /dev/ntsync exists, which takes load off the CPU
  if modinfo ntsync >/dev/null 2>&1; then
    echo ntsync | $SUDO tee /etc/modules-load.d/ntsync.conf >/dev/null
    $SUDO modprobe ntsync 2>/dev/null || true
    [ -e /dev/ntsync ] || echo "!!  no /dev/ntsync"
  fi

  # gamemode switches the CPU to the performance governor while a game runs; its polkit action asks for a password, and nothing
  # here shows a password dialog, so it never worked. Allow it for the admin group (wheel), and let the user renice games.
  if command -v gamemoded >/dev/null 2>&1; then
    printf '%s\n' 'polkit.addRule(function(action, subject) {' \
      '    if ((action.id == "com.feralinteractive.GameMode.governor-helper" || action.id == "com.feralinteractive.GameMode.cpu-helper") && subject.isInGroup("wheel")) return polkit.Result.YES;' \
      '});' | $SUDO tee /etc/polkit-1/rules.d/50-torii-gamemode.rules >/dev/null
    getent group gamemode >/dev/null && ! id -nG "$USER" | grep -qw gamemode && $SUDO usermod -aG gamemode "$USER"   # at next login
  fi

  # Caps Lock = Escape in the keyboard itself (games read the physical key, XKB's caps:escape does not reach them)
  if [ -f "$REPO/packages/capslock-esc.hwdb" ]; then
    $SUDO install -m 644 "$REPO/packages/capslock-esc.hwdb" /etc/udev/hwdb.d/90-torii-capslock.hwdb
    $SUDO systemd-hwdb update && $SUDO udevadm trigger --subsystem-match=input --action=change || true
  fi

  # xdg-open / Dolphin / browsers use the same apps as the `open` command
  [ -x "$REPO/.config/torii/bin/torii-open" ] && "$REPO/.config/torii/bin/torii-open" --apply || true

  # Java: several JDKs are installed (Minecraft needs different ones); the system default is the 21 LTS
  if command -v archlinux-java >/dev/null 2>&1 && archlinux-java status 2>/dev/null | grep -q java-21-openjdk; then
    $SUDO archlinux-java set java-21-openjdk || true
  fi

  say "Docker service"
  if command -v docker >/dev/null 2>&1; then
    $SUDO systemctl enable --now docker.service || echo "!!  could not enable docker.service"
    id -nG "$USER" | grep -qw docker || $SUDO usermod -aG docker "$USER"   # takes effect at next login
  fi

  say "Bluetooth service"
  if systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
    $SUDO systemctl enable --now bluetooth.service || echo "!!  could not enable bluetooth.service (no adapter here is fine)"
    # power the adapter on at boot, and let a controller that lost its pairing (Xbox) pair again without a prompt
    $SUDO sed -i -E 's/^#?\s*AutoEnable\s*=.*/AutoEnable=true/; s/^#?\s*JustWorksRepairing\s*=.*/JustWorksRepairing=always/; s/^#?\s*FastConnectable\s*=.*/FastConnectable=true/' /etc/bluetooth/main.conf
    $SUDO sed -i -E 's/^#?\s*ReconnectAttempts\s*=.*/ReconnectAttempts=7/; s/^#?\s*ReconnectIntervals\s*=.*/ReconnectIntervals=1,2,4,8,16,32,64/' /etc/bluetooth/main.conf
  fi

  say "Helium: theme colour policy + default browser"
  if command -v helium-browser >/dev/null 2>&1; then
    bash "$REPO/packages/helium-policy.sh"
    # keep the cookies in the browser's own store (not KWallet, which Dolphin pulls in): then a copy of the profile
    # (private-push.sh) still signs you in to Telegram / Discord on a fresh install
    flags="${XDG_CONFIG_HOME:-$HOME/.config}/helium-browser-flags.conf"
    grep -qs -- '--password-store=basic' "$flags" || echo '--password-store=basic' >> "$flags"
    # the local proxy (v2rayN / xray on 127.0.0.1:10808): used first, a direct connection when it is not running;
    # the home network and local names never go through it. Edit ~/.config/helium-browser-flags.conf to change or remove.
    grep -qs -- '--proxy-server' "$flags" || {
      echo '--proxy-server=socks5://127.0.0.1:10808,direct://' >> "$flags"
      echo '--proxy-bypass-list="<local>;localhost;127.0.0.1;192.168.0.0/16;10.0.0.0/8;172.16.0.0/12;*.local"' >> "$flags"
    }
    if [[ $(xdg-settings get default-web-browser 2>/dev/null) != helium.desktop ]]; then
      xdg-settings set default-web-browser helium.desktop || echo "!!  could not set the default browser"
    fi
  else
    echo "  Helium is not installed, skipping"
  fi
fi

say "Theme (first run picks the first wallpaper; later runs keep your current one)"
export PATH="$HOME/.config/torii/bin:$PATH"
if command -v torii-theme >/dev/null 2>&1 && command -v matugen >/dev/null 2>&1; then
  torii-theme restore || echo "!!  torii-theme restore failed (see above); the shell starts with built-in colours"
else
  echo "  torii-theme or matugen missing, skipping (run torii-theme restore after installing matugen)"
fi

say "Torii shell setup done. Log out and back in, or start it now:  torii-shell start"
