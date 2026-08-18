"""Interactive probe: does pi's TUI editor actually enter and honour vim normal mode?

The RPC smoke regulator (modules/checks/pi-agent-environment.nix) proves pi-vim
loads without an extension_error, which is a load claim rather than a behaviour
claim: pi-vim registers no slash command, so nothing in the RPC surface observes
whether `ctx.ui.setEditorComponent` produced a working modal editor. That is only
visible on a real terminal, so this probe allocates a pty, drives one keystroke
sequence, and reads the rendered frames back.

The sequence is `i`, `abc`, Esc, `x`. pi's prompt starts in insert mode, so the
leading `i` is literal text and the buffer reads `iabc`; Esc leaves insert mode
and `x` deletes the character under the cursor. The oracle is the discriminating
difference against a run with pi-vim unregistered:

  with pi-vim     buffer `iab`,  INSERT and NORMAL mode labels rendered
  without pi-vim  buffer `iabcx`, no mode labels

Deliberately not a flake check. Every wait here is a wall-clock sleep against TUI
repaint, which is load-sensitive in a way a build sandbox running other
derivations in parallel would make flaky. Promoting it would mean replacing the
sleeps with a render-settled predicate first.

Usage:
    DRIVE_HOME=<scratch dir> DRIVE_OUT=<transcript path> \
      python3 pi-vim-modal-editing-probe.py <pi executable> <pi-vim store path> \
      [patched|novim]
"""

import json
import os
import pty
import re
import select
import shutil
import sys
import time
from pathlib import Path

PI = sys.argv[1]
VIM = sys.argv[2]
REGISTER_VIM = (sys.argv[3] if len(sys.argv) > 3 else "patched") == "patched"

STARTUP_SETTLE_SECONDS = 6.0
KEYSTROKE_SETTLE_SECONDS = 1.5

home = Path(os.environ["DRIVE_HOME"])
if home.exists():
    shutil.rmtree(home)
agent = home / ".pi" / "agent"
agent.mkdir(parents=True)
(home / "proj").mkdir()
(home / "tmp").mkdir()
(agent / "settings.json").write_text(
    json.dumps({"enableInstallTelemetry": False, "packages": [VIM] if REGISTER_VIM else []})
)
# Offline mode still requires a selectable model for the TUI to reach the prompt.
(agent / "models.json").write_text(
    json.dumps(
        {
            "providers": {
                "smoke-local": {
                    "baseUrl": "http://127.0.0.1:9/v1",
                    "api": "openai-completions",
                    "models": [{"id": "smoke-model"}],
                }
            }
        }
    )
)

env = {
    "HOME": str(home),
    "PI_CODING_AGENT_DIR": str(agent),
    "XDG_CONFIG_HOME": str(home / ".config"),
    "XDG_DATA_HOME": str(home / ".local" / "share"),
    "XDG_CACHE_HOME": str(home / ".cache"),
    "TMPDIR": str(home / "tmp"),
    "PI_OFFLINE": "1",
    "TERM": "xterm-256color",
    "PATH": os.environ["PATH"],
    "COLUMNS": "100",
    "LINES": "30",
}

pid, fd = pty.fork()
if pid == 0:
    os.chdir(str(home / "proj"))
    os.execve(
        PI,
        [PI, "--no-session", "--no-approve", "--model", "smoke-local/smoke-model"],
        env,
    )

frames = b""


def pump(seconds):
    global frames
    deadline = time.time() + seconds
    while time.time() < deadline:
        readable, _, _ = select.select([fd], [], [], 0.2)
        if not readable:
            continue
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            break
        if not chunk:
            break
        frames += chunk


pump(STARTUP_SETTLE_SECONDS)
for keys in (b"iabc", b"\x1b", b"x"):
    os.write(fd, keys)
    pump(KEYSTROKE_SETTLE_SECONDS)
try:
    os.write(fd, b"\x03")
    pump(0.5)
    os.write(fd, b"\x03")
    pump(1.0)
except OSError:
    pass
os.close(fd)
try:
    os.waitpid(pid, 0)
except ChildProcessError:
    pass

transcript = frames.decode("utf-8", "replace")
Path(os.environ["DRIVE_OUT"]).write_text(transcript)
plain = re.sub(
    r"\x1b\[[0-9;?]*[a-zA-Z]|\x1b[\]P][^\x07\x1b]*(\x07|\x1b\\)?|\x1b[()][A-B0-2]", "", transcript
)

observations = {
    "insert_label": "INSERT" in plain,
    "normal_label": "NORMAL" in plain,
    "typed_text_reached_buffer": "iabc" in plain,
    "normal_mode_x_deleted_rather_than_inserted": "iabcx" not in plain,
}
expected = dict.fromkeys(observations, REGISTER_VIM)
expected["typed_text_reached_buffer"] = True

for name, observed in observations.items():
    print(f"{name}={observed} expected={expected[name]}")
if observations != expected:
    raise SystemExit(f"probe oracle violated; transcript at {os.environ['DRIVE_OUT']}")
print("probe=ok")
