-----------------------
---- WINDOW BARS   ----
-----------------------
-- Title bars (close / minimise / maximise, drag to move, double-click to maximise) on floating windows, drawn by the
-- hyprbars plugin (AUR hyprland-plugin-hyprbars; packages/aur.txt). Tiled windows have none. Height and the side of the
-- buttons are chosen in Setup > Windows (torii-hypr bars). hl.plugin.load does not load a plugin from the config, so
-- torii-bars-setup loads it once Hyprland is up and then runs windowbars_apply.lua. A missing or mismatched plugin only
-- means no bars; the session is not affected.
hl.exec_cmd(os.getenv("HOME") .. "/.config/torii/bin/torii-bars-setup")
