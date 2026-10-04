#!/usr/bin/env python3
"""xsecurelock auth module with a GNOME-style card instead of the grey box.

xsecurelock forwards the keys you type on stdin. This module collects the
password, hands it to xsecurelock's PAM helper (authproto_pam — the part that
actually checks it) and reports progress to the lock-screen video (ui.lua, via
mpv's IPC socket), which draws the card. It maps no window of its own, so the
video stays visible. Exit status 0 means "unlock".

Safety: any unexpected error hands over to xsecurelock's default dialog
(auth_x11), so a bug in here cannot keep you locked out.
"""
import glob
import json
import os
import select
import socket
import subprocess
import sys
import time

FALLBACK = "/usr/libexec/xsecurelock/auth_x11"
AUTHPROTO = os.environ.get("XSECURELOCK_AUTHPROTO") or "/usr/libexec/xsecurelock/authproto_pam"
try:
    TIMEOUT = max(5, int(os.environ.get("XSECURELOCK_AUTH_TIMEOUT") or 30))
except ValueError:
    TIMEOUT = 30
SOCKDIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "lockscreen")


def log(msg):
    print(f"auth_card: {msg}", file=sys.stderr, flush=True)


def ui(state, dots=0, message=""):
    """Tell every lock-screen video (one per monitor) what to draw."""
    cmd = {"command": ["script-message", "lockui", state, str(dots), message]}
    payload = (json.dumps(cmd) + "\n").encode()
    for path in glob.glob(os.path.join(SOCKDIR, "mpv-*.sock")):
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(0.3)
                s.connect(path)
                s.sendall(payload)
        except OSError:
            pass


# --- xsecurelock's helper protocol: "<type> <len>\n<message>\n" -------------
def write_packet(fd, ptype, message):
    data = message.encode()
    os.write(fd, f"{ptype} {len(data)}\n".encode() + data + b"\n")


def read_packet(stream):
    header = stream.readline()
    if not header:
        return None, ""
    ptype, length = header.decode().split(" ", 1)
    data = stream.read(int(length))
    stream.read(1)  # trailing newline
    return ptype, data.decode(errors="replace")


# --- Keyboard input -----------------------------------------------------------
def prompt(message=""):
    """Read one line from the forwarded keys. None = cancelled or timed out."""
    buf = bytearray()
    deadline = time.monotonic() + TIMEOUT
    ui("active", 0, message)
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return None
        ready, _, _ = select.select([0], [], [], remaining)
        if not ready:
            return None
        ch = os.read(0, 1)
        if not ch:
            return None  # EOF: xsecurelock went away
        deadline = time.monotonic() + TIMEOUT
        b = ch[0]
        if b in (8, 127):          # Backspace / Delete: drop one UTF-8 character
            while buf:
                if (buf.pop() & 0xC0) != 0x80:
                    break
        elif b in (1, 21):         # Ctrl-A / Ctrl-U: clear
            buf.clear()
        elif b == 27:              # Escape: cancel
            return None
        elif b in (10, 13):        # Enter
            return buf.decode(errors="replace")
        elif b >= 32:              # printable (including UTF-8 bytes)
            buf += ch
        else:
            continue
        typed = len(buf.decode(errors="ignore"))
        ui("active", typed, message if typed == 0 else "")


# --- One PAM conversation -------------------------------------------------------
def authenticate(message):
    """Returns "ok", "fail" or "cancel"."""
    proc = subprocess.Popen([AUTHPROTO], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    to_pam = proc.stdin.fileno()
    cancelled = False
    try:
        while True:
            ptype, text = read_packet(proc.stdout)
            if ptype is None:
                break
            if ptype in ("P", "U"):
                answer = prompt(message)
                message = ""
                if answer is None:
                    cancelled = True
                    write_packet(to_pam, "x", "")
                else:
                    write_packet(to_pam, ptype.lower(), answer)
                    answer = None
                    ui("checking")
            elif ptype in ("e", "i"):
                message = text   # PAM says something: show it on the next prompt
            else:
                log(f"unknown packet type {ptype!r}")
                break
    finally:
        try:
            proc.stdin.close()
        except OSError:
            pass
        status = proc.wait()
    if status == 0:
        return "ok"
    return "cancel" if cancelled else "fail"


def main():
    message = ""
    while True:
        result = authenticate(message)
        if result == "ok":
            ui("ok")
            return 0
        if result == "cancel":
            ui("idle")
            return 1
        message = "Wrong password"   # stay on the card; keys typed meanwhile are kept


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # never strand the user: use xsecurelock's own dialog
        log(f"error ({e!r}); falling back to auth_x11")
        ui("idle")
        os.execv(FALLBACK, [FALLBACK])
