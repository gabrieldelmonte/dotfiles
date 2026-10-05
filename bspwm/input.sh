#!/usr/bin/env bash
# input.sh — apply GNOME's keyboard, mouse, touchpad and trackpoint settings
# under bspwm.
#
# GNOME's settings daemon does this in a GNOME session; bspwm has none, so
# devices otherwise run on libinput defaults (fast, with acceleration). The
# values come from org.gnome.desktop.peripherals.*, i.e. what you set in
# Settings → Keyboard and Mouse & Touchpad (Super+I) — layouts, keyboard options
# such as Caps Lock behaviour, pointer speed. With --watch, changes apply live.
#
#   input.sh          apply to the keyboard and all pointing devices now
#   input.sh --watch  keep running and re-apply when a device appears
#                     (plugging in or waking a mouse resets it to defaults)
#                     or when the settings change

get() { gsettings get "org.gnome.desktop.peripherals.$1" "$2" 2>/dev/null | tr -d "'"; }

# set_prop <id> <property> <value...> — only if the device has that property.
set_prop() {
    local id=$1 prop=$2; shift 2
    xinput list-props "$id" 2>/dev/null | grep -q "$prop (" && xinput set-prop "$id" "$prop" "$@" 2>/dev/null
}

# Accel profile: libinput lists (adaptive, flat[, custom]); fill in as many
# values as the device has.
set_profile() {
    local id=$1 profile=$2 n
    n=$(xinput list-props "$id" 2>/dev/null | awk -F: '/libinput Accel Profiles Available \(/{print NF ? split($2, a, ",") : 0}')
    [ -n "$n" ] && [ "$n" -gt 0 ] || return
    local values=(); for ((i = 0; i < n; i++)); do values+=(0); done
    if [ "$profile" = flat ]; then values[1]=1; else values[0]=1; fi   # default = adaptive
    set_prop "$id" "libinput Accel Profile Enabled" "${values[@]}"
}

bool() { [ "$1" = true ] && echo 1 || echo 0; }

# Keyboard: layouts from org.gnome.desktop.input-sources "sources" (xkb
# entries like 'br' or 'us+intl') and its "xkb-options" (e.g.
# caps:ctrl_modifier = Caps Lock works as Ctrl). With more than one layout,
# Alt+Shift switches between them.
apply_keyboard() {
    local layouts variants options
    read -r layouts variants < <(python3 - <<'PY'
import ast, subprocess
def get(key):
    out = subprocess.run(["gsettings", "get", "org.gnome.desktop.input-sources", key],
                         capture_output=True, text=True).stdout.strip()
    out = out.removeprefix("@a(ss) ").removeprefix("@as ")
    try:
        return ast.literal_eval(out)
    except Exception:
        return []
layouts, variants = [], []
for kind, name in get("sources"):
    if kind == "xkb":
        layout, _, variant = name.partition("+")
        layouts.append(layout); variants.append(variant)
print(",".join(layouts) or "br", ",".join(variants) or ",")
PY
)
    options=$(gsettings get org.gnome.desktop.input-sources xkb-options 2>/dev/null |
              sed -E "s/^@as //; s/[][' ]//g")
    [[ $layouts == *,* ]] && options="${options:+$options,}grp:alt_shift_toggle"
    [ "$variants" = "," ] && variants=""
    # -option "" first: clear options left over from before, then set ours.
    setxkbmap -layout "$layouts" ${variants:+-variant "$variants"} -option "" ${options:+-option "$options"}
}

apply() {
    apply_keyboard
    local m_speed m_profile m_natural t_speed t_profile t_tap t_natural t_dwt t_click p_speed p_profile
    m_speed=$(get mouse speed);         m_profile=$(get mouse accel-profile)
    m_natural=$(get mouse natural-scroll)
    t_speed=$(get touchpad speed);      t_profile=$(get touchpad accel-profile)
    t_tap=$(get touchpad tap-to-click); t_natural=$(get touchpad natural-scroll)
    t_dwt=$(get touchpad disable-while-typing); t_click=$(get touchpad click-method)
    p_speed=$(get pointingstick speed); p_profile=$(get pointingstick accel-profile)

    # Slave pointer devices only (skip the virtual core/XTEST ones).
    xinput list --short | grep -E 'slave +pointer' | grep -v XTEST |
    sed -E 's/.*↳ (.*[^ \t])[ \t]+id=([0-9]+).*/\2\t\1/' |
    while IFS=$'\t' read -r id name; do
        case "${name,,}" in
            *touchpad*|*trackpad*)
                set_prop "$id" "libinput Accel Speed" "${t_speed:--0.3}"
                set_profile "$id" "${t_profile:-default}"
                set_prop "$id" "libinput Tapping Enabled" "$(bool "${t_tap:-true}")"
                set_prop "$id" "libinput Natural Scrolling Enabled" "$(bool "${t_natural:-true}")"
                set_prop "$id" "libinput Disable While Typing Enabled" "$(bool "${t_dwt:-true}")"
                # click-method "fingers" = two-finger click (clickfinger); otherwise button areas.
                [ "$t_click" = fingers ] && set_prop "$id" "libinput Click Method Enabled" 0 1
                [ "$t_click" = areas ] && set_prop "$id" "libinput Click Method Enabled" 1 0
                ;;
            *trackpoint*|*"pointing stick"*)
                set_prop "$id" "libinput Accel Speed" "${p_speed:-0}"
                set_profile "$id" "${p_profile:-default}"
                ;;
            *)
                set_prop "$id" "libinput Accel Speed" "${m_speed:-0}"
                set_profile "$id" "${m_profile:-default}"
                set_prop "$id" "libinput Natural Scrolling Enabled" "$(bool "${m_natural:-false}")"
                ;;
        esac
    done
}

apply

if [ "${1:-}" = --watch ]; then
    # Settings changes (e.g. the Mouse & Touchpad sliders) — applied live.
    for schema in input-sources peripherals.mouse peripherals.touchpad peripherals.pointingstick; do
        gsettings monitor "org.gnome.desktop.$schema" 2>/dev/null |
        while read -r _; do
            while read -r -t 0.3 _; do :; done   # dragging a slider = many events
            apply
        done &
    done
    # XI2 hierarchy events fire when devices are added or enabled (a newly
    # plugged keyboard gets the system defaults, so the keyboard is redone too).
    xinput --test-xi2 --root 2>/dev/null | grep --line-buffered -E 'HierarchyChanged' |
    while read -r _; do
        while read -r -t 1 _; do :; done   # one plug = a burst of events
        apply
    done
fi
