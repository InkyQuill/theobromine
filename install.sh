#!/usr/bin/env bash
set -euo pipefail

PLASMOID_ID="net.inkyquill.theobromine"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"

echo "Installing Theobromine to: $INSTALL_DIR"

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/." "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/contents/scripts/inhibit.py"

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
