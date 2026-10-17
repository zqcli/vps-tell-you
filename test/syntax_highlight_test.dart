import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/connections/sftp_editor_page.dart';
import 'package:vps_tell_you/connections/syntax_highlight.dart';
import 'package:vps_tell_you/connections/syntax_highlight_controller.dart';
import 'package:vps_tell_you/connections/terminal_scheme.dart';
import 'package:vps_tell_you/core/app_theme.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations.dart';
import 'package:vps_tell_you/l10n/generated/app_localizations_zh.dart';

import 'support/fake_sftp_session.dart';
import 'terminal_scheme_test.dart' show contrast;

/// "text:kind" for every token of a multi-line [text].
List<String> lex(SynLang lang, String text) {
  final out = <String>[];
  var state = 0;
  for (final line in text.split('\n')) {
    final r = lexLine(lang, line, state);
    state = r.state;
    for (final t in r.toks) {
      out.add('${line.substring(t.start, t.end)}:${t.kind.name}');
    }
  }
  return out;
}

/// All lines of [text] lexed, with the carried states.
List<(String, LexResult)> lexAll(SynLang lang, String text) {
  final out = <(String, LexResult)>[];
  var state = 0;
  for (final line in text.split('\n')) {
    final r = lexLine(lang, line, state);
    out.add((line, r));
    state = r.state;
  }
  return out;
}

Future<TextSpan> build(
  WidgetTester tester,
  SyntaxHighlightController c, {
  bool composing = false,
}) async {
  late TextSpan span;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        span = c.buildTextSpan(
          context: context,
          style: const TextStyle(fontSize: 14),
          withComposing: composing,
        );
        return const SizedBox();
      },
    ),
  );
  return span;
}

