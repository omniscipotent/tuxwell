"""Behaviour tests for bin/tuxwell (the background service).

The service is a bash script. It is sourced with TUXWELL_LIB=1 (which stops it from running) and its functions are
called with a fake `pactl`, so no audio system is needed: the fake records every call and answers from canned output.
Run: python3 -m unittest discover -s tests
"""
import os, subprocess, tempfile, textwrap, unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVICE = os.path.join(ROOT, "bin", "tuxwell")

# Canned `pactl` output. Sink 7 is the headset (stereo), sink 9 is the virtual surround sink.
SINKS = "7\talsa_output.usb-Audeze_LLC_Audeze_Maxwell_XBOX_Dongle.iec958-stereo\tPipeWire\ts24le 2ch 48000Hz\tRUNNING\n" \
        "9\ttuxwell_surround\tPipeWire\tfloat32le 8ch 48000Hz\tRUNNING\n"
SINKS_NO_SURROUND = SINKS.splitlines()[0] + "\n"
HEADSET = "alsa_output.usb-Audeze_LLC_Audeze_Maxwell_XBOX_Dongle.iec958-stereo"


def stream(idx, sink, corked, name, binary):
    return textwrap.dedent(f"""\
        Sink Input #{idx}
        \tDriver: PipeWire
        \tSink: {sink}
        \tCorked: {corked}
        \tProperties:
        \t\tapplication.name = "{name}"
        \t\tapplication.process.binary = "{binary}"

        """)


def run_bash(script, conf=None, extra_env=None):
    """Source the service as a library, run `script`, return (stdout, list of recorded pactl calls)."""
    with tempfile.TemporaryDirectory() as d:
        log = os.path.join(d, "calls.log")
        cfg = os.path.join(d, "tuxwell.conf")
        if conf is not None:
            open(cfg, "w").write(conf)
        env = dict(os.environ, TUXWELL_LIB="1", XDG_CONFIG_HOME=d, XDG_DATA_HOME=d, HOME=d)
        os.makedirs(os.path.join(d, "tuxwell"), exist_ok=True)
        if conf is not None:
            os.replace(cfg, os.path.join(d, "tuxwell", "tuxwell.conf"))
        env.update(extra_env or {})
        full = f"source '{SERVICE}'\nCALLS='{log}'\n{script}"
        p = subprocess.run(["bash", "-c", full], capture_output=True, text=True, env=env)
        calls = open(log).read().splitlines() if os.path.exists(log) else []
        return p.stdout + p.stderr, calls


def mock(sinks=SINKS, inputs="", default=HEADSET, volume="76%"):
    """Bash code defining a fake pactl and stating what it reports. ${...!r} becomes a bash $'...' string, so \\t and \\n are real tabs and newlines."""
    return textwrap.dedent(f"""
        pactl() {{
          echo "$*" >> "$CALLS"
          case "${{1:-}} ${{2:-}}" in
            "list short") [ "${{3:-}}" = sinks ] && printf '%s' ${sinks!r} ;;
            "list sink-inputs") printf '%s' ${inputs!r} ;;
            "get-default-sink"*) echo {default} ;;
            "get-sink-volume"*) echo "Volume: front-left: 49808 / {volume} / -7.15 dB,   front-right: 49808 / {volume} / -7.15 dB" ;;
          esac
        }}
    """)


class Settings(unittest.TestCase):
    def load(self, conf):
        out, _ = run_bash('load_settings\nfor v in HW_VOLUME HRTF EQ LFE_DB BASS_DB SURROUND_GAIN AUTO_DEFAULT SURROUND_APPS; do printf "%s=[%s]\\n" "$v" "${!v}"; done', conf)
        return dict(l.split("=", 1) for l in out.splitlines() if "=[" in l)

    def test_good_values(self):
        s = self.load("HW_VOLUME=80\nEQ=maxwell2-neutral\nLFE_DB=14\nBASS_DB=3\nSURROUND_GAIN=0.4\nHRTF=H3_x.sofa\n")
        self.assertEqual((s["HW_VOLUME"], s["EQ"], s["LFE_DB"], s["BASS_DB"], s["SURROUND_GAIN"], s["HRTF"]),
                         ("[80]", "[maxwell2-neutral]", "[14]", "[3]", "[0.4]", "[H3_x.sofa]"))

    def test_out_of_range_and_garbage_keep_defaults(self):
        s = self.load("HW_VOLUME=999\nLFE_DB=99\nBASS_DB=-3\nSURROUND_GAIN=9\nAUTO_DEFAULT=2\nHW_VOLUME=abc\n")
        self.assertEqual((s["HW_VOLUME"], s["LFE_DB"], s["BASS_DB"], s["SURROUND_GAIN"], s["AUTO_DEFAULT"]),
                         ("[86]", "[10]", "[0]", "[0.27]", "[1]"))

    def test_unsafe_values_rejected_and_never_executed(self):
        marker = os.path.join(tempfile.gettempdir(), "tuxwell_test_pwned")
        s = self.load(f"EQ=../../etc/passwd\nHRTF=a/b.sofa\nBASS_DB=2;touch {marker}\nSURROUND_APPS=$(touch {marker})\n")
        self.assertEqual((s["EQ"], s["BASS_DB"]), ("[off]", "[0]"))
        self.assertFalse(os.path.exists(marker))

    def test_whitespace_crlf_and_quotes(self):
        s = self.load("BASS_DB=2   \r\nLFE_DB= 12\r\nEQ=\"maxwell2-harman\"\r\nSURROUND_APPS='Plex HTPC|steam_app'  \r\n")
        self.assertEqual((s["BASS_DB"], s["LFE_DB"], s["EQ"], s["SURROUND_APPS"]), ("[2]", "[12]", "[maxwell2-harman]", "[Plex HTPC|steam_app]"))

    def test_missing_file_keeps_defaults(self):
        self.assertEqual(self.load(None)["HW_VOLUME"], "[86]")


