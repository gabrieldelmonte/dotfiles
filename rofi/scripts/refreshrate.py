#!/usr/bin/env python3
"""Refresh rate menu (Super+Shift+R): pick a screen, then one of the rates it
offers at its current resolution (arandr cannot change the rate).

The new rate is remembered with the rest of the screen layout
(bspwm/layout.py), so it comes back at the next login or plug.
"""
import os
import subprocess
import sys

sys.path.insert(0, os.path.expanduser("~/.config/bspwm"))
sys.dont_write_bytecode = True
import layout  # noqa: E402

THEME = "window {width: %dpx;} listview {lines: %d;} inputbar {children: [prompt];}"


def rofi(prompt, rows, width):
    res = subprocess.run(["rofi", "-dmenu", "-i", "-p", prompt, "-format", "i",
                          "-theme-str", THEME % (width, len(rows))],
                         input="\n".join(rows), capture_output=True, text=True)
    out = res.stdout.strip()
    return int(out) if out.isdigit() else None


on = sorted((o for o in layout.outputs().values() if o["enabled"] and o.get("mode")),
            key=lambda o: o["x"])
if not on:
    sys.exit(0)

# 1. Which screen (skipped with a single one).
where = {1: ["Screen"], 2: ["Left", "Right"], 3: ["Left", "Centre", "Right"]}.get(
    len(on), ["Screen %d" % (i + 1) for i in range(len(on))])
if len(on) == 1:
    out = on[0]
else:
    rows = []
    for o, pos in zip(on, where):
        product = o["ident"][2]
        if o["name"].startswith(("eDP", "LVDS", "DSI")):
            name = "Notebook"
        else:
            name = product if not product.startswith("0x") else o["name"]
        rows.append("󰍹  %-7s %s  ·  %s @ %.0f Hz" % (pos, name, o["mode"], o["rate"]))
    i = rofi("Refresh rate", rows, 560)
    if i is None:
        sys.exit(0)
    out = on[i]

# 2. Which rate (fastest first, duplicates merged).
rates = sorted({round(r, 2) for r in out["modes"][out["mode"]]}, reverse=True)
rows = ["%7.2f Hz%s" % (r, "  (current)" if abs(r - out["rate"]) < 0.01 else "") for r in rates]
i = rofi(out["name"], rows, 340)
if i is None:
    sys.exit(0)
subprocess.run(["xrandr", "--output", out["name"], "--mode", out["mode"], "--rate", "%.2f" % rates[i]])
