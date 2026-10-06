"""Loopback-only, synthetic SSH fixture. Never launches a shell or commands.

The only input interpretation is echoing bytes into an SSH channel. Even power
command strings are inert data. Authentication is an in-memory test comparison;
no OS users, authorized_keys, agents, keyrings or persistent access are touched.
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


def event(kind, **fields):
    print(json.dumps({"event": kind, **fields}), flush=True)


class Session(asyncssh.SSHServerSession):
    def __init__(self, owner):
        self.owner = owner
        self.channel = None

    def connection_made(self, channel):
        self.channel = channel
        self.owner.state["sessions"].add(self)

    def pty_requested(self, term_type, term_size, term_modes):
        event("pty", connection=self.owner.number, term=term_type,
              columns=term_size[0], rows=term_size[1])
        return True

    def terminal_size_changed(self, width, height, pixwidth, pixheight):
        event("resize", connection=self.owner.number, columns=width, rows=height)

    def shell_requested(self):
        event("shell", connection=self.owner.number)
        return True

    def exec_requested(self, command):
        # A hard safety boundary: this fixture has no command execution path.
        event("exec_rejected", connection=self.owner.number)
        return False

    def session_started(self):
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
        event("input", connection=self.owner.number,
              data=base64.b64encode(data).decode("ascii"))
        self.channel.write(b"echo:" + data)

    def connection_lost(self, exc):
        self.owner.state["sessions"].discard(self)
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
    args = parser.parse_args()
    fixtures = Path(__file__).resolve().parents[2] / "fixtures" / "security"
    host_key = asyncssh.read_private_key(fixtures / args.host_key)
    state = {"next": 1, "connections": set(), "sessions": set(),
             "delay_auth": args.delay_auth,
             "allowed_key": asyncssh.read_public_key(
                 fixtures / "ed25519_encrypted.fixture.pub")}
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
                    session.owner.connection.close()
    finally:
        listener.close()
        await listener.wait_closed()
        for connection in list(state["connections"]):
            connection.close()
            await connection.wait_closed()


if __name__ == "__main__":
    asyncio.run(main())
