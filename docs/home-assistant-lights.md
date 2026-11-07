# Home Assistant lights

Open **Setup → Home Assistant lights** in the notch.

- **Follow wallpaper color** enables or disables automatic updates. Disabling leaves the lights as they are.
- **Global brightness** controls all added lights while following is enabled. Zero turns them off.
- **Add new light** discovers RGB-capable Home Assistant lights, or accepts a `light.*` entity ID.
- **Added lights** lets you remove lights from theme following without deleting them in Home Assistant.
- **Access token** is a masked input for a long-lived token. **Server address** changes the instance URL.
- **Apply current theme now** reapplies the color and brightness when following is enabled.

Applied wallpaper/theme changes update the lights automatically, including wallpaper shuffle. Picker previews do not. Added lights are turned on when a new color is applied with nonzero brightness. Home Assistant may slightly adjust RGB values to the device's color gamut.

Settings, token, discovered lights and synchronization status stay under `~/.local/state/torii/homeassistant*.json`, outside the dotfiles repository. JSON files have mode 0600. Tokens pass to the helper over stdin, never as process arguments or menu status. LAN API requests bypass shell proxy variables.

The shell debounces theme changes and checks every 30 seconds to retry failed requests or pick up settings. An unchanged successfully applied theme makes no network request. Errors appear in the Setup menu. Disabling following prevents further light commands.

Implementation uses Home Assistant's [REST API](https://developers.home-assistant.io/docs/api/rest/) and `light.turn_on` / `light.turn_off`. Tests: `python tests/test_homeassistant.py`.
