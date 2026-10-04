#!/usr/bin/env bash
# monitors.sh — lay out screens, desktops, wallpaper and bar for the
# monitors connected right now. Run by bspwmrc at start and by hotplug.sh
# on every RandR change. Idempotent: safe to run any number of times.

# --- 1. Outputs: enable new ones (right of the primary), turn off unplugged ---
primary=$(xrandr --query | awk '/ connected primary/ {print $1; exit}')
[ -n "$primary" ] || primary=$(xrandr --query | awk '/ connected/ {print $1; exit}')

xrandr --query | awk '/ connected/ && !/[0-9]+x[0-9]+\+[0-9]+\+[0-9]+/ {print $1}' |
while read -r out; do
    xrandr --output "$out" --auto --right-of "$primary"
done
xrandr --query | awk '/ disconnected [0-9]+x[0-9]+\+/ {print $1}' |
while read -r out; do
    xrandr --output "$out" --off
done

# --- 2. Desktops: 1-5 on the primary, 6-10 on the second screen (if any) ---
second=$(bspc query -M --names | grep -vx "$primary" | head -1)
for d in 1 2 3 4 5 6 7 8 9 10; do
    target=$primary
    [ -n "$second" ] && [ "$d" -ge 6 ] && target=$second
    if bspc query -D --names | grep -qx "$d"; then
        bspc desktop "$d" -m "$target" 2>/dev/null
    else
        bspc monitor "$target" -a "$d"   # lost with a removed monitor: recreate
    fi
done
# bspwm gives every new monitor a placeholder desktop ("Desktop"); drop it.
for d in $(bspc query -D --names); do
    case $d in [1-9]|10) ;; *) bspc desktop "$d" -r 2>/dev/null ;; esac
done
if [ -n "$second" ]; then
    bspc monitor "$primary" -o 1 2 3 4 5
    bspc monitor "$second"  -o 6 7 8 9 10
else
    bspc monitor "$primary" -o 1 2 3 4 5 6 7 8 9 10
fi

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
"$HOME/.config/polybar/launch.sh"

# --- 5. Lock screen image for this layout (built in the background) ---
"$HOME/.config/rofi/scripts/lock.sh" --prepare &
