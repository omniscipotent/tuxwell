# Contributing

Thanks for helping. The goal is to make Tuxwell work on more distros and more Audeze dongles, and to keep it easy to trust.

## The most useful things right now
1. **Test it on your distro or dongle** and open a *Device / distro report* issue with the output of `tuxwell-report`.
2. **Packaging**: the sofa plugin package name per distro in `install.sh`, plus an AUR / .deb / Flatpak recipe.
3. **Other desktops**: tray behaviour on KDE and others, and the desktop entry.
4. **Other dongles and the Maxwell (1)**: confirm the HID packets (see [docs/DEVICES.md](docs/DEVICES.md)).

## Ground rules
- **Never send guessed values to a headset.** Only send values that have already been confirmed to work on real hardware, and say in
  your PR how you confirmed them. (Out-of-range preset values powered a headset off during testing.)
- Keep the installer user-level. Anything that needs root (the udev rule) stays optional and clearly explained.
- No telemetry, and no network access beyond the checksummed head-response downloads.
- Settings files are data: never `source` or `eval` them. Validate every value.
- Small PRs with a clear description of what you tested and on what hardware.

## Getting oriented
Read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) first: it explains the pieces, the service lifecycle and the volume model.
[docs/SETTINGS.md](docs/SETTINGS.md) lists every setting. The layout:

| Path | What it is |
|---|---|
| `bin/tuxwell` | The background service (bash). Functions are documented and can be sourced for testing. |
| `bin/tuxwell-render-surround` | Builds the surround config from the template (Python, stdlib only). |
| `bin/tuxwell-hrtf`, `bin/tuxwell-test-sound`, `bin/tuxwell-report` | Head-response manager, test sound, diagnostics. |
| `gui/tuxwell-gui` | The control panel and tray icon (Python, GTK4 + libadwaita). |
| `pipewire/tuxwell-surround.conf.in` | The surround graph template. |
| `data/` | Head-response catalog and the headphone-correction profiles (with credits). |
| `tools/` | `fit-eq.py` regenerates the Maxwell 2 correction; `test-install.sh` tests the installer. |
| `tests/` | Unit tests. |

## Checks to run before opening a PR
```bash
python3 -m unittest discover -s tests        # unit tests (no audio system or GTK needed)
shellcheck -S warning bin/tuxwell bin/tuxwell-report bin/tuxwell-hrtf install.sh tools/test-install.sh
python3 -m pyflakes gui/tuxwell-gui bin/tuxwell-render-surround bin/tuxwell-test-sound tools/fit-eq.py   # optional
tools/test-install.sh                        # installs into throwaway homes; needs network once (TUXWELL_OFFLINE=1 skips that part)
```
CI runs the unit tests, ShellCheck and the desktop-file validation on every push.

### How the tests work
- `tests/test_service.py` sources the service with `TUXWELL_LIB=1` (which stops it from running) and replaces `pactl` with a fake that
  records calls and answers from canned output. That is how routing, "is it playing" and follow-playback are tested without audio.
- `tests/test_gui_logic.py` stubs GTK, so the settings validation and the output-switch plan are tested without a display.
- `tests/test_render.py` runs the renderer on the real template.

## Code style
- **Comment the why, not the what.** Explain a choice, a measurement, a protocol quirk or a trap; don't restate the code.
- Every function gets a one-line description of what it does; non-obvious ones also say what they assume or return.
- The GUI must never wait on a subprocess on the main thread: use `bg()` (see the header of `gui/tuxwell-gui`).
- Prefer one snapshot of state per decision over repeated queries (`snapshot()` in the service).

## Adding things
- **A device**: see [docs/DEVICES.md](docs/DEVICES.md) ("Adding a device").
- **A head-response set**: add a row to `data/hrtf-catalog.tsv` with its checksum (`tuxwell-hrtf` verifies it).
- **A headphone correction**: add a profile to `data/eq/`, a row to `data/eq/catalog.tsv`, and its source to `data/eq/README.md`.
  Say what it was measured on and what target it aims at. Don't commit raw third-party measurements; commit the derived filters and a way to reproduce them.
