"""Independent character choices over four real ENet Godot processes."""
import argparse
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--players", type=int, choices=[2, 3, 4], default=4)
parser.add_argument("--script", choices=["release16_coop_test.gd", "release16_rescue_coop_test.gd"], default="release16_coop_test.gd")
args = parser.parse_args()
players = args.players
out = root / "builds" / f"release16-{args.script.removesuffix('.gd')}-{players}"
out.mkdir(parents=True, exist_ok=True)
jobs = []
try:
    for role, tag in [("host", "1")]+[("client", str(i)) for i in range(1, players)]:
        handle = (out / f"{role}-{tag}.log").open("w")
        job = subprocess.Popen(["godot", "--headless", "--path", str(root), "--script", "res://tests/"+args.script, "--", f"--role={role}", f"--tag={tag}", f"--players={players}"], stdout=handle, stderr=subprocess.STDOUT)
        jobs.append((role, tag, job, handle))
        if role == "host":
            time.sleep(.7)
    deadline = time.monotonic()+40
    bad = False
    for role, tag, job, handle in jobs:
        try:
            job.wait(timeout=max(1, deadline-time.monotonic()))
        except subprocess.TimeoutExpired:
            job.terminate(); job.wait(timeout=5); bad = True
        handle.close()
        content = (out / f"{role}-{tag}.log").read_text()
        print(role, tag, "exit", job.returncode)
        for line in content.splitlines():
            if any(word in line for word in ["RESULT:", "FAIL:", "SCRIPT ERROR:", "ERROR:", "ObjectDB"]): print(line)
        bad |= job.returncode != 0 or any(word in content for word in ["FAIL:", "SCRIPT ERROR:", "ERROR:", "ObjectDB"])
    raise SystemExit(1 if bad else 0)
finally:
    for _, _, job, handle in jobs:
        if job.poll() is None:
            job.terminate(); job.wait(timeout=5)
        handle.close()
