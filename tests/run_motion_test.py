"""Two real ENet processes; regress the 30-FPS guest movement failure."""
from pathlib import Path
import os
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
out = Path(os.environ.get("MOTION_LOG_DIR", str(root / "builds" / "motion-test")))
out.mkdir(parents=True, exist_ok=True)
processes = []
handles = []
try:
    for role in ["host", "client"]:
        handle = (out / (role + ".log")).open("w")
        handles.append(handle)
        processes.append(subprocess.Popen(["godot", "--headless", "--path", str(root), "--script", "res://tests/motion_" + role + "_test.gd"], stdout=handle, stderr=subprocess.STDOUT))
        if role == "host":
            time.sleep(0.7)
    deadline = time.monotonic() + 35
    bad = False
    for process in processes:
        try:
            process.wait(timeout=max(1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            bad = True
            for pending in processes:
                if pending.poll() is None:
                    pending.terminate()
                    pending.wait(timeout=5)
            break
    for handle in handles:
        handle.close()
    for role, process in zip(["host", "client"], processes):
        content = (out / (role + ".log")).read_text()
        print(role, "exit", process.returncode)
        for line in content.splitlines():
            if any(word in line for word in ["RESULT:", "METRICS:", "FAIL:", "SCRIPT ERROR:", "ERROR:", "WARNING: ObjectDB"]):
                print(line)
        bad |= process.returncode != 0 or any(word in content for word in ["FAIL:", "SCRIPT ERROR:", "ERROR:", "WARNING: ObjectDB"])
    sys.exit(1 if bad else 0)
finally:
    for process in processes:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
    for handle in handles:
        if not handle.closed:
            handle.close()
