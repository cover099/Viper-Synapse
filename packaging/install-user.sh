#!/usr/bin/env bash
# Installs Viper Synapse for this user only, from the source tree (no root):
#   ~/.local/lib/viper-synapse        the published app, service and viper-cli
#   ~/.local/bin/viper-synapse        the launcher (the autostart entry and the menu run this)
#   ~/.local/share/applications       the menu entry; ~/.local/share/icons the icons
#   ~/.config/autostart               start at sign-in, in the tray (as the app's own Settings switch writes it)
# Run it again to update. --no-autostart leaves sign-in alone. Device access still needs the udev rule
# (packaging/udev/70-viper-synapse.rules in /etc/udev/rules.d), which this does not touch.
set -euo pipefail
cd "$(dirname "$0")/.."
LIB="$HOME/.local/lib/viper-synapse"
BIN="$HOME/.local/bin"
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "── publish"
for project in ViperSynapse.App ViperSynapse.Service ViperSynapse.Cli; do
    dotnet publish "src/$project/$project.csproj" -c Release -o "$STAGE" -v q --nologo
done
# (as build-release.sh: the views must be compiled in, and all three programs present)
grep -qa CompiledAvaloniaXaml "$STAGE/viper-synapse.dll" || { echo "!! no compiled XAML in viper-synapse.dll" >&2; exit 3; }
for f in viper-synapse viper-synapsed viper-cli; do
    [[ -x "$STAGE/$f" ]] || { echo "!! $f is missing from the publish" >&2; exit 3; }
done

echo "── install to $LIB"
# A running copy holds its files: stop it first (it is started again at the end).
pkill -x viper-synapsed 2>/dev/null || true
pkill -x viper-synapse 2>/dev/null || true
sleep 1
rm -rf "$LIB"
mkdir -p "$LIB" "$BIN"
cp -a "$STAGE"/. "$LIB"/
ln -sf "$LIB/viper-synapse" "$BIN/viper-synapse"
ln -sf "$LIB/viper-cli" "$BIN/viper-cli"

for s in 16 32 48 64 128 256 512; do
    install -Dm644 "assets/icon-$s.png" "$SHARE/icons/hicolor/${s}x${s}/apps/viper-synapse.png"
done
install -Dm644 packaging/io.github.codingncaffeine.ViperSynapse.desktop "$SHARE/applications/io.github.codingncaffeine.ViperSynapse.desktop"
sed -i "s|^Exec=.*|Exec=$BIN/viper-synapse|" "$SHARE/applications/io.github.codingncaffeine.ViperSynapse.desktop"
update-desktop-database "$SHARE/applications" 2>/dev/null || true
gtk-update-icon-cache -q "$SHARE/icons/hicolor" 2>/dev/null || true

if [[ "${1:-}" != "--no-autostart" ]]; then
    mkdir -p "$CONFIG/autostart"
    cat > "$CONFIG/autostart/viper-synapse.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Viper Synapse
Comment=Razer device settings, key bindings and macros
Exec=$BIN/viper-synapse --background
Icon=viper-synapse
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
    echo "── starts at sign-in (in the tray)"
fi
echo "── done: $BIN/viper-synapse"
