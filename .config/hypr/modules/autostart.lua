-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function () 
  -- torii shell: notch bar, control panel, launcher, wallpaper (replaces waybar + hyprpaper).
  -- `torii-shell fallback` brings the old ones back if it ever misbehaves.
  hl.exec_cmd("$HOME/.config/torii/bin/torii-shell start")
  hl.exec_cmd("swaync &")
  hl.exec_cmd("$HOME/.config/torii/bin/torii-nightlight apply")
  hl.exec_cmd("$HOME/.config/torii/bin/torii-automove apply")
end)
