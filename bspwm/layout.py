#!/usr/bin/env python3
"""layout.py — put the screens where they belong (run by monitors.sh).

X starts every connected screen at 0,0, so after a boot with several monitors
they all sit on top of each other. This keeps one layout per set of monitors
(told apart by their EDID, so another screen on the same port is a different
set):

  * the set of connected monitors changed (boot, plug, unplug)
        → restore its layout: the one you last arranged (arandr, Super+Shift+I),
          else the one GNOME saved in ~/.config/monitors.xml, else side by side
          (external screens left to right, the notebook panel last);
  * same monitors, new arrangement (you just applied one in arandr)
        → remember it.

Layouts are stored in ~/.local/state/bspwm/layouts.json.
"""
import json
import os
import re
import subprocess
import xml.etree.ElementTree as ET

STORE = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
                     "bspwm", "layouts.json")
LAST = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "bspwm-layout-key")
GNOME = os.path.expanduser("~/.config/monitors.xml")


def edid_ident(hexdata):
    """(vendor, product, serial) the way GNOME's monitors.xml names a screen."""
    try:
        b = bytes.fromhex(hexdata)
    except ValueError:
        return "", "", ""
    if len(b) < 128:
        return "", "", ""
    v = (b[8] << 8) | b[9]
    vendor = "".join(chr(((v >> s) & 0x1f) + 64) for s in (10, 5, 0))
    product = "0x%04x" % (b[10] | b[11] << 8)
    serial = "0x%08x" % int.from_bytes(b[12:16], "little")
    for off in (54, 72, 90, 108):
        d = b[off:off + 18]
        if d[0] == 0 and d[1] == 0:
            text = d[5:18].split(b"\n")[0].decode("ascii", "replace").strip()
            if d[3] == 0xFC and text:
                product = text
            elif d[3] == 0xFF and text:
                serial = text
    return vendor, product, serial


def outputs():
    """Connected and enabled outputs from xrandr --prop."""
    res, cur, in_edid = {}, None, False
    for line in subprocess.run(["xrandr", "--prop"], capture_output=True, text=True).stdout.splitlines():
        m = re.match(r"(\S+) (connected|disconnected)( primary)? ?(\d+x\d+\+\d+\+\d+)? ?(left|right|inverted)? ?\(", line)
        if m:
            cur = {"name": m.group(1), "connected": m.group(2) == "connected",
                   "primary": bool(m.group(3)), "enabled": bool(m.group(4)),
                   "rotate": m.group(5) or "normal", "edid": "", "modes": {}}
            if m.group(4):
                w, h, x, y = map(int, re.split(r"[x+]", m.group(4)))
                cur.update(x=x, y=y, w=w, h=h)
            res[cur["name"]] = cur
            in_edid = False
            continue
        if cur is None:
            continue
        if line.startswith("\tEDID:"):
            in_edid = True
        elif in_edid and line.startswith("\t\t"):
            cur["edid"] += line.strip()
        else:
            in_edid = False
            m = re.match(r"\s+(\d+x\d+)\S*\s+(.*)", line)
            if m and not line.startswith("\t"):
                rates = re.findall(r"([\d.]+)(\*?)", m.group(2))
                cur["modes"].setdefault(m.group(1), []).extend(float(r) for r, _ in rates)
                for r, star in rates:
                    if star:
                        cur["mode"], cur["rate"] = m.group(1), float(r)
    for o in res.values():
        o["ident"] = (o["name"],) + edid_ident(o["edid"])
    return res


def key_of(connected):
    return "|".join(sorted(":".join(o["ident"]) for o in connected))


