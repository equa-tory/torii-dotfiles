# Home Assistant lights

Open **Setup → Home Assistant lights** in the notch.

- **Follow wallpaper color** enables or disables automatic updates. Disabling leaves the lights as they are.
- **Global brightness** controls all added lights while following is enabled. Zero turns them off.
- **Add new light** discovers RGB-capable Home Assistant lights, or accepts a `light.*` entity ID.
- **Added lights** lets you remove lights from theme following without deleting them in Home Assistant.
- **Access token** is a masked input for a long-lived token. **Server address** changes the instance URL.
- **Apply current theme now** reapplies the color and brightness when following is enabled.

Applied wallpaper/theme changes update the lights automatically, including wallpaper shuffle. Picker previews do not. Before applying a color or brightness update, Torii checks current Home Assistant states and targets only added lights that are already on. Off, unavailable, unknown and missing lights are skipped, including when using Apply current theme now. Turning a light on manually leaves its saved color until the next theme or brightness update. Home Assistant may slightly adjust RGB values to the device's color gamut.

Settings, token, discovered lights and synchronization status stay under `~/.local/state/torii/homeassistant*.json`, outside the dotfiles repository. JSON files have mode 0600. Tokens pass to the helper over stdin, never as process arguments or menu status. LAN API requests bypass shell proxy variables.

The shell debounces theme changes and checks every 30 seconds to retry failed requests or pick up settings. An unchanged successfully applied theme makes no network request. Errors appear in the Setup menu. Disabling following prevents further light commands.

Implementation uses Home Assistant's [REST API](https://developers.home-assistant.io/docs/api/rest/) and `light.turn_on` / `light.turn_off`. Tests: `python tests/test_homeassistant.py`.

## Manual controls and keyboard shortcuts

Open **Home Assistant** from the launcher's main menu for lights, switches, fans and input booleans. Enter toggles the selected entity; its current state appears alongside its name. **Refresh devices** reloads states, as does opening this menu.

Select any device and press **Ctrl+K → Add binding** to assign a global keyboard shortcut. The same menu supports aliases and pinning. Device IDs keep bindings stable when friendly names change. Connection credentials are shared with Setup → Home Assistant lights.

Manual toggles do not apply wallpaper colors or change theme-following settings. A light still enrolled in theme following can turn on again at the next wallpaper/theme update; disable following or remove that light if you want only manual control.
