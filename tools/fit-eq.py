#!/usr/bin/env python3
"""Reproduce the Maxwell 2 correction profiles from a frequency-response CSV (columns: frequency,raw).

Needs the AutoEq package and numpy/pandas (pip install autoeq). Fetch the targets from AutoEq's targets/ folder
(e.g. "Diffuse field 5128.csv", "Harman over-ear 2018.csv"). Example:
  python3 tools/fit-eq.py maxwell2.csv "Diffuse field 5128.csv" out.txt
Only 100 Hz-14 kHz is trusted (see data/eq/README.md); bass and the extreme top end are left alone.
"""
import sys
import numpy as np
import pandas as pd
from autoeq import constants as C
from autoeq.frequency_response import FrequencyResponse


def load(path, name):
    d = pd.read_csv(path)
    return FrequencyResponse(name=name, frequency=d["frequency"].values, raw=d["raw"].values)


def ramp(f, lo0, lo1, hi0, hi1):
    """0 below lo0, rising (log scale) to 1 at lo1, 1 until hi0, falling to 0 at hi1."""
    lf = np.log(f)
    w = np.where(f <= lo0, 0, np.where(f < lo1, (lf - np.log(lo0)) / (np.log(lo1) - np.log(lo0)), 1.0))
    return w * np.where(f >= hi1, 0, np.where(f > hi0, 1 - (lf - np.log(hi0)) / (np.log(hi1) - np.log(hi0)), 1.0))


def main(measurement, target, out, n_peaking=8):
    fr = load(measurement, "headphone"); fr.interpolate(); fr.center()
    tgt = load(target, "target"); tgt.interpolate(); tgt.center()
    fr.process(compensation=tgt, min_mean_error=True, fs=48000, max_gain=6.0,
               bass_boost_gain=0.0, bass_boost_fc=C.DEFAULT_BASS_BOOST_FC, bass_boost_q=C.DEFAULT_BASS_BOOST_Q,
               treble_boost_gain=0.0, treble_boost_fc=C.DEFAULT_TREBLE_BOOST_FC, treble_boost_q=C.DEFAULT_TREBLE_BOOST_Q,
               window_size=C.DEFAULT_SMOOTHING_WINDOW_SIZE, treble_window_size=C.DEFAULT_TREBLE_SMOOTHING_WINDOW_SIZE,
               treble_f_lower=C.DEFAULT_TREBLE_F_LOWER, treble_f_upper=C.DEFAULT_TREBLE_F_UPPER, treble_gain_k=C.DEFAULT_TREBLE_GAIN_K)
    fr.equalization = fr.equalization * ramp(fr.frequency, 100.0, 300.0, 9000.0, 14000.0)
    filters = [{"type": "HIGH_SHELF", "fc": 10000, "q": 0.7}] + [{"type": "PEAKING", "min_fc": 150, "max_fc": 12000}] * n_peaking
    peqs = fr.optimize_parametric_eq({"optimizer": {"min_std": 0.008}, "filters": filters}, 48000, preamp=0.0)
    fr.write_eqapo_parametric_eq(out, peqs)
    m = (fr.frequency >= 150) & (fr.frequency <= 12000)
    err = np.sqrt(np.mean((fr.equalization[m] - fr.parametric_eq[m]) ** 2))
    print(f"wrote {out}; remaining error {err:.2f} dB RMS over 150 Hz-12 kHz")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:4])
