"""Tests for the pure logic in gui/tuxwell-gui (settings validation, parsing, the output-switch plan).

The GUI imports GTK at module level. These tests stub it, so they run on machines without GTK (such as CI) and never
open a window. Run: python3 -m unittest discover -s tests
"""
import importlib.machinery, importlib.util, os, sys, tempfile, types, unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_gui(config_home):
    """Import the GUI script with a stubbed `gi` and XDG_CONFIG_HOME pointing at config_home."""
    gi = types.ModuleType("gi")
    gi.require_version = lambda *a, **k: None
    repo = types.ModuleType("gi.repository")
    base = type("Base", (), {})
    repo.Adw = types.SimpleNamespace(ApplicationWindow=base, Application=base)
    repo.Gtk = repo.Gio = repo.GLib = types.SimpleNamespace()
    sys.modules.update({"gi": gi, "gi.repository": repo})
    os.environ["XDG_CONFIG_HOME"] = config_home
    loader = importlib.machinery.SourceFileLoader("tuxwell_gui", os.path.join(ROOT, "gui", "tuxwell-gui"))
    mod = importlib.util.module_from_spec(importlib.util.spec_from_loader("tuxwell_gui", loader))
    loader.exec_module(mod)
    return mod


class Settings(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        os.makedirs(os.path.join(self.dir.name, "tuxwell"))
        self.g = load_gui(self.dir.name)

    def tearDown(self):
        self.dir.cleanup()

    def write(self, text):
        with open(os.path.join(self.dir.name, "tuxwell", "tuxwell.conf"), "w") as fh:
            fh.write(text)

    def test_defaults_when_no_file(self):
        c = self.g.read_conf()
        self.assertEqual((c["HW_VOLUME"], c["LFE_DB"], c["AUTO_DEFAULT"]), ("86", "10", "1"))

    def test_broken_values_fall_back_to_defaults(self):
        self.write("HW_VOLUME=xyz\nLFE_DB=abc\nBASS_DB=\nSURROUND_GAIN=not-a-number\nAUTO_DEFAULT=maybe\nEQ=zzz/../x\nHRTF=a/b.sofa\n")
        c = self.g.read_conf()
        self.assertEqual((c["HW_VOLUME"], c["LFE_DB"], c["BASS_DB"], c["SURROUND_GAIN"], c["AUTO_DEFAULT"], c["EQ"]),
                         ("86", "10", "0", "0.27", "1", "off"))
        self.assertNotIn("HRTF", c)

    def test_out_of_range_values_fall_back(self):
        self.write("HW_VOLUME=999\nLFE_DB=99\nSURROUND_GAIN=9\n")
        c = self.g.read_conf()
        self.assertEqual((c["HW_VOLUME"], c["LFE_DB"], c["SURROUND_GAIN"]), ("86", "10", "0.27"))

    def test_valid_values_and_unknown_keys_are_kept(self):
        self.write("HW_VOLUME=70\nEQ=maxwell2-neutral\nSURROUND_APPS='Plex HTPC|steam_app'\nHRTF=H5_x.sofa\n")
        c = self.g.read_conf()
        self.assertEqual((c["HW_VOLUME"], c["EQ"], c["SURROUND_APPS"], c["HRTF"]), ("70", "maxwell2-neutral", "Plex HTPC|steam_app", "H5_x.sofa"))

    def test_write_then_read_round_trips(self):
        c = self.g.read_conf(); c["SURROUND_APPS"] = "Plex HTPC|x"; c["LFE_DB"] = "12"
        self.g.write_conf(c)
        again = self.g.read_conf()
        self.assertEqual((again["SURROUND_APPS"], again["LFE_DB"]), ("Plex HTPC|x", "12"))


class Helpers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.g = load_gui(cls.tmp.name)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_volume_percent(self):
        out = "Volume: front-left: 49808 /  76% / -7.15 dB,   front-right: 49808 /  76% / -7.15 dB"
        self.assertEqual(self.g.volume_percent(out), 76)
        self.assertIsNone(self.g.volume_percent("nothing here"))

    def test_read_tsv(self):
        with tempfile.NamedTemporaryFile("w", suffix=".tsv") as t:
            t.write("a\tb\tc\n\nd\te\tf\n"); t.flush()
            self.assertEqual(self.g.read_tsv(t.name), [["a", "b", "c"], ["d", "e", "f"]])
        self.assertEqual(self.g.read_tsv("/no/such/file"), [])

    def test_tilde_hides_the_home_folder(self):
        home = os.path.expanduser("~")
        self.assertEqual(self.g.tilde(home + "/.local/x"), "~/.local/x")
        self.assertEqual(self.g.tilde("/etc/x"), "/etc/x")


HEADSET = "alsa_output.usb-Audeze_Maxwell.iec958-stereo"


def block(idx, sink, name, node=None):
    extra = f"\t\tnode.name = \"{node}\"\n" if node else ""
    return f"Sink Input #{idx}\n\tSink: {sink}\n\tProperties:\n\t\tmedia.name = \"{name}\"\n{extra}\n"


class OutputPlan(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.g = load_gui(cls.tmp.name)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def state(self, default):
        return {"sinks": {HEADSET: "7", "tuxwell_surround": "9", "other": "3"}, "headset": HEADSET, "surround": True,
                "default": default, "rate": "48 kHz"}

    def test_to_surround_hands_the_volume_over_and_moves_only_streams_from_the_headset_sink(self):
        inputs = block(1, 7, "Plex") + block(2, 3, "Speakers app") + block(3, 7, "Tuxwell Surround (7.1)") + block(5, 7, "playback", node="tuxwell_surround.output") + block(4, 9, "already")
        cmds = self.g.plan_output_switch(self.state(HEADSET), True, 64, inputs)
        self.assertEqual(cmds, [["pactl", "set-sink-volume", "tuxwell_surround", "64%"],
                                ["pactl", "set-sink-volume", HEADSET, "100%"],
                                ["pactl", "set-default-sink", "tuxwell_surround"],
                                ["pactl", "move-sink-input", "1", "tuxwell_surround"]])   # not #2 (other sink), #3 (the filter's own), #4 (there)

    def test_to_stereo(self):
        cmds = self.g.plan_output_switch(self.state("tuxwell_surround"), False, 58, block(1, 9, "Plex"))
        self.assertEqual(cmds, [["pactl", "set-sink-volume", HEADSET, "58%"], ["pactl", "set-sink-volume", "tuxwell_surround", "100%"],
                                ["pactl", "set-default-sink", HEADSET], ["pactl", "move-sink-input", "1", HEADSET]])

    def test_no_volume_handover_when_already_on_the_target_or_unknown(self):
        self.assertEqual(self.g.plan_output_switch(self.state("tuxwell_surround"), True, 64, "")[0:1], [["pactl", "set-default-sink", "tuxwell_surround"]])
        self.assertEqual(self.g.plan_output_switch(self.state("other"), True, 64, "")[0:1], [["pactl", "set-default-sink", "tuxwell_surround"]])

    def test_unavailable_output_gives_none(self):
        st = self.state(HEADSET); del st["sinks"]["tuxwell_surround"]
        self.assertIsNone(self.g.plan_output_switch(st, True, 64, ""))
        self.assertIsNone(self.g.plan_output_switch({"sinks": {}, "headset": None, "default": ""}, False, None, ""))


if __name__ == "__main__":
    unittest.main()
