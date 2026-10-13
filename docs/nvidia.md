# NVIDIA on Arch + Hyprland

`packages/nvidia.sh` (run by `install.sh`, only when an NVIDIA GPU is found) installs the driver pinned to
595.71.05 and CUDA 13.2 from the Arch Archive, adds `IgnorePkg`, blacklists nouveau, puts the nvidia modules into the
initramfs and adds `nvidia_drm.modeset=1` to the kernel command line. `NVIDIA_PIN=0 bash packages/nvidia.sh`
uses the newest repository driver instead. Remove the `IgnorePkg` line in `/etc/pacman.conf` to update again.

## Symptom: monitors broken / low resolution / `nvidia-smi` fails
- Hyprland shows one monitor as "Unknown", a wrong resolution (1024x768), `nvidia-smi` says
  "couldn't communicate with driver", `lspci -k` shows `Kernel driver in use: nouveau`.

Cause: nouveau grabs the GPU before the proprietary driver, or the DKMS module is not built for this kernel.

1. `lspci -k | grep -A3 VGA` and `dkms status` (only "added" and not "installed" means it was not built).
2. Build it: `sudo dkms install nvidia/<version> -k $(uname -r)`
3. Blacklist nouveau: `/etc/modprobe.d/blacklist-nouveau.conf` with `blacklist nouveau` and `options nouveau modeset=0`.
4. `/etc/mkinitcpio.conf`: `MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)` (check the spelling of `nvidia_modeset`).
5. `sudo mkinitcpio -P` (no "module not found" errors).
6. Reboot. `lsmod | grep nouveau` must be empty and `nvidia-smi` must show the GPU.

If it worked once and then broke, it was probably luck in the load order: nouveau was not blacklisted yet.
With systemd-boot or GRUB add `nvidia_drm.modeset=1` to the kernel parameters (limine: done by the script).