class Routing(unittest.TestCase):
    def route(self, inputs, sinks=SINKS, apps="Plex HTPC"):
        out, calls = run_bash(mock(sinks=sinks, inputs=inputs) + f'\nSURROUND_APPS="{apps}"\nSINKS=$(pactl list short sinks)\nINPUTS=$(pactl list sink-inputs)\nroute_apps')
        return out, [c for c in calls if c.startswith("move-sink-input")]

    def test_moves_matching_stream_off_stereo(self):
        out, moves = self.route(stream(5, 7, "no", "Plex HTPC", "plex-bin"))
        self.assertEqual(moves, ["move-sink-input 5 tuxwell_surround"])
        self.assertIn("moved stream 5", out)

    def test_leaves_stream_already_on_surround(self):
        self.assertEqual(self.route(stream(5, 9, "no", "Plex HTPC", "plex-bin"))[1], [])

    def test_ignores_other_apps(self):
        self.assertEqual(self.route(stream(6, 7, "no", "Firefox", "firefox"))[1], [])

    def test_only_matching_streams_are_moved(self):
        inputs = stream(5, 7, "no", "Plex HTPC", "plex-bin") + stream(6, 7, "no", "Firefox", "firefox") + stream(8, 7, "yes", "Plex HTPC", "QtWebEngineProcess")
        self.assertEqual(self.route(inputs)[1], ["move-sink-input 5 tuxwell_surround", "move-sink-input 8 tuxwell_surround"])

    def test_no_surround_sink_means_no_moves(self):
        self.assertEqual(self.route(stream(5, 7, "no", "Plex HTPC", "plex-bin"), sinks=SINKS_NO_SURROUND)[1], [])

    def test_empty_app_list_disables_routing(self):
        self.assertEqual(self.route(stream(5, 7, "no", "Plex HTPC", "plex-bin"), apps="")[1], [])


class Playing(unittest.TestCase):
    def playing(self, inputs, apps="plex-bin"):
        out, _ = run_bash(mock(inputs=inputs) + f'\nPLAYING_APPS="{apps}"\nINPUTS=$(pactl list sink-inputs)\nis_playing && echo YES || echo NO')
        return out.strip().splitlines()[-1]

    def test_uncorked_player_is_playing(self):
        self.assertEqual(self.playing(stream(5, 9, "no", "Plex HTPC", "plex-bin")), "YES")

    def test_corked_player_is_paused(self):
        self.assertEqual(self.playing(stream(5, 9, "yes", "Plex HTPC", "plex-bin")), "NO")

    def test_menu_sounds_do_not_count(self):
        # Plex's menu stream stays active while the video is paused: only the player's own stream counts.
        inputs = stream(5, 9, "yes", "Plex HTPC", "plex-bin") + stream(6, 9, "no", "Plex HTPC", "QtWebEngineProcess")
        self.assertEqual(self.playing(inputs), "NO")

    def test_no_streams(self):
        self.assertEqual(self.playing(""), "NO")


class FollowPlayback(unittest.TestCase):
    def follow(self, default, inputs, volume="64%", last_play=0, extra=""):
        script = mock(inputs=inputs, default=default, volume=volume) + textwrap.dedent(f"""
            PLAYING_APPS=plex-bin; AUTO_DEFAULT=1; last_play={last_play}
            {extra}
            SINKS=$(pactl list short sinks); INPUTS=$(pactl list sink-inputs); DEFAULT_SINK=$(pactl get-default-sink)
            auto_default
        """)
        out, calls = run_bash(script)
        return out, [c for c in calls if c.startswith(("set-sink-volume", "set-default-sink"))]

    def test_playing_switches_to_surround_and_carries_volume(self):
        _, c = self.follow(HEADSET, stream(5, 9, "no", "Plex HTPC", "plex-bin"))
        self.assertEqual(c, ["set-sink-volume tuxwell_surround 64%", f"set-sink-volume {HEADSET} 100%", "set-default-sink tuxwell_surround"])

    def test_paused_switches_back_to_stereo_and_carries_volume(self):
        _, c = self.follow("tuxwell_surround", stream(5, 9, "yes", "Plex HTPC", "plex-bin"), volume="58%")
        self.assertEqual(c, [f"set-sink-volume {HEADSET} 58%", "set-sink-volume tuxwell_surround 100%", f"set-default-sink {HEADSET}"])

    def test_holds_surround_briefly_after_playback_stops(self):
        # Just stopped (last_play = now): stay on surround so changing episode does not flip the output back and forth.
        _, c = self.follow("tuxwell_surround", "", last_play="$(printf '%(%s)T' -1)")
        self.assertEqual(c, [])

    def test_leaves_a_third_output_alone(self):
        self.assertEqual(self.follow("alsa_output.usb-Scarlett.analog-stereo", stream(5, 9, "no", "Plex HTPC", "plex-bin"))[1], [])

    def test_disabled(self):
        self.assertEqual(self.follow(HEADSET, stream(5, 9, "no", "Plex HTPC", "plex-bin"), extra="AUTO_DEFAULT=0")[1], [])

    def test_already_correct_does_nothing(self):
        self.assertEqual(self.follow("tuxwell_surround", stream(5, 9, "no", "Plex HTPC", "plex-bin"))[1], [])


if __name__ == "__main__":
    unittest.main()
