# Torii shell

One Quickshell (QML) shell replaces Waybar, hyprlauncher and hyprpaper: a notch bar on every monitor, a control
panel, a wallpaper switcher and a launcher. A CLI (`torii-theme`) restyles the whole desktop from the wallpaper.

## Keys

`mainMod` is `ALT` in `.config/hypr/modules/binds.lua`, on every machine (the Super key is left free).

| Key | Does |
|---|---|
| `mainMod + SPACE` | launcher |
| `mainMod + N` | control panel (sound, Bluetooth, network, background apps) |
| `mainMod + CTRL + SPACE` | wallpaper / theme switcher (`<` `>` preview, `Space`/`Enter` apply, `Esc` cancel) |
| `mainMod + SHIFT + D` | dark / light |
| `mainMod + SHIFT + R` | reload the shell |
| `mainMod + SHIFT + Q / W / E` | screenshot, screenshot of a zone, start/stop screen recording |

`Esc` or a click outside closes any panel. Panels only open on the focused monitor.
(`CTRL + ALT + SPACE` also hits the XKB layout toggle in `input.lua`.)

## Config

One file, hot-reloaded: `~/.config/torii/config.json`. Every key is optional.

| Key | Default | |
|---|---|---|
| `notch.shape` | `attached` | `attached` (touches the top edge) or `floating` (a pill with a gap) |
| `notch.opacity` | `1.0` | |
| `notch.radius` / `height` / `gap` | `16` / `34` / `6` | `gap` is for `floating` |
| `notch.zoneTrim` | `12` | px removed from the strip the notch reserves: a smaller gap between the notch and windows |
| `workspaces.count` | `5` | always shown per monitor; occupied/active ones beyond that are added |
| `weather.location` / `lat` / `lon` / `refreshMin` | system timezone city / `0` / `20` | Open-Meteo, no API key, Celsius. Empty `location` = the city of the system timezone (geocoded once); a city name or `lat`+`lon` override it. Click the weather for the forecast; wind ≥ 30 km/h shows a wind icon |
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

Opens as a single input (`mainMod+SPACE`). Everything works from the keyboard:

| Key | Does |
|---|---|
| `↓` | show the menus (Apps, Setup, ...); `↓`/`↑`/`Tab`/`Ctrl+J`/`Ctrl+K` move |
| `↑` on the first row | collapse back to the bare input |
| `→` (cursor at the end) / `Enter` | open a menu or run the item (`→` on a Wi-Fi network or Bluetooth device opens its actions) |
| `←` (cursor at the start) | go back one menu; at the top it collapses, then closes |
| `Page Down` / `Page Up` | jump a page; `Home` / `End` (empty field) the first / last row |
| `←` / `→` on a slider row | change it (`Shift` = bigger steps): night light temperature, mouse sensitivity (Setup) |
| `Esc` | close (or cancel a question such as a password) |

Typing searches every menu and submenu at once, with the path shown under each result (inside a menu it searches that menu).
Quicklinks work at the top level (`v cats`, `git`). No history is kept.

**Menu order** is in `~/.config/torii/menu.json`: `order` for the top level, `submenus.<id>` for a submenu (ids: `setup`,
`configs`, `defaults`, ...), `hidden` for ids to remove. Entries not listed keep their default place after the listed ones.
It reloads while the launcher is closed.

**Trigger** menu (`torii-*` scripts in `~/.config/torii/bin`, each also works from a terminal):
- Capture (`torii-capture`): screenshot of the screen or a zone (saved in `~/Pictures/Screenshots` and copied), screen recording
  of the focused monitor (run it again to stop, saved in `~/Videos`), text from a screen zone (OCR, English + Russian), QR code,
  colour picker.
- Transcode (`torii-transcode`): pick a recent image or video, a format (png jpg jpeg webp / mp4 mov gif) and a size; the
  result is written next to the original.
