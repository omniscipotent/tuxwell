# Supported hardware and distros

Tuxwell is built around one tested setup. **Everything else is untested, and help is very welcome.**

## Headsets and dongles

| Device | USB ID | Status |
|---|---|---|
| Maxwell 2, Xbox dongle | `3329:4b28` | **Tested** (audio fixes, surround, presets) |
| Maxwell 2, PlayStation / PC dongle | `3329:4b29`, `3329:4b2a` | Untested. Audio parts probably work; presets need confirming |
| Maxwell 2 over USB-C (direct) | unknown | Untested |
| Maxwell (1), dongles | `3329:4b18`, `3329:4b19`, `3329:4b1a`, `3329:4b1e` | Untested. Different firmware; preset bytes may differ |
| Bluetooth | n/a | Not supported (this project is about the USB dongle) |

IDs other than `4b28` come from other community projects and the udev rule, not from testing.

### What is device specific
- **Audio side** (hardware volume, 48/96 kHz, mic profile, surround): the service finds the dongle by name (`Audeze` in the ALSA card / sink name), so it may already work on other Audeze USB devices.
- **Headset side** (presets, sidetone, chat mix): the control panel talks to the HID interface with the Xbox dongle's ID `3329:00004B28` (`DONGLE_HID` at the top of `gui/maxwell-linux-gui`).
  Other models need their packets confirmed first. See [PRESETS.md](PRESETS.md) for the preset values and the gotcha about control `SET_REPORT`.

### Adding a device
1. Run `maxwell-linux-report` and open a **Device report** issue with the output.
2. Talk it through in the issue before sending anything new to the headset. Compare with the table in [PRESETS.md](PRESETS.md). Don't guess values on real hardware: out-of-range preset values powered a headset off during testing.

## Distros

| Distro | Status |
|---|---|
| Fedora 44, GNOME, PipeWire 1.6 | **Tested** |
| Everything else with PipeWire and systemd | Untested |

What differs between distros:
- the package providing PipeWire's `sofa` filter-chain plugin (`libspa-filter-graph-plugin-sofa.so`); Fedora's is `pipewire-module-filter-chain-sofa`;
- how a tray icon is shown (the app speaks the StatusNotifierItem protocol; GNOME needs a tray extension, KDE has it built in);
- `lsusb`, `pactl`, `amixer`, `pw-metadata` and `magick` names/packages;
- the udev rule path is standard, but check `uaccess` works with your seat manager.

If you get it working somewhere new, please send a PR updating this table and `install.sh`.
