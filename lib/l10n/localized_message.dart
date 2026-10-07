import 'generated/app_localizations.dart';
import 'locale_preference.dart';

/// Safe app-authored messages resolve at display time, so changing language
/// never requires retrying a network operation or discarding an error state.
/// Never wrap native/transport errors or user-provided text in a message.
abstract interface class LocalizedMessage {
  String messageFor(AppLocalizations l10n);
}

typedef MessageBuilder = String Function(AppLocalizations l10n);

class LocalizedText implements LocalizedMessage {
  const LocalizedText(this.builder);
  final MessageBuilder builder;
  @override
  String messageFor(AppLocalizations l10n) => builder(l10n);
  @override
  String toString() => messageFor(defaultLocalizations);
}

class LocalizedArgumentError extends ArgumentError implements LocalizedMessage {
  LocalizedArgumentError(this.builder);
  final MessageBuilder builder;
  @override
  String get message => messageFor(defaultLocalizations);
  @override
  String messageFor(AppLocalizations l10n) => builder(l10n);
}

class LocalizedFormatException implements FormatException, LocalizedMessage {
  const LocalizedFormatException(this.builder);
  final MessageBuilder builder;
  @override
  String get message => messageFor(defaultLocalizations);
  @override
  Object? get source => null;
  @override
  int? get offset => null;
  @override
  String messageFor(AppLocalizations l10n) => builder(l10n);
  @override
  String toString() => 'FormatException: $message';
}

class LocalizedStateError extends StateError implements LocalizedMessage {
  LocalizedStateError(this.builder) : super('');
  final MessageBuilder builder;
  @override
  String get message => messageFor(defaultLocalizations);
  @override
  String messageFor(AppLocalizations l10n) => builder(l10n);
}

class LocalizedUnsupportedError extends UnsupportedError
    implements LocalizedMessage {
  LocalizedUnsupportedError(this.builder) : super('');
  final MessageBuilder builder;
  @override
  String get message => messageFor(defaultLocalizations);
  @override
  String messageFor(AppLocalizations l10n) => builder(l10n);
}

String localizedText(Object message, AppLocalizations l10n) =>
    message is LocalizedMessage ? message.messageFor(l10n) : message.toString();
