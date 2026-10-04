#!/usr/bin/env python3
"""Keybinding cheat sheet (Super + /), like which-key in Neovim.

Desktop keys come from ~/.config/sxhkd/sxhkdrc, where "## Section" starts a
group and a "# Description" line directly above a binding describes it.
tmux keys come from `tmux list-keys -N`: tmux's own defaults plus every
binding in ~/.tmux.conf that has a note (bind -N "...").
Shows everything in rofi; type to filter (e.g. "tmux"). Choosing a
single-action desktop binding also runs it.
"""
import html
import os
import re
import subprocess
from pathlib import Path

SXHKDRC = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "sxhkd" / "sxhkdrc"

KEY_NAMES = {
    "super": "Super", "shift": "Shift", "ctrl": "Ctrl", "control": "Ctrl", "alt": "Alt",
    "return": "Enter", "space": "Space", "escape": "Esc", "tab": "Tab", "print": "Print",
    "slash": "/", "backslash": "\\", "comma": ",", "period": ".", "bracketleft": "[", "bracketright": "]",
    "left": "←", "right": "→", "up": "↑", "down": "↓",
    "xf86audioraisevolume": "Vol+", "xf86audiolowervolume": "Vol−",
    "xf86audiomute": "Mute", "xf86audiomicmute": "MicMute",
    "xf86monbrightnessup": "Bright+", "xf86monbrightnessdown": "Bright−",
    "xf86audioplay": "Play", "xf86audiopause": "Pause", "xf86audionext": "Next",
    "xf86audioprev": "Prev", "xf86audiostop": "Stop",
}

def key_name(k: str) -> str:
    k = k.strip()
    return KEY_NAMES.get(k.lower(), k.upper() if len(k) == 1 else k)


def pretty_chord(chord: str) -> str:
    """'super + shift + {h,j,k,l}' → 'Super + Shift + H/J/K/L'."""
    def group(m: re.Match) -> str:
        prefix, items, suffix = m.group(1), m.group(2).split(","), m.group(3)
        out = []
        for it in items:
            r = re.fullmatch(r"(\w)-(\w)", it.strip())
            # Ranges: {1-9} → 1–9
            out.append(f"{r[1]}–{r[2]}" if r else key_name(prefix + it.strip() + suffix))
        # "/" separates alternatives (H/J/K/L) unless a key is "/" itself.
        return " or ".join(out) if "/" in out else "/".join(out)
    # A brace group may sit inside a key name (XF86Audio{Raise,Lower}Volume).
    parts = []
    for part in chord.split("+"):
        if "{" in part:
            parts.append(re.sub(r"(\w*)\{([^}]*)\}(\w*)", group, part.strip()))
        else:
            parts.append(key_name(part))
    return " + ".join(parts)


def parse(text: str):
    """Yield (section, chord, description, command) for each binding."""
    section, desc = "", ""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("## "):
            section, desc = line[3:].strip(), ""
        elif line.startswith("#"):
            desc = line.lstrip("#").strip()
        elif not line.strip():
            desc = ""  # a description belongs to the binding right below it
        elif not line[0].isspace():
            command = lines[i + 1].strip() if i + 1 < len(lines) else ""
            yield section, line.strip(), desc or command, command
            desc = ""
            i += 1
        i += 1


TMUX_MODS = {"C": "Ctrl", "M": "Alt", "S": "Shift"}
TMUX_KEYS = {"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "PPage": "PgUp",
             "NPage": "PgDn", "BSpace": "Backspace", "DC": "Delete", "IC": "Insert"}


def tmux_key(key: str) -> str:
    """'S-C-a' → 'Ctrl+Shift+A', 'M-Up' → 'Alt+↑'."""
    *mods, base = key.split("-") if key != "-" else ["-"]
    if base == "" and mods:  # a key that is itself "-", e.g. "M--"
        mods, base = mods[:-1], "-"
    names = [TMUX_MODS.get(m, m) for m in mods]
    # tmux tells "r" from "R": show the capital as Shift+R, the lowercase as R.
    if len(base) == 1 and base.isupper():
        names.append("Shift")
    names = sorted(set(names), key=["Ctrl", "Alt", "Shift"].index)
    base = TMUX_KEYS.get(base, base.upper() if len(base) == 1 and base.isalpha() else base)
    return "+".join(names + [base])


def tmux_binds():
    """Return (prefix, [("tmux", keys, note, None), ...]) from `tmux list-keys -N`."""
    # Use the running server; without one, start a throwaway server with the
    # user's config just to read its keys.
    cmd = ["tmux", "list-keys", "-N"]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        if out.returncode != 0:
            out = subprocess.run(
                ["tmux", "-L", "cheatsheet", "-f", str(Path.home() / ".tmux.conf"),
                 "new-session", "-d", ";", "list-keys", "-N", ";", "kill-server"],
                capture_output=True, text=True, timeout=10)
        prefix = subprocess.run(["tmux", "show", "-gv", "prefix"],
                                capture_output=True, text=True, timeout=3).stdout.strip() or "C-b"
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return "C-b", []
    binds = []
    for line in out.stdout.splitlines():
        m = re.match(r"^(\S*)\s+(\S+)\s+(.+)$", line)
        if not m:
            continue
        table, key, note = m.groups()
        keys = tmux_key(key)
        if table == prefix:
            keys = f"Prefix → {keys}"
        binds.append(("tmux", keys, note.strip(), None))
    return prefix, binds


def main() -> None:
    binds = [(sec, pretty_chord(chord), desc, cmd)
             for sec, chord, desc, cmd in parse(SXHKDRC.read_text())]
    tmux_prefix, tmux = tmux_binds()
    binds += tmux
    width = max(len(k) for _, k, _, _ in binds)
    rows = []
    for section, keys, desc, _ in binds:
        keys = keys.ljust(width)
        rows.append(
            # Colours inherit the row's text colour so the selected row stays
            # readable; the section is drawn faded instead of in a fixed grey.
            f"<b>{html.escape(keys)}</b>   "
            f"{html.escape(desc)}  <span fgalpha='50%' size='small'>{html.escape(section)}</span>"
        )

    theme = ("window { width: 1080px; } listview { lines: 16; } "
             "element-icon { enabled: false; } inputbar { children: [prompt, entry]; }")
    result = subprocess.run(
        ["rofi", "-dmenu", "-i", "-markup-rows", "-format", "i", "-p", "Keys",
         "-mesg", f"Type to filter (try \"tmux\") · tmux prefix is {tmux_key(tmux_prefix)} · Enter runs desktop bindings · Esc closes",
         "-theme-str", theme],
        input="\n".join(rows), capture_output=True, text=True,
    )
    if result.returncode != 0 or not result.stdout.strip():
        return
    command = binds[int(result.stdout.strip())][3]
    # Brace groups ({h,j,k,l}) are several actions: nothing single to run.
    if command and "{" not in command:
        subprocess.Popen(["bash", "-c", command], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    main()
