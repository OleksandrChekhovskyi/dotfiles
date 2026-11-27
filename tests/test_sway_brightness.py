"""Test Sway's DDC brightness helper without touching real monitors."""

import io
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "home.linux/.local/bin/sway-brightness"
HELPER = runpy.run_path(str(SCRIPT))
BUS = ("--bus", "9", "--skip-ddc-checks")
EDID = ("--edid", "test-edid")


def reply(stdout="", stderr="", status=0):
    return subprocess.CompletedProcess([], status, stdout, stderr)


class BrightnessTest(unittest.TestCase):
    def setUp(self):
        self.run_ddc = self.enterContext(patch("subprocess.run"))
        self.clock = self.enterContext(patch("time.monotonic", return_value=100))
        self.state = io.StringIO()
        self.addCleanup(self.state.close)

    def press(self, direction):
        self.state.seek(0)
        HELPER["brightness"](self.state, [BUS, EDID], direction)

    def commands(self):
        return [call.args[0][2:] for call in self.run_ddc.call_args_list]

    def test_burst_reads_once_then_reads_again_after_idle(self):
        self.run_ddc.side_effect = [reply("VCP 10 C 50 100"), reply(), reply(),
                                    reply("VCP 10 C 80 100"), reply()]
        self.press(1)
        self.clock.return_value = 103
        self.press(-1)
        self.clock.return_value = 108
        self.press(1)
        self.assertEqual(self.commands(), [
            [*BUS, "getvcp", "10"], [*BUS, "--noverify", "setvcp", "10", "55"],
            [*BUS, "--noverify", "setvcp", "10", "50"],
            [*BUS, "getvcp", "10"], [*BUS, "--noverify", "setvcp", "10", "85"],
        ])

    def test_bus_failure_falls_back_to_edid_and_clamps_to_monitor_max(self):
        self.run_ddc.side_effect = [reply(status=1), reply("VCP 10 C 196 200"),
                                    reply(status=1), reply()]
        self.press(1)
        self.assertEqual(self.commands(), [
            [*BUS, "getvcp", "10"], [*EDID, "getvcp", "10"],
            [*BUS, "--noverify", "setvcp", "10", "200"],
            [*EDID, "--noverify", "setvcp", "10", "200"],
        ])

    def test_failed_write_invalidates_cached_value(self):
        self.state.write("99 50 100\n")
        self.run_ddc.return_value = reply(stderr="DDC failed", status=1)
        with self.assertRaisesRegex(RuntimeError, "DDC failed"):
            self.press(1)
        self.assertEqual(self.state.getvalue(), "")

    def test_connector_prefers_aux_adapter_over_ddc_link(self):
        with tempfile.TemporaryDirectory() as root:
            connector = Path(root)
            (connector / "ddc").symlink_to("/sys/devices/i2c-4")
            self.assertEqual(HELPER["ddc_bus"](connector), "4")
            (connector / "i2c-9").mkdir()
            self.assertEqual(HELPER["ddc_bus"](connector), "9")
