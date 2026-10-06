#!/usr/bin/env bash
# monitors.sh — lay out screens, desktops, wallpaper and bar for the
# monitors connected right now. Run by bspwmrc at start and by hotplug.sh
# on every RandR change. Idempotent: safe to run any number of times.

# One run at a time (bspwmrc and hotplug.sh can both start one); the lock is
# fd 9, which the long-lived programs started below must not inherit.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/bspwm-monitors.lock"
flock 9

# --- 1. Outputs: restore / remember the arrangement (layout.py), turn off unplugged ---
xrandr --query | awk '/ disconnected [0-9]+x[0-9]+\+/ {print $1}' |
while read -r out; do
    xrandr --output "$out" --off
done
"$(dirname "$(readlink -f "$0")")/layout.py"

# Wait until bspwm has caught up with the new layout (one monitor per screen).
screens=$(xrandr --listmonitors | awk 'NR == 1 {print $2}')
for _ in $(seq 20); do
    [ "$(bspc query -M | wc -l)" = "$screens" ] && break
    sleep 0.1
done

# --- 2. Desktops 1-10, numbered left to right across the screens ---
# 1 screen: 1-10.  2 screens: 1-5 | 6-10.  3 screens: 1-3 | 4-7 | 8-10
# (leftover desktops go to the middle screens).
mapfile -t mons < <(xrandr --listmonitors |
    sed -n 's#.* [0-9]*/[0-9]*x[0-9]*/[0-9]*+\([0-9]*\)+[0-9]* \(.*\)$#\1 \2#p' | sort -n | awk '{print $2}')
n=${#mons[@]}
# A spare placeholder per screen, so no desktop move ever empties a monitor.
for m in "${mons[@]}"; do bspc monitor "$m" -a Desktop; done
counts=(); for ((i = 0; i < n; i++)); do counts+=($((10 / n))); done
for ((r = 10 % n, i = n / 2, step = 1; r > 0; r--)); do   # middle first, then outwards
    counts[i]=$((counts[i] + 1))
    i=$((i + (step % 2 ? -step : step))); step=$((step + 1))
done
d=1
for ((i = 0; i < n; i++)); do
    names=()
    for ((j = 0; j < counts[i]; j++, d++)); do
        names+=("$d")
        if bspc query -D --names | grep -qx "$d"; then
            bspc desktop "$d" -m "${mons[i]}" 2>/dev/null
        else
            bspc monitor "${mons[i]}" -a "$d"   # lost with a removed monitor: recreate
        fi
    done
    order[i]="${names[*]}"
done
# bspwm gives every new monitor a placeholder desktop ("Desktop"); drop it.
for d in $(bspc query -D --names); do
    case $d in [1-9]|10) ;; *) bspc desktop "$d" -r 2>/dev/null ;; esac
done
for ((i = 0; i < n; i++)); do
    bspc monitor "${mons[i]}" -o ${order[i]}
done

# --- 3. Wallpaper (re-fill every screen at its new size) ---
# Same wallpaper as GNOME (ships with Ubuntu 24.04 in ubuntu-wallpapers-noble).
# Drop any image at ~/.config/bspwm/wallpaper to override it.
wp=""
for f in "$HOME/.config/bspwm/wallpaper" \
         /usr/share/backgrounds/Little_numbat_boy_by_azskalt.png; do
    [ -f "$f" ] && { wp=$f; break; }
done
if [ -n "$wp" ]; then feh --no-fehbg --bg-fill "$wp"; else xsetroot -solid "#eff1f5"; fi

# --- 4. One bar per monitor ---
"$HOME/.config/polybar/launch.sh" 9>&-

# --- 5. Lock screen image for this layout (built in the background) ---
"$HOME/.config/rofi/scripts/lock.sh" --prepare 9>&- &
