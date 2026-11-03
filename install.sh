#!/usr/bin/env bash
# maxwell-linux installer (user-level; only the udev rule needs sudo). ./install.sh [--uninstall]
set -eu
cd "$(dirname "$(readlink -f "$0")")"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/maxwell-linux"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/maxwell-linux/hrtf"
HRTF=D1_48K_24bit_256tap_FIR_SOFA.sofa
HRTF_SHA256=9af7cb19531e52fb7ae8ec92621e6ab62b1d5fe584b3742be36699a0ddb0ccd4
URL='https://zenodo.org/records/12092466/files/D1_HRIR_SOFA.zip?download=1'
if [ "${1:-}" = "--uninstall" ]; then
  systemctl --user disable --now maxwell-linux.service 2>/dev/null || true
  rm -f ~/.local/bin/maxwell-linux ~/.local/bin/maxwell-linux-report ~/.local/bin/maxwell-linux-gui ~/.local/share/applications/io.github.maxwell_linux.desktop ~/.config/systemd/user/maxwell-linux.service "$CFG/surround.conf"
  systemctl --user daemon-reload
  echo "Removed. HRTF and $CFG/maxwell.conf kept. udev rule: sudo rm /etc/udev/rules.d/70-audeze-maxwell.rules"; exit 0
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
mkdir -p "$CFG" "$DATA" ~/.local/bin ~/.config/systemd/user
if [ ! -f "$DATA/$HRTF" ]; then
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  curl --proto '=https' --tlsv1.2 -fL -o "$tmp/h.zip" "$URL"
  unzip -j "$tmp/h.zip" "D1_HRIR_SOFA/$HRTF" -d "$tmp"
  echo "$HRTF_SHA256  $tmp/$HRTF" | sha256sum -c - >/dev/null || { echo "HRTF checksum mismatch, refusing to install it"; exit 1; }
  install -m644 "$tmp/$HRTF" "$DATA/$HRTF"
fi
sink=$(pactl list short sinks | awk '/Audeze/ {print $2; exit}')
sink=${sink:-alsa_output.usb-Audeze_LLC_Audeze_Maxwell_XBOX_Dongle_0000000000000000-00.iec958-stereo}
sed -e "s|@HRTF@|$DATA/$HRTF|g" -e "s|@GAIN@|0.125|g" -e "s|@TARGET@|$sink|g" pipewire/maxwell-surround.conf.in > "$CFG/surround.conf"
[ -f "$CFG/maxwell.conf" ] || cat > "$CFG/maxwell.conf" <<'C'
HW_VOLUME=86
DISABLE_MIC=1
SURROUND_ENABLED=1
HIRES=1
C
install -m755 bin/maxwell-linux ~/.local/bin/maxwell-linux
install -m755 bin/maxwell-linux-report ~/.local/bin/maxwell-linux-report
install -m644 systemd/maxwell-linux.service ~/.config/systemd/user/maxwell-linux.service
install -m755 gui/maxwell-linux-gui ~/.local/bin/maxwell-linux-gui
install -d ~/.local/share/applications
sed "s|@BIN@|$HOME/.local/bin|" gui/io.github.maxwell_linux.desktop.in > ~/.local/share/applications/io.github.maxwell_linux.desktop
chmod 644 ~/.local/share/applications/io.github.maxwell_linux.desktop
update-desktop-database ~/.local/share/applications 2>/dev/null || true
for z in 512 256 128 64 48 32 24 22 16; do install -d ~/.local/share/icons/hicolor/${z}x${z}/apps; magick assets/io.github.maxwell_linux.png -resize ${z}x${z} ~/.local/share/icons/hicolor/${z}x${z}/apps/io.github.maxwell_linux.png 2>/dev/null || cp assets/io.github.maxwell_linux.png ~/.local/share/icons/hicolor/${z}x${z}/apps/io.github.maxwell_linux.png; done
gtk-update-icon-cache -q ~/.local/share/icons/hicolor 2>/dev/null || true
systemctl --user daemon-reload; systemctl --user enable --now maxwell-linux.service
cmp -s udev/70-audeze-maxwell.rules /etc/udev/rules.d/70-audeze-maxwell.rules 2>/dev/null ||
  echo "HID access (optional): sudo install -m644 udev/70-audeze-maxwell.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=hidraw --action=change"
echo "Installed. Open Tuxwell from your app menu."
