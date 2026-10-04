#!/usr/bin/env bash
# brightness.sh up|down — screen backlight in 5% steps (never below 1%).
# Goes through systemd-logind, which lets the active session set the
# backlight without root or the "video" group (brightnessctl cannot here).
dev=$(ls /sys/class/backlight 2>/dev/null | head -1)
[ -n "$dev" ] || exit 0
b=/sys/class/backlight/$dev
max=$(cat "$b/max_brightness"); cur=$(cat "$b/brightness")
step=$(( max * 5 / 100 ))
case $1 in
    up)   new=$(( cur + step )) ;;
    down) new=$(( cur - step )) ;;
    *)    echo "usage: $0 up|down" >&2; exit 1 ;;
esac
min=$(( max / 100 ))
(( new < min )) && new=$min
(( new > max )) && new=$max
busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
    org.freedesktop.login1.Session SetBrightness ssu backlight "$dev" "$new"
