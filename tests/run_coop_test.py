"""Four real Godot processes and ENet/UDP; no mocked networking."""
from pathlib import Path
import os
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
out = Path(os.environ.get("COOP_LOG_DIR", str(root / "builds" / "coop-test")))
out.mkdir(parents=True, exist_ok=True)
processes = []
handles = []
try:
    for role, args in [("host", []), ("client1", ["--", "--tag=1"]), ("client2", ["--", "--tag=2"]), ("client3", ["--", "--tag=3"])]:
        script = "coop_host_test.gd" if role == "host" else "coop_client_test.gd"
        handle = (out / (role + ".log")).open("w")
        handles.append(handle)
        processes.append(subprocess.Popen(["godot", "--headless", "--path", str(root), "--script", "res://tests/" + script, *args], stdout=handle, stderr=subprocess.STDOUT))
        if role == "host":
            time.sleep(0.7)
    deadline = time.monotonic() + 45
    for process in processes:
        process.wait(timeout=max(1, deadline-time.monotonic()))
    for handle in handles:
        handle.close()
    bad = False
    for name, process in zip(["host", "client1", "client2", "client3"], processes):
        content = (out / (name + ".log")).read_text()
        print(name, "exit", process.returncode)
        for line in content.splitlines():
            if any(word in line for word in ["RESULT:", "FAIL:", "SCRIPT ERROR:", "ERROR:", "WARNING: ObjectDB"]):
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
