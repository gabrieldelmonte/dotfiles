#!/usr/bin/env bash
# Lock screen (Super+Shift+X, power menu, idle and suspend via xss-lock).
#
# With xsecurelock + mpv and a video at wallpapers/lockscreen.mp4 in this
# repo (a link to the actual file), the video loops full-screen while locked;
# typing blurs it and shows a GNOME-style card (lockscreen/: saver_video,
# ui.lua, auth_card).
# Otherwise: i3lock with the desktop wallpaper.
#
# "lock.sh --prepare" only pre-renders the i3lock fallback image (monitors.sh
# runs it at login and on hotplug, so locking itself stays instant).

dotfiles=$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)
video="$dotfiles/wallpapers/lockscreen.mp4"

# --- Fallback image: wallpaper filled per monitor (i3lock cannot scale) -------
wallpaper=""
for f in "$HOME/.config/bspwm/wallpaper" \
         /usr/share/backgrounds/Little_numbat_boy_by_azskalt.png; do
    [ -f "$f" ] && { wallpaper=$(readlink -f "$f"); break; }
done
screen=$(xrandr --query | sed -n 's/.* current \([0-9]*\) x \([0-9]*\),.*/\1x\2/p')
monitors=$(xrandr --listmonitors | sed -n 's#.* \([0-9]*\)/[0-9]*x\([0-9]*\)/[0-9]*+\([0-9]*\)+\([0-9]*\) .*#\1x\2+\3+\4#p')
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/lockscreen"
key=$(printf '%s %s %s %s' "$wallpaper" "$(stat -c %Y "$wallpaper" 2>/dev/null)" "$screen" "$monitors" | md5sum | cut -c1-12)
img="$cache_dir/$key.png"
if [ -n "$wallpaper" ] && [ ! -f "$img" ]; then
    mkdir -p "$cache_dir"
    rm -f "$cache_dir"/*.png   # old layouts / wallpapers
    layers=()
    for m in $monitors; do
        size=${m%%+*}; offset=+${m#*+}
        layers+=( \( "$wallpaper" -resize "${size}^" -gravity center -extent "$size" +gravity \) -geometry "$offset" -composite )
    done
    convert -size "$screen" xc:'#eff1f5' "${layers[@]}" -depth 8 "$img.tmp.png" && mv "$img.tmp.png" "$img"
fi
[ "$1" = --prepare ] && exit 0

# --- Locker ------------------------------------------------------------------
if command -v xsecurelock >/dev/null && command -v mpv >/dev/null && [ -f "$video" ]; then
    # Video + GNOME-style card: our own saver and auth module (lockscreen/).
    # auth_card checks the password with xsecurelock's PAM helper and falls back
    # to xsecurelock's own dialog (styled below) if anything goes wrong.
    export XSECURELOCK_SAVER="$dotfiles/lockscreen/saver_video"
    export XSECURELOCK_AUTH="$dotfiles/lockscreen/auth_card"
    export XSECURELOCK_SAVER_RESET_ON_AUTH_CLOSE=0
    export XSECURELOCK_BACKGROUND_COLOR="#1e1e2e"                  # before the first frame
    # Fallback dialog (auth_x11) only: dark Latte.
    export XSECURELOCK_SHOW_DATETIME=1
    export XSECURELOCK_DATETIME_FORMAT="%H:%M  ·  %A, %d %B"
    export XSECURELOCK_SHOW_USERNAME=1
    export XSECURELOCK_SHOW_HOSTNAME=0
    export XSECURELOCK_SHOW_KEYBOARD_LAYOUT=1
    export XSECURELOCK_PASSWORD_PROMPT=asterisks
    export XSECURELOCK_FONT="Ubuntu Sans:size=16"
    export XSECURELOCK_AUTH_BACKGROUND_COLOR="#4c4f69"
    export XSECURELOCK_AUTH_FOREGROUND_COLOR="#eff1f5"
    export XSECURELOCK_AUTH_WARNING_COLOR="#f38ba8"   # readable red on dark
    export XSECURELOCK_SINGLE_AUTH_WINDOW=1
    export XSECURELOCK_DISCARD_FIRST_KEYPRESS=0   # first key typed is part of the password
    export XSECURELOCK_AUTH_TIMEOUT=30
    # Never blank while locked: the video keeps playing until you unlock.
    # (X's own screen saver / DPMS timers are paused below for the same reason.)
    export XSECURELOCK_BLANK_TIMEOUT=-1
    keep_screen_on=1
    # Keys that keep working while locked.
    export XSECURELOCK_KEY_XF86AudioRaiseVolume_COMMAND="wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
    export XSECURELOCK_KEY_XF86AudioLowerVolume_COMMAND="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
    export XSECURELOCK_KEY_XF86AudioMute_COMMAND="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    export XSECURELOCK_KEY_XF86AudioPlay_COMMAND="playerctl play-pause"
    export XSECURELOCK_KEY_XF86AudioPause_COMMAND="playerctl play-pause"
    export XSECURELOCK_KEY_XF86MonBrightnessUp_COMMAND="$HOME/.config/bspwm/brightness.sh up"
    export XSECURELOCK_KEY_XF86MonBrightnessDown_COMMAND="$HOME/.config/bspwm/brightness.sh down"
    locker=(xsecurelock)
else
    locker=(i3lock -n -e -f -c eff1f5)
    [ -f "$img" ] && locker+=(-i "$img")
fi

# Pause notifications while locked; afterwards restore whatever was set
# before (keeps Do Not Disturb on if it was on).
was_paused=$(dunstctl is-paused 2>/dev/null)
dunstctl set-paused true

# xss-lock --transfer-sleep-lock hands over a file descriptor that the locker
# closes once the screen is locked, which lets suspend continue. This wrapper
# must not keep its own copy open, or suspend waits for the timeout.
# Keep the display on while the video lock is up; restore the timers after.
if [ -n "${keep_screen_on:-}" ]; then
    saver=$(xset q | awk '/timeout:/ {print $2, $4; exit}')   # e.g. "600 600"
    dpms_on=$(xset q | grep -c "DPMS is Enabled")
    xset s off -dpms
fi

"${locker[@]}" &
locker_pid=$!
[ -n "$XSS_SLEEP_LOCK_FD" ] && eval "exec $XSS_SLEEP_LOCK_FD<&-"
wait "$locker_pid"

if [ -n "${keep_screen_on:-}" ]; then
    xset s ${saver:-600 600}
    [ "${dpms_on:-1}" -gt 0 ] && xset +dpms
fi

[ "$was_paused" = true ] || dunstctl set-paused false
pkill -USR1 -f '^bash .*polybar/scripts/notifications\.sh'   # refresh the bell