void main() {
  group('language detection', () {
    SynLang d(String name, {String? path, String text = ''}) =>
        detectLanguage(name: name, path: path ?? '/x/$name', text: text);

    test('by file name and extension', () {
      expect(d('deploy.sh'), SynLang.shell);
      expect(d('.bashrc'), SynLang.shell);
      expect(d('.zshrc'), SynLang.shell);
      expect(d('.profile'), SynLang.shell);
      expect(d('docker-compose.yml'), SynLang.yaml);
      expect(d('values.YAML'), SynLang.yaml);
      expect(d('config.json'), SynLang.json);
      expect(d('tsconfig.jsonc'), SynLang.json);
      expect(d('app.py'), SynLang.python);
      expect(d('index.js'), SynLang.javascript);
      expect(d('main.tsx'), SynLang.javascript);
      expect(d('README.md'), SynLang.markdown);
      expect(d('index.html'), SynLang.markup);
      expect(d('feed.xml'), SynLang.markup);
      expect(d('schema.sql'), SynLang.sql);
      expect(d('Dockerfile'), SynLang.dockerfile);
      expect(d('Dockerfile.prod'), SynLang.dockerfile);
      expect(d('api.dockerfile'), SynLang.dockerfile);
      expect(d('.env'), SynLang.ini);
      expect(d('.env.production'), SynLang.ini);
      expect(d('my.service'), SynLang.ini);
      expect(d('php.ini'), SynLang.ini);
      expect(d('sshd_config'), SynLang.ini);
      expect(d('notes.txt'), SynLang.generic);
      expect(d('Makefile'), SynLang.generic);
    });

    test('nginx by name, directory, or content', () {
      expect(d('nginx.conf'), SynLang.nginx);
      expect(
        d('default.conf', path: '/etc/nginx/conf.d/default.conf'),
        SynLang.nginx,
      );
      expect(
        d('mysite', path: '/etc/nginx/sites-available/mysite'),
        SynLang.nginx,
      );
      expect(d('x.conf', text: 'server {\n listen 80;\n}\n'), SynLang.nginx);
      expect(d('app.conf', text: 'key = value\n'), SynLang.ini);
    });

    test('shebang and content sniffing for files without an extension', () {
      expect(d('run', text: '#!/bin/bash\necho hi'), SynLang.shell);
      expect(d('run', text: '#!/usr/bin/env zsh\n'), SynLang.shell);
      expect(d('run', text: '#!/bin/sh\n'), SynLang.shell);
      expect(d('tool', text: '#!/usr/bin/env python3\n'), SynLang.python);
      expect(d('tool', text: '#!/usr/bin/env node\n'), SynLang.javascript);
      expect(d('tool', text: '#!/usr/bin/perl\n'), SynLang.generic);
      expect(d('data', text: '{"a": 1}'), SynLang.json);
      expect(d('page', text: '<?xml version="1.0"?>'), SynLang.markup);
      expect(d('plain', text: 'just words'), SynLang.generic);
    });
  });

  group('lexers', () {
    test('shell: shebang, keywords, variables, flags, operators, strings', () {
      expect(lex(SynLang.shell, '#!/bin/bash'), ['#!/bin/bash:meta']);
      expect(
        lex(
          SynLang.shell,
          'NAME="a-\$USER" # c\n'
          'if [ -f /x ]; then echo "\${NAME}" | grep -v y >> o; fi',
        ),
        [
          'NAME:variable',
          '"a-:string',
          '\$USER:variable',
          '":string',
          '# c:comment',
          'if:keyword',
          '-f:attribute',
          ';:operator',
          'then:keyword',
          'echo:builtin',
          '":string',
          '\${NAME}:variable',
          '":string',
          '|:operator',
          'grep:builtin',
          '-v:attribute',
          '>>:operator',
          ';:operator',
          'fi:keyword',
        ],
      );
      // single quotes are raw: no escape handling, no variables
      expect(lex(SynLang.shell, "echo 'a\\' \$X"), [
        'echo:builtin',
        "'a\\':string",
        '\$X:variable',
      ]);
      // a # inside a word is not a comment
      expect(lex(SynLang.shell, 'echo a#b'), ['echo:builtin']);
    });

    test('yaml: keys, lists, scalars, anchors, block scalars, comments', () {
      expect(
        lex(
          SynLang.yaml,
          'services:\n'
          '  web:\n'
          '    image: nginx:latest\n'
          '    ports:\n'
          '      - "80:80"\n'
          '    debug: true # why\n'
          '    n: 12\n'
          '    cmd: |\n'
          '      echo # not a comment\n'
          '    next: &a x\n'
          '# tail',
        ),
        [
          'services:key',
          'web:key',
          'image:key',
          'nginx:latest:string',
          'ports:key',
          '-:operator',
          '"80:80":string',
          'debug:key',
          'true:constant',
          '# why:comment',
          'n:key',
          '12:number',
          'cmd:key',
          '|:operator',
          'echo # not a comment:string',
          'next:key',
          '&a:variable',
          'x:string',
          '# tail:comment',
        ],
      );
    });

    test('json: keys vs strings, numbers, constants', () {
      expect(lex(SynLang.json, '{"a": [1, -2.5e3, true, null, "s"]}'), [
        '"a":key',
        '1:number',
        '2.5e3:number',
        'true:constant',
        'null:constant',
        '"s":string',
      ]);
    });

    test('ini / env / systemd / key-value conf', () {
      expect(
        lex(
          SynLang.ini,
          '[Service]\n# c\nExecStart=/bin/x --p 80\nPort 22\n'
          'export A="b c"\nR=always ; trailing',
        ),
        [
          '[Service]:heading',
          '# c:comment',
          'ExecStart:key',
          '=:operator',
          '80:number',
          'Port:key',
          '22:number',
          'export:keyword',
          'A:key',
          '=:operator',
          '"b c":string',
          'R:key',
          '=:operator',
          '; trailing:comment',
        ],
      );
    });

    test('nginx: block/directive keywords, variables, units, comments', () {
      expect(
        lex(
          SynLang.nginx,
          'server {\n  listen 80;\n  location /a/ { proxy_pass http://h; }\n'
          '  client_max_body_size 10m; # c\n  gzip on;\n'
          '  add_header X "v \$host";\n}',
        ),
        [
          'server:keyword',
          'listen:builtin',
          '80:number',
          'location:keyword',
          'proxy_pass:builtin',
          'client_max_body_size:builtin',
          '10m:number',
          '# c:comment',
          'gzip:builtin',
          'on:constant',
          'add_header:builtin',
          '"v :string',
          '\$host:variable',
          '":string',
        ],
      );
    });

    test(
      'dockerfile: instructions only at line start, continuation, flags',
      () {
        expect(
          lex(
            SynLang.dockerfile,
            'FROM x AS b\nRUN a && \\\n  RUN b\nCOPY --from=b /a /b\n# c',
          ),
          [
            'FROM:keyword',
            'AS:keyword',
            'RUN:keyword',
            'COPY:keyword',
            '--from:attribute',
            '# c:comment',
          ],
        );
      },
    );

    test('python: triple-quoted strings span lines, decorators, defs', () {
      expect(
        lex(
          SynLang.python,
          '@app.get("/")\n'
          'def run(self, n=3):\n'
          '    """doc\n'
          '    more # not comment"""\n'
          '    return None  # c',
        ),
        [
          '@app.get:meta',
          '"/":string',
          'def:keyword',
          'run:builtin',
          'self:variable',
          '3:number',
          '"""doc:string',
          '    more # not comment""":string',
          'return:keyword',
          'None:keyword',
          '# c:comment',
        ],
      );
      expect(
        lexAll(SynLang.python, 'x = """a\nb\nc"""\ny').map((e) => e.$2.state),
        [3, 3, 0, 0],
      );
    });

    test('javascript: block comments and template literals span lines', () {
      final all = lexAll(
        SynLang.javascript,
        '/* a\nb */ let x = `t\n\${x}` + 1; // end',
      );
      expect(all.map((e) => e.$2.state), [1, 6, 0]);
      expect(
        lex(
          SynLang.javascript,
          'class Foo extends Bar { f() { return true; } }',
        ),
        [
          'class:keyword',
          'Foo:type',
          'extends:keyword',
          'Bar:type',
          'f:builtin',
          'return:keyword',
          'true:constant',
        ],
      );
    });

    test('markdown: headings, lists, fences, inline code, links', () {
      expect(
        lex(
          SynLang.markdown,
          '# T\n- a **b** `c`\n```sh\nls # x\n```\n[l](http://u) end',
        ),
        [
          '# T:heading',
          '-:operator',
          '**b**:keyword',
          '`c`:string',
          '```sh:meta',
          'ls # x:string',
          '```:meta',
          '[l]:key',
          '(http://u):variable',
        ],
      );
    });

    test('markup: tags, attributes, comments and tags across lines', () {
      expect(
        lex(SynLang.markup, '<!-- c\nd -->\n<a href="x"\n  id=y>t &amp; u</a>'),
        [
          '<!-- c:comment',
          'd -->:comment',
          '<a:tag',
          'href:attribute',
          '"x":string',
          'id:attribute',
          'y:attribute',
          '>:tag',
          '&amp;:constant',
          '</a:tag',
          '>:tag',
        ],
      );
    });

    test('sql: case-insensitive keywords, calls, strings, comments', () {
      expect(
        lex(
          SynLang.sql,
          "select count(*) from t where a = 'x' -- c\n/* b\n c */ limit 1;",
        ),
        [
          'select:keyword',
          'count:builtin',
          'from:keyword',
          'where:keyword',
          "'x':string",
          '-- c:comment',
          '/* b:comment',
          ' c */:comment',
          'limit:keyword',
          '1:number',
        ],
      );
    });

    test(
      'generic fallback: comments, strings, numbers; apostrophes are ok',
      () {
        expect(lex(SynLang.generic, '# c\n// d\nk "v" 42 don\'t /* e */'), [
          '# c:comment',
          '// d:comment',
          '"v":string',
          '42:number',
          '/* e */:comment',
        ]);
      },
    );

    test('invariants on adversarial input for every language', () {
      final rnd = math.Random(7);
      const alphabet =
          'abcXYZ019 \t"\'`\\#\$@{}[]()<>/*-=:;,.!&|%+_~'
          'defclassreturnSELECTFROMtrue\n';
      for (final lang in SynLang.values) {
        for (var n = 0; n < 300; n++) {
          final text = String.fromCharCodes([
            for (var i = 0; i < rnd.nextInt(400); i++)
              alphabet.codeUnitAt(rnd.nextInt(alphabet.length)),
          ]);
          for (final (line, r) in lexAll(lang, text)) {
            var end = 0;
            for (final t in r.toks) {
              expect(t.start, greaterThanOrEqualTo(end), reason: '$lang $line');
              expect(t.end, greaterThan(t.start), reason: '$lang $line');
              expect(t.end, lessThanOrEqualTo(line.length), reason: '$lang');
              end = t.end;
            }
          }
        }
      }
    });
  });

  group('code theme', () {
    test('follows the app brightness, preferring the chosen scheme', () {
      expect(
        CodeTheme.forApp(catppuccinMocha, Brightness.dark).scheme,
        catppuccinMocha,
      );
      expect(
        CodeTheme.forApp(githubLight, Brightness.dark).scheme.isDark,
        isTrue,
      );
      expect(CodeTheme.forApp(dracula, Brightness.light).scheme, githubLight);
      expect(
        CodeTheme.forApp(githubLight, Brightness.light).scheme,
        githubLight,
      );
    });

    test('every token colour is readable on every scheme background', () {
      for (final scheme in TerminalScheme.all) {
        final theme = CodeTheme(scheme);
        for (final kind in SynKind.values) {
          expect(
            contrast(theme.color(kind), theme.background),
            greaterThanOrEqualTo(3),
            reason: '${scheme.name} ${kind.name}',
          );
        }
        expect(
          contrast(theme.foreground, theme.background),
          greaterThanOrEqualTo(7),
        );
      }
    });
  });

  group('controller', () {
    final theme = CodeTheme(tokyoNight);

    testWidgets('visible text is identical for every language', (tester) async {
      final samples = {
        SynLang.shell:
            '#!/bin/sh\nif [ -f "\$A" ]; then\n  echo "é中 \$B"\nfi\n',
        SynLang.python: 'x = """a\nb"""\r\ndef f():\n\treturn 1\n\n',
        SynLang.yaml: 'a: |\n  x\n\nb: [1, 2]\n',
        SynLang.markup: '<a\n b="1">\n</a>\n',
        SynLang.javascript: 'let t = `a\nb`;\n',
        SynLang.plain: 'anything',
      };
      for (final e in samples.entries) {
        final c = SyntaxHighlightController(
          text: e.value,
          language: e.key,
          theme: theme,
        );
        final span = await build(tester, c);
        expect(span.toPlainText(), e.value, reason: '${e.key}');
        c.dispose();
      }
    });

    testWidgets('colours come from the scheme palette', (tester) async {
      final c = SyntaxHighlightController(
        text: 'if x: # c',
        language: SynLang.python,
        theme: theme,
      );
      final span = await build(tester, c);
      final colours = <String, Color?>{};
      span.visitChildren((s) {
        if (s is TextSpan && s.text != null && s.style?.color != null) {
          colours[s.text!] = s.style!.color;
        }
        return true;
      });
      expect(colours['if'], tokyoNight.theme.magenta);
      expect(colours['# c'], tokyoNight.theme.brightBlack);
    });

    testWidgets('IME composing and plain mode defer to the framework', (
      tester,
    ) async {
      final c = SyntaxHighlightController(
        text: 'abc',
        language: SynLang.python,
        theme: theme,
      );
      c.value = const TextEditingValue(
        text: 'abc',
        composing: TextRange(start: 0, end: 3),
      );
      final composing = await build(tester, c, composing: true);
      expect(composing.toPlainText(), 'abc');
      expect(composing.children!.length, lessThanOrEqualTo(3));
      c.language = SynLang.plain;
      expect(c.highlighting, isFalse);
      final plain = await build(tester, c);
      expect(plain.toPlainText(), 'abc');
    });

    testWidgets('editing re-lexes only the changed line', (tester) async {
      final lines = [for (var i = 0; i < 3000; i++) 'x$i = "v$i"  # c$i'];
      final c = SyntaxHighlightController(
        text: lines.join('\n'),
        language: SynLang.python,
        theme: theme,
      );
      await build(tester, c);
      expect(c.lexedLines, 3000);
      lines[1500] = 'y = 1';
      c.text = lines.join('\n');
      await build(tester, c);
      expect(c.lexedLines, 1);
      // appending and deleting lines reuses everything unchanged
      lines.add('z = 2');
      c.text = lines.join('\n');
      await build(tester, c);
      expect(c.lexedLines, 1);
      lines.removeAt(10);
      c.text = lines.join('\n');
      final span = await build(tester, c);
      expect(c.lexedLines, lessThanOrEqualTo(1));
      expect(span.toPlainText(), lines.join('\n'));
    });

    testWidgets('a selection move reuses the identical span', (tester) async {
      final c = SyntaxHighlightController(
        text: 'a = 1\nb = 2',
        language: SynLang.python,
        theme: theme,
      );
      final first = await build(tester, c);
      c.selection = const TextSelection.collapsed(offset: 3);
      expect(await build(tester, c), same(first));
      expect(c.lexedLines, 0);
      c.language = SynLang.plain;
      c.language = SynLang.python;
      expect(await build(tester, c), isNot(same(first)));
      c.text = 'a = 1\nb = 3';
      expect((await build(tester, c)).toPlainText(), 'a = 1\nb = 3');
    });

    testWidgets('a carried state re-lexes until it converges again', (
      tester,
    ) async {
      final lines = ['a = 1', 'b = """x', 'c', 'd"""', 'e = 2', 'f = 3'];
      final c = SyntaxHighlightController(
        text: lines.join('\n'),
        language: SynLang.python,
        theme: theme,
      );
      await build(tester, c);
      // Open a docstring earlier: everything below changes colour...
      lines[0] = 'a = """';
      c.text = lines.join('\n');
      var span = await build(tester, c);
      expect(c.lexedLines, greaterThan(1));
      expect(span.toPlainText(), lines.join('\n'));
      // ...and closing it again restores the original layout.
      lines[0] = 'a = 1';
      c.text = lines.join('\n');
      span = await build(tester, c);
      expect(span.toPlainText(), lines.join('\n'));
      final all = lexAll(SynLang.python, lines.join('\n'));
      expect(all.map((e) => e.$2.state), [0, 3, 3, 0, 0, 0]);
    });

    testWidgets('changing language or theme rebuilds the colours', (
      tester,
    ) async {
      final c = SyntaxHighlightController(
        text: 'SELECT 1',
        language: SynLang.generic,
        theme: theme,
      );
      await build(tester, c);
      var notified = 0;
      c.addListener(() => notified++);
      c.language = SynLang.sql;
      c.theme = CodeTheme(githubLight);
      expect(notified, 2);
      final span = await build(tester, c);
      expect(c.lexedLines, 1);
      Color? select;
      span.visitChildren((s) {
        if (s is TextSpan && s.text == 'SELECT') select = s.style?.color;
        return true;
      });
      expect(select, githubLight.theme.magenta);
    });

    testWidgets('size budget: 250 KiB stays interactive, 500 KiB stays plain', (
      tester,
    ) async {
      String file(int bytes) {
        final sb = StringBuffer();
        var i = 0;
        while (sb.length < bytes) {
          sb.writeln('    value_$i = compute(a, "text $i", 0x$i) # note $i');
          i++;
        }
        return sb.toString();
      }

      final big = file(250 * 1024);
      expect(big.length, lessThanOrEqualTo(syntaxHighlightMaxChars));
      final c = SyntaxHighlightController(
        text: big,
        language: SynLang.python,
        theme: theme,
      );
      final first = Stopwatch()..start();
      await build(tester, c);
      first.stop();
      expect(c.highlighting, isTrue);
      // one keystroke in the middle of a 256 KiB file
      final text = c.text;
      final mid = text.length ~/ 2;
      c.text = '${text.substring(0, mid)}x${text.substring(mid)}';
      final typing = Stopwatch()..start();
      late TextSpan span;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            span = c.buildTextSpan(
              context: context,
              style: null,
              withComposing: false,
            );
            return const SizedBox();
          },
        ),
      );
      typing.stop();
      expect(c.lexedLines, lessThanOrEqualTo(2));
      expect(span.toPlainText(), c.text);
      // Generous CI budgets; measured on a laptop: ~50 ms cold, ~5 ms per keystroke.
      expect(first.elapsedMilliseconds, lessThan(3000));
      expect(typing.elapsedMilliseconds, lessThan(250));

      final huge = SyntaxHighlightController(
        text: file(500 * 1024),
        language: SynLang.python,
        theme: theme,
      );
      expect(huge.tooLarge, isTrue);
      expect(huge.highlighting, isFalse);
      final watch = Stopwatch()..start();
      final plain = await build(tester, huge);
      watch.stop();
      expect(plain.children, anyOf(isNull, isEmpty));
      expect(plain.toPlainText(), huge.text);
      expect(huge.lexedLines, 0);
      expect(watch.elapsedMilliseconds, lessThan(250));
    });
  });

  group('editor page', () {
    late FakeSftpSession fake;
    final zh = AppLocalizationsZh();

    setUp(() {
      terminalSchemeChoice.value = TerminalScheme.defaultScheme;
      fake = FakeSftpSession()
        ..dir('/etc')
        ..dir('/etc/nginx');
    });

    Future<void> open(
      WidgetTester tester,
      String path,
      String text, {
      Brightness brightness = Brightness.light,
    }) async {
      fake.file(path, text);
      final file = await fake.readText(path);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(brightness: brightness),
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: SftpTextEditorPage(
            session: fake,
            path: path,
            name: path.split('/').last,
            file: file,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    SyntaxHighlightController controller(WidgetTester tester) =>
        tester
                .widget<TextField>(
                  find.byKey(const ValueKey('sftp-editor-field')),
                )
                .controller!
            as SyntaxHighlightController;

    testWidgets('subtitle names the detected language; ⋯ switches or turns '
        'highlighting off', (tester) async {
      await open(tester, '/etc/nginx/nginx.conf', 'server {\n listen 80;\n}\n');
      expect(find.textContaining('nginx · '), findsOneWidget);
      expect(controller(tester).language, SynLang.nginx);
      await tester.tap(find.byKey(const ValueKey('sftp-editor-more')));
      await tester.pumpAndSettle();
      expect(find.text(zh.r4HlAuto), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('sftp-lang-python')),
      );
      await tester.tap(find.byKey(const ValueKey('sftp-lang-python')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Python · '), findsOneWidget);
      expect(controller(tester).language, SynLang.python);
      await tester.tap(find.byKey(const ValueKey('sftp-editor-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sftp-lang-plain')));
      await tester.pumpAndSettle();
      expect(find.textContaining('${zh.r4HlPlain} · '), findsOneWidget);
      expect(controller(tester).highlighting, isFalse);
      await tester.tap(find.byKey(const ValueKey('sftp-editor-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sftp-lang-auto')));
      await tester.pumpAndSettle();
      expect(controller(tester).language, SynLang.nginx);
      expect(controller(tester).highlighting, isTrue);
    });

    testWidgets('the code block follows the app light/dark mode', (
      tester,
    ) async {
      terminalSchemeChoice.value = dracula;
      await open(tester, '/etc/a.sh', 'echo hi', brightness: Brightness.light);
      expect(controller(tester).theme!.scheme, githubLight);
      await open(tester, '/etc/a.sh', 'echo hi', brightness: Brightness.dark);
      expect(controller(tester).theme!.scheme, dracula);
    });

    testWidgets('files over the cap stay plain and say so', (tester) async {
      final text = 'x = 1\n' * 50000;
      await open(tester, '/etc/big.py', text);
      expect(controller(tester).tooLarge, isTrue);
      expect(find.textContaining(zh.r4HlTooLarge), findsOneWidget);
      expect(controller(tester).highlighting, isFalse);
    });

    testWidgets('editing and saving behave as before', (tester) async {
      await open(tester, '/etc/a.sh', 'echo hi\n');
      await tester.enterText(
        find.byKey(const ValueKey('sftp-editor-field')),
        'echo bye\n',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sftp-editor-save')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(fake.text('/etc/a.sh'), 'echo bye\n');
      expect(find.text(zh.r3SftpSaved), findsOneWidget);
    });
  });
}
