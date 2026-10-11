import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/net_address.dart';

String? canon(String input) => NetAddress.tryParse(input)?.host;

void main() {
  group('RFC 5952 canonical IPv6', () {
    // Vectors from RFC 5952 sections 2, 4.1, 4.2 and 4.3 plus common forms.
    const vectors = {
      // 4.1 leading zeros are suppressed
      '2001:0db8:0000:0000:0000:0000:0000:0001': '2001:db8::1',
      '2001:db8::0001': '2001:db8::1',
      // 4.2.1 `::` replaces at least two groups
      '2001:db8:0:0:0:0:2:1': '2001:db8::2:1',
      // 4.2.2 a single zero group is not shortened
      '2001:db8:0:1:1:1:1:1': '2001:db8:0:1:1:1:1:1',
      '2001:db8::1:1:1:1:1': '2001:db8:0:1:1:1:1:1',
      // 4.2.3 the longest run wins
      '2001:0:0:1:0:0:0:1': '2001:0:0:1::1',
      '2001:db8:0:0:1:0:0:1': '2001:db8::1:0:0:1', // tie: the first run
      // 4.3 lower case
      '2001:DB8:AAAA:BBBB:CCCC:DDDD:EEEE:FFFF':
          '2001:db8:aaaa:bbbb:cccc:dddd:eeee:ffff',
      // special addresses
      '0:0:0:0:0:0:0:0': '::',
      '::': '::',
      '0:0:0:0:0:0:0:1': '::1',
      '::1': '::1',
      '1:0:0:0:0:0:0:0': '1::',
      '1::': '1::',
      'fe80:0:0:0:0:0:0:1': 'fe80::1',
      // IPv4-mapped / compatible notations map to one hex form
      '::ffff:192.0.2.1': '::ffff:c000:201',
      '::FFFF:C000:0201': '::ffff:c000:201',
      '0:0:0:0:0:ffff:192.0.2.1': '::ffff:c000:201',
      '64:ff9b::192.0.2.33': '64:ff9b::c000:221',
      '1:2:3:4:5:6:1.2.3.4': '1:2:3:4:5:6:102:304',
      '1:2:3:4:5:6:7::': '1:2:3:4:5:6:7:0', // single zero group
      '::2:3:4:5:6:7:8': '0:2:3:4:5:6:7:8', // single zero group
    };
    vectors.forEach((input, expected) {
      test(input, () {
        expect(canon(input), expected);
        expect(canon('[$input]'), expected, reason: 'bracketed');
        // Canonical text is a fixed point.
        expect(canon(expected), expected);
        expect(NetAddress.tryParse(input)!.kind, NetHostKind.ipv6);
      });
    });

    test('all spellings of one address share one key', () {
      final forms = [
        '2001:db8::1',
        '2001:DB8::1',
        '2001:0db8:0:0:0:0:0:1',
        '2001:db8:0::1',
        '[2001:DB8:0000::0001]',
      ];
      expect(forms.map(canon).toSet(), {'2001:db8::1'});
    });

    test('rejects malformed IPv6', () {
      for (final bad in [
        ':',
        ':::',
        '1:::2',
        '1::2::3',
        ':1:2:3:4:5:6:7',
        '1:2:3:4:5:6:7:',
        '1:2:3:4:5:6:7:8:9',
        '1:2:3:4:5:6:7::8', // `::` would stand for zero groups
        '::1:2:3:4:5:6:7:8',
        '12345::1',
        'g::1',
        '1.2.3.4::',
        '::1.2.3',
        '::1.2.3.256',
        '::01.2.3.4',
        '1::2.3.4.5:6',
        '2001:db8::1/64',
        '2001:db8::1 ',
        ' 2001:db8::1',
        '[2001:db8::1',
        '2001:db8::1]',
        '[]',
        '[[::1]]',
        '[1.2.3.4]',
        '[example.com]',
        '::1:22:',
      ]) {
        expect(NetAddress.tryParse(bad), isNull, reason: bad);
      }
    });

    test('bare form can be required for stored values', () {
      expect(NetAddress.tryParse('[::1]', allowBrackets: false), isNull);
      expect(NetAddress.tryParse('::1', allowBrackets: false), isNotNull);
    });
  });

  group('zone ids', () {
    test('link-local only, kept verbatim', () {
      final a = NetAddress.tryParse('FE80:0:0:0:0:0:0:1%en0')!;
      expect(a.address, 'fe80::1');
      expect(a.zone, 'en0');
      expect(a.host, 'fe80::1%en0');
      expect(a.isLinkLocal, isTrue);
      expect(a.display, '[fe80::1%en0]');
      expect(canon('[fe80::1%Wlan0]'), 'fe80::1%Wlan0');
      expect(canon('fe80::1%12'), 'fe80::1%12');
      expect(canon('febf::1%eth0.100'), 'febf::1%eth0.100'); // fe80::/10
    });

    test('rejected on other addresses and bad zone text', () {
      for (final bad in [
        '2001:db8::1%en0',
        '::1%lo0',
        'fec0::1%en0', // outside fe80::/10
        'fe80::1%',
        'fe80::1%en 0',
        'fe80::1%a%b',
        'fe80::1%0123456789abcdef', // 16 chars
        '1.2.3.4%en0',
        'example.com%en0',
      ]) {
        expect(NetAddress.tryParse(bad), isNull, reason: bad);
      }
    });

    test('zone is part of the key', () {
      expect(canon('fe80::1%en0'), isNot(canon('fe80::1%en1')));
      expect(canon('fe80::1%en0'), isNot(canon('fe80::1')));
    });
  });

  group('IPv4 and names', () {
    test('strict dotted decimal', () {
      expect(canon('192.0.2.1'), '192.0.2.1');
      expect(NetAddress.tryParse('192.0.2.1')!.kind, NetHostKind.ipv4);
      for (final bad in [
        '1.2.3',
        '1.2.3.4.5',
        '256.1.1.1',
        '01.2.3.4',
        '1.2.3.04',
        '0x7f.0.0.1',
        '127.1',
        '2130706433',
        '1.2.3.4.',
        ' 1.2.3.4',
        '-1.2.3.4',
      ]) {
        expect(NetAddress.tryParse(bad), isNull, reason: bad);
      }
    });

    test('numeric names only in lenient mode (stored legacy records)', () {
      expect(NetAddress.tryParse('127.1'), isNull);
      expect(NetAddress.tryParse('127.1', lenientNames: true), isNotNull);
      expect(
        NetAddress.tryParse('1.2.3', lenientNames: true)!.kind,
        NetHostKind.domain,
      );
    });

    test('domains are lower-cased, trailing dot dropped', () {
      expect(canon('Example.COM'), 'example.com');
      expect(canon('example.com.'), 'example.com');
      expect(canon('a-b.c1.example'), 'a-b.c1.example');
      expect(canon('localhost'), 'localhost');
      expect(NetAddress.tryParse('example.com')!.kind, NetHostKind.domain);
      expect(NetAddress.tryParse('v6.example')!.isIp, isFalse);
      for (final bad in [
        '',
        '.',
        '-a.com',
        'a-.com',
        'a..com',
        'a b.com',
        'a_b.com',
        'münchen.de',
        'a/b',
        'user@host',
        'http://x.com',
        '${'a' * 64}.com',
        '${List.filled(60, 'abcd').join('.')}.com', // > 253
      ]) {
        expect(NetAddress.tryParse(bad), isNull, reason: bad);
      }
    });

    test('unspecified and link-local flags', () {
      expect(NetAddress.tryParse('0.0.0.0')!.isUnspecified, isTrue);
      expect(NetAddress.tryParse('::')!.isUnspecified, isTrue);
      expect(NetAddress.tryParse('::ffff:0.0.0.0')!.isUnspecified, isTrue);
      expect(NetAddress.tryParse('::1')!.isUnspecified, isFalse);
      expect(NetAddress.tryParse('example.com')!.isUnspecified, isFalse);
      expect(NetAddress.tryParse('fe80::1')!.isLinkLocal, isTrue);
      expect(NetAddress.tryParse('2001:db8::1')!.isLinkLocal, isFalse);
    });
  });

  group('display and host:port', () {
    test('formatHostPort brackets IPv6 only', () {
      expect(formatHostPort('2001:db8::1', 22), '[2001:db8::1]:22');
      expect(formatHostPort('[2001:db8::1]', 22), '[2001:db8::1]:22');
      expect(formatHostPort('fe80::1%en0', 22), '[fe80::1%en0]:22');
      expect(formatHostPort('192.0.2.1', 22), '192.0.2.1:22');
      expect(formatHostPort('example.com', 2222), 'example.com:2222');
      expect(
        formatUserHostPort('root', '2001:db8::1', 22),
        'root@[2001:db8::1]:22',
      );
      expect(
        formatUserHostPort('root', 'example.com', 22),
        'root@example.com:22',
      );
      expect(
        NetAddress.tryParse('2001:DB8::1')!.withPort(2222),
        '[2001:db8::1]:2222',
      );
    });

    test('splitHostPort', () {
      ({String host, String? port})? s(String v) => splitHostPort(v);
      expect(s('example.com'), (host: 'example.com', port: null));
      expect(s('example.com:22'), (host: 'example.com', port: '22'));
      expect(s('192.0.2.1:2222'), (host: '192.0.2.1', port: '2222'));
      expect(s('[2001:db8::1]:22'), (host: '2001:db8::1', port: '22'));
      expect(s('[2001:db8::1]'), (host: '2001:db8::1', port: null));
      expect(s('[fe80::1%en0]:22'), (host: 'fe80::1%en0', port: '22'));
      // Bare IPv6 is an address, never host + port.
      expect(s('2001:db8::1'), (host: '2001:db8::1', port: null));
      expect(s('2001:db8::1:22'), (host: '2001:db8::1:22', port: null));
      expect(s('::1'), (host: '::1', port: null));
      expect(s('[::1'), isNull);
      expect(s('[::1]x'), isNull);
      expect(s('[::1]:'), (host: '::1', port: ''));
    });
  });
}
