#!/usr/bin/env bash
# Power menu (Super+X or the power pill in polybar).
dir="$(dirname "$(readlink -f "$0")")"
lock="󰌾  Lock"
logout="󰍃  Log out"
suspend="󰒲  Suspend"
reboot="󰜉  Reboot"
shutdown="󰐥  Shut down"

choice=$(printf '%s\n' "$lock" "$suspend" "$logout" "$reboot" "$shutdown" |
    rofi -dmenu -i -p "Power" -theme-str 'window {width: 320px;} listview {lines: 5;} inputbar {children: [prompt];}')

case "$choice" in
    "$lock")     "$dir/lock.sh" ;;
    "$suspend")  systemctl suspend ;;
    "$logout")   bspc quit ;;
    "$reboot")   systemctl reboot ;;
    "$shutdown") systemctl poweroff ;;
esac
