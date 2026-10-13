#!/usr/bin/env bash
# lockscreen/xscreensaver/lock.sh — lock with xscreensaver instead of
# xsecurelock (comparison build; rofi/scripts/lock.sh is still the one in use).
#
# Same look as the xsecurelock lock: the video loops with the clock
# (saver_video + ui.lua); typing brings up xscreensaver's own unlock dialog,
# themed Latte (XScreenSaver.ad), over the blurred, dimmed video.
# Same behaviour: notifications paused while locked, video kept on while
# charging, screen off after 5 minutes on battery, volume / brightness / media
# keys keep working while locked.
#
# xscreensaver is a daemon: started here if it is not running yet. Its
# settings are ~/.xscreensaver, a link to xscreensaver.conf in this folder.

here=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
lockdir=$(dirname "$here")
sockdir="${XDG_RUNTIME_DIR:-/tmp}/lockscreen"

# Ubuntu's package if installed, else the unpacked copy in ~/.local/opt.
if ! command -v xscreensaver >/dev/null; then
    opt="$HOME/.local/opt/xscreensaver/usr"
    export PATH="$opt/bin:$opt/libexec/xscreensaver:$PATH"
fi
command -v xscreensaver >/dev/null || { notify-send "Lock screen" "xscreensaver is not installed"; exit 1; }

# xss-lock --transfer-sleep-lock: suspend waits until this fd is closed. Only
# this script may hold it (closed once locked); background processes drop it.
drop_sleep_fd() { [ -n "${XSS_SLEEP_LOCK_FD:-}" ] && eval "exec $XSS_SLEEP_LOCK_FD<&-"; }

# One lock at a time (xss-lock and Super+Shift+X can both ask).
exec 8>"${XDG_RUNTIME_DIR:-/tmp}/lock-xscreensaver.lock"
flock -n 8 || exit 0

[ -e "$HOME/.xscreensaver" ] || ln -s "$here/xscreensaver.conf" "$HOME/.xscreensaver"
xrdb -merge "$here/XScreenSaver.ad"
if ! xscreensaver-command -version >/dev/null 2>&1; then
    ( drop_sleep_fd; exec xscreensaver --no-splash >/dev/null 2>&1 8>&- ) &
    for _ in $(seq 50); do xscreensaver-command -version >/dev/null 2>&1 && break; sleep 0.1; done
fi

# --- Helpers that run while locked ----------------------------------------
# Send a state to the lock-screen UI in every saver window (one per monitor).
ui() {   # ui <state> | ui pause <yes|no>
    local s cmd="script-message lockui $1 0 \"\""
    [ "$1" = pause ] && cmd="set pause $2"
    for s in "$sockdir"/mpv-*.sock; do
        [ -S "$s" ] && echo "$cmd" | socat - "UNIX-CONNECT:$s" >/dev/null 2>&1
    done
}

# The unlock dialog is xscreensaver-auth (also run briefly with --init at
# start-up, which does not count). While it is up: blur + dim, no clock.
# On battery, 5 minutes without the dialog: video paused and screen off;
# any key brings the dialog (and the video) back.
watch_dialog() {
    local up=0 now p idle=$SECONDS blanked=0
    while sleep 0.3; do
        now=0
        for p in $(pgrep -u "$USER" -x xscreensaver-au); do
            grep -qa -- --init "/proc/$p/cmdline" 2>/dev/null || now=1
        done
        if [ "$now" = 1 ]; then
            idle=$SECONDS
            [ "$blanked" = 1 ] && { ui pause no; blanked=0; }
            # Refresh now and then: ui.lua falls back to idle after 40 s of silence.
            { [ "$up" = 0 ] || [ $((SECONDS % 10)) = 0 ]; } && ui dialog
        elif [ "$up" = 1 ]; then
            ui idle
        fi
        up=$now
        if [ "$on_ac" = 0 ] && [ "$blanked" = 0 ] && [ $((SECONDS - idle)) -ge "$blank_after" ]; then
            ui pause yes; xset dpms force off 2>/dev/null; blanked=1
        fi
    done
}

