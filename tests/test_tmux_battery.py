"""Battery status tests with Linux sysfs and macOS pmset fixtures."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "home/.config/tmux/battery.sh"


class BatteryTest(unittest.TestCase):
    def setUp(self) -> None:
        self.root = Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.sysfs = self.root / "power_supply"
        self.sysfs.mkdir()
        self.script = self.root / "battery.sh"
        self.script.write_text(SCRIPT.read_text().replace(
            "/sys/class/power_supply", str(self.sysfs),
        ))
        self.mock("uname", "printf '%s\\n' Linux\n")

    def mock(self, name: str, body: str) -> None:
        path = self.root / name
        path.write_text(f"#!/bin/sh\n{body}")
        path.chmod(0o755)

    def battery(self, name: str = "BAT0", **values: str | int) -> None:
        path = self.sysfs / name
        path.mkdir()
        for key, value in values.items():
            (path / key).write_text(f"{value}\n")

    def output(self) -> str:
        result = subprocess.run(
            ["sh", str(self.script)], text=True, capture_output=True,
            env=os.environ | {"PATH": f"{self.root}{os.pathsep}{os.environ['PATH']}"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return result.stdout

    def test_no_battery(self) -> None:
        self.assertEqual(self.output(), "")

    def test_linux_states(self) -> None:
        self.battery(type="Battery", capacity=78, status="Charging")
        for state, label in [("Charging", "charging"), ("Discharging", "discharging"),
                             ("Full", "full"), ("Not charging", "plugged in"),
                             ("Unknown", "")]:
            with self.subTest(state=state):
                (self.sysfs / "BAT0/status").write_text(state)
                suffix = " " + label if label else ""
                self.assertEqual(self.output(), f"BAT 78%{suffix}   ")

    def test_linux_multiple_batteries(self) -> None:
        self.battery(type="Battery", capacity=78, status="Discharging")
        self.battery("BAT1", type="Battery", capacity=95, status="Full")
        self.assertEqual(self.output(), "BAT 78% discharging   BAT 95% full   ")

    def test_linux_ignores_peripherals_absent_and_invalid_batteries(self) -> None:
        self.battery("mouse", type="Battery", scope="Device", capacity=80)
        self.battery("AC", type="Mains", capacity=100)
        self.battery("absent", type="Battery", present=0, capacity=0)
        self.battery("missing", type="Battery")
        self.battery("invalid", type="Battery", capacity="bad")
        self.battery("range", type="Battery", capacity=101)
        self.assertEqual(self.output(), "")

    def test_macos_states(self) -> None:
        self.mock("uname", "printf '%s\\n' Darwin\n")
        for state, label in [("charging", "charging"), ("discharging", "discharging"),
                             ("charged", "full"), ("AC attached", "plugged in")]:
            with self.subTest(state=state):
                self.mock("pmset", "cat <<'EOF'\nNow drawing from 'AC Power'\n"
                          f" -InternalBattery-0 (id=123)\t78%; {state}; "
                          "0:42 remaining present: true\nEOF\n")
                self.assertEqual(self.output(), f"BAT 78% {label}   ")

    def test_macos_no_battery(self) -> None:
        self.mock("uname", "printf '%s\\n' Darwin\n")
        self.mock("pmset", "echo \"Now drawing from 'AC Power'\"\n")
        self.assertEqual(self.output(), "")

    def test_unsupported_os(self) -> None:
        self.mock("uname", "printf '%s\\n' FreeBSD\n")
        self.assertEqual(self.output(), "")


if __name__ == "__main__":
    unittest.main()
