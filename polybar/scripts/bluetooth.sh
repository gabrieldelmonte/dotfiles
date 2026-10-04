#!/usr/bin/env bash
# Bluetooth status for polybar. No adapter (e.g. the VM) → no output → module hidden.
show=$(timeout 2 bluetoothctl show 2>/dev/null)
[ -n "$show" ] || exit 0

blue="#1e66f5"; grey="#8c8fa1"
if ! grep -q "Powered: yes" <<<"$show"; then
    echo "%{F$grey}%{T2}󰂲%{T-} off%{F-}"
    exit 0
fi
device=$(timeout 2 bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)
if [ -n "$device" ]; then
    echo "%{F$blue}%{T2}󰂱%{T-}%{F-} ${device:0:12}"
else
    echo "%{F$blue}%{T2}󰂯%{T-}%{F-} on"
fi
