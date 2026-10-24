#!/bin/sh
# Installs (or updates) NoShell, a Caelestia shell fork. Arch Linux only. Sets up Caelestia itself first if it's missing.
#   curl -fsSL https://raw.githubusercontent.com/NoAppsStudioNo/NoShell/anime-calendar/install.sh | sh
# Uninstall: rm -rf ~/.config/quickshell/caelestia && paru -S caelestia-shell && caelestia shell -d
set -e

REPO=https://github.com/NoAppsStudioNo/NoShell
BRANCH=anime-calendar
DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/noshell" # builds and downloads; /tmp is often a small RAM disk

if ! command -v pacman >/dev/null; then
    echo "NoShell only supports Arch Linux." >&2
    exit 1
fi
if [ "$(id -u)" = 0 ]; then
    echo "Run this as your normal user, not root (it asks for sudo when needed)." >&2
    exit 1
fi

sudo pacman -S --needed --noconfirm git curl mpv libnotify base-devel cmake ninja qt6-shadertools

# Caelestia itself (Hyprland config, CLI, theming), the official way
if ! command -v caelestia >/dev/null; then
    helper=$(command -v paru || command -v yay || true)
    helper=${helper##*/}
    if [ -z "$helper" ]; then
        echo "Installing paru (an AUR helper, needed by Caelestia)"
        tmp=$(mktemp -d)
        git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru"
        (cd "$tmp/paru" && makepkg -si --noconfirm)
        rm -rf "$tmp"
        helper=paru
    fi
    echo "Installing Caelestia"
    "$helper" -S --needed --noconfirm caelestia-cli
    caelestia install --aur-helper "$helper" --noconfirm
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

# The shell's compiled plugin, built from this repo so it always matches the QML (replaces the caelestia-shell
# package). Versioned by the last change to the C++ side, so QML-only updates skip the few minutes of building.
want=$(git -C "$DIR" log -1 --format=%cd.%h --date=format:%Y%m%d -- plugin extras CMakeLists.txt)
have=$(pacman -Q noshell 2>/dev/null | awk '{print $2}' | cut -d- -f1)
if [ "$want" != "$have" ]; then
    echo "Building the shell (takes a few minutes, needs ~3 GB free in ~/.cache)"
    mkdir -p "$CACHE"
    tmp=$(mktemp -d -p "$CACHE")
    cp "$DIR/packaging/PKGBUILD" "$tmp/"
    (cd "$tmp" && NOSHELL_SRC="$DIR" makepkg -sf --noconfirm)
    for old in caelestia-shell caelestia-shell-git; do
        if pacman -Q "$old" >/dev/null 2>&1; then
            sudo pacman -Rdd --noconfirm "$old"
        fi
    done
    # Overwrite leftovers of a manual `cmake --install`, which pacman doesn't own
    sudo pacman -U --noconfirm --overwrite '/usr/lib/qt6/qml/Caelestia/*' --overwrite '/usr/lib/caelestia/*' \
        --overwrite '/etc/xdg/quickshell/caelestia/*' "$tmp"/noshell-*.pkg.tar.zst
    rm -rf "$tmp"
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
    mkdir -p "$CACHE"
    tmp=$(mktemp -d -p "$CACHE")
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

# Terminal greeting: NoShell instead of Caelestia. Only replaces a missing or stock Caelestia greeting, never a customised one.
greeting="${XDG_CONFIG_HOME:-$HOME/.config}/fish/functions/fish_greeting.fish"
if [ ! -e "$greeting" ] || grep -q '/ ____/___ ____' "$greeting"; then
    mkdir -p "$(dirname "$greeting")"
    cp "$DIR/assets/fish_greeting.fish" "$greeting"
fi

echo "Restarting the shell"
pkill -f "qs -c caelestia" || true
sleep 1
caelestia shell -d
echo "Done. Press + on the widget in the bottom-right corner of your desktop to pick anime."
echo "Live wallpapers: Settings > Wallpaper & style > Wallpaper Engine."
