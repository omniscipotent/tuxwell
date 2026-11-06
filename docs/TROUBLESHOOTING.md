# Troubleshooting

**First step for almost anything:** in the app, open **More → Something wrong? → Copy report** and paste it into your issue
(or run `tuxwell-report`). It contains no usernames, hostnames or file paths.

## There is no surround output
- Is the headset **on**? The surround output only exists while it is.
- Is the sofa plugin installed? `ls /usr/lib*/spa-0.2/filter-graph/*sofa*` should find a file. On Fedora:
  `sudo dnf install pipewire-module-filter-chain-sofa`.
- Look at the service: `systemctl --user status tuxwell` and `journalctl --user -u tuxwell -b`. A line saying
  *could not build the surround config* means the renderer failed; run `tuxwell-render-surround --help`.

## The headset is quiet
- The dongle's own gain defaults to a low level. Check **Listen → Headset volume** (or `HW_VOLUME`).
- In surround, check **Surround → Surround level**, and the bass controls for movie rumble. See [SETTINGS.md](SETTINGS.md).

## Plex (or another app) isn't going through surround
- Run `pactl list sink-inputs` while it plays and look for its `application.name`. Add what you find to `SURROUND_APPS`.
- Watch what the service does: `journalctl --user -u tuxwell -f` prints a line each time it moves a stream.

## The output doesn't switch when I pause
- **Follow playback** must be on (Listen tab), and `PLAYING_APPS` must match the player's own stream (for Plex Desktop and Plex HTPC it is `plex-bin`).
- Switching back to stereo waits a few seconds on purpose, so changing episode doesn't flip it back and forth.

## The sound preset / sidetone / chat mix don't work
- They need the optional HID access rule and audezeforlinux. See the README ("Optional: headset settings").
- After installing the udev rule, switch the headset **off and on** once.
- The preset dropdown uses a USB control transfer; if it says it can't reach the headset, the rule isn't active yet.

## No tray icon
- GNOME needs a tray extension (for example *Status Tray* or *AppIndicator*). KDE shows it natively.
- The icon appears once the app is open; closing the window hides it to the tray.

## The app doesn't open
- Run it from a terminal (`tuxwell-gui`) to see any error. A bad value in the settings file can't stop it any more (it falls back to the default), but a
  missing GTK/libadwaita install can: it needs `python3-gobject` and `libadwaita`.

## Undo everything
`./install.sh --uninstall` removes the commands, service, launcher and icons. Your settings and downloaded head responses are kept.
