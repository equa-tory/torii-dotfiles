#!/usr/bin/env bash
# Use the home server (192.168.1.50) as a cache for pacman, npm, pip, nuget and docker.
# Idempotent. If the server is not reachable (away from home) nothing is changed, so the public mirrors keep working.
#   bash packages/mirrors.sh
# Option (environment): MIRROR_HOST=192.168.1.50
set -euo pipefail

HOST="${MIRROR_HOST:-192.168.1.50}"
NEXUS="http://$HOST:8090/repository"
SUDO="${SUDO-sudo}"; if [[ $EUID -eq 0 ]]; then SUDO=""; fi
say() { printf '\n==> %s\n' "$*"; }

if ! curl -fsS -m 4 -o /dev/null "http://$HOST:3142/lastsync" && ! curl -fsS -m 4 -o /dev/null "http://$HOST:8090/"; then
  echo "Home server $HOST not reachable, mirrors left as they are."; exit 0
fi

say "pacman cache (http://$HOST:3142) goes first in the mirrorlist"
if curl -fsS -m 4 -o /dev/null "http://$HOST:3142/lastsync"; then
  line="Server = http://$HOST:3142/\$repo/os/\$arch"
  if ! grep -qxF "$line" /etc/pacman.d/mirrorlist; then
    $SUDO cp -a /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.torii-bak
    { echo "$line"; grep -vxF "$line" /etc/pacman.d/mirrorlist; } | $SUDO tee /etc/pacman.d/mirrorlist >/dev/null
  fi
  # reflector would overwrite the list; keep the cache first if it runs
else
  echo "  pacman cache is down, skipped"
fi

say "npm, pip, nuget (Nexus on :8090)"
put() {   # put <file> <content>  : replaces a torii-owned file, backs up a foreign one once
  mkdir -p "$(dirname "$1")"
  if [[ -e $1 ]] && ! grep -q 'torii-mirror' "$1"; then cp -a "$1" "$1.torii-bak"; fi
  printf '%s\n' "$2" > "$1"
}
put "$HOME/.npmrc" "# torii-mirror
registry=$NEXUS/npm-group/"
put "$HOME/.config/pip/pip.conf" "# torii-mirror
[global]
index-url = $NEXUS/pypi-proxy/simple/
trusted-host = $HOST"
put "$HOME/.nuget/NuGet/NuGet.Config" "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<!-- torii-mirror -->
<configuration>
  <packageSources>
    <clear />
    <add key=\"home-nuget\" value=\"$NEXUS/nuget-group/index.json\" allowInsecureConnections=\"true\" />
  </packageSources>
</configuration>"

say "docker registry mirrors (:8091, :8093)"
if command -v docker >/dev/null 2>&1 || [[ -d /etc/docker ]]; then
  $SUDO mkdir -p /etc/docker
  tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
  [[ -s /etc/docker/daemon.json ]] && cat /etc/docker/daemon.json > "$tmp" || echo '{}' > "$tmp"
  jq --arg a "http://$HOST:8091" --arg b "http://$HOST:8093" \
     '. + {"registry-mirrors": [$a,$b], "insecure-registries": ((."insecure-registries" // []) + ["\($a|sub("http://";""))","\($b|sub("http://";""))"] | unique)}' \
     "$tmp" | $SUDO tee /etc/docker/daemon.json >/dev/null
  $SUDO systemctl is-active --quiet docker && $SUDO systemctl reload docker || true
else
  echo "  docker not installed, skipped (rerun this after installing it)"
fi
echo "Mirrors done"
