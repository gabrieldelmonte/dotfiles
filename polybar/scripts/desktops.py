#!/usr/bin/env python3
"""desktops.py — the desktop list on the left of the bar (one per monitor).

Replaces polybar's internal/bspwm module, which can only put the "maximized"
icon after the whole list, and only for the focused desktop. Here the icon
sits right after every desktop in monocle layout (Super+M / Super+Z).

Like before: only desktops with windows (and the focused one) are listed;
click one to go there, scroll to move through them. Colours and the icon come
from gen-polybar.py through the environment.
"""
import json
import os
import subprocess
import sys

MON = os.environ.get("MONITOR") or subprocess.run(
    ["bspc", "query", "-M", "-m", "focused", "--names"], capture_output=True, text=True).stdout.strip()
C_FOCUSED = os.environ.get("C_FOCUSED", "#1e66f5")
C_OCCUPIED = os.environ.get("C_OCCUPIED", "#6c6f85")
C_URGENT = os.environ.get("C_URGENT", "#d20f39")
C_MAX = os.environ.get("C_MAX", "#7287fd")
MAX_ICON = os.environ.get("MAX_ICON", "\U000F0293")


def layouts():
    tree = subprocess.run(["bspc", "query", "-T", "-m", MON], capture_output=True, text=True).stdout
    try:
        return {d["name"]: d["layout"] for d in json.loads(tree)["desktops"]}
    except (ValueError, KeyError):
        return {}


def render(report):
    # Report: "WMname:o1:O2:f3:...:LT:TT:G...:mname2:..." — M/m starts a monitor,
    # then o/O occupied, f/F free, u/U urgent (upper case = focused).
    states, current = [], None
    for item in report.lstrip("W").split(":"):
        if not item:
            continue
        kind, name = item[0], item[1:]
        if kind in "Mm":
            current = name
        elif current == MON and kind in "oOfFuU":
            states.append((kind, name))
    lay = layouts()
    out = []
    for kind, name in states:
        if kind == "f":
            continue   # empty and not focused: hidden
        color = C_URGENT if kind in "uU" else C_FOCUSED if kind in "OF" else C_OCCUPIED
        text = f" %{{F{color}}}{name}%{{F-}}"
        if lay.get(name) == "monocle" and kind != "F":
            text += f" %{{F{C_MAX}}}%{{T2}}{MAX_ICON}%{{T-}}%{{F-}}"
        out.append(f"%{{A1:bspc desktop -f '{name}':}}{text} %{{A}}")
    return ("%{A4:bspc desktop -f prev.local.occupied:}%{A5:bspc desktop -f next.local.occupied:}"
            + "".join(out) + "%{A}%{A}")


last = None
proc = subprocess.Popen(["bspc", "subscribe", "report"], stdout=subprocess.PIPE, text=True)
for line in proc.stdout:
    text = render(line.strip())
    if text != last:
        print(text, flush=True)
        last = text
sys.exit(proc.wait())
