#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="net.inkyquill.theobromine"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if kpackagetool6 --list --type=Plasma/Applet 2>/dev/null | grep -q "^${PLASMOID_ID}$"; then
    echo "Upgrading Theobromine..."
    kpackagetool6 --upgrade "$SCRIPT_DIR" --type Plasma/Applet
else
    echo "Installing Theobromine..."
    kpackagetool6 --install "$SCRIPT_DIR" --type Plasma/Applet
fi

echo ""
echo "Done.  Restart plasmashell to load the widget:"
echo "  kquitapp6 plasmashell && kstart plasmashell"
echo ""
echo "Then right-click the panel → Add Widgets → search for 'Theobromine'."
echo ""
echo "Dependencies for the DBus inhibition path (recommended):"
echo "  Arch:   sudo pacman -S python-dbus python-gobject"
echo "  Fedora: sudo dnf install python3-dbus python3-gobject"
echo "  Ubuntu: sudo apt install python3-dbus python3-gi"
