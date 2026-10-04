#!/usr/bin/env bash
# NVIDIA GPU load and temperature for polybar. Prints "--" without an NVIDIA
# GPU (e.g. the VM). A runtime-suspended GPU (PRIME on-demand) is not woken up
# just to be measured: it shows "off" instead.
# Chip glyph (U+F2DB), same as the catppuccin tmux gpu module.
icon="%{F#8839ef}%{T2}%{T-}%{F-}"
dev=$(ls -d /sys/bus/pci/drivers/nvidia/0000:* 2>/dev/null | head -1)
if [ -z "$dev" ] || ! command -v nvidia-smi >/dev/null; then
    echo "$icon %{F#8c8fa1}--%{F-}"
    exit 0
fi
if [ "$(cat "$dev/power/runtime_status" 2>/dev/null)" = suspended ]; then
    echo "$icon %{F#8c8fa1}off%{F-}"
    exit 0
fi
IFS=', ' read -r load temp < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu \
                                         --format=csv,noheader,nounits 2>/dev/null | head -1)
[ -n "$load" ] && echo "$icon ${load}% %{F#8c8fa1}${temp}°%{F-}"
