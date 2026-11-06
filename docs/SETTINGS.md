# Settings

Tuxwell reads `~/.config/tuxwell/tuxwell.conf`, a plain list of `KEY=value` lines. Most settings can be changed in the app; the app
writes this file and restarts the service. You can also edit it by hand and run `systemctl --user restart tuxwell`.

- Values are checked. **A missing or invalid value falls back to its default**, so a typo can never stop Tuxwell starting.
- Spaces around a value, quotes, and Windows line endings are tolerated. Lines starting with `#` and unknown keys are ignored.
- The file is read as data and never executed.

| Key | Default | Range / values | Meaning |
|---|---|---|---|
| `HW_VOLUME` | `86` | 0 to 96 | The dongle's own gain; 1 step = 1 dB, 96 = loudest. Its idle level (about -20 dB) is why the headset feels quiet. |
| `HIRES` | `1` | `0` / `1` | Let PipeWire switch the dongle between 48 and 96 kHz to match what plays. It only switches when nothing else plays at the old rate. |
| `DISABLE_MIC` | `1` | `0` / `1` | Playback-only card profile, so the headset microphone never appears as an input. |
| `SURROUND_ENABLED` | `1` | `0` / `1` | Create the virtual 7.1 surround output. |
| `SURROUND_GAIN` | `0.27` | above 0 to 1.5 | Per-speaker level of the surround mix. 0.27 was measured to match stereo loudness for centred stereo. The app's slider goes from 0.10 to 0.60. |
| `CENTER_DB` | `3` | 0 to 9 | Extra dB on the centre channel, so 5.1 dialogue matches a stereo downmix. |
| `LFE_DB` | `10` | 0 to 24 | Lift for the dedicated bass (LFE) channel of 5.1/7.1 content. A cinema plays it about 10 dB above the other channels. |
| `BASS_DB` | `0` | 0 to 12 | Extra bass on everything in surround (a low shelf at 105 Hz). |
| `HRTF` | `D1_48K_24bit_256tap_FIR_SOFA.sofa` | a `.sofa` file name | The head response in use. Change it with `tuxwell-hrtf use <id>` or in the app (never a path). |
| `EQ` | `off` | `off` or a profile id | Headphone correction for the surround output, e.g. `maxwell2-neutral`. Ids are in `data/eq/catalog.tsv`. |
| `SURROUND_APPS` | `tv.plex.PlexHTPC\|Plex HTPC\|nl.g4d.Girens` | letters, digits, space `.` `_` `\|` `-` | A regex matched against each audio stream's properties. Matching apps are played through surround. |
| `AUTO_DEFAULT` | `1` | `0` / `1` | Make the default output follow playback: surround while the player plays, stereo when it pauses. |
| `PLAYING_APPS` | `plex-bin\|nl.g4d.Girens` | same characters as `SURROUND_APPS` | Regex for the player's *own* stream. Its menu/UI sounds must not count as playing. |
| `CTL_PATH` | *(empty)* | a file path | App only: where audezeforlinux's `maxwell_ctl.py` is, for the Headset tab. Empty means the default folder. |

## Finding an app's identifiers

Play something in the app, then run `pactl list sink-inputs`. The `application.name`, `application.process.binary` or Flatpak id shown
there is what `SURROUND_APPS` (and `PLAYING_APPS`) can match, for example:

```
SURROUND_APPS='tv.plex.PlexHTPC|Plex HTPC|steam_app'
```

## Examples

More punch in movies, a little more bass in everything:

```
LFE_DB=14
BASS_DB=3
```

Use a different head response and turn the correction on:

```
HRTF=H5_48K_24bit_256tap_FIR_SOFA.sofa
EQ=maxwell2-neutral
```
