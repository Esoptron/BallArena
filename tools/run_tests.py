#!/usr/bin/env python3
"""Run Godot integration tests with explicit renderer requirements and strict results.

No third-party Python packages are required. All logs/captures stay in builds/qa.
"""
from __future__ import annotations

import argparse
import concurrent.futures
from dataclasses import dataclass
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR_PATTERN = re.compile(
    r"SCRIPT ERROR:|\bERROR:|\bFAIL\b|Assertion failed|ObjectDB instances leaked|resources still in use"
)
PASS_PATTERN = re.compile(r"\bPASS\b")


@dataclass(frozen=True)
class TestCase:
    name: str
    script: Path
    graphics: bool = False
    arguments: tuple[str, ...] = ()


def discover(root: Path, suite: str) -> list[TestCase]:
    cases: list[TestCase] = []
    for script in sorted((root / "tests").glob("*_test.gd")):
        graphics = script.name.startswith("render_") or script.stem == "death_fragments_test"
        if suite == "headless" and graphics or suite == "graphics" and not graphics:
            continue
        if script.stem == "death_fragments_test":
            for hero in ("swordsman", "vampire", "knifeman", "katana", "club"):
                cases.append(TestCase(f"death_fragments_{hero}", script, True, ("{png}", hero)))
        else:
            arguments: tuple[str, ...] = ()
            if graphics:
                arguments = ("{directory}",) if script.stem == "render_vampire_test" else ("{png}",)
                if script.stem == "render_combat_effects_test":
                    arguments += ("{cooldown}",)
            cases.append(TestCase(script.stem, script, graphics, arguments))
            if script.stem == "render_runoff_test":
                cases.append(TestCase("render_runoff_fade", script, True, ("{png}", "fade")))
    return cases


def evaluate(returncode: int, output: str, require_pass: bool = True) -> tuple[bool, str]:
    if returncode != 0:
        return False, f"exit code {returncode}"
    if ERROR_PATTERN.search(output):
        return False, "Godot reported an error, assertion or leaked objects"
    if require_pass and not PASS_PATTERN.search(output):
        return False, "missing PASS marker (early exit or frame limit reached)"
    return True, ""


def execute(
    engine: str, root: Path, command: list[str], log: Path, timeout: float,
    require_pass: bool = True, user_arguments: list[str] | None = None,
) -> dict:
    started = time.monotonic()
    kwargs = {"creationflags": subprocess.CREATE_NO_WINDOW} if os.name == "nt" else {}
    arguments = [engine, "--path", str(root), *command, "--log-file", str(log)]
    if user_arguments:
        arguments += ["--", *user_arguments]
    try:
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text("", encoding="utf-8")
        result = subprocess.run(
            arguments,
            cwd=root, capture_output=True, timeout=timeout, **kwargs,
        )
        # The process output and Godot log cover different early-start failures.
        output = result.stdout.decode("utf-8", errors="replace") + result.stderr.decode("utf-8", errors="replace")
        if log.exists():
            output += "\n" + log.read_text(encoding="utf-8", errors="replace")
        passed, reason = evaluate(result.returncode, output, require_pass)
        return {"ok": passed, "reason": reason, "exit_code": result.returncode,
                "seconds": round(time.monotonic() - started, 3), "log": str(log),
                "details": output[-8000:] if not passed else ""}
    except subprocess.TimeoutExpired:
        # subprocess.run kills and waits for its own child on timeout.
        return {"ok": False, "reason": f"timeout after {timeout:g}s", "log": str(log)}
    except OSError as error:
        return {"ok": False, "reason": str(error), "log": str(log)}


def run_case(engine: str, root: Path, case: TestCase, output: Path, timeout: float) -> dict:
    directory = output / case.name
    directory.mkdir(parents=True, exist_ok=True)
    substitutions = {"directory": str(directory), "png": str(directory / "capture.png"),
                     "cooldown": str(directory / "cooldown.png")}
    command = ["--max-fps", "60"] if case.graphics else ["--headless", "--fixed-fps", "240"]
    command += ["--script", "res://" + case.script.relative_to(root).as_posix(), "--quit-after", "100000"]
    arguments = [argument.format(**substitutions) for argument in case.arguments]
    # --log-file must precede --, which belongs to the test's user arguments.
    log = directory / "godot.log"
    result = execute(engine, root, command, log, timeout, user_arguments=arguments)
    result.update({"name": case.name, "graphics": case.graphics})
    print(f"{case.name}: {'PASS' if result['ok'] else 'FAIL — ' + result['reason']}", flush=True)
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN") or shutil.which("godot") or shutil.which("godot4"))
    parser.add_argument("--suite", choices=("headless", "graphics", "all"), default="headless")
    parser.add_argument("--test", action="append", help="Run an exact discovered case name; repeat to select several.")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--jobs", type=int, default=1, help="Concurrent headless processes; graphics remain sequential.")
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument("--output", type=Path, default=ROOT / "builds" / "qa")
    parser.add_argument("--skip-import", action="store_true", help="Only if this checkout has already been imported.")
    args = parser.parse_args()
    if args.jobs < 1 or args.jobs > 16 or not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--jobs must be 1..16 and --timeout must be positive")
    cases = discover(ROOT, args.suite)
    if args.test:
        requested = set(args.test)
        unknown = requested - {case.name for case in cases}
        if unknown:
            parser.error("Unknown case(s) in this suite: " + ", ".join(sorted(unknown)))
        cases = [case for case in cases if case.name in requested]
    if not cases:
        parser.error("No tests discovered")
    if args.list:
        for case in cases:
            print(f"{case.name} ({'graphics' if case.graphics else 'headless'})")
        return 0
    if not args.godot:
        parser.error("Godot not found. Pass --godot or set GODOT_BIN.")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if not args.skip_import:
        imported = execute(args.godot, ROOT, ["--headless", "--editor", "--import"], output / "import.log", args.timeout, False)
        if not imported["ok"]:
            print("Import: FAIL — " + imported["reason"])
            print(imported.get("details", ""))
            return 1
    headless = [case for case in cases if not case.graphics]
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(lambda case: run_case(args.godot, ROOT, case, output, args.timeout), headless))
    results += [run_case(args.godot, ROOT, case, output, args.timeout) for case in cases if case.graphics]
    summary = {"passed": sum(result["ok"] for result in results), "total": len(results), "results": results}
    (output / "results.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n{summary['passed']}/{summary['total']} passed. Report: {output / 'results.json'}")
    for result in results:
        if not result["ok"]:
            print(f"\n{result['name']}: {result.get('details', result['reason'])}")
    return 0 if summary["passed"] == summary["total"] else 1


if __name__ == "__main__":
    sys.exit(main())
