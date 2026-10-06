#!/usr/bin/env bash
# hotplug.sh — re-run monitors.sh whenever a screen is plugged, unplugged or
# changes resolution. Started (and restarted) by bspwmrc.
dir="$(dirname "$(readlink -f "$0")")"

stdbuf -oL xev -root -event randr |   # line-buffered: xev holds events back in a pipe
    grep --line-buffered -E 'RRScreenChangeNotify|XRROutputChangeNotifyEvent' |
while read -r _; do
    # One plug produces a burst of events: wait until it has been quiet for 1 s.
    while read -r -t 1 _; do :; done
    # Its own RandR changes come back as events and cause one more run, which
    # finds nothing to change (events are not thrown away: a screen plugged in
    # meanwhile must still be handled).
    "$dir/monitors.sh"
done
