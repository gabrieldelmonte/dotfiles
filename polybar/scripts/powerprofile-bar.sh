#!/usr/bin/env bash
# Current power mode for polybar (custom/script, tail = true): gauge icon,
# redrawn every 10 s and immediately on SIGUSR1 (sent by the power mode menu).
# Prints nothing without power-profiles-daemon, which hides the module.
command -v powerprofilesctl >/dev/null || exit 0
draw() {
    case $(powerprofilesctl get 2>/dev/null) in
        performance) echo "%{F#fe640b}%{T2}󰓅%{T-}%{F-}" ;;   # peach
        balanced)    echo "%{F#1e66f5}%{T2}󰾅%{T-}%{F-}" ;;    # blue
        power-saver) echo "%{F#40a02b}%{T2}󰾆%{T-}%{F-}" ;;   # green
        *)           echo "" ;;
    esac
}
trap draw USR1
while true; do
    draw
    sleep 10 & wait $!
done
