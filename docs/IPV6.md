# IPv4 / IPv6 address handling

Every place that accepts, stores, compares, connects to or displays an IPv4
address must do the same for IPv6. This file records the audit that drove the
change (section 1), the design (section 2) and the behaviour contract
(section 3).

## 1. Audit (baseline `8900f4e`)

| Area | Baseline behaviour | Gap |
|---|---|---|
| `ServerRecord.validHost` | `InternetAddress.tryParse` or a DNS-label regex | Accepts `%zone` on any address, accepts `1.2.3`-style numeric names; no canonical form, so `2001:DB8::1` and `2001:db8:0::1` are different hosts |
| `ServerResources.ip` | One `ip` field, `validIp` accepts IPv4 *and* IPv6, rejects zone / unspecified / mapped-unspecified | IPv4 and IPv6 share one slot: a dual-stack machine cannot record both |
| `ServerForm` | Address row; hardware `IP` row is **hidden** while the address is an IP *or empty*; on save the typed IP overwrites `resources.ip` | Cannot hold a second family; hidden row is confusing; empty address hides it too |
| `ServerDetail` hardware grid | One `IP address` tile (two lines max, ellipsised) | No IPv6 tile; a 39-char IPv6 does not fit a third-width tile |
| Detail address card / copy | Plain `host` text, copies the bare host | OK (bare is what `ping` / `ssh` expect); long IPv6 relies on `maxLines: 2` ellipsis |
| Server search (`LedgerController.visible`) | Matches name, host, vendor, provider, purpose, region | Hardware IPs are not searched at all; IPv6 query forms not normalised |
| `SshConfigurationPage` | Only "not empty" check; the store later rejects with a generic toast | No inline format error; accepts nothing bracketed; no IPv6 hint |
| `normalizedHost` (host-trust key) | Lower-case, strips `[]`, RFC 5952 hex-only compression, rejects numeric IPv4 aliases and `%zone` | Works, but private; zone ids unsupported, so link-local hosts cannot be used |
| `SshTarget.label`, `TcpTarget.label` | Bracket IPv6 | OK |
| Other `host:port` strings | `security_pages` (3 places), `host_trust_pages` (2), `ssh_prompts`, `server_detail` SSH row interpolate `host:port` unbracketed | `2001:db8::1:22` is ambiguous with an address |
| `ssh_socket_io` / `ssh_service` | `Socket.startConnect(next.host, …)` with the normalised, bracket-free host | OK for IPv6 literals; zone ids never reach it |
| SFTP standalone (`sftp_connect_page` → `connectSftp`) | Same `SshTarget.normalized()` + `SshSocketConnection` path | Same as SSH |
| `TcpTarget` / `tcp_test_page` | Separate host and port fields; host field accepts `[v6]`; shows the actual remote address | No `host:port` paste; the result shows the remote address but not its family; `validHost` accepts a zone that the SSH normaliser then rejects |
| Host-trust DB (`host_trust` host+port) | Key from `normalizedHost` | Form-independent for IPv6 already; zone absent |
| Backup (`ledger_backup.dart`) | `host` ≤ 253 chars, `resources_json` ≤ 4096 and decoded by the strict `ServerResources.fromJson` | Unknown keys rejected (kept); `ipv6` must become an optional known key |
| SQLite | `resources_json TEXT`, `host TEXT` | No schema change needed |
| Demo data | Three IPv4 documentation addresses + `example.invalid`; no resources | No IPv6 example |
| Terminal highlight | `_ip6` regex, `_looksIp6` | Bare IPv6 highlighted; bracketed `[v6]:port` is not |
| Cloud (`lib/cloud/**`) | Already has `ipv4` / `ipv6` observations; `cloud_import` picks the first valid one into `ip` | Being removed by another helper; only kept compiling |

## 2. Design

### One connection address, two hardware addresses

* `ServerRecord.host` is the **connection address**: IPv4, IPv6 (optionally
  with a zone id for link-local) or a domain. One value, because SSH / SFTP /
  TCP use exactly one target.
* `ServerResources.ip` stays the **IPv4** hardware address (JSON key
  unchanged, so old data and old backups are valid) and the new optional
  `ServerResources.ipv6` is the IPv6 one. `ipv6` is only written to JSON when
  set, so records without it are byte-identical to before.
