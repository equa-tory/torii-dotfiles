# Start Hyprland through uwsm (only on a real tty, never inside ssh or another session)
if uwsm check may-start; then
    exec uwsm start hyprland.desktop
fi
