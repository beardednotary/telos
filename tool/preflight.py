"""Portable validation step for the existing Codemagic workflow editor.

Runs no build-number changes, signing, uploads, or releases.
"""

from pathlib import Path
import shutil
import subprocess
import sys

from verify_ios import verify


root = Path(__file__).resolve().parents[1]
verify()
flutter = shutil.which("flutter")
if flutter is None:
    sys.exit("Flutter is not on PATH; use Codemagic's configured Flutter SDK.")
commands = [
    [flutter, "--version"],
    [flutter, "pub", "get", "--enforce-lockfile"],
    [flutter, "analyze"],
    [flutter, "test", "--run-skipped", "--exclude-tags", "golden", "--reporter", "expanded"],
]
for command in commands:
    print("Running: " + " ".join(command[1:]), flush=True)
    result = subprocess.run(command, cwd=root, check=False)
    if result.returncode != 0:
        sys.exit(result.returncode)
print("Preflight passed. Continue with the existing signed iOS build and auto-numbering.")
