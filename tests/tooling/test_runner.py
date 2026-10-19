"""Regression tests for the verifier: a broken Godot process must never go green."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

root = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("ballarena_test_runner", root / "tools/run_tests.py")
runner = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = runner
spec.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def test_nonzero_exit_cannot_pass(self):
        self.assertFalse(runner.evaluate(1, "PASS")[0])

    def test_errors_and_failures_override_pass(self):
        for message in ["ERROR: invalid", "SCRIPT ERROR: freed object", "FAIL", "Assertion failed",
                        "ObjectDB instances leaked at exit", "resources still in use"]:
            with self.subTest(message=message):
                self.assertFalse(runner.evaluate(0, "PASS\n" + message)[0])

    def test_early_exit_requires_a_complete_test(self):
        self.assertFalse(runner.evaluate(0, "Godot engine started")[0])
        self.assertTrue(runner.evaluate(0, "Tests: PASS")[0])
        self.assertTrue(runner.evaluate(0, "import complete", require_pass=False)[0])

    def test_old_pass_log_is_not_reused(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "godot.log"
            log.write_text("Old successful test: PASS", encoding="utf-8")
            process = subprocess.CompletedProcess([], 0, b"", b"")
            with patch.object(runner.subprocess, "run", return_value=process):
                result = runner.execute("godot", root, [], log, 1)
            self.assertFalse(result["ok"])

    def test_log_options_precede_user_arguments(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "file with spaces.log"
            process = subprocess.CompletedProcess([], 0, b"PASS", b"")
            with patch.object(runner.subprocess, "run", return_value=process) as execute:
                result = runner.execute("godot", root, ["--script", "res://tests/test.gd"], log, 1,
                                        user_arguments=["image with spaces.png", "vampire"])
            self.assertTrue(result["ok"])
            arguments = execute.call_args.args[0]
            self.assertLess(arguments.index("--log-file"), arguments.index("--"))
            self.assertEqual(arguments[arguments.index("--") + 1:], ["image with spaces.png", "vampire"])
            self.assertNotIn("shell", execute.call_args.kwargs)

    def test_timeouts_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(runner.subprocess, "run", side_effect=subprocess.TimeoutExpired("godot", 1)):
                result = runner.execute("godot", root, [], Path(directory) / "log", 1)
            self.assertFalse(result["ok"])
            self.assertIn("timeout", result["reason"])

    def test_gpu_death_tests_are_not_headless_cases(self):
        headless = runner.discover(root, "headless")
        graphics = runner.discover(root, "graphics")
        self.assertTrue(headless)
        self.assertTrue(all(not case.graphics for case in headless))
        self.assertTrue(all(case.graphics for case in graphics))
        self.assertEqual(len([case for case in graphics if case.name.startswith("death_fragments_")]), 5)


if __name__ == "__main__":
    unittest.main()