# xscreensaver grabs the keyboard, so sxhkd never sees these keys while
# locked. XInput2 raw key events still reach us; run the same commands.
media_keys() {
    declare -A cmd
    local key kc
    local -A want=(
        [XF86AudioRaiseVolume]="wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        [XF86AudioLowerVolume]="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        [XF86AudioMute]="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        [XF86AudioPlay]="playerctl play-pause"
        [XF86AudioPause]="playerctl play-pause"
        [XF86MonBrightnessUp]="$HOME/.config/bspwm/brightness.sh up"
        [XF86MonBrightnessDown]="$HOME/.config/bspwm/brightness.sh down"
    )
    for key in "${!want[@]}"; do
        for kc in $(xmodmap -pke | awk -v k="$key" '{for (i = 4; i <= NF; i++) if ($i == k) {print $2; break}}'); do
            cmd[$kc]=${want[$key]}
        done
    done
    stdbuf -oL xinput test-xi2 --root 2>/dev/null |
    awk '/\(RawKeyPress\)/ {p = 1; next} p && /detail:/ {print $2; fflush(); p = 0}' |
    while read -r kc; do
        [ -n "${cmd[$kc]:-}" ] && sh -c "${cmd[$kc]}" >/dev/null 2>&1 &
    done
}

# --- Lock -------------------------------------------------------------------
on_ac=0
for ps in /sys/class/power_supply/*; do
    [ "$(cat "$ps/type" 2>/dev/null)" = Mains ] && [ "$(cat "$ps/online" 2>/dev/null)" = 1 ] && on_ac=1
done
# Testing: LOCK_ON_BATTERY=1 acts as if unplugged, LOCK_BLANK_AFTER=<s> shortens 5 min.
[ -n "${LOCK_ON_BATTERY:-}" ] && on_ac=0
blank_after=${LOCK_BLANK_AFTER:-300}
if [ "$on_ac" = 1 ]; then   # keep the video on until unlock
    saver=$(xset q | awk '/timeout:/ {print $2, $4; exit}')
    dpms_on=$(xset q | grep -c "DPMS is Enabled")
    xset s off -dpms
fi
was_paused=$(dunstctl is-paused 2>/dev/null)
dunstctl set-paused true 2>/dev/null

# Run the helpers in their own process group, so one kill stops them all.
set -m
( drop_sleep_fd; watch_dialog ) 8>&- &
dialog_pid=$!
( drop_sleep_fd; media_keys ) 8>&- &
keys_pid=$!
set +m

# Wait for the lock to be in place (then let suspend go on, see rofi/scripts/
# lock.sh) and then for the unlock.
coproc WATCH { drop_sleep_fd; exec stdbuf -oL xscreensaver-command -watch 8>&-; }
if xscreensaver-command -time 2>/dev/null | grep -q "locked"; then locked=1; else locked=0; fi
[ "$locked" = 0 ] && xscreensaver-command -lock >/dev/null
[ "$locked" = 1 ] && { drop_sleep_fd; XSS_SLEEP_LOCK_FD=""; }
# Every 2 s without news, also check that the daemon is still there and still
# locked: -watch would wait forever if xscreensaver crashed.
while true; do
    read -r -t 2 event _ <&"${WATCH[0]}"; rc=$?
    if [ "$rc" -gt 128 ]; then   # timeout
        [ "$locked" = 1 ] && ! xscreensaver-command -time 2>/dev/null | grep -q locked && break
        continue
    fi
    [ "$rc" = 0 ] || break       # -watch ended
    case $event in
        LOCK) locked=1 ;;
        UNBLANK) break ;;
    esac
    [ "$locked" = 1 ] && { drop_sleep_fd; XSS_SLEEP_LOCK_FD=""; }
done
kill "$WATCH_PID" 2>/dev/null
kill -- -"$dialog_pid" -"$keys_pid" 2>/dev/null

if [ "$on_ac" = 1 ]; then
    xset s ${saver:-600 600}
    [ "${dpms_on:-1}" -gt 0 ] && xset +dpms
fi
[ "$was_paused" = true ] || dunstctl set-paused false 2>/dev/null
pkill -USR1 -f '^bash .*polybar/scripts/notifications[.]sh'   # refresh the bell