- Emoji: Trigger > Emoji, or type `:grin` at the top level. It copies the emoji and types it into the focused window.
- Reminder: minutes, then a message; a systemd timer shows a notification.
- File auto mover (`torii-automove`): while it is on, files that newly appear in `~/Downloads` are moved to the folder in
  `automove.to` of `config.json` (default `/mnt/mass/Media_MASS/Photo/inbox`). It waits on inotify, ignores partial
  downloads and files that existed before you switched it on, and never creates the folder when the share is not mounted.
  A `.zip` is unzipped once (archive order) into `<to>/_/<zip name>/` (`automove.unzipDir`, relative to `to` or absolute) and the
  zip is deleted; a broken zip stays and you get a notification; every other file lands in `<to>` itself.
- Switches: mute microphone, do not disturb, dark mode, menu bar shape (floating or attached), workspace layout
  (dwindle, master, scrolling) and window gaps (`torii-hypr`, remembered across logins).
- Passwordless sudo (`torii-sudo`): for 5 minutes or until reboot. The launcher asks for your password once (masked, never
  stored); the rule is `/etc/sudoers.d/90-torii-nopasswd`, checked with `visudo`. A root timer removes it after 5 minutes and
  `torii-sudo-reset.service` (installed by `torii-setup.sh`) removes it at every boot and shutdown. Turning it off needs no password.
- Add `~/apps` to the app menu: writes `.desktop` entries for the folders in `~/apps` so other launchers see them too.
- Speed test: network (Cloudflare) or disk (512 MB in your home folder); the result comes as a notification.

**Activity circles**: a second small pill to the right of the notch shows what is switched on right now (not background
apps): reminders (a ring that drains; click for the time left and message, the cross cancels), muted microphone, recording,
file auto mover, passwordless sudo (ring while the 5 minutes run), night light and do not disturb. Hover names the thing,
click turns it off. State comes from small files in `~/.local/state/torii/` that the `torii-*` scripts write, so it follows
changes made from a terminal too.

**Keys outside the launcher**: `mainMod+SHIFT+Q` screenshot of the screen, `+W` of a zone, `+E` starts/stops a recording (set in `binds.lua`).

**Install / Remove** (`torii-install`, `torii-apps`): packages open a small floating terminal with fzf (Tab picks several, Enter
installs or removes) and keep `packages/pacman.txt` and `packages/aur.txt` in step, so `./install.sh` brings the same set back.
Web apps (a Helium `--app=` window with the site's icon) and terminal apps (a command in a terminal, e.g. `dorm` = an ssh
command) are asked for in the launcher; their lists live in `~/.local/state/torii/{webapps,tuis}.json` (private, synced to the
home server by `private-push.sh`, restored by `personal.sh`). `Update system` runs the full upgrade. `Update torii configs` shows
`↓`/`↑` for commits to pull or push and `● changes` for local edits; it asks `[y/N]`, then commits, pulls and pushes.

**Learn**: Hyprland, tmux and Neovim shortcuts read from your own config files (`torii-learn`), plus your notes in
`~/.config/torii/learn/*.md` (opened read-only). **Todo**: add, toggle done, edit, remove, and optionally finished items at the
bottom; stored in `~/.local/state/torii/todo.json`. **System** (last): shut down, reboot, log out, sleep, each asks to confirm.

**Setup** menu: open any Hyprland/shell/kitty/tmux/nvim/zsh config in the editor (`Configs`); choose the default
browser, editor, files app and terminal (`Defaults`, `torii-default`; Hyprland binds and uwsm read
`~/.local/state/torii/defaults.env`); night light (`torii-nightlight`: temperature, manual or daily schedule; method `GPU` uses `hyprsunset`; `Screen filter` is a Hyprland screen shader that multiplies the picture by a warm colour (a calm
dark red, works on any GPU, the best choice on NVIDIA); `Screen overlay` lays a warm transparent layer over every screen, which can only blend and
tints blacks); network and Bluetooth (same backends as the control panel); default input and output device.
`~/apps` folders are listed under Apps: each folder is described by a `.desktop` file inside it (`~/apps/v2rayN-linux-64/v2rayN.desktop`). A folder without one gets it generated (`torii-apps generate`, run every time the launcher scans): the executable named like the folder, up to two levels down, and its icon. A `Windows app` manifest runs through Bottles:
`{"name": "Notepad++", "bottle": "Soft", "program": "npp.exe"}`.

