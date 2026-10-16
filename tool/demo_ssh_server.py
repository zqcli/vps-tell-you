"""Loopback-only demo SSH/SFTP server for the store screenshots and GIFs.

Built on test/support/ssh_fixture/server.py (same AsyncSSH host-key fixtures,
same hard rules): it binds 127.0.0.1 only and NEVER executes anything. The
"shell" answers a handful of fixed command lines with canned, synthetic text so
the terminal looks alive in docs/images. SFTP is the fixture's chroot-confined
subsystem serving a throw-away directory of synthetic files.

    python tool/demo_ssh_server.py --port 22022 --sftp-root /tmp/vps-demo-sftp

Login: user `demo`, password `demo-password` (synthetic, test-only).
Regenerating images: see docs/SCREENSHOTS.md.
"""

import asyncio
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "test" / "support" / "ssh_fixture"))
import server as fixture  # noqa: E402

PROMPT = b"\x1b[1;32mdemo@hk-01\x1b[0m:\x1b[1;34m~\x1b[0m$ "

CANNED = {
    "pwd": "/home/demo",
    "uptime": " 09:41:07 up 42 days, load 0.08",
    "ls -lah": (
        "total 36K\n"
        "drwxr-x--- 5 demo demo 4.0K .\n"
        "drwxr-xr-x 3 root root 4.0K ..\n"
        "drwxr-xr-x 2 demo demo 4.0K backups\n"
        "drwxr-xr-x 4 demo demo 4.0K projects\n"
        "-rwxr-xr-x 1 demo demo  356 deploy.sh\n"
        "-rw-r--r-- 1 demo demo 1.2K notes.txt"
    ),
    "df -h": (
        "Filesystem      Size  Used Avail Use% Mounted on\n"
        "/dev/vda1        40G   14G   25G  36% /\n"
        "tmpfs           992M     0  992M   0% /dev/shm\n"
        "/dev/vda15      105M  6.1M   99M   6% /boot/efi"
    ),
    "free -h": (
        "       total   used   free  avail\n"
        "Mem:   1.9Gi  612Mi  418Mi  1.1Gi\n"
        "Swap:  1.0Gi     0B  1.0Gi"
    ),
}


def install():
    async def greeting(self):
        await asyncio.sleep(0.2)
        if not self.channel.is_closing():
            self.channel.write(b"Welcome to Debian GNU/Linux 12 (demo)\r\n\r\n" + PROMPT)

    def session_started(self):
        if self.sftp:
            fixture.event("sftp_open", connection=self.owner.number)
            self.sftp.session_started()
            return
        self.line = b""
        asyncio.create_task(greeting(self))

    def data_received(self, data, datatype):
        if self.sftp:
            return self.sftp.data_received(data, datatype)
        for byte in data:
            if byte in (13, 10):
                command = self.line.decode("utf-8", "replace").strip()
                self.line = b""
                self.channel.write(b"\r\n")
                if command in CANNED:
                    self.channel.write(CANNED[command].replace("\n", "\r\n").encode() + b"\r\n")
                elif command:
                    self.channel.write(f"bash: {command.split()[0]}: demo shell\r\n".encode())
                self.channel.write(PROMPT)
            elif byte in (8, 127):
                if self.line:
                    self.line = self.line[:-1]
                    self.channel.write(b"\b \b")
            elif byte >= 32:
                self.line += bytes([byte])
                self.channel.write(bytes([byte]))

    async def validate_password(self, username, password):
        valid = username == "demo" and password == "demo-password"
        fixture.event("password", connection=self.number, valid=valid)
        return valid

    fixture.Session.session_started = session_started
    fixture.Session.data_received = data_received
    fixture.Server.validate_password = validate_password


TREE = {
    "notes.txt": "VPS notes\n- renew hk-01 before the 21st\n- rotate backups monthly\n",
    "deploy.sh": "#!/bin/sh\nset -eu\ncd /srv/app\ngit pull --ff-only\nsystemctl restart app\necho \"deployed\"\n",
    "nginx.conf": (
        "worker_processes auto;\n\nevents {\n    worker_connections 1024;\n}\n\n"
        "http {\n    server {\n        listen 80;\n        server_name example.com;\n"
        "        location / {\n            proxy_pass http://127.0.0.1:3000;\n        }\n    }\n}\n"
    ),
    "docker-compose.yml": (
        "services:\n  web:\n    image: nginx:1.27\n    ports:\n      - \"80:80\"\n"
        "    restart: unless-stopped\n  db:\n    image: postgres:16\n"
        "    volumes:\n      - db:/var/lib/postgresql/data\nvolumes:\n  db:\n"
    ),
    "config.json": '{\n  "name": "demo",\n  "port": 3000,\n  "debug": false\n}\n',
    "backups/db-2026-10-01.sql.gz": "synthetic\n" * 40,
    "backups/db-2026-10-08.sql.gz": "synthetic\n" * 55,
    "projects/app/README.md": "# app\n\nSynthetic demo project.\n",
    "projects/site/index.html": "<!doctype html>\n<title>demo</title>\n",
}


def seed_tree(root):
    now = time.time()
    for index, (name, text) in enumerate(TREE.items()):
        path = Path(root) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        # Spread the modified times so the listing looks lived-in.
        when = now - (index * 6 + 1) * 86400 - index * 4100
        os.utime(path, (when, when))


if __name__ == "__main__":
    # The fixture parses its own argv (--port, --sftp-root, --bind ...).
    if "--sftp-root" in sys.argv:
        root = Path(sys.argv[sys.argv.index("--sftp-root") + 1])
        root.mkdir(parents=True, exist_ok=True)
        seed_tree(root)
    install()
    asyncio.run(fixture.main())
