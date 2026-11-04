# How Tuxwell works

Tuxwell is a small set of cooperating pieces. None of them replaces PipeWire; they configure it, add one virtual output next
to the headset's own, and undo everything when the headset powers off.

## The pieces

| Piece | File | What it does |
|---|---|---|
| **Service** | `bin/tuxwell` | The heart. A bash script run as a systemd *user* service. Watches PipeWire, applies settings when the headset is on, undoes them when it is off, routes apps, and makes the default output follow playback. |
| **Renderer** | `bin/tuxwell-render-surround` | Python (stdlib only). Builds the surround filter-chain config from the template, the chosen head response, the gains and the optional correction. |
| **Template** | `pipewire/tuxwell-surround.conf.in` | The surround graph: 7 spatializers (one per speaker), the bass channel, two mixers, and placeholders the renderer fills in. |
| **Control panel** | `gui/tuxwell-gui` | GTK4 / libadwaita app and tray icon. A front end: it edits the settings file, restarts the service, and talks to the headset. |
| **Head responses** | `bin/tuxwell-hrtf`, `data/hrtf-catalog.tsv` | Lists, downloads (checksum-verified) and switches the 20 SADIE II sets. |
| **Corrections** | `data/eq/` | Parametric EQ profiles for the Maxwell, with credits (`data/eq/README.md`). `tools/fit-eq.py` regenerates the Maxwell 2 ones. |
| **Helpers** | `bin/tuxwell-test-sound`, `bin/tuxwell-report` | The "walk around your head" test sound; a non-personal diagnostics report for bug reports. |
| **HID access** | `udev/70-audeze-maxwell.rules` | Optional: lets your user talk to the headset's HID interface (presets, sidetone, chat mix). |

## The sound path

```
  your apps ──►  Tuxwell Surround (7.1) sink          (only apps in SURROUND_APPS, plus everything while surround is the default)
                          │
                          ▼
      7 spatializers (one per speaker, SADIE II head response) + the bass (LFE) channel
                          │
                          ▼
              mix to two ears ──► [optional] bass shelf + headphone correction (loudness-matched)
                          │
                          ▼
                 the headset's own sink ──► USB dongle ──► headset
```

The surround graph runs as **its own PipeWire client process** (`pipewire -c <config>`), started and stopped by the service.
That is why switching sets, levels or corrections never restarts PipeWire and never interrupts your other audio.

## The service lifecycle (`bin/tuxwell`)

1. **Settings** are loaded from `~/.config/tuxwell/tuxwell.conf`. The file is parsed as data (strict whitelist), never executed.
2. A **check** takes one snapshot of PipeWire (`pactl list short sinks`, `pactl list sink-inputs`, `pactl get-default-sink`) and
   decides what to do. It runs on every relevant event and at least every 5 seconds.
3. **The headset is "on" when a sink named Audeze exists.** The USB dongle stays plugged in when you power the headset off, but its
   audio sink disappears, so that is the signal.
4. On the **off → on** edge it runs `apply`: hardware volume, microphone profile, sample-rate switching, and the surround client.
5. While on, each check **routes** matching apps to the surround sink and lets the **default output follow playback**.
6. On the **on → off** edge (or when stopped) it runs `revert`: stops the surround client, removes its temp config, restores 48 kHz.

Events come from `pactl subscribe`. Bursts are coalesced into one check, and "change" events are included because an app's
properties (its name) can arrive just after its stream is created.

### One volume across two outputs

The surround sink feeds the headset sink, so the two volume stages sit in series and would multiply. Tuxwell keeps them from stacking:
when the default output switches, the output being left **hands its level to the one taking over and returns to 100%**. The volume
keys and the pop-up always show the output in use, and loudness doesn't jump.

## Choices worth knowing about

- **Preset changes use a USB control `SET_REPORT`** (`HIDIOCSOUTPUT`), not a plain `write()` to the hidraw node. On a Maxwell 2 a plain
  write only reaches 4 of the 10 presets. See [PRESETS.md](PRESETS.md).
- **Surround gain 0.27** was measured, not guessed: with that value, centred stereo is as loud through surround as through the stereo output.
- **The bass (LFE) channel is lifted by +10 dB** by default. Measured at the headset, it otherwise arrives about 11 dB *below* a normal
  channel, whereas a cinema plays it about 10 dB *above*. See `LFE_DB` in [SETTINGS.md](SETTINGS.md).
- **The Maxwell 2 correction** is generated from a published measurement with AutoEq's method and only trusts 100 Hz to 14 kHz.
  See [data/eq/README.md](../data/eq/README.md).
- **The renderer's temp file must end in `.conf`**: PipeWire refuses any other name.

## The control panel's threading rule

GTK's main loop must never wait on a subprocess, or the window freezes. Anything that runs `pactl`, `amixer`, `systemctl` or another
program goes through `bg()`, which runs it in a worker thread and hands the result back to the main loop. Status is refreshed by a
background poll every 2 seconds.

## Where things live

| Path | Contents |
|---|---|
| `~/.config/tuxwell/tuxwell.conf` | Settings ([SETTINGS.md](SETTINGS.md)) |
| `~/.local/share/tuxwell/surround.conf.in` | The surround template, rendered at each start |
| `~/.local/share/tuxwell/hrtf/` | Downloaded head responses |
| `~/.local/share/tuxwell/eq/` | Correction profiles and their catalog |
| `$XDG_RUNTIME_DIR/tuxwell-surround.*.conf` | The rendered config the running surround client uses (removed on revert) |
| `~/.local/bin/tuxwell*` | The commands |
| `~/.config/systemd/user/tuxwell.service` | The service unit |