**Quicklinks** live in `~/.config/torii/quicklinks.json` (hot-reloaded; type `quicklinks` in the launcher to edit):

```json
[
  {"keyword": "yt", "name": "YouTube", "url": "https://www.youtube.com/results?search_query={input}", "icon": "󰗃"},
  {"keyword": "git", "name": "My GitHub", "url": "https://github.com/equa-tory", "icon": "󰊤"}
]
```

`yt cats` searches (`{input}` is replaced), `yt` alone opens youtube.com, `git` opens its URL. `icon` is a single Nerd Font
glyph, an icon-theme name or an image path (none: the link glyph). The old `{"yt": "https://…{q}"}` map form still works.
They open in the default browser.

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

Lock screen, per-app volume. Bluetooth pairing is
"just works" only, because Quickshell has no PIN/passkey agent.

Each menu remembers the row you were on, so going back and forward lands where you left off (kept while the shell runs, nothing is written to disk).

**Launcher settings** (`launcher` in `config.json`): `placeholder` is the hint in the empty field (it fades in a moment after the
launcher opens), `rememberBack` / `rememberForward` switch the two row memories above, `menuHistory` lets menus and items you
used before rank higher while you search (never apps; the counts stay in `~/.local/state/torii/menu-usage.json`; delete the
file or set it to `false` to reset). Lists scroll smoothly and keep a row of margin, with a soft glow on the edge you can still scroll to.

**Night light fade** (Setup › Night light › Fade, 0–300 s, default 30, `0` = at once): with a daily schedule the colour eases in from
nothing to your temperature after the start time and eases out again before the end. Manual on/off and the slider act at once.

**Claude usage**: while the launcher is open and `~/.claude/.credentials.json` exists, a ring with the 5-hour usage sits next to
the weather (`torii-claude-usage`, read-only: it never refreshes the token). **Volume** changes show for about a second in the notch.
**Terminal/prompt colours**: `torii-theme` builds a five-step gradient from the wallpaper's primary → secondary → tertiary
colour (`ramp1`…`ramp5` in `tokens.json`); kitty's colours except red, nvim's blue/teal/green and the powerlevel10k prompt use it
(`~/.local/state/torii/theme/p10k-colors.zsh`, picked up by open shells at the next prompt).

**Notifications** are shown by the shell (it is the notification server, swaync is not started any more; remove it with
`pacman -Rns swaync`). A new one slides open at the right end of the notch for `notifications.popupSeconds` (5): click
runs its default action or brings the app forward, right click dismisses, hovering keeps it. The last 100 are kept in
the launcher's Notifications menu (and the bell in the control panel opens it); the badge counts the unread ones and is
hidden while do not disturb is on (`notifications.badgeInDnd`). Do not disturb also hides the other activities (only its own
circle stays) and silences the pop-ups and sounds, except critical ones.
Sounds (`torii-sound`): `sounds.reminder` / `sounds.notification` in `config.json` are file names in `~/.config/torii/sounds/`
(drop your own there) or absolute paths; missing files fall back to the freedesktop theme. `sounds.volume` is 0–1.

**Activities layout** (`config.json`): `activities.side` is `right` or `left` of the notch, `activities.style` is `pill`
(one round pill) or `circles` (every activity on its own circle).

**Media** (`Media`, MPRIS: players and browsers): whatever plays shows up as an activity, a circle with the cover and a
ring that fills with the track. Click it: title, artist and album (click them to bring the player forward), previous /
play / next, a seek bar you can drag, wheel or Left/Right (`media.seekSeconds`, default 10) to seek. Also from a key bind:
`qs -c torii ipc call media toggle|next|previous|seek 10`.
