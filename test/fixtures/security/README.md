# Synthetic SSH fixtures

These keys were generated solely for local automated tests with `ssh-keygen`.
They have never been installed in a real SSH server, agent, account, or
authorized keys file. The optional loopback protocol fixture loads these keys
only into its isolated in-memory server, which cannot execute commands. They
grant no real access and must never be used for real authentication.

- `ed25519.fixture`: unencrypted OpenSSH Ed25519
- `ed25519_encrypted.fixture`: the same public key, encrypted OpenSSH format;
  test-only passphrase `fixture-passphrase-only`, default 16 bcrypt rounds
- `rsa.fixture`: PKCS#1 PEM RSA, 2048 bits
- `ecdsa.fixture`: SEC1 PEM ECDSA, NIST P-256
- `ecdsa384.fixture`, `ecdsa521.fixture`: SEC1 PEM ECDSA, NIST P-384/P-521
- Corresponding `.pub` files contain public-key blobs for host-trust tests

Private fixtures deliberately use `.fixture` names; normal private-key file
extensions remain excluded by the repository's `.gitignore`.
