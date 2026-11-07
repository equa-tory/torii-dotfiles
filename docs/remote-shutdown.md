# Remote shutdown API

Open **Setup → Remote shutdown API**.

- **Enable remote shutdown** starts or stops the listener. When enabled, the user service starts automatically after login on subsequent boots.
- **Copy token** copies the private bearer token to the clipboard.
- **Regenerate token** immediately revokes the previous token, including while running. The replacement persists across reboots.
- The menu shows current IPv4 URLs, port **10809**, path **/shutdown**, method **POST**, and the required authorization header.
- **Authorize shutdown without a password** installs the one-time polkit permission for your user using an administrator prompt. It permits only logind power-off actions, including when other sessions exist. It does not grant arbitrary commands or sudo access.

From another device on the trusted LAN or VPN:

```sh
curl -X POST http://192.168.1.176:10809/shutdown \
  -H 'Authorization: Bearer YOUR_COPIED_TOKEN'
```

Use the current address shown in the menu if the PC's IP changes. This sends a real shutdown request. The API accepts no commands or other power actions. GET requests cannot shut down the PC; tokens in URLs are not accepted.

The listener binds all IPv4 interfaces. HTTP does not encrypt the token, so use it only on a trusted LAN or through a VPN; do not expose this port to the public internet.

Private settings live in `~/.local/state/torii/remote-power.json` with mode 0600, outside Git. They contain the enabled state and persistent token. Menu status never includes the token. The generated user unit is `~/.config/systemd/user/torii-remote-power.service`; logs: `journalctl --user -u torii-remote-power.service`. The one-time policy is `/etc/polkit-1/rules.d/49-torii-remote-power.rules`.

The default is disabled. Enabling needs no root permission after the one-time policy setup. This user service becomes available after login, rather than at the pre-login screen.

Tests: `python tests/test_remote_power.py`. They use an isolated HTTP listener with shutdown mocked, checking authorization, method/path, disabling, persistent tokens and immediate revocation.
