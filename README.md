# Theobromine

A KDE Plasma 6 plasmoid that prevents your system from sleeping or locking the screen — with optional countdown timers. Think Caffeine/Espresso on GNOME or Amphetamine on macOS, but for KDE.

Named after the stimulant found in chocolate 🍫

---

## Features

- **Fast timer starts** — click the panel icon, then choose a common duration or no limit
- **Arbitrary timers** — set any duration up to 99 h 59 min with editable hour/minute controls
- **Auto-deactivate** — when the timer expires caffeine mode turns off automatically
- **Compact countdown display** — remaining time shown next to the icon in the panel while a timer runs
- **Light & dark theme aware** — simple symbolic cup icon adapts to the active Plasma theme
- **Wayland + X11** — uses DBus inhibition APIs natively; falls back to `xset` + `systemd-inhibit` on X11-only setups

---

## How it works

The plasmoid launches a small Python daemon (`inhibit.py`) that holds two DBus inhibition locks for as long as it runs:

| Lock | Prevents |
|------|----------|
| `org.freedesktop.ScreenSaver.Inhibit` | Screen lock and screensaver |
| `org.kde.Solid.PowerManagement.PolicyAgent.AddInhibition` (`InterruptSession`) | Idle suspend / sleep |

Killing the daemon releases both locks automatically — no manual cleanup needed.

A fallback path using `xset s off` and `systemd-inhibit` kicks in if `python-dbus` / `python-gobject` are unavailable.

---

## Requirements

- KDE Plasma 6
- Python 3
- **Recommended** (DBus path): `python-dbus` and `python-gobject`
  ```
  # Arch
  sudo pacman -S python-dbus python-gobject

  # Fedora
  sudo dnf install python3-dbus python3-gobject

  # Ubuntu/Debian
  sudo apt install python3-dbus python3-gi
  ```
- **Fallback** (X11 + systemd only): `xset`, `systemd-inhibit` — usually pre-installed

---

## Installation

```bash
git clone https://github.com/InkyQuill/theobromine.git
cd theobromine
bash install.sh
```

Then restart Plasma:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

Right-click the panel → **Add Widgets** → search for **Theobromine**.

---

## Project layout

```
theobromine/
├── metadata.json             # Plasma 6 package manifest
├── install.sh                # Installs to ~/.local/share/plasma/plasmoids/
└── contents/
    ├── ui/
    │   └── main.qml          # Plasmoid UI and logic
    ├── scripts/
    │   └── inhibit.py        # DBus inhibitor daemon
    └── icons/
        ├── theobromine-on-light.svg   # Active cup (light theme)
        ├── theobromine-on-dark.svg    # Active cup (dark theme)
        ├── theobromine-off-light.svg  # Inactive cup (light theme)
        ├── theobromine-off-dark.svg   # Inactive cup (dark theme)
        ├── timer-short.svg
        ├── timer-medium.svg
        ├── timer-long.svg
        └── timer-infinite.svg
```

---

## License

GPL-2.0-or-later
