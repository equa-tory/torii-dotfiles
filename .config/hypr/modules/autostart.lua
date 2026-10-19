-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function () 
  -- torii shell: notch bar, control panel, launcher, wallpaper (replaces waybar + hyprpaper).
  -- `torii-shell fallback` brings the old ones back if it ever misbehaves.
  hl.exec_cmd("$HOME/.config/torii/bin/torii-shell start")
  hl.exec_cmd("$HOME/.config/torii/bin/torii-nightlight apply")
  hl.exec_cmd("$HOME/.config/torii/bin/torii-automove apply")
  hl.exec_cmd("$HOME/.config/torii/bin/torii-remind apply")
  hl.exec_cmd("$HOME/.config/torii/bin/torii-sudo clear")
  hl.exec_cmd("$HOME/.config/torii/bin/torii-capture reset")
  hl.exec_cmd("$HOME/.config/torii/bin/torii-rules autostart")      -- apps with "Start at login" in Setup > App rules
  hl.exec_cmd("$HOME/.config/torii/bin/torii-localsend watch")       -- text sent with LocalSend is copied and pasted
  hl.exec_cmd("ydotoold")                                            -- a virtual mouse: dragging a maximised window out of it (floatmode.lua)
end)
