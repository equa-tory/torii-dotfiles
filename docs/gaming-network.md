# Gaming over Wi-Fi

Torii disables Wi-Fi power saving by default to avoid power-management delays
on the desktop. `packages/torii-setup.sh` installs the policy automatically.
To apply just this change to an existing installation:

```sh
bash packages/wifi-latency.sh
```

The script installs `/etc/NetworkManager/conf.d/90-torii-wifi-latency.conf`
with `wifi.powersave=2` (disabled), reloads only NetworkManager configuration,
and applies `iw dev <interface> set power_save off` to current Wi-Fi interfaces.
It does not reconnect, restart networking, change proxy settings, or change game
launch options. A profile explicitly choosing enable or ignore is respected;
the global policy applies to profiles using the default (0).

Check the runtime policy with `iw dev <interface> get power_save`. After a
normal reconnect or reboot, NetworkManager applies the saved default again.
This trades some battery life for latency on machines using Wi-Fi.

During a 20-minute Deadlock observation, router ping was normally 1.5 ms but
reached 109 ms, and some bursts coincided with 94–112 ms of in-game jitter.
Runtime Wi-Fi power saving was enabled. Disabling it is a targeted mitigation,
not proof that power saving caused every burst. Compare a similar gameplay
session, ideally with an Ethernet run too. Game ping also rose independently of
the router/public probes, and GPU thermal slowdown was observed; those can need
separate investigation.

On the observed machine, the setting applied without reconnecting and
NetworkManager read back `wifi.powersave=2`. A two-minute check afterward
received all 120 router probes, averaging 2.41 ms, but still included one
100 ms spike. The jitter is therefore not confirmed resolved by this change.

To restore the previous global policy, remove the Torii configuration and run
`sudo nmcli general reload conf`. A normal reconnect applies the remaining
NetworkManager defaults. To restore power saving on the current interface
immediately, use `sudo iw dev <interface> set power_save on`. Neither rollback
command requires restarting NetworkManager.

Reference: [NetworkManager Wi-Fi power-save values](https://networkmanager.dev/docs/api/latest/settings-802-11-wireless.html).
