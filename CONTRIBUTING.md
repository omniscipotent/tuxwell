# Contributing

Thanks for helping. The goal is to make this work on more distros and more Audeze dongles.

## The most useful things right now
1. **Test it on your distro or dongle** and open a *Device / distro report* issue with the output of `maxwell-linux-report`.
2. **Packaging**: the sofa plugin package name per distro in `install.sh`, plus an AUR / .deb / Flatpak recipe.
3. **Other desktops**: tray behaviour on KDE and others, and the desktop entry.
4. **Other dongles and the Maxwell (1)**: confirm the HID packets (see [docs/DEVICES.md](docs/DEVICES.md)).

## Ground rules
- **Never send guessed values to a headset.** Only send values that have already been confirmed to work on real hardware, and say in your PR how you confirmed them.
- Keep the installer user-level. Anything that needs root (the udev rule) stays optional and clearly explained.
- No telemetry, no network access beyond the one pinned, checksummed HRTF download.
- Shell: `shellcheck -S warning bin/* install.sh` must pass. Python: `python3 -m py_compile gui/maxwell-linux-gui`. CI runs both.
- Small PRs with a clear description of what you tested and on what hardware.

## Layout
- `bin/maxwell-linux` is the background service (applies and reverts settings when the headset powers on and off).
- `gui/maxwell-linux-gui` is the GTK4 control panel and tray icon.
- `pipewire/` is the surround sink template; `udev/` is the HID access rule; `systemd/` is the user unit.
