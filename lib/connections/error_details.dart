import '../l10n/generated/app_localizations.dart';
import '../l10n/localized_message.dart';
import '../security/security_models.dart';

/// Where a connection attempt stopped. Shown as "What failed".
enum ErrorStage {
  /// Reading the credential or key, or checking the target, before any I/O.
  setup,

  /// Name resolution and the TCP connection to the target.
  connect,

  /// Dialling the proxy or its CONNECT / SOCKS5 exchange.
  proxy,

  /// TLS to an HTTPS proxy.
  proxyTls,
  handshake,
  hostKey,
  authentication,

  /// Opening the terminal channel (PTY + shell).
  shell,
  sftp,

  /// After the session was up: remote close, write failure.
  session;

  String label(AppLocalizations l10n) => switch (this) {
    setup => l10n.r14StageSetup,
    connect => l10n.r14StageConnect,
    proxy => l10n.r14StageProxy,
    proxyTls => l10n.r14StageProxyTls,
    handshake => l10n.r14StageHandshake,
    hostKey => l10n.r14StageHostKey,
    authentication => l10n.r14StageAuthentication,
    shell => l10n.r14StageShell,
    sftp => l10n.r14StageSftp,
    session => l10n.r14StageSession,
  };
}

/// The original error behind a friendly message, kept so the user can read
/// (and copy) what actually went wrong.
///
/// In memory only: it is never written to the database, a log or an export.
/// The technical text is redacted when the object is created, so no code path
/// can display or copy an unredacted version.
class ErrorDetails {
  ErrorDetails({
    required this.stage,
    required String technical,
    this.target,
    this.proxy,
    DateTime? time,
    Iterable<String> secrets = const [],
  }) : technical = redactSecrets(technical, secrets: secrets),
       time = time ?? DateTime.now();

  /// [error] is described as `Type: message` (the type is not repeated when
  /// the error's own text already starts with it, as `SocketException` does).
  factory ErrorDetails.from(
    Object error, {
    required ErrorStage stage,
    String? target,
    String? proxy,
    DateTime? time,
    Iterable<String> secrets = const [],
    String? note,
  }) => ErrorDetails(
    stage: stage,
    technical: [describeError(error), ?note].join('\n'),
    target: target,
    proxy: proxy,
    time: time,
    secrets: secrets,
  );

  final ErrorStage stage;

  /// `user@host:port` (IPv6 bracketed), when there is a target.
  final String? target;

  /// Proxy name / type / address, when the attempt went through one.
  final String? proxy;
  final DateTime time;

  /// Redacted raw text: exception type and message, protocol replies.
  final String technical;

  ErrorDetails copyWith({
    ErrorStage? stage,
    String? target,
    String? proxy,
    String? technical,
  }) => ErrorDetails(
    stage: stage ?? this.stage,
    technical: technical ?? this.technical,
    target: target ?? this.target,
    proxy: proxy ?? this.proxy,
    time: time,
  );

  String timeText() {
    String two(int v) => v.toString().padLeft(2, '0');
    final t = time.toLocal();
    final offset = t.timeZoneOffset;
    final minutes = offset.inMinutes.abs();
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)} '
        '${offset.isNegative ? '-' : '+'}${two(minutes ~/ 60)}:${two(minutes % 60)}';
  }

  /// Plain text for the clipboard (what the sheet shows).
  String report(AppLocalizations l10n) => [
    l10n.r14ErrorDetails,
    '${l10n.r14ErrorStage}: ${stage.label(l10n)}',
    if (target != null) '${l10n.r14ErrorTarget}: $target',
    if (proxy != null) '${l10n.r14ErrorProxy}: $proxy',
    '${l10n.r14ErrorTime}: ${timeText()}',
    '',
    technical,
  ].join('\n');

  @override
  String toString() => 'ErrorDetails(${stage.name})';
}

/// A connection failure that keeps the original error next to the friendly,
/// localized message. Every existing mapping keeps its text; only callers
/// that know the stage and the raw error use this subtype.
class ConnectionFailure extends SecurityFailure {
  ConnectionFailure(
    LocalizedMessage super.details, {
    required this.stage,
    required this.technical,
  });
  final ErrorStage stage;

  /// Raw, not yet redacted; [ErrorDetails] redacts it on creation.
  final String technical;
}

/// `Type: message`, without repeating the type when the text has it already.
String describeError(Object error) {
  // FormatException.toString quotes a slice of the parsed source (which may be
  // a key); only its message is kept.
  if (error is FormatException) return 'FormatException: ${error.message}';
  final type = error.runtimeType.toString();
  final text = error.toString();
  return text.startsWith(type) ? text : '$type: $text';
}

const _redacted = '[REDACTED]';

/// Removes secrets from [text] before it is displayed or copied:
/// PEM blocks (also a truncated one), the values in [secrets], `Authorization`
/// and `Proxy-Authorization` header values, `user:password@` in URLs,
/// `password=` / `passphrase=` style pairs and long base64 runs (key bodies).
String redactSecrets(String text, {Iterable<String> secrets = const []}) {
  var out = text;
  out = out.replaceAll(
    RegExp(r'-----BEGIN [A-Z0-9 ]+-----[\s\S]*?(?:-----END [A-Z0-9 ]+-----|$)'),
    '[REDACTED PEM]',
  );
  out = out.replaceAllMapped(
    RegExp(r'((?:proxy-)?authorization\s*:)[^\r\n]*', caseSensitive: false),
    (m) => '${m[1]} $_redacted',
  );
  out = out.replaceAllMapped(
    RegExp(r'([A-Za-z][A-Za-z0-9+.\-]*://)[^\s/@]*@'),
    (m) => '${m[1]}$_redacted@',
  );
  out = out.replaceAllMapped(
    RegExp(
      r'''((?:password|passwd|passphrase|secret|token)["']?\s*=\s*)("[^"]*"|'[^']*'|[^\s,;&]+)''',
      caseSensitive: false,
    ),
    (m) => '${m[1]}$_redacted',
  );
  // Anything that still looks like a key body (long base64 run).
  out = out.replaceAll(
    RegExp(r'[A-Za-z0-9+/]{60,}={0,2}'),
    '[REDACTED BASE64]',
  );
  final known = secrets.where((s) => s.isNotEmpty).toSet().toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final secret in known) {
    out = secret.length >= 4
        ? out.replaceAll(secret, _redacted)
        // Very short values would wreck ordinary words; mask whole tokens.
        : out.replaceAllMapped(
            RegExp('(?<![A-Za-z0-9])${RegExp.escape(secret)}(?![A-Za-z0-9])'),
            (_) => _redacted,
          );
  }
  return out;
}
