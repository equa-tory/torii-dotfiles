#!/usr/bin/env bash
# NVIDIA driver setup for Wayland/Hyprland. Does nothing on machines without an NVIDIA GPU (the VM).
#   bash packages/nvidia.sh            pinned driver, see PIN below
#   NVIDIA_PIN=0 bash packages/nvidia.sh   newest driver from the repos, no pin
# Troubleshooting notes: docs/nvidia.md
set -euo pipefail

NVIDIA_VER="${NVIDIA_VER:-595.71.05}"; CUDA_VER="${CUDA_VER:-13.2}"
PIN="${NVIDIA_PIN:-1}"
SUDO="${SUDO-sudo}"; if [[ $EUID -eq 0 ]]; then SUDO=""; fi
say() { printf '\n==> %s\n' "$*"; }
warn() { printf '!!  %s\n' "$*" >&2; }

if ! lspci 2>/dev/null | grep -qiE 'vga|3d' || ! lspci | grep -iE 'vga|3d' | grep -qi nvidia; then
  echo "No NVIDIA GPU here, skipping."; exit 0
fi

say "Driver packages"
pkgs=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils nvidia-settings linux-headers)
if [[ $PIN == 1 ]]; then
  # exact versions from the Arch Archive (https://archive.archlinux.org), kept with IgnorePkg
  base=https://archive.archlinux.org/packages
  ok=1
  for p in nvidia-open-dkms nvidia-utils lib32-nvidia-utils; do
    f="$p-$NVIDIA_VER-1-x86_64.pkg.tar.zst"; [[ $p == lib32-* ]] && f="$p-$NVIDIA_VER-1-x86_64.pkg.tar.zst"
    if ! installed=$(pacman -Q "$p" 2>/dev/null) || [[ $installed != "$p $NVIDIA_VER-1" ]]; then
      $SUDO pacman -U --needed --noconfirm "$base/${p:0:1}/$p/$f" || ok=0
    fi
  done
  if ((ok)); then
    echo "  cuda $CUDA_VER: installing from the archive when available"
    $SUDO pacman -U --needed --noconfirm "$(curl -fsS "$base/c/cuda/" | grep -o "cuda-${CUDA_VER//./\\.}[^\"]*x86_64\.pkg\.tar\.zst" | sort -V | tail -1 | sed "s#^#$base/c/cuda/#")" || warn "cuda $CUDA_VER not found in the archive"
    if ! grep -q '^IgnorePkg.*nvidia-open-dkms' /etc/pacman.conf; then
      $SUDO sed -i '/^\[options\]/a IgnorePkg = nvidia-open-dkms nvidia-utils lib32-nvidia-utils cuda' /etc/pacman.conf
    fi
  else
    warn "pinned driver failed (kernel too new for it, or the archive is down). Using the repository version."
    PIN=0
  fi
fi
if [[ $PIN != 1 ]]; then $SUDO pacman -S --needed --noconfirm "${pkgs[@]}" cuda; fi
$SUDO pacman -S --needed --noconfirm linux-headers nvidia-settings || true

say "Module for the running kernel"
ver=$(pacman -Q nvidia-open-dkms | awk '{print $2}' | sed 's/-.*//')
if dkms status 2>/dev/null | grep -q "nvidia.*$ver.*added"; then
  $SUDO dkms install "nvidia/$ver" -k "$(uname -r)" || warn "dkms build failed, see docs/nvidia.md"
fi

say "Keep nouveau away"
$SUDO mkdir -p /etc/modprobe.d
printf 'blacklist nouveau\noptions nouveau modeset=0\n' | $SUDO tee /etc/modprobe.d/blacklist-nouveau.conf >/dev/null

say "Early loading in the initramfs"
want='MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)'
if ! grep -qxF "$want" /etc/mkinitcpio.conf; then
  $SUDO sed -i "s/^MODULES=.*/$want/" /etc/mkinitcpio.conf
fi
$SUDO mkinitcpio -P

say "nvidia_drm.modeset=1 on the kernel command line"
for f in /boot/limine.conf /boot/limine/limine.conf; do
  [[ -f $f ]] || continue
  if ! grep -q 'nvidia_drm.modeset=1' "$f"; then
    $SUDO sed -i 's/^\(\s*cmdline:.*\)$/\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1/' "$f"
  fi
done
echo "Reboot, then check:  lsmod | grep nouveau (empty)  and  nvidia-smi"
