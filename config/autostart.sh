#!/usr/bin/env bash
set +e

# D-Bus & systemd environment propagation
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=wlroots:mango
systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
systemctl --user start graphical-session.target >/dev/null 2>&1 || true

# # Cleanly restart XDG desktop portal via systemd
# systemctl --user stop xdg-desktop-portal.service xdg-desktop-portal-wlr.service xdg-desktop-portal-gtk.service xdg-desktop-portal-hyprland.service >/dev/null 2>&1 || true
# systemctl --user restart xdg-desktop-portal.service &

# # Polkit authentication agent
# if [ -x "/usr/lib/xfce-polkit/xfce-polkit" ]; then
#     /usr/lib/xfce-polkit/xfce-polkit >/dev/null 2>&1 &
# fi

# Notification daemon (dunst is installed and themed)
dunst >/dev/null 2>&1 &

# Wallpaper daemon for MangoWM (apply random wallpaper & wallust colors on boot)
bash "$HOME/.config/mango/scripts/WallpaperDaemon.sh" --random >/dev/null 2>&1 &

# Night light daemon
wlsunset -s 18:00 -S 06:00 -T 6500 -t 3500 >/dev/null 2>&1 &

# Status bar (mangobar)
pkill mangobar || true
mangobar -c "$HOME/.config/mango/mangobar/config.jsonc" -s "$HOME/.config/mango/mangobar/style.css" >/dev/null 2>&1 &

# Clipboard persistence and history
wl-clip-persist --clipboard regular --reconnect-tries 0 >/dev/null 2>&1 &
wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
wl-paste --type image --watch cliphist store >/dev/null 2>&1 &


# Idle manager (hypridle with Mango config, enabled by default, caffeine off)
pkill -x hypridle 2>/dev/null || true
hypridle -q -c "$HOME/.config/mango/config/hypridle.conf" >/dev/null 2>&1 &

# Optional user pomodoro timer
if [ -f "$HOME/.config/mango/scripts/hypr-pomodoro-timer.sh" ]; then
    bash "$HOME/.config/mango/scripts/hypr-pomodoro-timer.sh" 25 5 >/dev/null 2>&1 &
fi
