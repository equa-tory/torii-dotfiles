# Torii shell

One Quickshell (QML) shell replaces Waybar, hyprlauncher and hyprpaper: a notch bar on every monitor, a control
panel, a wallpaper switcher and a launcher. A CLI (`torii-theme`) restyles the whole desktop from the wallpaper.

## Keys

`mainMod` is `ALT` in `.config/hypr/modules/binds.lua` (change it to `SUPER` on real hardware).

| Key | Does |
|---|---|
| `mainMod + SPACE` | launcher |
| `mainMod + N` | control panel (sound, Bluetooth, network, background apps) |
| `mainMod + CTRL + SPACE` | wallpaper / theme switcher (`<` `>` preview, `Space`/`Enter` apply, `Esc` cancel) |
| `mainMod + SHIFT + D` | dark / light |
| `mainMod + SHIFT + R` | reload the shell |

`Esc` or a click outside closes any panel. Panels only open on the focused monitor.
(With `ALT`, `CTRL + ALT + SPACE` also hits the XKB layout toggle in `input.lua`; with `SUPER` there is no clash.)

## Config

One file, hot-reloaded: `~/.config/torii/config.json`. Every key is optional.

| Key | Default | |
|---|---|---|
| `notch.shape` | `attached` | `attached` (touches the top edge) or `floating` (a pill with a gap) |
| `notch.opacity` | `1.0` | |
| `notch.radius` / `height` / `gap` | `16` / `34` / `6` | `gap` is for `floating` |
| `workspaces.count` | `5` | always shown per monitor; occupied/active ones beyond that are added |
| `weather.lat` / `lon` / `refreshMin` | Moscow / `20` | Open-Meteo, no API key, Celsius |
| `wallpaper.dir` / `transitionMs` | `~/Pictures/wallpapers` / `600` | |
| `theme.tint` | `0.15` | `0` pure black backgrounds … `1` backgrounds tinted by the wallpaper |
| `apps.dir` | `~/apps` | see below |
| `quicklinks` | `~/.config/torii/quicklinks.json` | |
| `font.family` / `size` | JetBrainsMono Nerd Font / `13` | |

Colours are not configured here: they come from the wallpaper.

## Theme

```
torii-theme set <image> | next | prev | random | restore | mode [dark|light|toggle] | palette <image> | current
```

* Dark is the default. `mode toggle` flips everything live.
* The accent comes from the wallpaper (matugen). To hand-pick one for a wallpaper, write
  `~/.config/torii/overrides/<file name>.json` containing `{"accent": "#ff8800"}`.
* Applied to the shell, Hyprland borders, kitty, Neovim (running instances too), tmux, GTK 3/4 (`adw-gtk3`),
  Qt (qt6ct), fastfetch and Helium. kitty, nvim, tmux, Hyprland, GTK 3 and Helium change live;
  GTK 4 / libadwaita and Qt apps pick it up the next time they start.
* Generated files live in `~/.local/state/torii`, never in the repo. The first run after login restores the last theme.
* `border_size` in `decorations.lua` is `0`, so the themed border colours are only visible if you raise it.

**Helium** is themed through a managed browser policy (`BrowserThemeColor`), not by touching the profile:
`/etc/chromium/policies/managed/torii-theme.json` links to the generated file (`packages/helium-policy.sh`).
Side effect of any managed policy: Helium shows "managed by your organization" and DNS-over-HTTPS is switched off.
Undo: `sudo rm /etc/chromium/policies/managed/torii-theme.json`.

## Launcher

Type to search apps, `~/apps` folders and quicklinks. Recently used come first (`~/.local/state/torii/launcher-recent.json`).

**Quicklinks** live in `~/.config/torii/quicklinks.json` (hot-reloaded; type `quicklinks` in the launcher to edit):

```json
{ "yt": "https://www.youtube.com/results?search_query={q}", "git": "https://github.com/equa-tory" }
```

`yt cats` searches, `yt` alone opens youtube.com, `git` opens its URL. They open in the default browser.

**Apps without a `.desktop`** (mac style): every folder directly inside `~/apps` that has an `app.json` is an app.
Nothing is moved or installed.

```json
{ "name": "v2rayN", "exec": "v2rayN-linux-64/v2rayN", "icon": "icon.png", "keywords": ["vpn"], "description": "Proxy client" }
```

`exec` is relative to the folder (the app starts with that folder as its working directory). `icon` is a file in the
folder or an icon-theme name; both are optional, as are `name` and `keywords`.

## Moving around

* `torii-shell reload | stop | start | status`
* **Emergency fallback:** `torii-shell fallback` stops the shell and brings back Waybar + hyprpaper (their config is still
  in `.config/waybar`). `torii-shell start` returns to the shell.
* **Uninstall:** `torii-shell fallback`, remove the Torii lines from `.config/hypr/modules/{autostart,binds}.lua`,
  `stow -D .`, and remove the Helium policy link above.

## Reinstall

`./install.sh` on a fresh Arch install does everything: packages (`packages/pacman.txt`, `packages/aur.txt`), stow,
`packages/torii-setup.sh` (wallpapers, theme, Bluetooth service, Helium policy, default browser). It can be run again.
Wallpapers you add go to `~/Pictures/wallpapers`, which is a real directory and never part of this repo.

## Developing without hardware

`torii-shell mock` starts the shell with fake Wi-Fi networks, Bluetooth devices, audio devices and tray items
(`TORII_MOCK=1`), so every panel state can be seen in a VM. Test a second monitor with
`hyprctl output create headless` / `hyprctl output remove HEADLESS-1`.

## Not built (by design)

Notifications (swaync keeps running; never run two daemons), lock screen, OSD popups, per-app volume. Bluetooth pairing is
"just works" only, because Quickshell has no PIN/passkey agent.
