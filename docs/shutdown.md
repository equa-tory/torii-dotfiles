# Shutdown sequencing

The notch's **System → Shut down** and the remote shutdown API use `torii-power` to:

1. Queue the action as an independent user service, so closing QuickShell cannot cancel it.
2. Stop an active UWSM desktop and wait for its graphical-session stop job.
3. Request normal `systemctl poweroff`. Desktop cleanup has bounded waits; this does not use forced power-off or skip filesystem unmounting.

This addresses the session shutdown ordering as a workaround for intermittent shutdown hangs. Hyprland documents UWSM session management and ordered shutdown at https://wiki.hypr.land/useful-utilities/uwsm/ .

On 2026-11-12, boot -2 recorded a power-off request at 00:49:29, then the persistent journal ended without identifying a blocked unit. Other boots showed filesystem unmounts. This does not prove the underlying cause or exclude a driver/firmware hang. The change needs verification during normal shutdowns; no actual shutdown was performed during implementation.

After a failed shutdown, inspect the preceding boot:

```sh
journalctl -b -1 -e --no-pager
journalctl -b -1 --user-unit=torii-poweroff.service --no-pager
journalctl -b -1 -k --no-pager
```

If shutdown gets stuck and a text console is available (Ctrl+Alt+F3), `systemctl list-jobs` and `journalctl -b -e` can identify the job still running. A photo of the last console message is useful for failures after journald exits.

A separate existing issue was found: the NTFS volume mounted at `/mnt/hdd01` is dirty and refuses to mount. Repair it with Windows chkdsk when available; do not force-mount it to work around the dirty flag. It was not established as the shutdown cause and was left unchanged.

Tests: `python tests/test_power.py` and `python tests/test_remote_power.py` mock all actual power commands.
