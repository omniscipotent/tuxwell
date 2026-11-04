"""Tests for bin/tuxwell-render-surround. Run: python3 -m unittest discover -s tests"""
import importlib.machinery, importlib.util, os, subprocess, sys, tempfile, unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RENDER = os.path.join(ROOT, "bin", "tuxwell-render-surround")
TEMPLATE = os.path.join(ROOT, "pipewire", "tuxwell-surround.conf.in")
EQ = os.path.join(ROOT, "data", "eq", "maxwell2-neutral.txt")
_l = importlib.machinery.SourceFileLoader("render", RENDER)
_spec = importlib.util.spec_from_loader("render", _l)
R = importlib.util.module_from_spec(_spec)
_l.exec_module(R)


def render(*extra):
    cmd = [sys.executable, RENDER, "--template", TEMPLATE, "--hrtf", "/x/h.sofa", "--gain", "0.3",
           "--center-db", "3", "--target", "sink.test", *extra]
    p = subprocess.run(cmd, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


class Render(unittest.TestCase):
    def test_plain(self):
        rc, out, _ = render()
        self.assertEqual(rc, 0)
        self.assertNotRegex(out, r"@[A-Z_]+@")
        self.assertIn('outputs = [ "mixL:Out" "mixR:Out" ]', out)
        self.assertEqual(out.count('filename = "/x/h.sofa"'), 7)
        self.assertEqual(out.count("gain = 0.3 "), 6)            # six speakers at the base gain
        self.assertIn("gain = 0.4238", out)                       # the centre is +3 dB
        self.assertIn("label = copy  name = inLFE", out)          # untouched bass channel

    def test_lfe_boost(self):
        rc, out, _ = render("--lfe-db", "10")
        self.assertEqual(rc, 0)
        self.assertIn('name = inLFE control = { "Mult" = 3.1623', out)

    def test_lfe_requires_node(self):
        with tempfile.NamedTemporaryFile("w", suffix=".in") as t:
            t.write("outputs = [ \"@OUT_L@\" \"@OUT_R@\" ]\n@EQ_NODES@\n@EQ_LINKS@\n")
            t.flush()
            p = subprocess.run([sys.executable, RENDER, "--template", t.name, "--hrtf", "h", "--gain", "1", "--target", "t", "--lfe-db", "6"],
                               capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0)

    def test_correction_chain(self):
        rc, out, err = render("--eq", EQ)
        self.assertEqual(rc, 0)
        n = len(R.parse_profile(EQ))
        self.assertEqual(out.count("label = bq_"), 2 * n)         # same filters on both ears
        self.assertIn('outputs = [ "eqL%d:Out" "eqR%d:Out" ]' % (n, n), out)
        self.assertIn("level offset", err)

    def test_bass_only(self):
        rc, out, _ = render("--bass-db", "4")
        self.assertEqual(rc, 0)
        self.assertEqual(out.count("label = bq_lowshelf"), 2)
        self.assertIn('outputs = [ "eqL1:Out" "eqR1:Out" ]', out)

    def test_no_placeholders_ever_left(self):
        for extra in ([], ["--eq", EQ], ["--bass-db", "3", "--lfe-db", "12", "--eq", EQ]):
            self.assertNotRegex(render(*extra)[1], r"@[A-Z_]+@")


class Profile(unittest.TestCase):
    def test_parse_formats(self):
        with tempfile.NamedTemporaryFile("w", suffix=".txt") as t:
            t.write("# comment\nPreamp: -4.3 dB\nFilter 1: ON LSC Fc 105 Hz Gain -2.2 dB Q 0.70\n"
                    "Filter 2: ON PK Fc 3913 Hz Gain 4.4 dB Q 1.82\nFilter 3: OFF PK Fc 500 Hz Gain 9 dB Q 1\n"
                    "Filter 4: ON HS Fc 10000 Hz Gain -0.0 dB Q 0.70\nnonsense line\n")
            t.flush()
            f = R.parse_profile(t.name)
        self.assertEqual([x[0] for x in f], ["bq_lowshelf", "bq_peaking", "bq_highshelf"])   # OFF filters are skipped

    def test_flat_profile_changes_nothing(self):
        mk, peak = R.makeup_db([("bq_peaking", 1000.0, 0.0, 1.0)])
        self.assertAlmostEqual(mk, 0.0, places=3)
        self.assertAlmostEqual(peak, 0.0, places=3)

    def test_boost_raises_peak(self):
        _, peak = R.makeup_db([("bq_peaking", 3000.0, 6.0, 1.0)])
        self.assertGreater(peak, 5.5)


if __name__ == "__main__":
    unittest.main()
