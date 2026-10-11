"""Loopback-only, synthetic SSH fixture. Never launches a shell or commands.

The only input interpretation is echoing bytes into an SSH channel. Even power
command strings are inert data. Authentication is an in-memory test comparison;
no OS users, authorized_keys, agents, keyrings or persistent access are touched.

An SFTP subsystem exists only when the test passes ``--sftp-root DIR``: it is
confined (AsyncSSH chroot) to that per-test temporary directory and runs on
its own channel, next to the unchanged fake shell. Without the flag an ``sftp``
subsystem request is refused like any other and still no shell/exec runs.
"""

import argparse
import asyncio
import base64
import json
import socket
import struct
import sys
from pathlib import Path

import asyncssh
from asyncssh.stream import SSHServerStreamSession


def event(kind, **fields):
    print(json.dumps({"event": kind, **fields}), flush=True)


class Session(asyncssh.SSHServerSession):
    def __init__(self, owner):
        self.owner = owner
        self.channel = None
        self.sftp = None  # delegate for the optional sftp subsystem channel

    def connection_made(self, channel):
        self.channel = channel
        self.owner.state["sessions"].add(self)

    def pty_requested(self, term_type, term_size, term_modes):
        event("pty", connection=self.owner.number, term=term_type,
              columns=term_size[0], rows=term_size[1])
        return True

    def terminal_size_changed(self, width, height, pixwidth, pixheight):
        event("resize", connection=self.owner.number, columns=width, rows=height)

    def subsystem_requested(self, subsystem):
        factory = self.owner.state["sftp_factory"]
        if subsystem != "sftp" or factory is None:
            return False
        # AsyncSSH's own stream session runs the SFTP protocol on this channel.
        self.sftp = SSHServerStreamSession(None, factory, 3)
        self.sftp.connection_made(self.channel)
        return True

    def shell_requested(self):
        event("shell", connection=self.owner.number)
        return True

    def exec_requested(self, command):
        # A hard safety boundary: this fixture has no command execution path.
        event("exec_rejected", connection=self.owner.number)
        return False

    def session_started(self):
        if self.sftp:
            event("sftp_open", connection=self.owner.number)
            self.sftp.session_started()
            return

        async def greeting():
            if self.channel.is_closing():
                return
            self.channel.write(b"fixture-ready\r\n")
            # Deliberately split a multibyte UTF-8 scalar across SSH packets.
            for piece in (b"\xe4", b"\xbd", b"\xa0\xe5\xa5\xbd\r\n"):
                if self.channel.is_closing():
                    return
                self.channel.write(piece)
                await asyncio.sleep(0.02)
            if not self.channel.is_closing():
                self.channel.write_stderr(b"fixture-stderr\r\n")
        asyncio.create_task(greeting())

    def data_received(self, data, datatype):
        if self.sftp:
            return self.sftp.data_received(data, datatype)
        event("input", connection=self.owner.number,
              data=base64.b64encode(data).decode("ascii"))
        self.channel.write(b"echo:" + data)

    def eof_received(self):
        return self.sftp.eof_received() if self.sftp else False

    def pause_writing(self):
        if self.sftp:
            self.sftp.pause_writing()

    def resume_writing(self):
        if self.sftp:
            self.sftp.resume_writing()

    def connection_lost(self, exc):
        self.owner.state["sessions"].discard(self)
        if self.sftp:
            self.sftp.connection_lost(exc)
            event("sftp_closed", connection=self.owner.number)
            return
        event("session_closed", connection=self.owner.number)


class Server(asyncssh.SSHServer):
    def __init__(self, state):
        self.state = state
        self.number = state["next"]
        state["next"] += 1
        self.connection = None

    def connection_made(self, connection):
        self.connection = connection
        self.state["connections"].add(connection)
        event("connection", connection=self.number)

    def connection_lost(self, exc):
        self.state["connections"].discard(self.connection)
        event("closed", connection=self.number)

    def begin_auth(self, username):
        event("auth_begin", connection=self.number, username=username)
        return True

    def password_auth_supported(self):
        return True

    def public_key_auth_supported(self):
        return True

    async def validate_password(self, username, password):
        if self.state["delay_auth"]:
            await asyncio.sleep(self.state["delay_auth"])
        valid = username == "fixture" and password == "synthetic-password-only"
        event("password", connection=self.number, valid=valid)
        return valid

    def validate_public_key(self, username, key):
        valid = username == "fixture" and key == self.state["allowed_key"]
        event("public_key", connection=self.number, valid=valid)
        return valid

    def auth_completed(self):
        event("authenticated", connection=self.number)

    def session_requested(self):
        return Session(self)


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--host-key", default="ed25519.fixture")
    parser.add_argument("--delay-auth", type=float, default=0)
    parser.add_argument("--login-timeout", type=float, default=10)
    parser.add_argument("--sftp-root", default=None)
    args = parser.parse_args()
    fixtures = Path(__file__).resolve().parents[2] / "fixtures" / "security"
    host_key = asyncssh.read_private_key(fixtures / args.host_key)
    state = {"next": 1, "connections": set(), "sessions": set(),
             "delay_auth": args.delay_auth, "sftp_factory": None,
             "allowed_key": asyncssh.read_public_key(
                 fixtures / "ed25519_encrypted.fixture.pub")}
    if args.sftp_root:
        root = Path(args.sftp_root).resolve()
        if not root.is_dir():
            raise SystemExit("--sftp-root must be an existing directory")
        chroot = str(root).encode("utf-8")
        state["sftp_factory"] = lambda chan: asyncssh.SFTPServer(
            chan, chroot=chroot)
    listener = await asyncssh.create_server(
        lambda: Server(state), "127.0.0.1", args.port,
        server_host_keys=[host_key], encoding=None, line_editor=False,
        login_timeout=args.login_timeout)
    event("ready", port=listener.get_port(),
          public_key=host_key.export_public_key().decode("ascii").strip())
    reader = asyncio.StreamReader()
    await asyncio.get_running_loop().connect_read_pipe(
        lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
    try:
        while line := await reader.readline():
            command = json.loads(line)
            if command["action"] == "stop":
                break
            if command["action"] == "disconnect":
                for connection in list(state["connections"]):
                    connection.close()
            if command["action"] == "abort":
                for connection in list(state["connections"]):
                    # Per-test loopback socket only: close with TCP RST to
                    # exercise asynchronous broken-pipe writer failures.
                    connection.get_extra_info("socket").setsockopt(
                        socket.SOL_SOCKET, socket.SO_LINGER,
                        struct.pack("ii", 1, 0))
                    connection.abort()
            if command["action"] == "finish":
                for session in list(state["sessions"]):
                    # Synthetic output immediately followed by channel and
                    # transport close, without executing anything remotely.
                    session.channel.write(b"f" * 65536)
                    session.channel.write("fixture-final-你好\r\n".encode("utf-8"))
                    session.channel.write_stderr(b"fixture-final-stderr\r\n")
                    session.channel.exit(0)
                    # connection.close() ultimately aborts the transport.
                    # Wait for channel-close acknowledgement so the fixture
                    # itself cannot discard its pending final writes.
                    await session.channel.wait_closed()
                    session.owner.connection.close()
    finally:
        listener.close()
        await listener.wait_closed()
        for connection in list(state["connections"]):
            connection.close()
            await connection.wait_closed()


if __name__ == "__main__":
    asyncio.run(main())
