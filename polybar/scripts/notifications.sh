#!/usr/bin/env bash
# Do-not-disturb indicator for polybar (custom/script with tail = true).
# Runs continuously: redraws every 5 s, and immediately on SIGUSR1 — the bar's
# click handler toggles dunst and sends that signal, so the bell flips at once.
# While paused, also shows how many notifications are waiting.
draw() {
    if [ "$(dunstctl is-paused 2>/dev/null)" = true ]; then
        waiting=$(dunstctl count waiting 2>/dev/null)
        [ "${waiting:-0}" -gt 0 ] 2>/dev/null || waiting=""   # only show a real count
        echo "%{F#d20f39}%{T2}󰂛%{T-}%{F-}${waiting:+ $waiting}"
    else
        echo "%{F#8839ef}%{T2}󰂚%{T-}%{F-}"
    fi
}
trap draw USR1
while true; do
    draw
    sleep 5 & wait $!   # wait returns early when USR1 arrives
done