* Legacy data may hold an IPv6 in `ip`. Decoding moves it to `ipv6` when the
  latter is empty (an API marker on `ip` moves with it). Nothing else changes.

### Form

There is no host/address field. The hardware section has independent,
optional `IPv4`, `IPv6` and `Hostname` rows; nothing is mirrored between them.
`ServerRecord.primaryAddress` (IPv4, else IPv6, else hostname, else the legacy
`servers.host`) is what the list, detail, copy action and the SSH / TCP
defaults use.

**Legacy `servers.host`** (column kept, no schema change): when an older
server is edited, its host is prefilled into the matching *empty* field (IPv4 →
`IPv4`, IPv6 → `IPv6` in canonical form, domain → `Hostname`) and `host` is
cleared on save once the value is stored there. If that field already holds a
different value, or the host fits no field (zoned link-local, odd names), `host`
is left untouched and the detail page keeps showing it as "Saved address".
Blanking the prefilled field also keeps `host`; nothing is ever dropped.

### Canonical form

`lib/core/net_address.dart` is the single parser. IPv6 is stored and compared
as RFC 5952 §4 lower-case text with the longest (first on ties) run of ≥ 2
zero groups compressed. Mixed notation (`::ffff:192.0.2.1`) is accepted on
input and canonicalised to hex (`::ffff:c000:201`), which is also what the
pre-existing host-trust records contain, so no migration is needed.
`::ffff:a.b.c.d` is a **different** trust key from `a.b.c.d` (fail closed).

### Zone ids

Allowed only on link-local (`fe80::/10`) literals, 1–15 chars of
`[A-Za-z0-9._-]`, kept verbatim (case-sensitive on Linux). The zone is part of
the host-trust key: the same `fe80::1` on another interface can be another
machine, and the key is device-local anyway. Hardware `ipv6` never has a zone.
Brackets are display / input syntax only and never stored or passed to
`Socket.connect`.

### Display

`[2001:db8::1]:22`, `user@[2001:db8::1]:22`; IPv4 and domains are unchanged.
Copy actions copy the bare address.

## 3. Contract summary

* Input forms accepted for the same IPv6 address share one host-trust key.
* Numeric-looking names (`127.1`, `0x7f.1`) fail closed for connections.
* Backups accept `ipv6` (optional) and still reject any other unknown key.
  `ip` holding an IPv6 (older data) is moved to `ipv6` on read; with both set
  it is rejected.
* SQLite is untouched: `resources_json` / `host` are TEXT, so no schema bump
  and no migration; backup stays v1.

## 4. Where it applies

| Place | Behaviour |
|---|---|
| Server form | `IPv4`, `IPv6`, `Hostname` rows, independent and optional (validated with `net_address.dart`; IPv6 stored canonical); fields stack under the label when a full-length address cannot share the line (decided from the maximum width, not the typed text, so focus is kept) |
| Detail | `IPv4` tile in the grid, `IPv6` full-width tile (wraps); no separate address card (only a legacy host that fits no field is shown, up to 3 lines); Copy Address copies the bare primary address |
| Search | hardware IPv4 / IPv6 / hostname and the legacy host; an IPv6 query in any spelling also matches the canonical form |
| SSH settings | inline validation (`NetAddress`), saved canonical |
| SSH / SFTP / TCP connect | bare canonical host to `Socket.connect`; host-trust key `host` + `port` |
| TCP test | address field takes `host`, `host:port`, `[v6]`, `[v6]:port`; the port moves into the port field; a bare IPv6 is never split; result shows the connected address and its family |
| Display | `[v6]:port`, `user@[v6]:port` (terminal title, prompts, trust lists, SSH row) |
| Terminal highlight | also `[v6]:port` |
| Demo data | JP-01 uses `2001:db8:0:22::1` |

## 5. Verification

`test/net_address_test.dart` (RFC 5952 vectors), `server_resources_test`,
`ledger_backup_test`, `hardware_configuration_test` (form), `ipv6_search_test`,
`tcp_test` / `tcp_widget_test`, `security_validation_test` (trust key across
spellings), `security_widget_test` (SSH settings) and
`ssh_ipv6_loopback_test` (real SSH + SFTP over `::1` through the loopback-only
fixture, `--bind ::1`; skipped with a stated reason on hosts without `::1`).
The zone-id TCP test needs `fe80::1%lo0` (macOS / BSD) and is skipped elsewhere.
