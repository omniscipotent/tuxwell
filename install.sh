#!/usr/bin/env bash
# Tuxwell installer. Everything is installed for the current user only; nothing needs root except the optional udev rule.
#
#   ./install.sh               install or upgrade (safe to run again)
#   ./install.sh --uninstall   remove the commands, service, launcher and icons (settings and downloaded data are kept)
#
# What it does, in order
#   1. checks the tools it needs and warns if PipeWire's "sofa" plugin (needed for surround) is missing
#   2. migrates an older install that used the name "maxwell-linux" (keeps settings and downloaded data)
#   3. downloads the default head response and verifies it against a pinned SHA-256
#   4. installs the commands, the surround template, the correction profiles, the service, the launcher and the icons
#   5. enables and starts the user service
#   6. prints the one-time sudo command for the optional HID access rule (headset presets, sidetone, chat mix)
#
# Where things go (all under $HOME unless XDG_* says otherwise)
#   ~/.local/bin/tuxwell*                         the commands
#   ~/.config/tuxwell/tuxwell.conf                settings (created once, never overwritten)
#   ~/.config/systemd/user/tuxwell.service        the background service
#   ~/.local/share/tuxwell/                       surround template, head responses (hrtf/), corrections (eq/), catalogs
#   ~/.local/share/applications, .../icons        launcher and icons
set -eu
cd "$(dirname "$(readlink -f "$0")")"                          # run from the repository, wherever it was started from

# --- locations ---------------------------------------------------------------------------------------------------------
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/tuxwell"
ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/tuxwell"
HRTF_DIR="$ROOT/hrtf"
BIN="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"
APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor"
APP_ID="io.github.omniscipotent.Tuxwell"                          # launcher and icon name (reverse-DNS, as GNOME expects)
COMMANDS="tuxwell tuxwell-report tuxwell-hrtf tuxwell-render-surround tuxwell-test-sound tuxwell-gui"
ICON_SIZES="512 256 128 64 48 32 24 22 16"

# The default head response (SADIE II subject D1, Apache-2.0, University of York). Pinned so a tampered or truncated
# download is refused. Other sets are fetched later by tuxwell-hrtf, each with its own pinned checksum.
HRTF=D1_48K_24bit_256tap_FIR_SOFA.sofa
HRTF_SHA256=9af7cb19531e52fb7ae8ec92621e6ab62b1d5fe584b3742be36699a0ddb0ccd4
HRTF_URL='https://zenodo.org/records/12092466/files/D1_HRIR_SOFA.zip?download=1'

# --- steps -------------------------------------------------------------------------------------------------------------
uninstall() {
  systemctl --user disable --now tuxwell.service 2>/dev/null || true
  for c in $COMMANDS; do rm -f "${BIN:?}/$c"; done
  rm -f "${APPS_DIR:?}/$APP_ID.desktop" "${UNIT_DIR:?}/tuxwell.service" "${ICON_DIR:?}"/*/apps/"$APP_ID.png"
  systemctl --user daemon-reload
  echo "Removed. Head responses and $CFG/tuxwell.conf kept. udev rule: sudo rm /etc/udev/rules.d/70-audeze-maxwell.rules"
}

check_requirements() {
  local t
  for t in pipewire pactl pw-metadata amixer lsusb curl unzip; do
    command -v "$t" >/dev/null || { echo "missing: $t"; exit 1; }
  done
  # Surround needs PipeWire's "sofa" filter-chain plugin. Its package name differs per distro.
  if ! ls /usr/lib*/spa-0.2/filter-graph/*sofa* >/dev/null 2>&1; then
    echo "note: surround needs PipeWire's sofa filter-chain plugin."
    . /etc/os-release 2>/dev/null || true
    case "${ID:-}" in
      fedora) echo "  Fedora: sudo dnf install pipewire-module-filter-chain-sofa" ;;
      *)      echo "  Install the package that provides libspa-filter-graph-plugin-sofa.so for ${PRETTY_NAME:-your distro}"
              echo "  and tell us the package name: https://github.com/omniscipotent/tuxwell/issues" ;;
    esac
  fi
}

# Earlier versions were called "maxwell-linux". Carry over the settings and the downloaded data, then remove the old install.
migrate_old_install() {
  local old_cfg old_root d
  old_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/maxwell-linux"
  old_root="${XDG_DATA_HOME:-$HOME/.local/share}/maxwell-linux"
  [ -d "$old_cfg" ] || [ -d "$old_root" ] || [ -e "$UNIT_DIR/maxwell-linux.service" ] || return 0
  echo "Migrating from the old name (maxwell-linux)..."
  systemctl --user disable --now maxwell-linux.service 2>/dev/null || true
  rm -f "$BIN/maxwell-linux" "$BIN/maxwell-linux-gui" "$BIN/maxwell-linux-report" "$UNIT_DIR/maxwell-linux.service" \
        "$APPS_DIR/io.github.maxwell_linux.desktop" "$ICON_DIR"/*/apps/io.github.maxwell_linux.png \
        "${XDG_RUNTIME_DIR:-/tmp}"/maxwell-linux-surround.*
  if [ -f "$old_cfg/maxwell.conf" ] && [ ! -f "$CFG/tuxwell.conf" ]; then
    mkdir -p "$CFG"
    cp "$old_cfg/maxwell.conf" "$CFG/tuxwell.conf"
    sed -i "s#/maxwell-linux/#/tuxwell/#g" "$CFG/tuxwell.conf"      # paths inside the old settings point at the old folder
  fi
  [ -f "$CFG/tuxwell.conf" ] && rm -rf "${old_cfg:?}"               # only once the settings were safely copied
  if [ -d "$old_root" ]; then
    mkdir -p "$ROOT"
    for d in hrtf audezeforlinux; do
      [ -d "$old_root/$d" ] && [ ! -e "$ROOT/$d" ] && mv "$old_root/$d" "$ROOT/$d"
    done
    rmdir "$old_root" 2>/dev/null || true
  fi
}

