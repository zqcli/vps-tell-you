"""Host-side orchestrator for the README / wiki screenshots and GIFs.

Runs the scripted tour (integration_test/screenshots_test.dart) with
`flutter drive` on the booted iOS simulator. The tour asks this process over
loopback HTTP to take pixel-real screenshots (`xcrun simctl io screenshot`) or
to start / stop video recording (`simctl io recordVideo`). Raw output goes to
build/shots/<lang>/raw; `finish` (post-processing) is in tool/finish_images.py.

    export PATH=/path/to/flutter/bin:$PATH
    python3 tool/make_screenshots.py --udid <UDID> --lang zh --lang en

See docs/SCREENSHOTS.md for the whole procedure.
"""

import argparse
import contextlib
import os
import signal
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parents[1]
SSH_PORT = 22022
SFTP_ROOT = "/tmp/vps-demo-sftp"


class Capture:
    def __init__(self, udid, raw):
        self.udid = udid
        self.raw = raw
        self.recording = None

    def shot(self, name):
        target = self.raw / f"{name}.png"
        subprocess.run(
            ["xcrun", "simctl", "io", self.udid, "screenshot", "--type=png", str(target)],
            check=True, capture_output=True)
        print(f"  shot {name}", flush=True)

    def rec_start(self, name):
        target = self.raw / f"{name}.mp4"
        target.unlink(missing_ok=True)
        self.recording = subprocess.Popen(
            ["xcrun", "simctl", "io", self.udid, "recordVideo", "--codec=h264",
             "--force", str(target)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1.0)
        print(f"  rec start {name}", flush=True)

    def rec_stop(self):
        if self.recording:
            time.sleep(0.8)
            self.recording.send_signal(signal.SIGINT)
            self.recording.wait(timeout=30)
            self.recording = None
            print("  rec stop", flush=True)


def serve(capture):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            url = urlparse(self.path)
            name = parse_qs(url.query).get("name", [""])[0]
            try:
                if url.path == "/shot":
                    capture.shot(name)
                elif url.path == "/rec/start":
                    capture.rec_start(name)
                elif url.path == "/rec/stop":
                    capture.rec_stop()
                self.send_response(200)
            except Exception as error:  # reported to the tour as a failure
                print("  host error:", error, flush=True)
                self.send_response(500)
            self.end_headers()

        def log_message(self, *args):
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def set_sim_language(udid, lang):
    """Boots the simulator in the language being captured, so the system
    keyboard, dialogs and fonts match the app (zh-Hans-CN or en)."""
    languages = {"zh": ("zh-Hans-CN", "zh_CN"), "en": ("en", "en_US")}[lang]
    current = subprocess.run(
        ["xcrun", "simctl", "spawn", udid, "defaults", "read", ".GlobalPreferences",
         "AppleLocale"], capture_output=True, text=True).stdout.strip()
    if current != languages[1]:
        for key, value in (("AppleLanguages", None), ("AppleLocale", languages[1])):
            command = ["xcrun", "simctl", "spawn", udid, "defaults", "write",
                       ".GlobalPreferences", key]
            command += ["-array", languages[0]] if value is None else [value]
            subprocess.run(command, check=True)
        subprocess.run(["xcrun", "simctl", "shutdown", udid], check=True)
        subprocess.run(["xcrun", "simctl", "boot", udid], check=True)
        subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"],
                       check=True, capture_output=True)
    subprocess.run(
        ["xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41",
         "--batteryState", "charged", "--batteryLevel", "100",
         "--cellularBars", "4", "--wifiBars", "3"], check=True)


def start_demo_ssh(python):
    # The fixture stops when its stdin closes, so keep a pipe open.
    process = subprocess.Popen(
        [python, "-u", str(ROOT / "tool/demo_ssh_server.py"),
         "--port", str(SSH_PORT), "--sftp-root", SFTP_ROOT],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    ready = process.stdout.readline()
    assert '"ready"' in ready, ready
    return process


@contextlib.contextmanager
def integration_test_dependency():
    """Temporarily add the integration_test dev dependency.

    It is not in the committed pubspec.yaml because Flutter 3.47 links
    dev-dependency plugins into iOS release builds (flutter#163874). The
    original pubspec.yaml / pubspec.lock are restored afterwards.
    """
    pubspec, lock = ROOT / "pubspec.yaml", ROOT / "pubspec.lock"
    saved = pubspec.read_bytes(), lock.read_bytes()
    text = saved[0].decode()
    marker = "dev_dependencies:\n"
    if "integration_test:" in text or marker not in text:
        raise SystemExit("pubspec.yaml: unexpected dev_dependencies layout")
    pubspec.write_text(text.replace(
        marker, marker + "  integration_test:\n    sdk: flutter\n", 1))
    try:
        subprocess.run(["flutter", "pub", "get"], cwd=ROOT, check=True)
        yield
    finally:
        pubspec.write_bytes(saved[0])
        lock.write_bytes(saved[1])
        subprocess.run(["flutter", "pub", "get", "--enforce-lockfile"],
                       cwd=ROOT, check=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--udid", required=True)
    parser.add_argument("--lang", action="append", choices=["zh", "en"])
    parser.add_argument("--theme", default="light", choices=["light", "dark"])
    parser.add_argument("--only", default="", help="SHOT_ONLY test name filter")
    parser.add_argument("--restore-zh", action="store_true",
                        help="leave the simulator in Chinese when done")
    parser.add_argument("--ssh-python", default=os.environ.get(
        "VPS_SSH_FIXTURE_PYTHON", sys.executable))
    args = parser.parse_args()
    with integration_test_dependency():
        run(args)


def run(args):
    ssh = start_demo_ssh(args.ssh_python)
    try:
        for lang in args.lang or ["zh", "en"]:
            raw = ROOT / "build" / "shots" / lang / "raw"
            raw.mkdir(parents=True, exist_ok=True)
            capture = Capture(args.udid, raw)
            server = serve(capture)
            set_sim_language(args.udid, lang)
            print(f"== {lang} (host port {server.server_port})", flush=True)
            subprocess.run(
                ["flutter", "drive",
                 "--driver=test_driver/integration_test.dart",
                 "--target=integration_test/screenshots_test.dart",
                 "-d", args.udid,
                 f"--dart-define=SHOT_LOCALE={lang}",
                 f"--dart-define=SHOT_THEME={args.theme}",
                 f"--dart-define=SHOT_PORT={server.server_port}",
                 f"--dart-define=SHOT_SSH_PORT={SSH_PORT}",
                 f"--dart-define=SHOT_ONLY={args.only}"],
                cwd=ROOT, check=True)
            capture.rec_stop()
            server.shutdown()
    finally:
        if args.restore_zh:
            set_sim_language(args.udid, "zh")
        ssh.stdin.close()
        ssh.terminate()


if __name__ == "__main__":
    main()
