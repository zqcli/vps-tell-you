/// The one parser for network host input: IPv4, IPv6 and DNS names.
///
/// Pure Dart (no `dart:io`), so the result never depends on the platform's
/// resolver. See `docs/IPV6.md` for the design.
///
/// * IPv6 is stored and compared as RFC 5952 §4 text: lower case, no leading
///   zeros, the longest run (first on ties) of two or more zero groups becomes
///   `::`. Mixed notation (`::ffff:192.0.2.1`) is accepted and canonicalised to
///   hex, so every spelling of an address maps to one key.
/// * A zone id (`%en0`) is accepted only on link-local (`fe80::/10`) literals.
/// * Brackets are input / display syntax only; they are never part of
///   [NetAddress.host].
library;

enum NetHostKind { ipv4, ipv6, domain }

class NetAddress {
  const NetAddress._(this.kind, this.address, this.zone, this._bytes);

  final NetHostKind kind;

  /// Canonical text without zone: dotted IPv4, RFC 5952 IPv6 or a lower-case
  /// DNS name without trailing dot.
  final String address;

  /// Link-local zone id (interface name or index), IPv6 only.
  final String? zone;
  final List<int>? _bytes;

  /// Canonical, bracket-free text: what is stored, compared and handed to
  /// `Socket.connect`.
  String get host => zone == null ? address : '$address%$zone';
  bool get isIp => kind != NetHostKind.domain;
  bool get isIpv6 => kind == NetHostKind.ipv6;

  /// `0.0.0.0`, `::` and `::ffff:0.0.0.0`: never a real machine address.
  bool get isUnspecified {
    final bytes = _bytes;
    if (bytes == null) return false;
    if (bytes.every((byte) => byte == 0)) return true;
    return bytes.length == 16 &&
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 255 &&
        bytes[11] == 255 &&
        bytes.skip(12).every((byte) => byte == 0);
  }

  /// `fe80::/10`.
  bool get isLinkLocal {
    final bytes = _bytes;
    return kind == NetHostKind.ipv6 && _isLinkLocal(bytes!);
  }

  /// Display form: IPv6 in brackets, everything else unchanged.
  String get display => isIpv6 ? '[$host]' : host;

  /// `host:port` that is unambiguous for IPv6: `[2001:db8::1]:22`.
  String withPort(int port) => '$display:$port';

  /// Parses one host. Does not trim: callers decide what whitespace means.
  ///
  /// * [allowBrackets]: accept `[v6]`; stored values must be bare.
  /// * [lenientNames]: accept numeric-looking names such as `127.1` or
  ///   `0x7f.1` as DNS names. They are ambiguous (many resolvers read them as
  ///   IPv4), so every connection path leaves this off; it only exists so that
  ///   already-stored records stay readable.
  static NetAddress? tryParse(
    String input, {
    bool allowBrackets = true,
    bool lenientNames = false,
  }) {
    if (input.isEmpty || input.length > 255) return null;
    if (input.startsWith('[') || input.endsWith(']')) {
      if (!allowBrackets ||
          !input.startsWith('[') ||
          !input.endsWith(']') ||
          input.length < 4) {
        return null;
      }
      return _parseIpv6WithZone(input.substring(1, input.length - 1));
    }
    if (input.contains(':')) return _parseIpv6WithZone(input);
    final v4 = _parseIpv4(input);
    if (v4 != null) {
      return NetAddress._(NetHostKind.ipv4, v4.join('.'), null, v4);
    }
    return _parseDomain(input, lenientNames: lenientNames);
  }

  /// RFC 5952 text for [bytes] (16 bytes).
  static String _formatIpv6(List<int> bytes) {
    assert(bytes.length == 16);
    final groups = List<int>.generate(
      8,
      (index) => (bytes[index * 2] << 8) | bytes[index * 2 + 1],
    );
    var longestStart = -1;
    var longestLength = 1; // a single zero group is never compressed
    for (var index = 0; index < groups.length;) {
      if (groups[index] != 0) {
        index++;
        continue;
      }
      final start = index;
      while (index < groups.length && groups[index] == 0) {
        index++;
      }
      if (index - start > longestLength) {
        longestStart = start;
        longestLength = index - start;
      }
    }
    String join(Iterable<int> values) =>
        values.map((part) => part.toRadixString(16)).join(':');
    if (longestStart < 0) return join(groups);
    return '${join(groups.take(longestStart))}::'
        '${join(groups.skip(longestStart + longestLength))}';
  }

  @override
  bool operator ==(Object other) =>
      other is NetAddress && other.kind == kind && other.host == host;
  @override
  int get hashCode => Object.hash(kind, host);
  @override
  String toString() => host;
}

