#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import time

force = "--force" in sys.argv or "--test" in sys.argv
lockfile = "/tmp/qs-autostart.lock"

if not force:
    if os.path.exists(lockfile):
        sys.exit(0)
    try:
        with open(lockfile, "w") as lf:
            lf.write(str(os.getpid()))
    except Exception:
        pass

config_path = os.path.expanduser("~/.config/illogical-impulse/config.json")
if not os.path.exists(config_path):
    sys.exit(0)

try:
    with open(config_path) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

autostart = data.get("hyprland", {}).get("autostartApps", {})
if not force and not autostart.get("enable", False):
    sys.exit(0)

for app in autostart.get("apps", []):
    cmd = app.get("cmd", "").strip()
    workspace = app.get("workspace", 1)
    delay = app.get("delay", 0)
    if not cmd:
        continue

    expanded_cmd = os.path.expanduser(cmd)
    escaped_cmd = expanded_cmd.replace("\\", "\\\\").replace('"', '\\"')

    # Com UWSM, o app roda na própria unidade systemd (fora do processo do Hyprland)
    if shutil.which("uwsm"):
        escaped_cmd = f"uwsm app -- {escaped_cmd}"

    # Switch workspace and execute application via Hyprland Lua dispatchers
    subprocess.run(["hyprctl", "dispatch", f"hl.dsp.focus({{ workspace = {workspace} }})"], capture_output=True)
    subprocess.Popen(
        ["hyprctl", "dispatch", f'hl.dsp.exec_cmd("{escaped_cmd}")'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True
    )

    if delay > 0:
        time.sleep(delay)