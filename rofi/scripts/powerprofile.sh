#!/usr/bin/env bash
# Power Mode menu (Super+P, or click the gauge in the bar): Performance,
# Balanced or Power Saver, via power-profiles-daemon — the same switch GNOME uses.
command -v powerprofilesctl >/dev/null || { notify-send "Power Mode" "power-profiles-daemon is not installed"; exit 1; }
current=$(powerprofilesctl get)
row() {  # row <profile> <icon> <label>
    local mark=""; [ "$1" = "$current" ] && mark="  (current)"
    printf '%s  %s%s\n' "$2" "$3" "$mark"
}
choice=$( { row performance "󰓅" "Performance"
            row balanced    "󰾅" "Balanced"
            row power-saver "󰾆" "Power Saver"; } |
    rofi -dmenu -i -p "Power Mode" -format i \
         -theme-str 'window {width: 340px;} listview {lines: 3;} inputbar {children: [prompt];}')
case $choice in
    0) profile=performance ;;
    1) profile=balanced ;;
    2) profile=power-saver ;;
    *) exit 0 ;;
esac
powerprofilesctl set "$profile"
pkill -USR1 -f '^bash .*polybar/scripts/powerprofile-bar\.sh'   # refresh the bar icon
