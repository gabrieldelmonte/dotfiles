#!/usr/bin/env bash
# hotplug.sh — re-run monitors.sh whenever a screen is plugged, unplugged or
# changes resolution. Started (and restarted) by bspwmrc.
dir="$(dirname "$(readlink -f "$0")")"

xev -root -event randr | grep --line-buffered -E 'RRScreenChangeNotify|XRROutputChangeNotifyEvent' |
while read -r _; do
    # One plug produces a burst of events: wait until it has been quiet for 1 s.
    while read -r -t 1 _; do :; done
    "$dir/monitors.sh"
    # monitors.sh changes RandR itself; swallow the echo of its own changes.
    while read -r -t 2 _; do :; done
done
