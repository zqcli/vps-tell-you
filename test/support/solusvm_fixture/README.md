# Synthetic SolusVM / RackNerd ctrl fixtures

`flutter test test/solusvm_adapter_test.dart test/solusvm_tls_test.dart` runs local protocol tests. The native TLS suite requires the installed `openssl` CLI and uses a temporary self-signed localhost certificate. Production clients must reject it; only test-injected trust contexts accept it. Tests never disable hostname validation or contact a service provider.

The optional manual Linux GUI harness is `test/support/cloud_native_fixture.dart`. It uses the real `NativeSecretStore`, a temporary SQLite file, an isolated synthetic-only keyring, and a test-only private certificate trust context. Its factory rejects every endpoint except `https://localhost:$VPS_CLOUD_FIXTURE_PORT`. It is not reachable from production `main.dart`.

Manual prerequisites: create a private temporary directory with `localhost.crt` and `localhost.key` (SAN `DNS:localhost`, `basicConstraints=critical,CA:FALSE`, `keyUsage=critical,digitalSignature,keyEncipherment`, `extendedKeyUsage=serverAuth`), run `server.py --cert ... --key ... --port ...` on the same desktop as the app, launch with `VPS_CLOUD_FIXTURE_DIR` and `VPS_CLOUD_FIXTURE_PORT`, and provide a separately authorized isolated GNOME Keyring / private D-Bus session. Never use the normal keyring, real credentials, or an external host. Build the harness using `flutter build linux --release --target test/support/cloud_native_fixture.dart`; rebuild the normal target afterward.

Synthetic credentials:
- V1 `SYNTHETIC_KEY` / `SYNTHETIC_HASH`
- V2 `SYNTHETIC_TOKEN`; `SYNTHETIC_OTHER` returns a different account ID
- RackNerd ctrl `SYNTHETIC_RACK_KEY+ /&=` / `SYNTHETIC_RACK_HASH+ /&=`; one form-urlencoded `action=info`, `rdtype=json` request with the five resource flags returns synthetic resource JSON without a CPU count. Invalid RackNerd credentials return HTTP 200 with `status=error`.
- For V1/V2, `SYNTHETIC_SLOW` makes a request stall; arbitrary wrong values yield HTTP 401.

V1 keeps multipart `action=status` support for the current eight fields and the original three-field fixture. RackNerd uses a separate exact form/JSON contract; it never changes V1/V2 behavior.

The server supports only the closed read paths. It never runs shell/power actions and logs no headers, bodies or credentials. Certificates/keys, keyring home, SQLite and logs belong outside the repository and should be cleaned after QA.
