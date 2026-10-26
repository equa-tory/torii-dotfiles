# System files kept for reference

`fstab` is a copy of `/etc/fstab` from the main machine (drives and the network shares). It is **not** installed by `install.sh`: the UUIDs belong to that machine's disks. On a new machine take the share lines (cifs) and the `ntfs3` lines as a starting point and replace the UUIDs (`lsblk -f`).

The shares read their login from root-only files (`/root/.smb-dorm`, `/root/.smb-media`, `/root/.smb-umbrel`), which are never stored here. Edit the live file from the launcher: Setup > Configs > Mounts (fstab). After a change copy it back here: `cp /etc/fstab ~/torii-dotfiles/system/fstab`.
