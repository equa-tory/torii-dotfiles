#!/usr/bin/env bash
# Personal data from the home server: apps, browser profile, SMB credentials, extra disks and shares.
#
# Nothing private lives in the public dotfiles repo. The home server keeps ONE folder (default ~/torii-private):
#   home/                 mirrored into your home folder: home/apps/v2rayN, home/.config/<browser profile>, ...
#   system/fstab.extra    extra /etc/fstab lines (disks, SMB shares). Added in a guarded way, see apply_fstab
#   system/root/<file>    copied to /root/<file> with mode 600 (SMB credentials)
#
# If the server cannot be reached (away from home, no LAN) this skips quietly. Run it again later:
#   bash packages/personal.sh
# Option (environment): PRIVATE_SRC=user@host:path/   rsync source, default below
set -euo pipefail

PRIVATE_SRC="${PRIVATE_SRC:-equa@192.168.1.50:torii-private/}"   # user@host:path (path is relative to the server's home)
PRIVATE_SRC="${PRIVATE_SRC%/}/"
FSTAB="${FSTAB:-/etc/fstab}"
ROOT_HOME="${ROOT_HOME:-/root}"
DEV_ROOT="${DEV_ROOT:-/dev/disk}"
SUDO="${SUDO-sudo}"; if [[ $EUID -eq 0 ]]; then SUDO=""; fi

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }
command -v rsync >/dev/null || { warn "rsync is not installed (pacman -S rsync)"; exit 1; }

# mktemp -d is private (mode 700): credentials never sit in a readable place, and it is deleted at the end
stage=$(mktemp -d); tmp_files=()
trap 'rm -rf "$stage" "${tmp_files[@]}"' EXIT

say "Fetching private data from $PRIVATE_SRC"
if ! rsync -a -e "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8" "$PRIVATE_SRC" "$stage/"; then
  warn "Home server not reachable (or wrong login/path). Skipping personal data."
  warn "Run it later:  bash packages/personal.sh"
  exit 0
fi

# ---- 1. files for your home folder (apps, browser profile, launchers) ----
if [[ -d $stage/home ]]; then
  say "Restoring files into $HOME"
  rsync -a --backup --suffix=.bak "$stage/home/" "$HOME/"      # permissions kept, replaced files saved as *.bak
fi

# ---- 2. credentials for root (SMB logins) ----
if [[ -d $stage/system/root ]]; then
  say "Installing credentials into $ROOT_HOME"
  $SUDO install -d -m 700 "$ROOT_HOME"
  while IFS= read -r -d '' f; do
    $SUDO install -m 600 -o root -g root "$f" "$ROOT_HOME/$(basename "$f")"
    echo "  $ROOT_HOME/$(basename "$f")"
  done < <(find "$stage/system/root" -maxdepth 1 -type f -print0)
fi

# ---- 3. extra mounts: guarded so a missing disk or server can never stop the boot ----
parse_errors() {   # number of lines of the fstab that systemd cannot even read
  local n
  n=$(findmnt --verify --tab-file "$FSTAB" 2>&1 | sed -n 's/^\([0-9][0-9]*\) parse error.*/\1/p') || true
  echo "${n:-0}"
}
device_present() {   # is the disk named in the fstab line in THIS machine?
  local dir tag=${1#*=}
  case $1 in
    UUID=*)      dir=by-uuid ;;
    LABEL=*)     dir=by-label ;;
    PARTUUID=*)  dir=by-partuuid ;;
    PARTLABEL=*) dir=by-partlabel ;;
    /dev/*)      [[ -e $1 ]]; return ;;
    *)           return 0 ;;          # network shares: checked through their credentials below
  esac
  [[ -e $DEV_ROOT/$dir/$tag ]]
}
apply_fstab() {
  local extra=$stage/system/fstab.extra line dev mnt fstype opts dump pass cred out="" need tmp new pe_before pe_after
  [[ -s $extra ]] || return 0
  say "Extra mounts"
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    read -r dev mnt fstype opts dump pass _ <<<"$line"
    if [[ -z ${opts:-} ]]; then warn "skipping a malformed line: $line"; continue; fi
    if ! device_present "$dev"; then echo "  skip $mnt: $dev is not in this machine"; continue; fi
    if [[ $fstype == cifs ]] && ! command -v mount.cifs >/dev/null; then
      echo "  skip $mnt: cifs-utils is not installed"; continue
    fi
    cred=$(grep -o 'credentials=[^,]*' <<<"$opts" | head -1 | cut -d= -f2 || true)
    if [[ -n $cred ]] && ! $SUDO test -f "$cred"; then echo "  skip $mnt: $cred is missing"; continue; fi
    # Boot safety, always enforced: never wait for it (nofail + automount), and cap how long a dead server can block
    for need in nofail x-systemd.automount; do [[ ,$opts, == *",$need,"* ]] || opts+=",$need"; done
    if [[ $fstype == cifs || $fstype == nfs* ]]; then
      [[ ,$opts, == *",_netdev,"* ]] || opts+=",_netdev"
      [[ $opts == *x-systemd.mount-timeout=* ]] || opts+=",x-systemd.mount-timeout=10s"
    fi
    # Without these a cifs share is owned by root: only sudo could write to it (the file auto mover failed on this)
    if [[ $fstype == cifs ]]; then
      [[ $opts == *uid=* ]]       || opts+=",uid=${SUDO_UID:-$(id -u)}"
      [[ $opts == *gid=* ]]       || opts+=",gid=${SUDO_GID:-$(id -g)}"
      [[ $opts == *file_mode=* ]] || opts+=",file_mode=0664"
      [[ $opts == *dir_mode=* ]]  || opts+=",dir_mode=0775"
    fi
    $SUDO mkdir -p "$mnt"
    out+="$dev  $mnt  $fstype  $opts  ${dump:-0}  ${pass:-0}"$'\n'
    echo "  add  $mnt"
  done < "$extra"
  if [[ -z $out ]]; then echo "  nothing applies to this machine"; return 0; fi

  $SUDO cp -a "$FSTAB" "$FSTAB.torii-bak"
  pe_before=$(parse_errors)
  tmp=$(mktemp); new=$(mktemp); tmp_files+=("$tmp" "$new")
  sed '/^# >>> torii personal mounts >>>$/,/^# <<< torii personal mounts <<<$/d' "$FSTAB" > "$tmp"   # rerun = replace, not duplicate
  { cat "$tmp"; echo '# >>> torii personal mounts >>>'; printf '%s' "$out"; echo '# <<< torii personal mounts <<<'; } > "$new"
  $SUDO install -m 644 "$new" "$FSTAB"
  pe_after=$(parse_errors)
  if (( pe_after > pe_before )); then
    $SUDO cp -a "$FSTAB.torii-bak" "$FSTAB"
    warn "The new lines broke the fstab (parse error). Old fstab restored."; return 1
  fi
  $SUDO systemctl daemon-reload 2>/dev/null || true
  # lines added while the system is running are not picked up until the next boot: start their automounts now
  while read -r _ mnt _; do
    [[ -n ${mnt:-} ]] && $SUDO systemctl start "$(systemd-escape -p --suffix=automount "$mnt")" 2>/dev/null || true
  done <<<"$out"
  echo "  fstab updated (backup: $FSTAB.torii-bak). The disks and shares mount when first used."
}
apply_fstab || warn "Mounts were not added. The system boots fine without them."

say "Personal data done"
