#!/bin/sh
# Installs (or updates) NoShell on top of an existing Caelestia install. Arch Linux only.
#   curl -fsSL https://raw.githubusercontent.com/NoAppsStudioNo/NoShell/anime-calendar/install.sh | sh
# Uninstall: rm -rf ~/.config/quickshell/caelestia && caelestia shell -d   (falls back to the stock shell)
set -e

REPO=https://github.com/NoAppsStudioNo/NoShell
BRANCH=anime-calendar
SUPPORTED=2.5.0
DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"

if ! pacman -Q caelestia-shell >/dev/null 2>&1; then
    echo "caelestia-shell is not installed. Install Caelestia first: https://github.com/caelestia-dots/caelestia" >&2
    exit 1
fi
version=$(pacman -Q caelestia-shell | awk '{print $2}' | cut -d- -f1)
[ "$version" = "$SUPPORTED" ] || echo "Warning: built for caelestia-shell $SUPPORTED but you have $version, things may break."

missing=""
for pkg in git curl mpv libnotify; do
    pacman -Q "$pkg" >/dev/null 2>&1 || missing="$missing $pkg"
done
if [ -n "$missing" ]; then
    echo "Installing:$missing"
    sudo pacman -S --needed --noconfirm $missing
fi

if git -C "$DIR" remote get-url origin 2>/dev/null | grep -q NoShell; then
    echo "Updating $DIR"
    git -C "$DIR" pull --ff-only
else
    if [ -e "$DIR" ] || [ -L "$DIR" ]; then
        backup="$DIR.bak-$(date +%Y%m%d-%H%M%S)"
        echo "Moving existing $DIR to $backup"
        mv "$DIR" "$backup"
    fi
    mkdir -p "$(dirname "$DIR")"
    git clone -b "$BRANCH" "$REPO" "$DIR"
fi

echo "Restarting the shell"
pkill -f "qs -c caelestia" || true
sleep 1
caelestia shell -d
echo "Done. Press + on the widget in the bottom-right corner of your desktop to pick shows."
