#!/usr/bin/env bash
# tuxwell installer (user-level; only the udev rule needs sudo). ./install.sh [--uninstall]
set -eu
cd "$(dirname "$(readlink -f "$0")")"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/tuxwell"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/tuxwell/hrtf"
HRTF=D1_48K_24bit_256tap_FIR_SOFA.sofa
HRTF_SHA256=9af7cb19531e52fb7ae8ec92621e6ab62b1d5fe584b3742be36699a0ddb0ccd4
URL='https://zenodo.org/records/12092466/files/D1_HRIR_SOFA.zip?download=1'
if [ "${1:-}" = "--uninstall" ]; then
  systemctl --user disable --now tuxwell.service 2>/dev/null || true
  rm -f ~/.local/bin/tuxwell ~/.local/bin/tuxwell-report ~/.local/bin/tuxwell-hrtf ~/.local/bin/tuxwell-render-surround ~/.local/bin/tuxwell-test-sound ~/.local/bin/tuxwell-gui ~/.local/share/applications/io.github.omniscipotent.Tuxwell.desktop ~/.config/systemd/user/tuxwell.service
  systemctl --user daemon-reload
  echo "Removed. HRTF and $CFG/tuxwell.conf kept. udev rule: sudo rm /etc/udev/rules.d/70-audeze-maxwell.rules"; exit 0
fi
for t in pipewire pactl pw-metadata amixer lsusb curl unzip; do command -v $t >/dev/null || { echo "missing: $t"; exit 1; }; done
if ! ls /usr/lib*/spa-0.2/filter-graph/*sofa* >/dev/null 2>&1; then
  echo "note: surround needs PipeWire's sofa filter-chain plugin."
  . /etc/os-release 2>/dev/null || true
  case "${ID:-}" in
    fedora) echo "  Fedora: sudo dnf install pipewire-module-filter-chain-sofa" ;;
    *)      echo "  Install the package that provides libspa-filter-graph-plugin-sofa.so for ${PRETTY_NAME:-your distro}"
            echo "  and tell us the package name: https://github.com/omniscipotent/tuxwell/issues" ;;
  esac
fi
# --- migrate from the old name (maxwell-linux): keep settings and downloaded data, drop the old install ---
OLD_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/maxwell-linux"
OLD_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/maxwell-linux"
NEW_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/tuxwell"
if [ -d "$OLD_CFG" ] || [ -d "$OLD_ROOT" ] || [ -e ~/.config/systemd/user/maxwell-linux.service ]; then
  echo "Migrating from the old name (maxwell-linux)..."
  systemctl --user disable --now maxwell-linux.service 2>/dev/null || true
  rm -f ~/.local/bin/maxwell-linux ~/.local/bin/maxwell-linux-gui ~/.local/bin/maxwell-linux-report \
        ~/.config/systemd/user/maxwell-linux.service ~/.local/share/applications/io.github.maxwell_linux.desktop \
        ~/.local/share/icons/hicolor/*/apps/io.github.maxwell_linux.png "${XDG_RUNTIME_DIR:-/tmp}"/maxwell-linux-surround.*
  if [ -f "$OLD_CFG/maxwell.conf" ] && [ ! -f "$CFG/tuxwell.conf" ]; then
    mkdir -p "$CFG"
    cp "$OLD_CFG/maxwell.conf" "$CFG/tuxwell.conf"
    sed -i "s#/maxwell-linux/#/tuxwell/#g" "$CFG/tuxwell.conf"
  fi
  [ -f "$CFG/tuxwell.conf" ] && rm -rf "$OLD_CFG"   # only once the copy worked
  if [ -d "$OLD_ROOT" ]; then
    mkdir -p "$NEW_ROOT"
    for d in hrtf audezeforlinux; do
      [ -d "$OLD_ROOT/$d" ] && [ ! -e "$NEW_ROOT/$d" ] && mv "$OLD_ROOT/$d" "$NEW_ROOT/$d"
    done
    rmdir "$OLD_ROOT" 2>/dev/null || true
  fi
fi
mkdir -p "$CFG" "$DATA" ~/.local/bin ~/.config/systemd/user
if [ ! -f "$DATA/$HRTF" ]; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  curl --proto '=https' --tlsv1.2 -fL -o "$tmp/h.zip" "$URL"
  unzip -j "$tmp/h.zip" "D1_HRIR_SOFA/$HRTF" -d "$tmp"
  echo "$HRTF_SHA256  $tmp/$HRTF" | sha256sum -c - >/dev/null || { echo "HRTF checksum mismatch, refusing to install it"; exit 1; }
  install -m644 "$tmp/$HRTF" "$DATA/$HRTF"
fi
ROOT="$(dirname "$DATA")"
install -Dm644 pipewire/tuxwell-surround.conf.in "$ROOT/surround.conf.in"
install -d "$ROOT/eq"; install -m644 data/eq/*.txt data/eq/catalog.tsv "$ROOT/eq/"
rm -f "$CFG/surround.conf"        # older installs baked this at install time; it is rendered at each start now
[ -f "$CFG/tuxwell.conf" ] || cat > "$CFG/tuxwell.conf" <<'C'
HW_VOLUME=86
DISABLE_MIC=1
SURROUND_ENABLED=1
HIRES=1
C
install -m755 bin/tuxwell ~/.local/bin/tuxwell
install -m755 bin/tuxwell-report ~/.local/bin/tuxwell-report
install -m755 bin/tuxwell-hrtf ~/.local/bin/tuxwell-hrtf
install -m755 bin/tuxwell-render-surround ~/.local/bin/tuxwell-render-surround
install -m755 bin/tuxwell-test-sound ~/.local/bin/tuxwell-test-sound
install -Dm644 data/hrtf-catalog.tsv "$(dirname "$DATA")/hrtf-catalog.tsv"
install -m644 systemd/tuxwell.service ~/.config/systemd/user/tuxwell.service
install -m755 gui/tuxwell-gui ~/.local/bin/tuxwell-gui
install -d ~/.local/share/applications
sed "s|@BIN@|$HOME/.local/bin|" gui/io.github.omniscipotent.Tuxwell.desktop.in > ~/.local/share/applications/io.github.omniscipotent.Tuxwell.desktop
chmod 644 ~/.local/share/applications/io.github.omniscipotent.Tuxwell.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true
for z in 512 256 128 64 48 32 24 22 16; do install -d ~/.local/share/icons/hicolor/${z}x${z}/apps; magick assets/io.github.omniscipotent.Tuxwell.png -resize ${z}x${z} ~/.local/share/icons/hicolor/${z}x${z}/apps/io.github.omniscipotent.Tuxwell.png 2>/dev/null || cp assets/io.github.omniscipotent.Tuxwell.png ~/.local/share/icons/hicolor/${z}x${z}/apps/io.github.omniscipotent.Tuxwell.png; done
gtk-update-icon-cache -q ~/.local/share/icons/hicolor 2>/dev/null || true
systemctl --user daemon-reload; systemctl --user enable --now tuxwell.service
cmp -s udev/70-audeze-maxwell.rules /etc/udev/rules.d/70-audeze-maxwell.rules 2>/dev/null ||
  echo "HID access (optional): sudo install -m644 udev/70-audeze-maxwell.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=hidraw --action=change"
echo "Installed. Open Tuxwell from your app menu."
