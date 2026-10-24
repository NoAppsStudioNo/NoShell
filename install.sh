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

# Live wallpapers: waywallen + its Wallpaper Engine plugin, only if Wallpaper Engine is installed in Steam.
# Pinned to the versions NoShell is tested with; utils/scripts/wallpaper-engine.py drives them.
# ponytail: library paths with spaces in libraryfolders.vdf are missed
WAYWALLEN="$HOME/.local/opt/waywallen/waywallen.AppImage"
WE_PLUGIN="$HOME/.local/share/waywallen/plugins/org.waywallen.open-wallpaper-engine"
we=""
for lib in "$HOME/.steam/steam" "$HOME/.local/share/Steam" \
    $(sed -n 's/.*"path"[[:space:]]*"\(.*\)"/\1/p' "$HOME/.steam/steam/steamapps/libraryfolders.vdf" 2>/dev/null); do
    [ -d "$lib/steamapps/common/wallpaper_engine/assets" ] && we=1
done
if [ -z "$we" ]; then
    echo "Wallpaper Engine not found in Steam, skipping live wallpapers (install it and rerun this script to get them)."
elif [ "$(uname -m)" != x86_64 ]; then
    echo "Live wallpapers are only set up on x86_64, skipping."
else
    sudo pacman -S --needed --noconfirm fuse2 glib2 python unzip
    tmp=$(mktemp -d)
    if ! sha256sum -c --status <<EOF 2>/dev/null
78c6948e4a1412dde98ff7a033e8682a4461e67ac1ea8368d9412c9a5f12974e  $WAYWALLEN
EOF
    then
        echo "Downloading waywallen (80 MB)"
        curl -fL -o "$tmp/waywallen.AppImage" https://github.com/waywallen/waywallen/releases/download/v0.4.3/waywallen-0.4.3-x86_64.AppImage
        (cd "$tmp" && echo "78c6948e4a1412dde98ff7a033e8682a4461e67ac1ea8368d9412c9a5f12974e  waywallen.AppImage" | sha256sum -c --quiet)
        mkdir -p "$(dirname "$WAYWALLEN")"
        install -m 755 "$tmp/waywallen.AppImage" "$WAYWALLEN"
    fi
    if ! grep -q '^version = "0.3.0"' "$WE_PLUGIN/plugin.toml" 2>/dev/null; then
        echo "Downloading the Wallpaper Engine plugin (146 MB)"
        curl -fL -o "$tmp/plugin.zip" https://github.com/waywallen/open-wallpaper-engine/releases/download/v0.3.0/org.waywallen.open-wallpaper-engine-0.3.0-linux-x86_64.zip
        (cd "$tmp" && echo "2ec53af3aee77f56350e959646bc8fdc257320ca640002efcd7de8e324ae7589  plugin.zip" | sha256sum -c --quiet)
        rm -rf "$WE_PLUGIN"
        mkdir -p "$WE_PLUGIN"
        unzip -q "$tmp/plugin.zip" -d "$WE_PLUGIN"
    fi
    rm -rf "$tmp"
fi

echo "Restarting the shell"
pkill -f "qs -c caelestia" || true
sleep 1
caelestia shell -d
echo "Done. Press + on the widget in the bottom-right corner of your desktop to pick shows."
