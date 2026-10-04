#!/usr/bin/env bash
# Lock screen: blurred snapshot of the desktop, Latte base colour as fallback.
img="${XDG_RUNTIME_DIR:-/tmp}/lockscreen.png"
args=(-n -e -f -c eff1f5)
# Downscale + upscale is a fast stand-in for a heavy gaussian blur.
if import -silent -window root -scale 10% -blur 0x3 -scale 1000% "$img" 2>/dev/null; then
    args+=(-i "$img")
fi
# Pause notifications while locked; afterwards restore whatever was set
# before (keeps Do Not Disturb on if it was on).
was_paused=$(dunstctl is-paused 2>/dev/null)
dunstctl set-paused true
i3lock "${args[@]}"
[ "$was_paused" = true ] || dunstctl set-paused false
pkill -USR1 -f '^bash .*polybar/scripts/notifications\.sh'   # refresh the bell
rm -f "$img"
