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
#   PULL_ONLY="helium webapps apps localsend"   restore just these parts into $HOME (the launcher's Sync menu uses it), nothing else
#
# Where it comes from: the home server over ssh (its authorized_keys must have this computer's key: the key is shown below
# when ssh is refused; put it on GitHub, then run update-ssh-keys.sh from the Umbrel share). If ssh does not work, the
# copy on the Umbrel share (SMB, no ssh): mounted by itself, you only type the Umbrel password.
set -euo pipefail

PRIVATE_SRCS="${PRIVATE_SRC:-equa@192.168.1.50:torii-private/}"   # user@host:path (path is relative to the server's home)
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

# Where the data lives: the home server first, then the backup copy on the Umbrel share (mounted at /mnt/umbrel)
BACKUP_DIR="${PRIVATE_BACKUP:-/mnt/umbrel/Documents/torii-private}"
umbrel_share="//192.168.1.23/equa's Umbrel"
got=0
for PRIVATE_SRC in $PRIVATE_SRCS; do
  PRIVATE_SRC="${PRIVATE_SRC%/}/"
  say "Fetching private data from $PRIVATE_SRC"
  if rsync -a -e "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -o BatchMode=yes" "$PRIVATE_SRC" "$stage/"; then got=1; break; fi
done
if ((!got)); then
  warn "Home server not reachable by ssh (no key accepted, or it is off)."
  [[ -f $HOME/.ssh/id_ed25519 ]] || ssh-keygen -q -N "" -t ed25519 -f "$HOME/.ssh/id_ed25519"
  warn "This computer's key (add it at https://github.com/settings/keys, then run update-ssh-keys.sh from the Umbrel share):"
  cut -d' ' -f1,2 "$HOME/.ssh/id_ed25519.pub" >&2
  # the Umbrel share is not in /etc/fstab yet on a fresh install (that comes from this very folder): mount it for now
  if ! ls "$BACKUP_DIR" >/dev/null 2>&1 && [[ -t 0 && -z ${UMBREL_NO_MOUNT:-} ]] && command -v mount.cifs >/dev/null; then
    say "Mounting the Umbrel share (SMB) to use the backup copy"
    read -rsp "Umbrel password for ${UMBREL_USER:-umbrel} (empty = skip): " upw; echo
    if [[ -n $upw ]]; then
      umount_dir=$(mktemp -d)
      if $SUDO mount -t cifs "${UMBREL_SHARE:-$umbrel_share}" "$umount_dir" \
           -o "username=${UMBREL_USER:-umbrel},password=$upw,vers=3.0,uid=$(id -u),gid=$(id -g),file_mode=0664,dir_mode=0775"; then
        BACKUP_DIR="$umount_dir/Documents/torii-private"
        trap '$SUDO umount "$umount_dir" 2>/dev/null; rmdir "$umount_dir" 2>/dev/null; rm -rf "$stage" "${tmp_files[@]}"' EXIT
      else
        warn "Could not mount the Umbrel share"
      fi
    fi
    unset upw
  fi
  if ls "$BACKUP_DIR" >/dev/null 2>&1 && [[ -n $(ls -A "$BACKUP_DIR" 2>/dev/null) ]]; then
    say "Using the backup copy in $BACKUP_DIR"
    rsync -rltD --no-perms "$BACKUP_DIR/" "$stage/"          # a cifs share has no unix modes: private folders are made 700 below
    find "$stage/home" -type d -exec chmod 700 {} + 2>/dev/null || true
    find "$stage/home/.config" "$stage/home/.local" -type f -exec chmod go-rwx {} + 2>/dev/null || true
  else
    warn "No backup copy either (needs /mnt/umbrel mounted). Skipping personal data."
    warn "Run it later:  bash packages/personal.sh"
    exit 0
  fi
fi

# ---- 1. files for your home folder (apps, browser profile, launchers) ----
if [[ -d $stage/home ]]; then
  say "Restoring files into $HOME"
  filter=()
  if [[ -n ${PULL_ONLY:-} ]]; then          # only some parts: keep the parent folders, then just these paths
    filter=(--include=/.config/ --include=/.local/ --include=/.local/share/ --include=/.local/share/applications/ --include=/.local/state/ --include=/.local/state/torii/ --include=/.config/net.imput.helium/ --include=/.config/net.imput.helium/Default/ "--include=/.config/net.imput.helium/Default/Service Worker/")
    for part in $PULL_ONLY; do
      case $part in
        helium)    filter+=("--include=/.config/net.imput.helium/***") ;;
        webapps)   filter+=(--include=/.local/state/torii/webapps.json --include=/.local/state/torii/tuis.json "--include=/.config/net.imput.helium/Local State"
                            --include='/.config/net.imput.helium/Default/Cookies*' --include=/.config/net.imput.helium/Default/Preferences
                            "--include=/.config/net.imput.helium/Default/Local Storage/***" "--include=/.config/net.imput.helium/Default/Session Storage/***"
                            "--include=/.config/net.imput.helium/Default/IndexedDB/***" "--include=/.config/net.imput.helium/Default/Service Worker/Database/***"
                            "--include=/.config/net.imput.helium/Default/Service Worker/ScriptCache/***") ;;
        apps)      filter+=("--include=/.local/share/applications/*.desktop" --include=/.local/state/torii/backup-apps.txt "--include=/apps/***") ;;
        localsend) filter+=(--include=/.local/share/org.localsend.localsend_app/***) ;;
        *) warn "unknown part: $part" ;;
      esac
    done
    filter+=(--exclude='*')
  fi
  rsync -a --backup --suffix=.bak "${filter[@]}" "$stage/home/" "$HOME/"      # permissions kept, replaced files saved as *.bak
  # apps kept at the top of the server's home folder belong in ~/apps, where the launcher looks (v2rayN-linux-64, ...)
  for d in "$stage"/home/*-linux-64 "$stage"/home/v2rayN*; do
    [[ -d $d ]] || continue
    name=$(basename "$d")
    if [[ -d $HOME/$name && ! -e $HOME/apps/$name ]]; then
      mkdir -p "$HOME/apps" && mv "$HOME/$name" "$HOME/apps/$name" && echo "  moved ~/$name -> ~/apps/$name"
    fi
  done
fi

[[ -z ${PULL_ONLY:-} ]] || exit 0          # a partial pull stops here (no root credentials, no fstab)

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
