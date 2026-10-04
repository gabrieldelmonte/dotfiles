#!/usr/bin/env bash
# battery-notify.sh — low-battery warnings (GNOME shows these; bspwm does not).
# Checks every minute while discharging: a normal notification at 15% and a
# critical one (stays until dismissed) at 5%. Each fires once per discharge.
bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1)
[ -n "$bat" ] || exit 0
warned_low=false warned_critical=false
while true; do
    status=$(cat "$bat/status"); level=$(cat "$bat/capacity")
    if [ "$status" = Discharging ]; then
        if [ "$level" -le 5 ] && ! $warned_critical; then
            notify-send -u critical -i battery-caution "Battery critically low: ${level}%" \
                "Plug in the charger now — the notebook will shut down soon."
            warned_critical=true warned_low=true
        elif [ "$level" -le 15 ] && ! $warned_low; then
            notify-send -u normal -i battery-low "Battery low: ${level}%" "Consider plugging in the charger."
            warned_low=true
        fi
    else
        warned_low=false warned_critical=false   # re-arm after charging
    fi
    sleep 60
done
