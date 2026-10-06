#!/usr/bin/env bash
# Start one polybar per monitor (re-run safely on bspwm restart).
killall -q polybar
for i in $(seq 15); do
    pgrep -u "$UID" -x polybar > /dev/null || break
    [ "$i" = 15 ] && killall -q -9 polybar   # still there after 3 s: force it
    sleep 0.2
done

for m in $(polybar --list-monitors | cut -d":" -f1); do
    MONITOR=$m polybar --reload main >"${XDG_RUNTIME_DIR:-/tmp}/polybar-$m.log" 2>&1 &
done
