# Backing up chosen .desktop apps to torii-private (plan, not built yet)

Status: **idea, untested**. The home server is off; try it tomorrow and then build it.
The leading `_` marks it as a note, not finished documentation.

## What already works
`personal.sh` pulls everything under `equa@192.168.1.50:torii-private/home/` into `$HOME`
(`rsync -a --backup --suffix=.bak`), so anything pushed there comes back on a fresh install together with
`~/apps/v2rayN-linux-64` and the Helium profile. `packages/private-push.sh` is the push side (`helium-push.sh` is
its Helium-only shortcut). `~/.local/state/torii/{webapps,tuis}.json` already go the same way.

## The idea
Only the apps you choose, not every `.desktop`:

1. A list `~/.config/torii/backup-apps.txt` (in the repo, one desktop-file name per line, `#` comments):
   ```
   v2rayN.desktop
   telegram-desktop.desktop
   ```
   Only entries from `~/.local/share/applications` (the ones you or torii created, `torii-app-*`, web apps).
   System ones from `/usr/share/applications` come from packages and are not backed up.
2. `private-push.sh` gets one more path group: for each name in the list, push
   `.local/share/applications/<name>` plus whatever it needs:
   - the `Icon=` file when it is an absolute path inside `$HOME`;
   - for `~/apps/<folder>` apps, the folder itself (like v2rayN today). Big ones are rsynced with `--exclude` for
     caches and logs.
3. `personal.sh` needs no change: the files land back in `~/.local/share/applications` and `~/apps`.
   Then `apps-sync.sh` runs `torii-apps generate`, which rebuilds the `.desktop` of any `~/apps` folder that lacks one.
4. Launcher: Install/Remove menu entry "Back up this app" (adds/removes the name in the list) and a Trigger entry
   "Push private backup" that runs `private-push.sh` in a floating terminal (never silently, it can be hundreds of MB).

## Open questions for tomorrow
- Is the server reachable by name or only by `192.168.1.50`? (the scripts use the address)
- Size of `~/apps` folders worth pushing, and whether the web-app profile data should be left out.
- Games and anything with a licence/token inside the folder must stay out of the list (the server copy is private,
  the repo is public: the *list* is in the repo, the *files* never are).
