# Wallpaper folders

Open the wallpaper menu with Ctrl+Alt+Space. Page Up now jumps forward a visible
page, and Page Down jumps backward. Left/Right still move one wallpaper.
The panel keeps the same width when switching folders.

The current wallpaper is selected when opening the menu. Up moves to the folder
controls; Left/Right select a control and Enter activates it. Down returns to the
wallpapers. Down again enters the shuffle controls, and Up returns from there.
Folder controls have a keyboard selection outline and stay visible as you move.

All shows the library; Animated filters videos and GIFs automatically. These two
views cannot be deleted. Custom folders are collections of links, so the same
image can belong to several folders without copying its file. No favorites are
created.

- **New folder** (N): enter a name and press Enter.
- **Edit** (E): select a picture first, then click folder chips
  to toggle its membership. The first nine custom folders also have number keys
  1–9. Select Done and press Enter, or press Escape, to finish editing memberships.
- **A**: toggle shuffle participation for all pictures in the current folder.
  If any are excluded, enable all; otherwise exclude all. Shared pictures use
  the same shuffle setting everywhere. Space still toggles one picture.
- Drag a folder by its **⋮** handle to reorder it. Order is saved in
  `.torii-albums/.order.json`; All and Animated can be moved too.
- **Tab / Shift+Tab**: browse folders. Selecting a folder filters the thumbnails.
- **Delete** in a custom folder removes the selected picture's link only.
- **Delete folder** (D): press D once, then D again to confirm, or use the buttons. Original files stay
  in All. All and Animated are protected.

Files remain in the configured wallpaper directory. Links live under its hidden
`.torii-albums/<folder>/` directory. The helper refuses to delete a collection
containing regular files or subdirectories, so manually added originals cannot
be accidentally removed by Delete folder. Applying a wallpaper uses its source
path, so deleting its collection does not invalidate the active wallpaper.

Folder selection only filters the browser. Automatic random wallpaper changes
still use the existing library and exclusions set with Space or A.
Hidden notch widgets, including Codex, are also shown while browsing wallpapers.

## Roll back this experiment

A snapshot of the menu before adding folders is saved locally. Restore it with:

```sh
bash "$(cat ~/.local/state/torii/wallpaper-folders-backup/latest)/rollback.sh"
```

This restores the previous menu while retaining the reversed page keys and the
compact Codex widget. The removed implementation is saved in the backup too.
Original wallpapers and any collection links are untouched. The script applies
to this local experiment, rather than being a general git reset.

Backend checks: `python tests/test_wallpaper_folders.py`.
