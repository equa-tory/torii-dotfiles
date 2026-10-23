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
| `mainMod + arrows` | move focus (across monitors too) |
| `mainMod + SHIFT + arrows` | move the window (past a monitor's edge it goes to the next monitor) |
| `mainMod + C / V / X / Z / A` | copy, paste, cut, undo, select all in any app (Ctrl+Shift variants in kitty); work inside the launcher too |
| `SUPER + Left / Right` | start / end of the line (`Shift` selects to it); works inside the launcher too |

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
  A `.zip` is unzipped once (archive order) into `<unzipTo>/<zip name>/` (`automove.unzipTo`, any path, empty = `<to>/_`) and the
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
Web apps (a Helium `--app=` window with the site's icon; with the *browser* option a normal browser tab) and TUIs (a command in a terminal; with the *quiet* option it runs with no window, a notification says when it is done and the output is in `~/.local/state/torii/tui-<name>.log`). Both options are switched in Install › Edit web apps and TUIs; removing one asks first. Example: a TUI (`dorm` = an ssh
command) are asked for in the launcher; their lists live in `~/.local/state/torii/{webapps,tuis}.json` (private, synced to the
home server by `private-push.sh`, restored by `personal.sh`). `Update system` runs the full upgrade. `Update torii configs` shows
`↓`/`↑` for commits to pull or push and `● changes` for local edits; it asks `[y/N]`, then commits, pulls and pushes.

**Learn**: Hyprland, tmux and Neovim shortcuts read from your own config files (`torii-learn`; **Enter** on a shortcut opens the config at that line). The tip shown is the comment right above a Hyprland bind (or after it), `bind -N "tip"` in tmux and `desc = "tip"` in nvim; for binds made in a loop, a `-- keys: ALT + 1 … 0 | tip` line above the loop does it, plus your notes in
`~/.config/torii/learn/*.md` (opened read-only). **Todo**: add, toggle done, edit, remove, and optionally finished items at the
bottom; stored in `~/.local/state/torii/todo.json`. **System** (last): shut down, reboot, log out, sleep, each asks to confirm.

**Setup** menu: open any Hyprland/shell/kitty/tmux/nvim/zsh config in the editor (`Configs`); choose the default
browser, editor, files app and terminal (`Defaults`, `torii-default`; Hyprland binds and uwsm read
`~/.local/state/torii/defaults.env`); night light (`torii-nightlight`: temperature, manual or daily schedule; method `GPU` uses `hyprsunset`; `Screen filter` is a Hyprland screen shader that multiplies the picture by a warm colour (a calm
dark red, works on any GPU, the best choice on NVIDIA); `Screen overlay` lays a warm transparent layer over every screen, which can only blend and
tints blacks); network and Bluetooth (same backends as the control panel); default input and output device.
AirPods and Beats show their battery (and ⚡ while charging) in both lists: BlueZ has none for them, so `torii-bt-battery` asks them over Apple's own AAP channel every 90 s while one is connected.
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

**Appearance** (Setup › Appearance): bar height and bar opacity (`notch.height`, `notch.opacity` in `config.json`, live), monitor scale
(one slider per monitor, `torii-hypr scale`), window opacity and blur (on/off, size, passes, vibrancy). Hyprland ignores a scale that leaves a
fractional logical size, so the slider snaps to the nearest factor the resolution allows (1920x1080: 0.5 … 1.25, 1.5, 2; the VM's 1896x1003 only 1).
Choices are kept in `~/.local/state/torii/hypr-user.json` and replayed at every start by `hypr-user.lua`.

**Launcher extras:** type a sum (`2+2`, `sqrt(16)*3`, `2^10`, `sin(pi/2)`) and the first row is the result, Enter copies it. Quicklinks without an
`icon` use the site's own icon (fetched once by `torii-favicon` into `~/.cache/torii/favicons`). A search that matches nothing goes to DuckDuckGo (`ddg`).
**Launcher search clutter:** Setup › Launcher search lists the menus with an On/Off switch for "their rows show up when you type" (App rules is off by
default; the menu itself is still found). **App rules** are grouped by workspace: *Capture workspace N* saves every app on that workspace at once (arrange it, then press it; "Capture workspace N again" inside a group does the same for that group), and the session rebuilds it at login. A capture *replaces* what was saved for that workspace (an app saved there that is not on it now is dropped). *Open all saved apps now* (or *Open workspace N apps* inside a group) starts the saved apps that are not open yet and leaves the open ones alone. *Use how it is now* in one app's rule saves what its open window looks like (workspace, floating, place
and size, background, start at login); terminal apps from `~/apps` (cliamp, lava lamp, ...) get their own window class `torii-app-<name>` so they can be
placed and started at login too (the session starts them silently on their workspace). **Clean up** (launcher, top level): torii-clean frees trash, app
caches, package downloads, old logs, crash dumps and Docker leftovers (root parts ask for your password in a terminal), lists unused packages, and finds files
over 100 MB in Downloads, Documents, Videos, Pictures, Desktop, Music (move to trash, show in files).

**Your own apps on the home server:** web apps and TUIs made in the launcher (Install › Web app / TUI) are kept in
`~/.local/state/torii/{webapps,tuis}.json`; a `.desktop` file you write yourself goes in `~/.local/share/applications/`, and a program folder in
`~/apps/<name>/`. `bash packages/private-push.sh` copies all of that (plus the Helium profile and LocalSend) to `~/torii-private/home/` on the server
(`ONLY=apps bash packages/private-push.sh` just the apps; `--dry-run` shows what would go). `./install.sh` restores them through `packages/personal.sh`.

**Backup copy.** The private folder is also kept on the Umbrel share (`/mnt/umbrel/Documents/torii-private`, mounted through the `Umbrel` line of `system/fstab.extra`). `private-push.sh` refreshes it at the end (or run `bash packages/private-mirror.sh`); when the home server is unreachable, `packages/personal.sh` restores from that copy instead. `ONLY=webapps` pushes just the web/terminal app lists.
Apps shipped with the repo (`apps/*/app.json`) are not pushed. **Disk usage** (`torii-gdu`, the `gdu` alias: skips network shares below the folder and reads a spinning disk one file at a time) opens on `/` including `/home`, skipping `/mnt` and `/media` (big data drives and network shares are
not scanned), in the theme colours.

**Calendar:** Tab in the calendar walks into the day's events, `d` or Delete removes the chosen one (also on iCloud); Setup › Calendar sync has
the automatic sync switch and how often it runs (1, 5, 15, 30, 60 minutes). **Night light:** Setup › Night light › Dimming sets how much darker the
screen filter makes the screen (0 = only the colour changes).

**Windows** (Alt+Tab, Alt+Shift+N, Setup › Windows):
- *Alt+Tab* shows a card with a live picture per open window, most recently used first. Tab / Shift+Tab / Alt+Left / Alt+Right move,
  letting go of Alt focuses the selected window (switching workspace, or bringing back a minimised one), **Alt+Q** closes the *selected*
  window, Esc cancels. It works the same with tiled and floating windows.
- *Alt+H* minimises the window (it stays in Alt+Tab). A quick Alt+Tab tap switches at once; the menu only opens if Alt is held.
- *Alt+Shift+N* switches the whole desktop between tiled and floating. Floating windows get a title bar (hyprbars plugin) with
  close / minimise / maximise (drag the bar to move, double-click to maximise); tiled windows have none. Each window remembers its
  floating size and place, also across the switch (animated), and the mode survives a restart. In float mode Alt+Shift+Left/Right snap a window to half of the screen (still floating), Alt+Shift+Up fills the work area (inside the gaps, below the title bar),
  Alt+Shift+Down gives the old place back. Windows that were floating on
  their own (dialogs, app rules) stay floating in tiled mode. Setup › Windows has the same switch, the bar height and which side
  the buttons are on (left: close, minimise, maximise like macOS; right: minimise, maximise, close like Windows).
- The plugin is loaded by `torii-bars-setup` (Hyprland reloads its config whenever a plugin is loaded, so the newest run wins and
  nothing is ever unloaded there). After Hyprland updates, rebuild it: `yay -S hyprland-plugin-hyprbars`. Without it only the bars are missing.

**Night light fade** (Setup › Night light › Fade, 0–300 s, default 30, `0` = at once): with a daily schedule the colour eases in from
nothing to your temperature after the start time and eases out again before the end. Manual on/off and the slider act at once.

**Claude usage**: while the launcher is open and `~/.claude/.credentials.json` exists, a ring with the 5-hour usage sits next to
the weather (`torii-claude-usage`, read-only: it never refreshes the token). **Volume** changes show for about a second in the notch.
**Terminal/prompt colours**: `torii-theme` builds a five-step gradient from the wallpaper's primary → secondary → tertiary
colour (`ramp1`…`ramp5` in `tokens.json`); kitty's colours except red, nvim's blue/teal/green and the powerlevel10k prompt use it
(`~/.local/state/torii/theme/p10k-colors.zsh`, picked up by open shells at the next prompt).

**Notifications** are shown by the shell (it is the notification server, swaync is not started any more; remove it with
`pacman -Rns swaync`). A new one opens for `notifications.popupSeconds` (5), as wide as its text needs (at most 340 px), as its own pill next to the notch (`notifications.expand`: `side`, the default) or inside the notch, which then grows around it (`center`): click
runs its default action or brings the app forward, right click dismisses, hovering keeps it. The last 100 are kept in
the launcher's Notifications menu (and the bell in the control panel opens it); the badge counts the unread ones and is
hidden while do not disturb is on (`notifications.badgeInDnd`). Do not disturb also hides the other activities (only its own
circle stays) and silences the pop-ups and sounds, except critical ones.
Sounds (`torii-sound`, Setup › Sounds picks them and plays a preview): `sounds.reminder` / `sounds.notification` in `config.json` are file names in
`~/.config/torii/sounds/` (drop your own there; two short defaults are shipped) or absolute paths; empty means `reminder.*` /
`notification.*` from that folder, then the freedesktop theme. `sounds.volume` is 0–1.

**Activities layout** (`config.json`): `activities.side` is `right` or `left` of the notch, `activities.style` is `pill`
(one round pill) or `circles` (every activity on its own circle).

**Media** (`Media`, MPRIS: players and browsers): whatever plays shows up as an activity (not while the player's own window has focus: `media.onlyWhenUnfocused`, a browser counts as focused whenever one of its windows is), a circle with the cover and a
ring that fills with the track. Click it: title, artist and album (click them to bring the player forward), previous /
play / next, a seek bar you can drag, wheel or Left/Right (`media.seekSeconds`, default 10) to seek. Also from a key bind:
`qs -c torii ipc call media toggle|next|previous|seek 10`.

**Widgets** (`widgets.left` / `widgets.right` in `config.json`, or Setup › Widgets): they only take room while the launcher or the
control panel is open (defaults: `claude` on the left with the 5-hour usage and the time until it resets, `battery` on the right,
only if the machine has one). `system` (CPU, RAM, GPU, VRAM and temperatures, `torii-sys stats`; click: the process list) and
the Processes menu are switched off for now: set `features.systemInfo` to `true` in `config.json` to bring them back. **Processes** (launcher root, `torii-sys procs`): sort by
CPU / RAM / GPU with the first row, type to filter by name or pid, Enter asks `y` (stop) or `9` (force kill). The session,
the shell, Hyprland, systemd, D-Bus, PipeWire and v2rayN are never listed.

**Popup windows and special workspaces in App rules:** *Add an app › Open windows* lists a browser's popups (for example the Google sign-in window) as their own rows ("… · popup of helium"); such a rule matches the title the popup opened with, so the next popup is caught too (it only has workspace, background and floating). The workspace picker also offers special workspaces (*Special magic*, any other existing one, or a new name), and *Capture special …* saves the apps on a special workspace. In the config a rule is `{"class": "helium", "title": "Sign in", "workspace": "special:magic"}`.

**App rules** (Setup › App rules, `torii-rules`, saved in `~/.config/torii/app-rules.json`): what happens when a window of an app
opens: on a workspace (optionally in the background, without switching to it) and/or floating. *Add an app* lists the windows
that are open right now (open the app first: its window class is what a rule matches), the installed apps, or lets you type a
class. Changes are applied to the running Hyprland at once and again at every start (`hypr-rules.lua`, loaded by `hyprland.lua`).

**Language**: the keyboard layout (EN / RU) is always shown left of the workspaces; click it to switch (`hyprctl switchxkblayout all next`).

**Dolphin** (the default file manager, `packages/dolphin.sh` seeds it once and never overwrites your changes; `--reset` restores the shipped
look): opens in Downloads, sidebar with Desktop / Documents / Downloads / Pictures / Videos / Root / Network and your drives under Devices
(the Recent, Search and Tags groups are hidden), toolbar with Back / Forward / Up / menu only. Its colours come from the wallpaper theme:
`torii-theme` writes `kdeglobals` and `torii.colors` (KDE apps ignore qt6ct for colours) and links them into `~/.config` and
`~/.local/share/color-schemes`; the icon set follows dark/light.

## Boot menu and Dolphin look
- **Limine** (`packages/limine-theme.sh`, install part `limine`): `torii-theme` renders `limine.conf` (colours from the wallpaper palette) and a
  blurred, darkened `limine-wallpaper.jpg` into `~/.local/state/torii/theme/`; the script copies them to `/boot/torii/` and keeps a
  `# torii-theme begin/end` block at the top of `/boot/limine.conf` (the boot entries are never touched; `quiet: yes` is removed so the menu shows;
  the first original is `/boot/limine.conf.torii-bak`). It needs sudo and runs when you run it, so run `bash packages/limine-theme.sh`
  again after you change the wallpaper if you want the boot menu to follow.
- **Dolphin / Qt apps**: with `darkly` (AUR, rounded soft Qt style) and `papirus-icon-theme` installed, `torii-theme` uses them (style Darkly, Papirus icons)
  and softer surfaces in the generated colour scheme; without them it falls back to Fusion + Breeze icons.

## Sync (Install > Sync torii)
Tick what to push and press *Push ticked now*; *Pull everything now* always brings all of it (`torii-sync`; both show what will happen and ask first):
**Configs** (the dotfiles repo on GitHub: commit + push / pull, uncommitted changes are kept), **Helium profile**, **Web apps and logins**,
**My desktop apps** (the ones ticked under *Choose desktop apps…*, list in `~/.local/state/torii/backup-apps.txt`) and **LocalSend** go to / come
from `torii-private` on the home server. *Push overwrites the saved copy with this computer; pull overwrites files here with the saved copy*
(replaced private files stay next to the new one as `*.bak`). Close Helium and the web apps before pushing or pulling its profile.
The server is reached over ssh with this computer's key (add it to GitHub, then run `update-ssh-keys.sh` from the Umbrel share); when ssh is
refused, `personal.sh` shows the key and falls back to the backup copy on the Umbrel share over SMB (you only type the Umbrel password).

### Qt style and icon themes: install, remove, test
- **Folders in the accent colour:** `torii-theme` builds `~/.local/share/icons/Papirus-Torii` (Papirus with every blue folder icon swapped for the Papirus
  colour nearest to the wallpaper accent: red, orange, yellow, green, teal, cyan, blue, indigo, violet, magenta, grey). It changes with the wallpaper
  (run `torii-theme restore -f` to rebuild by hand, restart Dolphin to see it).
- **Install** a style or icons: `yay -S darkly papirus-icon-theme` (or any other from the AUR / `pacman -S`); icon themes are folders in `/usr/share/icons`
  or `~/.local/share/icons`, Qt styles are plugins in `/usr/lib/qt6/plugins/styles`. **Remove**: `yay -Rns darkly`; torii-theme falls back to Fusion and
  Breeze by itself. **Test** without changing anything: `QT_STYLE_OVERRIDE=Fusion dolphin` (style), `dolphin` after `kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark` (icons, undo with the old name), or look at what is installed: `ls /usr/lib/qt6/plugins/styles /usr/share/icons`.
- **Make torii colour another style / icon theme:** the colours already reach every Qt app through `~/.config/kdeglobals` (the `torii` colour scheme) and qt6ct;
  set the name in `torii-theme` (`widget_style()` and `icon_theme()`). Styles that draw their own colours (Kvantum themes) ignore the scheme: use Kvantum's
  "Kvantum" style with a theme made from `~/.local/state/torii/theme/tokens.json`, or keep a scheme-following one like Darkly.

## Boot menu look and system snapshots
- **Boot menu look** (Setup > Boot menu, `limine` in `~/.config/torii/config.json`): picture (the desktop wallpaper or any image), brightness, blur and how solid
  the dark panel behind the text is. *Apply* runs `packages/limine-theme.sh` (sudo) and takes effect at the next boot.
- **Snapshots** (`packages/snapshots.sh`, install part `snapshots`; btrfs root + Limine): snapper takes a snapshot of `/` before and after every pacman
  transaction (snap-pac) and on demand (Setup > System snapshots). The newest three states from before an update (or taken by hand) are in the Limine menu
  under *Snapshots*: each boots a writable copy of that state with its own kernel, so an update that broke something can be undone by booting the
  snapshot. To make it permanent: `sudo torii-snapshots rollback` (or the launcher entry): the snapshot becomes the system again, the broken one stays as
  `@broken-<date>`, reboot. `/home`, logs and the package cache are not part of a snapshot. Snapshots are on the same disk: they undo a bad update,
  they are not a backup against a dead drive.

## Games (Steam, Proton)
- Steam games open fullscreen on the 240 Hz monitor (window rule in `hypr/modules/rules.lua`); the game itself stays windowed in its video settings, because its own fullscreen mode breaks the mouse under XWayland. **Alt+Shift+F** leaves / enters fullscreen.
- The launcher, control centre (Alt+N) and Alt+Tab switcher show over a fullscreen window too (the notch window moves to the overlay layer while a panel is open).
- While a game is fullscreen and has the focus the normal binds are off, so Alt+1..0 and the other Alt keys reach the game. Kept: Alt+Shift+F, Alt+Space (launcher), Alt+N (control centre), Alt+Tab, the media keys. Out of fullscreen (Alt+Shift+F), or while a panel (launcher, control centre, Alt+Tab) is open, every bind works; **Alt+Shift+G** gives the window binds back by hand.
- Windows mode (Alt+Shift+N): the focus changes only when you click a window, hovering the mouse over one does not; in tiling mode hovering still focuses.
- Tiling mode, floating window: **Alt+Shift+arrows** nudge it 80 px; at the screen edge Left / Right carry it to the next monitor.
- Defaults for all games: `PROTON_ENABLE_NVAPI=1` and `PROTON_USE_NTSYNC=1` (uwsm/env, ntsync module from `torii-setup.sh`), `gamemoderun` as the launch option and GE-Proton as the compatibility tool: `bash packages/steam-defaults.sh` with Steam closed (run it again after installing new games; your own launch options are kept). gamemode switches the CPU to the performance governor while a game runs (`.config/gamemode.ini`, polkit rule from `torii-setup.sh`).
- Deadlock: `-novid -high` in its launch options. Per game, the options are Steam > game > Properties.

## open: files from the terminal
`open FILE...` (alias of `torii-open`, Linux) opens each file with the app for its kind: video and audio in mpv, pictures in imv, pdf in zathura, markdown rendered in glow (a pager, `q` leaves; `open -c file.md` to pick nvim or bat instead), text / json / code (cpp cs py lua sh ...) in nvim in the same terminal, databases in DB Browser, `.exe` through umu + GE-Proton in one shared prefix (`~/.local/share/torii/wine-prefix`: no bottle per program, first start sets the prefix up, big programs like Krita take ~30 s; log `~/.local/state/torii/umu.log`). If a kind has no app set or installed it asks (fzf list of installed apps that handle it, or "install mpv" etc.) and remembers the answer in `~/.local/state/torii/open-apps.conf`. `open -c FILE` chooses again, `torii-open --list` shows the table, `torii-open --apply` (run by install.sh) makes Dolphin and `xdg-open` use the same apps. The kinds and their preferred apps are the `KINDS` table at the top of `.config/torii/bin/torii-open`.

## LocalSend: text is pasted at once
`torii-localsend watch` (started at login by `hypr/modules/autostart.lua`) reads LocalSend's receive history; when a text message arrives it goes to the clipboard and is pasted into the focused window (Ctrl+V, Ctrl+Shift+V in a terminal) with a small notification. LocalSend itself is not changed. Turn on **Quick Save** once in LocalSend (Settings > Receive) so a message is accepted without a dialog; its window does not take the focus (window rule) and is closed again right after the paste (it goes to the tray). If you are in the LocalSend window itself, the text is only copied. Copy only, no paste: `~/.local/state/torii/localsend.json` with `{"paste": false}`. Files still go to LocalSend's folder as before.

## Windows mode: resize and maximise
- **Resize edge** (Setup > Windows): drag the edge of a window to resize it; the slider is how far outside the window the grab area reaches (0 = off, default 12 px).
- Double-click the title bar: the action is chosen in Setup > Windows > "Double-click on the title bar" (maximise by default: fills the work area and a second double-click gives the old size back; fullscreen, big window, centre, minimise or nothing). The green button always maximises. Dragging the title bar of a window filled this way gives it its old size at once, with the mouse on the bar; that first drag ends there (press the bar again to carry on). It needs `ydotoold` (started at login): a virtual mouse release ends Hyprland's own drag, which would otherwise jump away from the mouse. Nothing is ever pressed virtually, so no button can stay down.

## Launcher: Ctrl+K on a row, app rules, resize from the top

* **Ctrl+K** on any row or folder opens its small menu: *Pin to the launcher* (pinned rows show as soon as the launcher opens, above the menus; Down from the last one shows the rest), *Add alias* (typing it finds the row first, also inside menus the search skips), *Add binding* (press the keys; a Hyprland bind runs the row, or opens the folder in the launcher: `torii-binds` writes `~/.local/state/torii/launcher-binds.lua`), *Never show this* (hidden everywhere, quicklinks too). The same rows undo each one, and Setup › Launcher search lists everything chosen this way. Ctrl+P is up now (Ctrl+K was).
* Setup › App rules › *Add the focused app* (and every other way of adding one) opens the new rule's settings at once.
* Trigger › *Date next to the clock* puts the date in the notch clock.
* A floating window can be resized from the strip just above its title bar (top, top-left, top-right): `modules/edgeresize.lua` switches on a mouse-resize submap while the cursor is there.

## Screen recording with sound

Trigger › Capture › *Screen recording* (`torii-record`, `torii-capture record` starts and stops it): the picture is recorded by wf-recorder, each sound by pw-record, and ffmpeg joins them when you stop (the video is copied, not encoded again). Choose what goes in: what the computer plays, the microphone, and programs on their own track (the list shows what plays sound now, e.g. the game and Discord; a program must be playing when the recording starts). *Separate audio tracks* makes every source its own track in the file (Off: one mix); *Folder with files* saves `~/Videos/<time>/video.mp4` (mixed sound) plus one `.flac` per source instead of one file. *Microphone volume* is the real input level, *Microphone in the recording* a gain applied to the file only, and *Hear the microphone* plays it in the output to check (it stops by itself). Settings: `capture.rec` in `config.json`.

**Web apps on their own recording track.** Every window of the ordinary browser (Helium) plays into the same sound stream, so the Discord web app cannot be told apart from a music tab. Install › Edit web apps and TUIs › *web app* › **Own browser process** starts that web app with a profile of its own (`~/.local/share/torii/webapp/<name>`, sign in once more): its sound is then a stream of its own, listed in Screen recording › Programs on their own track as "Discord (web app)".

**Dolphin previews.** `ffmpegthumbs` (video), `kdegraphics-thumbnailers`, `kimageformats` and kio-extras (music covers) are installed, and `torii-setup.sh` writes the preview list into `dolphinrc` (it had been left empty, which turns every thumbnail off). Quick look: Dolphin has no Space-bar preview, but F11 (Information panel) shows the picture, video or cover of the selected item with a play button, and its details.

**Installs and the dotfiles.** Install › *Add installs to the dotfiles* (`install.track` in `config.json`): on, packages installed or removed in the launcher are written to `packages/pacman.txt` and `aur.txt`; off, they are left alone.

**Disk usage like FreeCommander / WizTree.** Walking the folders of a big NTFS drive takes minutes, because every folder is a seek (a spinning disk) and gdu has to ask the kernel about millions of files. Windows tools are fast because they read the NTFS Master File Table, which holds every name, parent and size, in one pass. `torii-gdu` does that for an NTFS drive (`torii-gdu /mnt/hdd01`, or Disk usage in the launcher, which asks which disk): `.config/torii/src/torii-mft.c` (built once into `~/.cache/torii/torii-mft` with `cc`) reads the table through the block device (it asks for your sudo password) and writes the JSON that `gdu -f` shows. Tested: hdd02 (850 GiB, 285 000 files) in 0.2 s, hdd01 (925 GiB, 1.08 million files) in a few seconds, totals within 1 GiB of `df`. The view is of the scan (no delete in it); other disks and folders use plain gdu, which now leaves out the drives under `/` and the network shares.

**Archives.** Double-click (or `open FILE`) on a zip, tar.*, 7z or rar extracts it into a folder named like the archive next to it (`-1`, `-2`... when that exists), with a notification when it is done (`extract:here` in `torii-open`, bsdtar). Setup › Defaults › Open files with › archive can pick Ark instead. `torii-setup.sh` also writes `ShowPreview=true` into Dolphin's global view properties.

## Clipboard history (Super+V)

Super+V opens the clipboard history in the notch: type to filter, Up/Down choose, Enter pastes into the window underneath
(Ctrl+Shift+V in a terminal), Delete forgets the chosen entry, Ctrl+Delete forgets all. `cliphist` records text and images
(`torii-clip watch` runs from the autostart); `torii-clip list|paste|delete|clear` are the commands behind it.

## Wallpapers menu and a random wallpaper

Setup > Wallpapers: open the wallpaper panel, open the wallpapers folder, "Change randomly" (off, a minutes slider from 5 to 120, on login) and "Random wallpaper now".
`torii-wallpaper shuffle off|<minutes>|login` does it (a systemd user timer for minutes; the autostart runs it once for "login"); `wallpaper.shuffle` in config.json.

Weather: the shell fetches it with `curl` (Qt's own requests never finished here). When the weather service is blocked, set `weather.proxy`
(e.g. `http://127.0.0.1:10808`): it is used when the direct request fails. A failed fetch is why the weather icon turns dim: it fades to half after 50 minutes without fresh data.

A quiet TUI app that fails now says "click to see the log": the notification opens the log in a terminal.
The game keys (Alt binds off in a fullscreen Steam game) only count while that game is on the visible workspace, so leaving it for another workspace gives the shortcuts back.

## Night light per monitor

Setup > Night light > Per monitor: a slider for each monitor (2000-6500 K); "Same temperature on all monitors" undoes it. Works in the GPU
and the Screen filter methods (the filter's dimming is applied per monitor too), not in the overlay.
hyprsunset can only colour every screen alike, and wlsunset grabs all outputs for itself, so with an own temperature set `torii-ctm`
(src/torii-ctm.c, built on first use into ~/.cache/torii) sets one colour matrix per monitor through the same Hyprland protocol as hyprsunset.
It re-reads ~/.local/state/torii/ctm.txt when that changes, so moving a slider does not flicker. `torii-nightlight monitor <name|all> <kelvin>|reset`.

TUI apps get ~/.local/bin and ~/.cargo/bin on the PATH (apps started from the launcher did not, so `claude` was not found).

Title bars are fully opaque now (the theme template used 95 % alpha, so blur and the window shadow showed through the bar and its rounded corners).

Per-monitor night light: wlsunset needs the cold side warmer than the warm side, so a fixed temperature is sent as T and T+1 K (before, the process refused to start and the screen went neutral).

Alt+Tab: if the shell's window list is empty (it went stale once after a fullscreen game) the key now refreshes it and retries instead of doing nothing. `qs -c torii ipc call windows count` prints "listed/known" windows ("0/61" = stale list) for diagnosing.

## Letter workspaces (Alt+W, letter)

Alt+W then a letter (a-z) goes to the workspace of that letter, Alt+Shift+W then a letter moves the window there (Esc, any other key or 2 s cancels). Nothing else changed:
the numbers and every other bind stay. A letter is a named Hyprland workspace; you give it apps in Setup > App rules > (an app) > Workspace > Letter…
(or pick a letter already in use). The notch shows a pill for every letter that has an app rule or a window, left of the numbered workspaces
(the clock stays in the middle); the pills get an outline while Alt+W waits for the letter. Removing the last rule that uses a letter
removes its pill. Changing an app's workspace in the rules menu now keeps you in that menu (it used to fall back to the App rules list because the app moved to another group).

## Editing installed web apps and TUIs

Install > Edit web apps and TUIs: pick one and change it without removing it: a web app's browser / own process toggles, address and name; a TUI's "close when done (no window)", command and name.
**Command for the terminal**: a word (e.g. `ddd`) that runs the TUI in whatever terminal you type it in, with arguments passed on; it is a tiny script
`~/.local/bin/<word>` (marked torii-tui-alias, removed again when you clear or change the word), so nothing goes into .zshrc. A word that is already a
program (`dd`, `ls`) is refused unless you end it with `!` (`dd!`): then yours comes first on the PATH and the real program stays at /usr/bin. `torii-apps tui alias <name> <word|none>`, `edit`, `rename` do the same from a terminal.

Web apps on an address with a port (http://192.168.1.160:8123): the desktop entry's window class now leaves the port out like Chromium does, so "Start at login" in App rules finds the app (it used to fail with "Can't start").

## Moving the notch widgets

Setup > Widgets now moves every widget of the notch: keyboard layout, letter workspaces, workspaces, special workspaces and weather (next to Claude usage,
battery and system load). Each one goes Left or Right of the clock, or Off, and "Move closer to the clock / away from the clock" changes the order.
Where they were stays the default (language, letters, workspaces, special on the left next to the clock; weather first on the right).
The control panel arrow is pinned to the notch's right edge, whatever is on the right. Layout: `widgets.left`, `widgets.right`, `widgets.off` in config.json.