def gnome_layout(connected):
    """The matching configuration from GNOME's monitors.xml, if any."""
    want = {o["ident"]: o["name"] for o in connected}
    try:
        root = ET.parse(GNOME).getroot()
    except (OSError, ET.ParseError):
        return None
    for conf in root.iter("configuration"):
        layout, seen = {}, set()
        for lm in conf.findall("logicalmonitor"):
            for mon in lm.findall("monitor"):
                spec = mon.find("monitorspec")
                ident = tuple(spec.findtext(t, "") for t in ("connector", "vendor", "product", "serial"))
                seen.add(ident)
                if ident in want:
                    layout[want[ident]] = {
                        "x": int(lm.findtext("x", "0")), "y": int(lm.findtext("y", "0")),
                        "mode": "%sx%s" % (mon.findtext("mode/width"), mon.findtext("mode/height")),
                        "rate": float(mon.findtext("mode/rate", "0")),
                        "rotate": {"upside_down": "inverted"}.get(r := lm.findtext("transform/rotation", "normal"), r),
                        "primary": lm.findtext("primary", "no") == "yes"}
        for spec in conf.findall("disabled/monitorspec"):
            seen.add(tuple(spec.findtext(t, "") for t in ("connector", "vendor", "product", "serial")))
        if seen == set(want):
            return layout
    return None


def default_layout(connected):
    """Side by side: external screens in port order, the notebook panel last."""
    panel = lambda o: o["name"].startswith(("eDP", "LVDS", "DSI"))
    x, layout = 0, {}
    for o in sorted(connected, key=lambda o: (panel(o), o["name"])):
        mode = next(iter(o["modes"]), None)   # first listed = preferred
        if not mode:
            continue
        layout[o["name"]] = {"x": x, "y": 0, "mode": mode, "rate": 0, "rotate": "normal",
                             "primary": panel(o)}
        x += int(mode.split("x")[0])
    return layout


def apply(layout, outs):
    cmd = ["xrandr"]
    for o in outs.values():
        want = layout.get(o["name"]) if o["connected"] else None
        if not want:
            if o["enabled"]:
                cmd += ["--output", o["name"], "--off"]
            elif o["connected"]:   # not in the layout (e.g. disabled in GNOME): leave it
                pass
            continue
        cmd += ["--output", o["name"], "--pos", "%dx%d" % (want["x"], want["y"]),
                "--rotate", want.get("rotate", "normal")]
        rates = o["modes"].get(want["mode"])
        if rates:
            cmd += ["--mode", want["mode"]]
            if want.get("rate"):
                cmd += ["--rate", "%.2f" % min(rates, key=lambda r: abs(r - want["rate"]))]
        else:
            cmd += ["--auto"]
        if want.get("primary"):
            cmd += ["--primary"]
    subprocess.run(cmd)


def current_layout(connected):
    """The arrangement on screen now, or None if it is not worth saving
    (a screen is off, or two of them overlap/mirror)."""
    on = [o for o in connected if o["enabled"]]
    if len(on) != len(connected):
        return None
    for i, a in enumerate(on):
        for b in on[i + 1:]:
            if a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"] and \
               a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]:
                return None
    return {o["name"]: {"x": o["x"], "y": o["y"], "mode": o.get("mode", ""), "rate": o.get("rate", 0),
                        "rotate": o["rotate"], "primary": o["primary"]} for o in on}


def main():
    outs = outputs()
    connected = [o for o in outs.values() if o["connected"]]
    if not connected:
        return
    key = key_of(connected)
    try:
        with open(STORE) as f:
            store = json.load(f)
    except (OSError, ValueError):
        store = {}
    try:
        with open(LAST) as f:
            last = f.read()
    except OSError:
        last = ""

    if key != last:
        layout = store.get(key) or gnome_layout(connected) or default_layout(connected)
        apply(layout, outs)
    else:
        layout = current_layout(connected)
        if layout and store.get(key) != layout:
            store[key] = layout
            os.makedirs(os.path.dirname(STORE), exist_ok=True)
            with open(STORE + ".tmp", "w") as f:
                json.dump(store, f, indent=2)
            os.replace(STORE + ".tmp", STORE)
    with open(LAST, "w") as f:
        f.write(key)


if __name__ == "__main__":
    main()
