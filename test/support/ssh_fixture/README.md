# Isolated SSH protocol fixture

`server.py` uses an independent SSH implementation (AsyncSSH 2.22.0), binds only
to loopback on an ephemeral port, and authenticates synthetic data in memory.
It never executes a command or starts a shell. It never changes OS accounts,
`authorized_keys`, SSH agents, native keyrings, or persistent access. All keys
are existing test-only fixtures; they must never be used for real servers.

Install the prerequisite into a workspace-local Python 3.10+ virtualenv:

```sh
python3 -m venv ../vps-ssh-test-venv
../vps-ssh-test-venv/bin/python -m pip install --index-url https://pypi.org/simple \
  -r test/support/ssh_fixture/requirements.txt
VPS_SSH_FIXTURE_PYTHON="$PWD/../vps-ssh-test-venv/bin/python" \
  flutter test test/ssh_service_test.dart
```

CI can install the same requirements into its isolated Python environment and
set `VPS_SSH_FIXTURE_PYTHON=python3`. Tests fail with prerequisite instructions
when AsyncSSH is unavailable; protocol coverage is never silently skipped.
The fixture subprocess, sockets and temporary SQLite database are cleaned up
after every test, including assertion failures. No external host is contacted.

The fixture emits JSON events which contain only synthetic test usernames,
public host keys, PTY sizes, accepted/rejected authentication outcomes and
synthetic terminal bytes. It does not log passwords, passphrases or private
keys. Exec channel requests are rejected unconditionally.

## Optional SFTP subsystem

`server.py --sftp-root DIR` (Dart: `SshFixture.start(sftpRoot: dir)`) enables
an `sftp` subsystem on its own channel, next to the unchanged fake shell. It is
AsyncSSH's `SFTPServer` chroot-confined to `DIR` (a per-test temporary
directory), so `..` and absolute paths cannot leave it, and it is loopback
only. It reads and writes real files under `DIR` only; there is still no
shell or exec. Without the flag the `sftp` subsystem is refused. Events:
`sftp_open` / `sftp_closed` (no paths or contents). Used by
`test/sftp_session_test.dart`.