# Download the default head response unless it is already there, and refuse it if its checksum is wrong.
install_default_hrtf() {
  [ -f "$HRTF_DIR/$HRTF" ] && return 0
  local tmp
  tmp=$(mktemp -d); trap 'rm -rf "${tmp:?}"' EXIT
  curl --proto '=https' --tlsv1.2 -fL -o "$tmp/h.zip" "$HRTF_URL"
  unzip -j "$tmp/h.zip" "D1_HRIR_SOFA/$HRTF" -d "$tmp"
  echo "$HRTF_SHA256  $tmp/$HRTF" | sha256sum -c - >/dev/null || { echo "HRTF checksum mismatch, refusing to install it"; exit 1; }
  install -m644 "$tmp/$HRTF" "$HRTF_DIR/$HRTF"
}

install_files() {
  local c src
  # Commands. Most live in bin/; the control panel lives in gui/.
  for c in $COMMANDS; do
    src="bin/$c"; [ -f "$src" ] || src="gui/$c"
    install -m755 "$src" "$BIN/$c"
  done
  # Data the service and the app read at run time.
  install -Dm644 pipewire/tuxwell-surround.conf.in "$ROOT/surround.conf.in"      # rendered at each start (tuxwell-render-surround)
  install -Dm644 data/hrtf-catalog.tsv "$ROOT/hrtf-catalog.tsv"
  install -d "$ROOT/eq"; install -m644 data/eq/*.txt data/eq/catalog.tsv "$ROOT/eq/"
  rm -f "$CFG/surround.conf"                                                     # older installs baked this at install time
  # Settings: created once with the essentials, never overwritten. Everything else uses the built-in defaults.
  [ -f "$CFG/tuxwell.conf" ] || printf 'HW_VOLUME=86\nDISABLE_MIC=1\nSURROUND_ENABLED=1\nHIRES=1\n' > "$CFG/tuxwell.conf"
  # Service unit.
  install -m644 systemd/tuxwell.service "$UNIT_DIR/tuxwell.service"
}

# Launcher entry (with the absolute path to the app, so it works even if ~/.local/bin is not on the desktop's PATH) and icons.
install_launcher() {
  local z
  install -d "$APPS_DIR"
  sed "s|@BIN@|$BIN|" "gui/$APP_ID.desktop.in" > "$APPS_DIR/$APP_ID.desktop"
  chmod 644 "$APPS_DIR/$APP_ID.desktop"
  update-desktop-database "$APPS_DIR" 2>/dev/null || true
  for z in $ICON_SIZES; do
    install -d "$ICON_DIR/${z}x${z}/apps"
    magick "assets/$APP_ID.png" -resize "${z}x${z}" "$ICON_DIR/${z}x${z}/apps/$APP_ID.png" 2>/dev/null \
      || cp "assets/$APP_ID.png" "$ICON_DIR/${z}x${z}/apps/$APP_ID.png"       # no ImageMagick: use the full-size image
  done
  gtk-update-icon-cache -q "$ICON_DIR" 2>/dev/null || true
}

start_service() {
  systemctl --user daemon-reload
  systemctl --user enable --now tuxwell.service
}

hint_udev_rule() {
  cmp -s udev/70-audeze-maxwell.rules /etc/udev/rules.d/70-audeze-maxwell.rules 2>/dev/null && return 0
  echo "HID access (optional): sudo install -m644 udev/70-audeze-maxwell.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger --subsystem-match=hidraw --action=change"
}

# --- main --------------------------------------------------------------------------------------------------------------
if [ "${1:-}" = "--uninstall" ]; then uninstall; exit 0; fi
check_requirements
migrate_old_install
mkdir -p "$CFG" "$HRTF_DIR" "$BIN" "$UNIT_DIR"
install_default_hrtf
install_files
install_launcher
start_service
hint_udev_rule
echo "Installed. Open Tuxwell from your app menu."
