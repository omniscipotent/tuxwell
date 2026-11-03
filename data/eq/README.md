# Headphone corrections

Virtual surround assumes neutral headphones. These parametric EQ profiles correct the Maxwell's own sound towards a target so that
surround is more accurate (and, with the Harman option, a little more flattering).

## Maxwell 2 (what Tuxwell recommends if you have one)
`maxwell2-neutral.txt` and `maxwell2-harman.txt` were **generated** from a published measurement of the Maxwell 2:
[SoundGuys' B&K 5128 frequency-response chart](https://www.soundguys.com/product/audeze-maxwell-2/) (ANC off), fitted with the
[AutoEq](https://github.com/jaakkopasanen/AutoEq) method (MIT, see `LICENSE-AutoEq`) to its *Diffuse field 5128* and *Harman over-ear 2018*
targets. The raw measurement is not redistributed, only the resulting filters. `tools/fit-eq.py` reproduces them.

- The fit only trusts **100 Hz to 14 kHz** (fully from 300 Hz to 9 kHz). Bass depends on fit and seal and the trace may predate
  a bass firmware update, and the extreme top end is a measuring-rig artefact, so both are left alone.
- Against the neutral target the Maxwell 2 needed only about **1.5 dB RMS** of correction over 150 Hz to 12 kHz, and the filters capture it
  to within about 0.2 dB. That agrees with independent reviews calling it accurate out of the box. Expect a *gentle* change.
- It is **one measurement of one unit**, and assumes the headset is on its default *Audeze* sound preset. Trust your ears.

## Original Maxwell
The `maxwell1-*` profiles come from AutoEq (commit `7ae0f56d5307`, files unchanged) and are for the **original Maxwell**:

| File | AutoEq source |
|---|---|
| `maxwell1-audeze.txt` | `results/Kuulokenurkka/over-ear/Audeze Maxwell (Audeze preset)/Audeze Maxwell (Audeze preset) ParametricEQ.txt` |
| `maxwell1-immersive.txt` | `results/Kuulokenurkka/over-ear/Audeze Maxwell (immersive preset)/Audeze Maxwell (immersive preset) ParametricEQ.txt` |
| `maxwell1-footsteps.txt` | `results/Kuulokenurkka/over-ear/Audeze Maxwell (footsteps preset)/Audeze Maxwell (footsteps preset) ParametricEQ.txt` |
| `maxwell1-bass-boost.txt` | `results/Kuulokenurkka/over-ear/Audeze Maxwell (bass boost preset)/Audeze Maxwell (bass boost preset) ParametricEQ.txt` |
| `maxwell1-competition.txt` | `results/Kuulokenurkka/over-ear/Audeze Maxwell (competition preset)/Audeze Maxwell (competition preset) ParametricEQ.txt` |
| `maxwell1-treble-boost.txt` | `results/Kuulokenurkka/over-ear/Audeze Maxwell (treble boost preset)/Audeze Maxwell (treble boost preset) ParametricEQ.txt` |
| `maxwell1-rtings.txt` | `results/Rtings/Bruel & Kjaer 5128 over-ear/Audeze Maxwell/Audeze Maxwell ParametricEQ.txt` |

Measurements by the Kuulokenurkka reviewer (one per sound preset) and Rtings (B&K 5128). **They do not agree with the Maxwell 2 data**
(the shapes are essentially uncorrelated), so don't use them on a Maxwell 2.
