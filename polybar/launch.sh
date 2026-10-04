#!/usr/bin/env bash
# Start one polybar per monitor (re-run safely on bspwm restart).
killall -q polybar
while pgrep -u "$UID" -x polybar > /dev/null; do sleep 0.2; done

for m in $(polybar --list-monitors | cut -d":" -f1); do
    MONITOR=$m polybar --reload main >"${XDG_RUNTIME_DIR:-/tmp}/polybar-$m.log" 2>&1 &
done
