import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/terminal_highlight.dart';
import 'package:vps_tell_you/connections/terminal_highlighter.dart';
import 'package:xterm/xterm.dart';

/// "text:kind" for every span of [line].
List<String> tokens(String line, {bool cursorLine = false}) => [
  for (final s in highlightLine(line, cursorLine: cursorLine))
    '${line.substring(s.start, s.end)}:${s.kind.name}',
];

void main() {
  group('tokenizer', () {
    test('prompts: user@host, path and sign (root gets its own kind)', () {
      expect(tokens('root@hk-01:~/proj# ls /etc'), [
        'root@hk-01:userHost',
        '~/proj:promptPath',
        '#:promptRoot',
        '/etc:path',
      ]);
      expect(tokens('alice@box:/var/log\$ '), [
        'alice@box:userHost',
        '/var/log:promptPath',
        '\$:promptSign',
      ]);
      expect(tokens('[root@centos7 ~]# systemctl status nginx'), [
        'root@centos7:userHost',
        '~:promptPath',
        '#:promptRoot',
      ]);
      // An e-mail address is not a prompt (no sign), but still user@host.
      expect(tokens('mail bob@example.com now'), ['bob@example.com:userHost']);
    });

    test('network: IPv4 (+port/CIDR), IPv6, MAC, URL', () {
      expect(tokens('10.0.0.5:8080 192.168.0.0/24'), [
        '10.0.0.5:8080:ip',
        '192.168.0.0/24:ip',
      ]);
      expect(tokens('2001:db8::1 fe80::1 aa:bb:cc:dd:ee:ff'), [
        '2001:db8::1:ip',
        'fe80::1:ip',
        'aa:bb:cc:dd:ee:ff:ip',
      ]);
      expect(tokens('inet6 2001:db8::1/64 fe80::1%eth0 ::1 [2001:db8::1]:22'), [
        '2001:db8::1/64:ip',
        'fe80::1%eth0:ip',
        '::1:ip',
        '[2001:db8::1]:22:ip',
      ]);
      expect(tokens('see https://example.com/a?b=c, now'), [
        'https://example.com/a?b=c:url',
      ]);
    });

    test('paths: absolute, relative, home; but not prose or lone slashes', () {
      expect(tokens('cat /etc/hosts ./run.sh ../x ~/notes src/main.rs'), [
        '/etc/hosts:path',
        './run.sh:path',
        '../x:path',
        '~/notes:path',
        'src/main.rs:path',
      ]);
      expect(tokens('and/or / // a'), isEmpty);
      expect(tokens('/etc/passwd: bad'), ['/etc/passwd:path']);
    });

    test('numbers with units, percentages, durations; plain words stay', () {
      expect(tokens('40G 12.5% 300ms 3.5GB 1,024 v1.2.3 52'), [
        '40G:number',
        '12.5%:number',
        '300ms:number',
        '3.5GB:number',
        '1,024:number',
        'v1.2.3:number',
        '52:number',
      ]);
      expect(tokens('3rd 5xx 2fa'), isEmpty);
    });

    test('dates, times, syslog and nginx stamps', () {
      expect(tokens('2026-10-11T12:34:56Z 12:34:56 11/Oct/2026:12:00:00'), [
        '2026-10-11T12:34:56Z:dateTime',
        '12:34:56:dateTime',
        '11/Oct/2026:12:00:00:dateTime',
      ]);
      expect(tokens('Oct 11 12:34:56 host sshd'), [
        'Oct:dateTime',
        '11:number',
        '12:34:56:dateTime',
      ]);
    });

    test('hex digests, 0x values and UUIDs', () {
      expect(
        tokens(
          'commit deadbeef12 at 0x1f id 550e8400-e29b-41d4-a716-446655440000',
        ),
        [
          'deadbeef12:hex',
          '0x1f:hex',
          '550e8400-e29b-41d4-a716-446655440000:hex',
        ],
      );
      expect(tokens('deadbeef'), isEmpty, reason: 'letters only: a word');
    });

    test('quoted strings; apostrophes in words are not quotes', () {
      expect(tokens('say "hello world" and \'x y\''), [
        '"hello world":string',
        "'x y':string",
      ]);
      expect(tokens("don't stop, it's fine"), isEmpty);
      expect(tokens('unterminated "quote 10.0.0.1'), ['10.0.0.1:ip']);
    });

    test('keywords: error/warn/ok/debug, "not found", case-insensitive', () {
      expect(tokens('[ERROR] disk failed: permission denied'), [
        'ERROR:error',
        'failed:error',
        'denied:error',
      ]);
      expect(tokens('bash: foo: command not found'), ['not found:error']);
      expect(tokens('WARN deprecated; Active: active (running)'), [
        'WARN:warn',
        'deprecated:warn',
        'Active:ok',
        'active:ok',
        'running:ok',
      ]);
      expect(tokens('DEBUG started'), ['DEBUG:debug', 'started:ok']);
    });

    test('key=value colours the key and re-reads the value', () {
      expect(tokens('level=warn host=hk-01 used=91% ip=10.1.1.1'), [
        'level:key',
        'warn:warn',
        'host:key',
        'used:key',
        '91%:number',
        'ip:key',
        '10.1.1.1:ip',
      ]);
      expect(tokens('--color=auto path="/a b"'), [
        '--color:key',
        'path:key',
        '"/a b":string',
      ]);
      expect(tokens('see http://x/?a=b'), ['http://x/?a=b:url']);
    });

    test('HTTP status codes follow the protocol token or a status key', () {
      expect(
        tokens('"GET / HTTP/1.1" 200 12 "GET /x HTTP/2.0" 404 "-" status=502'),
        [
          '"GET / HTTP/1.1":string',
          '200:http2xx',
          '12:number',
          '"GET /x HTTP/2.0":string',
          '404:http4xx',
          '"-":string',
          'status:key',
          '502:http5xx',
        ],
      );
      expect(tokens('GET HTTP/1.1 301 302'), ['301:http3xx', '302:number']);
      expect(tokens('code=200 loops 200'), [
        'code:key',
        '200:http2xx',
        '200:number',
      ]);
    });

    test('ls -l: name coloured by file type, link target stays a path', () {
      expect(tokens('drwxr-xr-x  2 root root 4096 Oct 11 12:34 my docs'), [
        '2:number',
        '4096:number',
        'Oct:dateTime',
        '11:number',
        '12:34:dateTime',
        'my docs:dir',
      ]);
      expect(tokens('-rwxr-xr-x  1 root root  812 Oct 11  2025 run.sh'), [
        '1:number',
        '812:number',
        'Oct:dateTime',
        '11:number',
        '2025:number',
        'run.sh:exec',
      ]);
      expect(
        tokens('lrwxrwxrwx 1 root root 11 2026-10-11 12:34 link -> /etc/hosts'),
        [
          '1:number',
          '11:number',
          '2026-10-11:dateTime',
          '12:34:dateTime',
          'link:link',
          '/etc/hosts:path',
        ],
      );
      // plain data file: nothing to colour for the name
      expect(
        tokens('-rw-r--r-- 1 root root 5 Oct 11 12:34 data.txt').last,
        '12:34:dateTime',
      );
    });

    test('comment lines; a prompt being typed on is not a comment', () {
      expect(tokens('# a comment  '), ['# a comment:comment']);
      expect(tokens('// note 10.0.0.1'), ['// note 10.0.0.1:comment']);
      expect(tokens('# ls /etc', cursorLine: true), ['/etc:path']);
      expect(tokens('#!/bin/sh'), ['#!/bin/sh:comment']);
      expect(tokens('#hashtag 10.0.0.1'), ['10.0.0.1:ip']);
    });

    test('invariants on adversarial input: sorted, in range, no overlap', () {
      final rnd = math.Random(42);
      const alphabet =
          'abcXYZ019 .:/\\@#\$%=-_"\'[](){}<>,;!?~|*+&^'
          'rootERRORhttp://:: 10.0.0.1 ';
      for (var n = 0; n < 4000; n++) {
        final len = rnd.nextInt(120);
        final line = String.fromCharCodes([
          for (var i = 0; i < len; i++)
            alphabet.codeUnitAt(rnd.nextInt(alphabet.length)),
        ]);
        var end = 0;
        for (final s in highlightLine(line, cursorLine: n.isEven)) {
          expect(s.start, greaterThanOrEqualTo(end), reason: line);
          expect(s.end, greaterThan(s.start), reason: line);
          expect(s.end, lessThanOrEqualTo(line.length), reason: line);
          expect(
            line.substring(s.start, s.end).trim(),
            isNotEmpty,
            reason: line,
          );
          end = s.end;
        }
      }
    });

    test('only the first $terminalHighlightMaxCells cells are examined', () {
      final line = '${'x ' * 300}10.0.0.1';
      expect(highlightLine(line), isEmpty);
      for (final s in highlightLine('1 ' * 500)) {
        expect(s.end, lessThanOrEqualTo(terminalHighlightMaxCells));
      }
    });

    test('every kind maps to an ANSI slot 0-15', () {
      for (final kind in HlKind.values) {
        expect(terminalHighlightSlot(kind), inInclusiveRange(0, 15));
      }
    });
  });

  group('highlighter on an xterm Terminal', () {
    const slotOk = 2, slotIp = 6;
    int ours(int slot) => TerminalHighlighter.oursFlag | CellColor.named | slot;

    /// Foreground word of the cell at (row, col) in the main buffer.
    int fg(Terminal t, int row, int col) =>
        t.buffer.lines[t.buffer.scrollBack + row].getForeground(col);

    Terminal terminal(String data, {int cols = 80, int rows = 10}) {
      final t = Terminal(maxLines: 5000)..resize(cols, rows);
      t.write(data);
      return t;
    }

    test(
      'colours plain output; text, attributes and backgrounds unchanged',
      () {
        const data =
            'root@h:~# ls /etc\r\n10.0.0.1 ok 12%\r\n\x1b[1mbold 5\x1b[0m\r\n';
        final reference = terminal(data);
        final t = terminal(data);
        final h = TerminalHighlighter(t, enabled: false);
        h.enabled = true;
        expect(h.runPass(), isTrue);
        expect(t.buffer.getText(), reference.buffer.getText());
        var coloured = 0;
        for (var row = 0; row < t.buffer.height; row++) {
          final a = t.buffer.lines[row], b = reference.buffer.lines[row];
          for (var i = 0; i < a.length; i++) {
            expect(a.getContent(i), b.getContent(i));
            expect(a.getBackground(i), b.getBackground(i));
            expect(a.getAttributes(i), b.getAttributes(i));
            if (a.getForeground(i) != b.getForeground(i)) {
              coloured++;
              expect(
                a.getForeground(i) & TerminalHighlighter.oursFlag,
                isNonZero,
              );
              expect(b.getForeground(i), 0);
            }
          }
        }
        expect(coloured, greaterThan(10));
        // "10.0.0.1" is cyan, "ok" green, bold text keeps its attribute.
        expect(fg(t, 1, 0), ours(slotIp));
        expect(fg(t, 1, 9), ours(slotOk));
        expect(fg(t, 2, 5), ours(3)); // "5" yellow
        h.dispose();
      },
    );

    test(
      'remote ANSI colours, backgrounds and inverse cells are untouched',
      () {
        final t = terminal(
          '\x1b[31m10.0.0.1\x1b[0m 10.0.0.2 \x1b[44m10.0.0.3\x1b[0m '
          '\x1b[7m10.0.0.4\x1b[0m \x1b[38;5;208m10.0.0.5\x1b[0m '
          '\x1b[38;2;1;2;3m10.0.0.6\x1b[0m\r\n',
        );
        final reference = terminal(
          '\x1b[31m10.0.0.1\x1b[0m 10.0.0.2 \x1b[44m10.0.0.3\x1b[0m '
          '\x1b[7m10.0.0.4\x1b[0m \x1b[38;5;208m10.0.0.5\x1b[0m '
          '\x1b[38;2;1;2;3m10.0.0.6\x1b[0m\r\n',
        );
        final h = TerminalHighlighter(t)..runPass();
        final line = t.buffer.lines[0], base = reference.buffer.lines[0];
        for (var i = 0; i < 9; i++) {
          expect(line.getForeground(i), base.getForeground(i), reason: '$i');
        }
        // second address (plain) is coloured, the others are not
        expect(line.getForeground(10), ours(slotIp));
        for (final start in [20, 31, 42, 53]) {
          for (var i = start; i < start + 8; i++) {
            expect(
              line.getForeground(i),
              base.getForeground(i),
              reason: 'col $i',
            );
          }
        }
        expect(t.buffer.getText(), reference.buffer.getText());
        h.dispose();
      },
    );

    test('alternate screen is never touched; main buffer resumes after', () {
      final t = terminal('error 10.0.0.1\r\n');
      final h = TerminalHighlighter(t);
      h.runPass();
      expect(fg(t, 0, 0), ours(1));
      t.write('\x1b[?1049h\x1b[Hfailed 10.0.0.2 ok');
      expect(t.isUsingAltBuffer, isTrue);
      final before = h.processedRows;
      expect(h.runPass(), isTrue);
      expect(h.processedRows, before);
      for (var i = 0; i < t.altBuffer.lines[0].length; i++) {
        expect(
          t.altBuffer.lines[0].getForeground(i) & TerminalHighlighter.oursFlag,
          0,
        );
      }
      t.write('\x1b[?1049l\r\nnext ok\r\n');
      expect(t.isUsingAltBuffer, isFalse);
      h.runPass();
      expect(
        t.buffer.lines[t.buffer.scrollBack + 2].getForeground(5),
        ours(slotOk),
      );
      h.dispose();
    });

    test('rewritten and edited rows never keep stale colours', () {
      final t = terminal('error 10.0.0.1 done');
      final h = TerminalHighlighter(t)..runPass();
      expect(fg(t, 0, 0), ours(1));
      // Remote redraws the row in plain text of a different shape.
      t.write('\r\x1b[2Kplain words here');
      h.runPass();
      final line = t.buffer.lines[t.buffer.scrollBack];
      for (var i = 0; i < 17; i++) {
        expect(line.getForeground(i), 0, reason: 'col $i');
      }
      // Remote applies its own colour over previously highlighted cells.
      t.write('\r\n10.0.0.9\r');
      h.runPass();
      expect(fg(t, 1, 0), ours(slotIp));
      t.write('\x1b[32mXX\x1b[0m');
      h.runPass();
      expect(
        fg(t, 1, 0),
        CellColor.named | 2,
        reason: 'remote colour wins, flag gone',
      );
      h.dispose();
    });

    test('turning it off removes every colour; turning on restores', () {
      const data = 'root@h:~# cat log\r\nerror 10.0.0.1 done 4G\r\n';
      final reference = terminal(data);
      final t = terminal(data);
      final h = TerminalHighlighter(t)..runPass();
      expect(fg(t, 1, 0), isNot(0));
      h.enabled = false;
      for (var row = 0; row < t.buffer.height; row++) {
        final a = t.buffer.lines[row], b = reference.buffer.lines[row];
        for (var i = 0; i < a.length; i++) {
          expect(a.getForeground(i), b.getForeground(i));
        }
      }
      h.runPass(); // disabled: no-op
      expect(fg(t, 1, 0), 0);
      h.enabled = true;
      h.runPass();
      expect(fg(t, 1, 0), ours(1));
      h.dispose();
    });

    test('cursor row: a minimal "# " prompt is not turned into a comment', () {
      final t = terminal('# ls /etc');
      final h = TerminalHighlighter(t)..runPass();
      expect(fg(t, 0, 0), 0);
      expect(fg(t, 0, 5), ours(4));
      t.write('\r\n');
      h.runPass();
      expect(fg(t, 0, 0), ours(8), reason: 'finished line is a comment');
      h.dispose();
    });

    test('streams through the listener without a manual pass', () async {
      final t = terminal('');
      final h = TerminalHighlighter(t);
      t.write('error 10.0.0.1\r\n');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(fg(t, 0, 0), ours(1));
      expect(fg(t, 0, 6), ours(slotIp));
      h.dispose();
      t.write('fail\r\n');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(fg(t, 1, 0), 0, reason: 'disposed highlighter is detached');
    });

    test('big output: only rows near the viewport are processed, fast', () {
      final t = Terminal(maxLines: 3000)..resize(100, 40);
      final sb = StringBuffer();
      for (var i = 0; i < 20000; i++) {
        sb.write(
          'line $i 10.0.${i % 255}.1 error=0 took ${i % 900}ms /var/log/x$i\r\n',
        );
      }
      t.write(sb.toString());
      final h = TerminalHighlighter(t);
      final watch = Stopwatch()..start();
      expect(h.runPass(), isTrue);
      watch.stop();
      expect(h.processedRows, lessThanOrEqualTo(40 + 12 + 1));
      // processedRows is the real guard; the time bound only catches a
      // gross regression and leaves room for slow shared CI runners.
      expect(watch.elapsedMilliseconds, lessThan(1000));
      // unchanged viewport: the second pass tokenizes nothing
      final done = h.processedRows;
      h.runPass();
      expect(h.processedRows, done);
      // a scroll into history processes just that window
      final custom = TerminalHighlighter(
        t,
        visibleLines: () => (first: 100, last: 139),
      )..runPass();
      expect(custom.processedRows, lessThanOrEqualTo(40 + 12 + 1));
      h.dispose();
      custom.dispose();
    });

    test('a pass honours its time budget and asks to continue', () {
      final t = Terminal(maxLines: 3000)..resize(120, 40);
      final sb = StringBuffer();
      for (var i = 0; i < 200; i++) {
        sb.write('error ${'10.0.0.1 /var/log/x 12% ' * 4}\r\n');
      }
      t.write(sb.toString());
      final h = TerminalHighlighter(t, budget: Duration.zero, margin: 100);
      expect(h.runPass(), isFalse);
      expect(h.processedRows, lessThan(100));
      h.dispose();
    });
  });
}
