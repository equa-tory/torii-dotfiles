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
  hl.exec_cmd("$HOME/.config/torii/bin/torii-binds apply")         -- launcher shortcuts that came with a copied config
  hl.exec_cmd("$HOME/.config/torii/bin/torii-clip watch")            -- clipboard history (Super+V)
  hl.exec_cmd("ydotoold")                                            -- a virtual mouse: dragging a maximised window out of it (floatmode.lua)
  -- a pairing agent: without one BlueZ answers "AuthenticationFailed" to a controller (Xbox) that pairs from the control centre
  hl.exec_cmd("sh -c 'pgrep -x bluetoothctl >/dev/null || { echo agent NoInputNoOutput; echo default-agent; sleep infinity; } | bluetoothctl >/dev/null 2>&1'")
  hl.exec_cmd("$HOME/.config/torii/bin/torii-bt-connect")           -- paired Bluetooth devices (AirPods, controller) connect after login
end)
