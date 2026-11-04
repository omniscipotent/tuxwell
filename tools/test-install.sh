#!/usr/bin/env bash
# End-to-end test of install.sh in throwaway home folders. Your real setup is never touched: HOME points at a temp
# directory and systemctl / update-desktop-database / gtk-update-icon-cache are replaced by stubs that only log.
#
#   tools/test-install.sh            runs everything (needs network once: it downloads and verifies the default head response)
#   TUXWELL_OFFLINE=1 tools/test-install.sh   skips the fresh-install scenario that downloads
#
# Scenarios: A) upgrade from the old "maxwell-linux" layout, B) brand-new machine, C) installed tools run, D) uninstall.
set -u
REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
T=$(mktemp -d); [ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "${T:?}"' EXIT
FAILS=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
check(){ if eval "$2"; then ok "$1"; else fail "$1"; fi; }

mkdir -p "$T/bin"
for c in systemctl update-desktop-database gtk-update-icon-cache; do
  printf '#!/bin/sh\necho "[%s] $*" >> "%s/stub.log"\n' "$c" "$T" > "$T/bin/$c"; chmod +x "$T/bin/$c"
done
install_in() { (cd "$REPO" && HOME="$1" XDG_CONFIG_HOME='' XDG_DATA_HOME='' PATH="$T/bin:$PATH" bash install.sh "${@:2}" 2>&1); }

echo "A) upgrade from the old maxwell-linux layout"
HA="$T/homeA"
mkdir -p "$HA/.config/maxwell-linux" "$HA/.local/share/maxwell-linux/hrtf" "$HA/.local/share/maxwell-linux/audezeforlinux" "$HA/.local/bin" "$HA/.config/systemd/user"
printf 'HW_VOLUME=77\nSURROUND_GAIN=0.31\nCTL_PATH=%s\n' "$HA/.local/share/maxwell-linux/audezeforlinux/maxwell_ctl.py" > "$HA/.config/maxwell-linux/maxwell.conf"
echo "fake-ctl" > "$HA/.local/share/maxwell-linux/audezeforlinux/maxwell_ctl.py"
touch "$HA/.local/share/maxwell-linux/hrtf/D1_48K_24bit_256tap_FIR_SOFA.sofa" "$HA/.local/bin/maxwell-linux" "$HA/.config/systemd/user/maxwell-linux.service"
install_in "$HA" >/dev/null
check "settings carried over"           'grep -q "HW_VOLUME=77" "$HA/.config/tuxwell/tuxwell.conf" && grep -q "SURROUND_GAIN=0.31" "$HA/.config/tuxwell/tuxwell.conf"'
check "path inside settings rewritten"   'grep -q "/tuxwell/audezeforlinux/" "$HA/.config/tuxwell/tuxwell.conf"'
check "old install removed"              '[ ! -e "$HA/.local/bin/maxwell-linux" ] && [ ! -e "$HA/.config/systemd/user/maxwell-linux.service" ] && [ ! -d "$HA/.config/maxwell-linux" ] && [ ! -d "$HA/.local/share/maxwell-linux" ]'
check "downloaded data moved"            '[ -f "$HA/.local/share/tuxwell/audezeforlinux/maxwell_ctl.py" ] && [ -f "$HA/.local/share/tuxwell/hrtf/D1_48K_24bit_256tap_FIR_SOFA.sofa" ]'
check "old service was disabled"         'grep -q "disable --now maxwell-linux" "$T/stub.log"'
check "new commands installed"           'for c in tuxwell tuxwell-gui tuxwell-hrtf tuxwell-report tuxwell-render-surround tuxwell-test-sound; do [ -x "$HA/.local/bin/$c" ] || exit 1; done'

if [ -z "${TUXWELL_OFFLINE:-}" ]; then
  echo "B) brand-new machine (downloads and verifies the default head response)"
  HB="$T/homeB"; mkdir -p "$HB"
  install_in "$HB" >/dev/null
  check "default settings created"       'grep -q "^HW_VOLUME=86" "$HB/.config/tuxwell/tuxwell.conf"'
  check "head response verified"         '[ "$(sha256sum "$HB/.local/share/tuxwell/hrtf/D1_48K_24bit_256tap_FIR_SOFA.sofa" | cut -c1-16)" = 9af7cb19531e52fb ]'
  check "template, corrections, catalogs" '[ -f "$HB/.local/share/tuxwell/surround.conf.in" ] && [ -f "$HB/.local/share/tuxwell/eq/maxwell2-neutral.txt" ] && [ -f "$HB/.local/share/tuxwell/hrtf-catalog.tsv" ]'
  check "launcher and icons"             '[ -f "$HB/.local/share/applications/io.github.omniscipotent.Tuxwell.desktop" ] && [ -f "$HB/.local/share/icons/hicolor/48x48/apps/io.github.omniscipotent.Tuxwell.png" ]'
  check "service enabled"                'grep -q "enable --now tuxwell.service" "$T/stub.log"'
  echo "C) the installed tools run from the clean home"
  check "tuxwell-hrtf lists sets"        'HOME="$HB" "$HB/.local/bin/tuxwell-hrtf" list | grep -q "Dummy D1"'
  check "renderer builds a config"       'HOME="$HB" python3 "$HB/.local/bin/tuxwell-render-surround" --template "$HB/.local/share/tuxwell/surround.conf.in" --hrtf x --gain 0.3 --target t --eq "$HB/.local/share/tuxwell/eq/maxwell2-neutral.txt" | grep -q "eqL1"'
  echo "D) uninstall"
  install_in "$HB" --uninstall >/dev/null
  check "commands and launcher removed"  '[ -z "$(ls "$HB/.local/bin" 2>/dev/null)" ] && [ ! -e "$HB/.local/share/applications/io.github.omniscipotent.Tuxwell.desktop" ]'
  check "icons removed"                  '[ -z "$(ls "$HB"/.local/share/icons/hicolor/*/apps/io.github.omniscipotent.Tuxwell.png 2>/dev/null)" ]'
  check "settings kept"                  '[ -f "$HB/.config/tuxwell/tuxwell.conf" ]'
fi
echo; [ "$FAILS" -eq 0 ] && echo "all install checks passed" || { echo "$FAILS check(s) FAILED"; exit 1; }
