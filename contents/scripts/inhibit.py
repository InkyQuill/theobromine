#!/usr/bin/env python3
"""
Theobromine inhibitor daemon.

Holds DBus inhibitions to prevent sleep and screen lock for as long as
this process is alive.  Kill the process to release all inhibitions.

Primary path   : org.freedesktop.ScreenSaver.Inhibit
                 org.kde.Solid.PowerManagement.PolicyAgent.AddInhibition
Fallback path  : xset s off / systemd-inhibit  (X11 + systemd only)
"""

import atexit
import os
import signal
import sys
import time

PID_FILE = "/tmp/theobromine.pid"


# ── PID / cleanup helpers ────────────────────────────────────────────────────

def _write_pid() -> None:
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))


def _remove_pid() -> None:
    try:
        os.unlink(PID_FILE)
    except OSError:
        pass


def _handle_signal(signum, frame) -> None:
    sys.exit(0)


# ── Primary path: python-dbus ────────────────────────────────────────────────

def _inhibit_dbus() -> None:
    """Hold DBus inhibitions; block until killed."""
    import dbus                          # python-dbus / python3-dbus
    import dbus.mainloop.glib
    from gi.repository import GLib      # python-gobject / python3-gi

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()
    held: list[tuple] = []

    # 1. Screensaver / screen lock
    try:
        proxy = bus.get_object(
            "org.freedesktop.ScreenSaver",
            "/org/freedesktop/ScreenSaver",
        )
        iface = dbus.Interface(proxy, "org.freedesktop.ScreenSaver")
        cookie = iface.Inhibit("Theobromine", "Caffeine mode active")
        held.append(("screensaver", iface, cookie))
    except Exception as exc:
        print(f"[theobromine] ScreenSaver inhibit failed: {exc}", file=sys.stderr)

    # 2. KDE PowerManagement — InterruptSession (4) prevents idle suspend/sleep
    try:
        proxy = bus.get_object(
            "org.kde.Solid.PowerManagement",
            "/org/kde/Solid/PowerManagement/PolicyAgent",
        )
        iface = dbus.Interface(proxy, "org.kde.Solid.PowerManagement.PolicyAgent")
        cookie = iface.AddInhibition(
            dbus.UInt32(4),   # InterruptSession
            "Theobromine",
            "Caffeine mode active",
        )
        held.append(("kde_pm", iface, cookie))
    except Exception as exc:
        print(f"[theobromine] KDE PowerManagement inhibit failed: {exc}", file=sys.stderr)

    if not held:
        raise RuntimeError("Could not establish any DBus inhibitions")

    loop = GLib.MainLoop()

    def _release() -> None:
        for name, iface, cookie in held:
            try:
                if name == "screensaver":
                    iface.UnInhibit(cookie)
                elif name == "kde_pm":
                    iface.ReleaseInhibition(cookie)
            except Exception:
                pass
        loop.quit()

    atexit.register(_release)
    loop.run()


# ── Fallback path: xset + systemd-inhibit ────────────────────────────────────

def _inhibit_fallback() -> None:
    """Fallback for systems without python-dbus."""
    import subprocess

    is_x11 = bool(os.environ.get("DISPLAY"))

    if is_x11:
        subprocess.run(["xset", "s", "off", "-dpms"], capture_output=True)
        atexit.register(
            lambda: subprocess.run(["xset", "s", "on", "+dpms"], capture_output=True)
        )

    # systemd-inhibit works on both X11 and Wayland
    proc = subprocess.Popen(
        [
            "systemd-inhibit",
            "--what=sleep:idle",
            "--who=Theobromine",
            "--why=Caffeine mode active",
            "--mode=block",
            "sleep",
            "infinity",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    atexit.register(proc.terminate)

    while True:
        time.sleep(50)
        if is_x11:
            subprocess.run(["xset", "s", "reset"], capture_output=True)


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    _write_pid()
    atexit.register(_remove_pid)

    try:
        _inhibit_dbus()
    except Exception as exc:
        print(
            f"[theobromine] DBus path failed ({exc}); trying xset/systemd fallback…",
            file=sys.stderr,
        )
        try:
            _inhibit_fallback()
        except Exception as exc2:
            print(f"[theobromine] Fallback also failed: {exc2}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
