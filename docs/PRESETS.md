# Selecting presets on the Maxwell 2

Presets are selected with HID output report ID 6 carrying the RACE frame `05 5A 05 00 00 09 00 00 <N>`:

| N | Preset | N | Preset |
|---|---|---|---|
| 1 | Audeze | 6 | Footsteps |
| 2 | Treble Boost | 7 | EQ 1 (custom slot) |
| 3 | Bass Boost | 8 | EQ 2 |
| 4 | Immersive | 9 | EQ 3 |
| 5 | Competition | 10 | EQ 4 |

Full report (62 bytes, zero padded): `06 09 80 05 5a 05 00 00 09 00 00 <N> 00 ...`

## The gotcha

The same bytes behave differently depending on how they reach the device (tested on a Maxwell 2, Xbox dongle `3329:4b28`,
firmware v1.0.5.7):

- **Plain `write()` to `/dev/hidrawN`** (what other Linux tools use): N = 1..4 selects EQ 1..4, N = 5..10 is ignored.
  Built-in presets cannot be reached.
- **Control `SET_REPORT` (`HIDIOCSOUTPUT`)**: N = 1..10 selects the preset named above.

maxwell-linux uses the second method.
Reading the active preset (`05 5A 04 00 01 09 00 00`) returns the same 1..10 numbering.

Note: do not experiment with other values for this setting. Out-of-range values can power the headset off.
