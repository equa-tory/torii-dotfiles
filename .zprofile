# Start Hyprland through uwsm (only on a real tty, never inside ssh or another session)
if command -v uwsm >/dev/null 2>&1 && uwsm check may-start; then
    exec uwsm start hyprland.desktop
fi
