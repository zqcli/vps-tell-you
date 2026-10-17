# Proxy TLS test fixtures

Synthetic, test-only certificates for the HTTPS-proxy tests. Never use them for
anything real; the private keys are public on purpose.

* `ca.pem` / `ca.key` – self-signed test CA, valid 2020–2120. The tests trust only this.
* `server.pem` / `server.key` – leaf signed by `ca.pem`, valid 2020–2120, CN `127.0.0.1`,
  SAN `localhost`, `127.0.0.1`, `::1`, serverAuth. Used as is on Linux/Android.
* `leaf.ext` – the extension file used to sign the leaf.
* `other_ca.pem` – an unrelated CA, to prove an untrusted chain is refused.

Apple's trust evaluation (macOS/iOS `dart:io`) rejects server certificates valid for
more than 398 days, so on macOS `test/support/proxy_tls.dart` signs a 30-day leaf
from `ca.key` + `leaf.ext` with the system `openssl` into a temp directory at test time.