/// Syntactic `host[:port]` split for one input field.
///
/// * `[v6]`, `[v6]:22` – brackets removed, port after `]:`.
/// * `host:22`, `1.2.3.4:22` – exactly one colon.
/// * two or more colons without brackets – a bare IPv6 address with **no**
///   port (`2001:db8::1:22` is an address, not `2001:db8::1` port 22).
///
/// Neither part is validated; returns `null` only for broken bracket syntax.
({String host, String? port})? splitHostPort(String input) {
  if (input.startsWith('[')) {
    final close = input.indexOf(']');
    if (close < 0) return null;
    final rest = input.substring(close + 1);
    if (rest.isEmpty) return (host: input.substring(1, close), port: null);
    if (!rest.startsWith(':')) return null;
    return (host: input.substring(1, close), port: rest.substring(1));
  }
  final first = input.indexOf(':');
  if (first < 0 || first != input.lastIndexOf(':')) {
    return (host: input, port: null);
  }
  return (host: input.substring(0, first), port: input.substring(first + 1));
}

/// `host:port` for display; IPv6 hosts (anything with a colon) get brackets.
String formatHostPort(String host, int port) => '${bracketedHost(host)}:$port';

/// `user@host:port` for display with an unambiguous IPv6 host.
String formatUserHostPort(String user, String host, int port) =>
    '$user@${formatHostPort(host, port)}';

/// [host] ready to be followed by `:port`: IPv6 (anything with a colon) in
/// brackets, everything else unchanged.
String bracketedHost(String host) =>
    host.contains(':') && !host.startsWith('[') ? '[$host]' : host;

bool _isLinkLocal(List<int> bytes) =>
    bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80;

final _ipv4Part = RegExp(r'^(?:0|[1-9][0-9]{0,2})$');

List<int>? _parseIpv4(String text) {
  final parts = text.split('.');
  if (parts.length != 4) return null;
  final bytes = <int>[];
  for (final part in parts) {
    if (!_ipv4Part.hasMatch(part)) return null;
    final value = int.parse(part);
    if (value > 255) return null;
    bytes.add(value);
  }
  return bytes;
}

final _zonePattern = RegExp(r'^[A-Za-z0-9._-]{1,15}$');

NetAddress? _parseIpv6WithZone(String text) {
  final percent = text.indexOf('%');
  final body = percent < 0 ? text : text.substring(0, percent);
  final zone = percent < 0 ? null : text.substring(percent + 1);
  final bytes = _parseIpv6(body);
  if (bytes == null) return null;
  if (zone != null) {
    // A scope id only means something for link-local addresses.
    if (!_isLinkLocal(bytes) || !_zonePattern.hasMatch(zone)) return null;
  }
  return NetAddress._(
    NetHostKind.ipv6,
    NetAddress._formatIpv6(bytes),
    zone,
    bytes,
  );
}

final _hexGroup = RegExp(r'^[0-9a-fA-F]{1,4}$');

List<int>? _parseIpv6(String text) {
  if (!text.contains(':')) return null;
  final doubleAt = text.indexOf('::');
  if (doubleAt >= 0 && text.indexOf('::', doubleAt + 1) >= 0) return null;

  List<int>? side(String part, {required bool last}) {
    if (part.isEmpty) return <int>[];
    final items = part.split(':');
    final groups = <int>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.contains('.')) {
        // An embedded IPv4 is only valid as the final 32 bits of the address.
        if (!last || i != items.length - 1) return null;
        final v4 = _parseIpv4(item);
        if (v4 == null) return null;
        groups
          ..add((v4[0] << 8) | v4[1])
          ..add((v4[2] << 8) | v4[3]);
      } else {
        if (!_hexGroup.hasMatch(item)) return null;
        groups.add(int.parse(item, radix: 16));
      }
    }
    return groups;
  }

  List<int> head, tail;
  if (doubleAt < 0) {
    final all = side(text, last: true);
    if (all == null || all.length != 8) return null;
    head = all;
    tail = const [];
  } else {
    final h = side(text.substring(0, doubleAt), last: false);
    final t = side(text.substring(doubleAt + 2), last: true);
    if (h == null || t == null || h.length + t.length > 7) return null;
    head = h;
    tail = t;
  }
  final groups = doubleAt < 0
      ? head
      : [...head, ...List.filled(8 - head.length - tail.length, 0), ...tail];
  return [
    for (final group in groups) ...[group >> 8, group & 0xff],
  ];
}

final _dnsLabel = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$');
final _numericName = RegExp(r'^(?:[0-9]+|0[xX][0-9a-fA-F]*)$');

NetAddress? _parseDomain(String input, {required bool lenientNames}) {
  final name = input.endsWith('.')
      ? input.substring(0, input.length - 1)
      : input;
  if (name.isEmpty || name.length > 253) return null;
  final labels = name.split('.');
  if (labels.any((label) => !_dnsLabel.hasMatch(label))) return null;
  // `127.1`, `0x7f.1`, `2130706433`: resolvers read these as IPv4 aliases.
  if (!lenientNames && _numericName.hasMatch(labels.last)) return null;
  return NetAddress._(NetHostKind.domain, name.toLowerCase(), null, null);
}
