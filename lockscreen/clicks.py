#!/usr/bin/env python3
"""clicks.py [FILE] — note every mouse button press, for auth_card.

With FILE, its modification time is set at each click (lock.sh runs it this
way for as long as the screen is locked); without, prints "click".

xsecurelock starts the auth module on any input, mouse movement included, and
only forwards keys. To open the card on a click (but not on movement or
scrolling), this listens to XInput2 *raw* button events on the root window:
X delivers those to every client that asks, even while xsecurelock holds the
pointer grab. Talks to libX11 / libXi directly (ctypes; no extra packages).
Exits non-zero if XInput2 is unavailable; auth_card then wakes on keys only.
"""
import ctypes
import ctypes.util
import os
import sys

XI_RawButtonPress = 15
XIAllDevices = 0
GenericEvent = 35
SCROLL_BUTTONS = {4, 5, 6, 7}   # wheel up/down/left/right: not a click

x11 = ctypes.CDLL(ctypes.util.find_library("X11") or "libX11.so.6")
xi = ctypes.CDLL(ctypes.util.find_library("Xi") or "libXi.so.6")


class XIEventMask(ctypes.Structure):
    _fields_ = [("deviceid", ctypes.c_int), ("mask_len", ctypes.c_int),
                ("mask", ctypes.POINTER(ctypes.c_ubyte))]


class XGenericEventCookie(ctypes.Structure):
    _fields_ = [("type", ctypes.c_int), ("serial", ctypes.c_ulong),
                ("send_event", ctypes.c_int), ("display", ctypes.c_void_p),
                ("extension", ctypes.c_int), ("evtype", ctypes.c_int),
                ("cookie", ctypes.c_uint), ("data", ctypes.c_void_p)]


class XIRawEvent(ctypes.Structure):   # leading fields only
    _fields_ = [("type", ctypes.c_int), ("serial", ctypes.c_ulong),
                ("send_event", ctypes.c_int), ("display", ctypes.c_void_p),
                ("extension", ctypes.c_int), ("evtype", ctypes.c_int),
                ("time", ctypes.c_ulong), ("deviceid", ctypes.c_int),
                ("sourceid", ctypes.c_int), ("detail", ctypes.c_int)]


class XEvent(ctypes.Union):
    _fields_ = [("type", ctypes.c_int), ("cookie", XGenericEventCookie),
                ("pad", ctypes.c_long * 24)]


x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XDefaultRootWindow.restype = ctypes.c_ulong
x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
x11.XQueryExtension.argtypes = [ctypes.c_void_p, ctypes.c_char_p] + [ctypes.POINTER(ctypes.c_int)] * 3
x11.XNextEvent.argtypes = [ctypes.c_void_p, ctypes.POINTER(XEvent)]
x11.XGetEventData.argtypes = [ctypes.c_void_p, ctypes.POINTER(XGenericEventCookie)]
x11.XFreeEventData.argtypes = [ctypes.c_void_p, ctypes.POINTER(XGenericEventCookie)]
x11.XFlush.argtypes = [ctypes.c_void_p]
xi.XIQueryVersion.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int)]
xi.XISelectEvents.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(XIEventMask), ctypes.c_int]


def report(path):
    if path:
        with open(path, "a"):
            pass
        os.utime(path)
    else:
        print("click", flush=True)


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else None
    dpy = x11.XOpenDisplay(None)
    if not dpy:
        return 2
    opcode, ev, err = ctypes.c_int(), ctypes.c_int(), ctypes.c_int()
    if not x11.XQueryExtension(dpy, b"XInputExtension", ctypes.byref(opcode), ctypes.byref(ev), ctypes.byref(err)):
        return 2
    # XI 2.1+: raw events reach every client that selects them, despite grabs.
    major, minor = ctypes.c_int(2), ctypes.c_int(2)
    if xi.XIQueryVersion(dpy, ctypes.byref(major), ctypes.byref(minor)) != 0 or (major.value, minor.value) < (2, 1):
        return 2
    bits = (ctypes.c_ubyte * 4)()
    bits[XI_RawButtonPress >> 3] |= 1 << (XI_RawButtonPress & 7)
    mask = XIEventMask(XIAllDevices, len(bits), bits)
    xi.XISelectEvents(dpy, x11.XDefaultRootWindow(dpy), ctypes.byref(mask), 1)
    x11.XFlush(dpy)

    event = XEvent()
    while True:
        x11.XNextEvent(dpy, ctypes.byref(event))
        cookie = event.cookie
        if cookie.type != GenericEvent or cookie.extension != opcode.value:
            continue
        if not x11.XGetEventData(dpy, ctypes.byref(cookie)):
            continue
        try:
            if cookie.evtype == XI_RawButtonPress:
                raw = ctypes.cast(cookie.data, ctypes.POINTER(XIRawEvent)).contents
                # Each click arrives twice: from the mouse itself and via the
                # master pointer (deviceid != sourceid). Count the first only.
                if raw.deviceid == raw.sourceid and raw.detail not in SCROLL_BUTTONS:
                    report(path)
        finally:
            x11.XFreeEventData(dpy, ctypes.byref(cookie))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (BrokenPipeError, KeyboardInterrupt):
        sys.exit(0)
