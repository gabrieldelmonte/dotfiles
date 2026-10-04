#!/usr/bin/env bash
# CPU temperature for polybar, shown next to the CPU usage.
# Average of all cores — the same value the tmux-cpu plugin shows — turning
# red from 85°C. Prints "--" without sensors (e.g. the VM).
sum=0 n=0
for h in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$h/name" 2>/dev/null)" = coretemp ] || continue
    for label in "$h"/temp*_label; do
        case $(cat "$label") in
            Core*) sum=$(( sum + $(cat "${label%_label}_input") )); n=$(( n + 1 )) ;;
        esac
    done
done
if [ "$n" -eq 0 ]; then
    echo "%{F#8c8fa1}--°%{F-}"
    exit 0
fi
avg=$(( (sum / n + 500) / 1000 ))
if [ "$avg" -ge 85 ]; then
    echo "%{F#d20f39}${avg}°%{F-}"
else
    echo "%{F#8c8fa1}${avg}°%{F-}"
fi
