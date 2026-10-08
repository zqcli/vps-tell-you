import 'dart:convert';

import 'package:http/http.dart' as http;

import '../l10n/generated/app_localizations.dart';
import 'cloud_models.dart';
import 'solusvm_adapter.dart';

enum CloudCredentialKind { keyHash, token }

typedef _AdapterBuilder = CloudAdapter Function(
  CloudEndpoint endpoint,
  CloudCredentials credentials, {
  CloudReadLimits? limits,
  DateTime Function()? clock,
  http.Client Function()? clientFactory,
});

/// A closed, immutable mapping of supported providers. It retains only rules
/// and constructors, never credentials or already-translated UI messages.
final class CloudProviderDefinition {
  const CloudProviderDefinition._({
    required this.provider,
    required this.displayName,
    required this.credentialKind,
    required this.endpointHint,
    required this._acceptsCredentials,
    required this._credentialsBuilder,
    required this._adapterBuilder,
    required this._templateInfo,
    required this._credentialsInfo,
    required this._resourceCompletionInfo,
    this._allowConsolePath = false,
    this._allowApiPath = false,
    required this._endpointValidation,
    required this._endpointInfo,
  });

  static CloudProviderDefinition of(CloudProvider provider) =>
      switch (provider) {
        CloudProvider.solusVm1 => _solusVm1,
        CloudProvider.solusVm2 => _solusVm2,
        CloudProvider.rackNerd => _rackNerd,
      };

  static final _solusVm1 = CloudProviderDefinition._(
    provider: CloudProvider.solusVm1,
    displayName: 'SolusVM 1',
    credentialKind: CloudCredentialKind.keyHash,
    endpointHint: 'https://panel.example.com:5656',
    acceptsCredentials: (value) => value is SolusVm1Credentials,
    credentialsBuilder: (key, hash, _) =>
        SolusVm1Credentials(key: key, hash: hash),
    adapterBuilder: (endpoint, credentials, {limits, clock, clientFactory}) =>
        SolusVm1Adapter(
          endpoint: endpoint,
          credentials: credentials as SolusVm1Credentials,
          limits: limits,
          clock: clock,
          clientFactory: clientFactory,
        ),
    allowConsolePath: true,
    templateInfo: (l10n) => l10n.cloudV1TemplateInfo,
    endpointValidation: (l10n) => l10n.cloudEndpointValidation,
    endpointInfo: (l10n) => l10n.cloudEndpointInfo,
    credentialsInfo: (l10n) => l10n.cloudV1CredentialsInfo,
    resourceCompletionInfo: (l10n) => l10n.cloudV1ResourcesInfo,
  );

  static final _solusVm2 = CloudProviderDefinition._(
    provider: CloudProvider.solusVm2,
    displayName: 'SolusVM 2',
    credentialKind: CloudCredentialKind.token,
    endpointHint: 'https://panel.example.com',
    acceptsCredentials: (value) => value is SolusVm2Credentials,
    credentialsBuilder: (_, _, token) => SolusVm2Credentials(token),
    adapterBuilder: (endpoint, credentials, {limits, clock, clientFactory}) =>
        SolusVm2Adapter(
          endpoint: endpoint,
          credentials: credentials as SolusVm2Credentials,
          limits: limits,
          clock: clock,
          clientFactory: clientFactory,
        ),
    templateInfo: (l10n) => l10n.cloudV2TemplateInfo,
    endpointValidation: (l10n) => l10n.cloudEndpointValidation,
    endpointInfo: (l10n) => l10n.cloudEndpointInfo,
    credentialsInfo: (l10n) => l10n.cloudV2CredentialsInfo,
    resourceCompletionInfo: (_) => null,
  );

  static final _rackNerd = CloudProviderDefinition._(
    provider: CloudProvider.rackNerd,
    displayName: 'RackNerd ctrl',
    credentialKind: CloudCredentialKind.keyHash,
    endpointHint: 'https://panel.example.com',
    acceptsCredentials: (value) => value is RackNerdCredentials,
    credentialsBuilder: (key, hash, _) =>
        RackNerdCredentials(key: key, hash: hash),
    adapterBuilder: (endpoint, credentials, {limits, clock, clientFactory}) =>
        RackNerdAdapter(
          endpoint: endpoint,
          credentials: credentials as RackNerdCredentials,
          limits: limits,
          clock: clock,
          clientFactory: clientFactory,
        ),
    allowApiPath: true,
    templateInfo: (l10n) => l10n.cloudRackNerdTemplateInfo,
    endpointValidation: (l10n) => l10n.cloudRackNerdEndpointValidation,
    endpointInfo: (l10n) => l10n.cloudRackNerdEndpointInfo,
    credentialsInfo: (l10n) => l10n.cloudRackNerdCredentialsInfo,
    resourceCompletionInfo: (l10n) => l10n.cloudRackNerdResourcesInfo,
  );

  final CloudProvider provider;
  final String displayName, endpointHint;
  final CloudCredentialKind credentialKind;
  final bool Function(CloudCredentials) _acceptsCredentials;
  final CloudCredentials Function(String, String, String) _credentialsBuilder;
  final _AdapterBuilder _adapterBuilder;
  final bool _allowConsolePath, _allowApiPath;
  final String Function(AppLocalizations) _templateInfo,
      _endpointValidation,
      _endpointInfo,
      _credentialsInfo;
  final String? Function(AppLocalizations) _resourceCompletionInfo;

  CloudCredentials createCredentials({
    String key = '',
    String hash = '',
    String token = '',
  }) => _credentialsBuilder(key, hash, token);

  CloudEndpoint parseEndpoint(String value) => CloudEndpoint.parse(
    value,
    allowSolusVm1ConsolePath: _allowConsolePath,
    allowRackNerdApiPath: _allowApiPath,
  );

  void validateCredentials(CloudCredentials credentials) {
    if (!_acceptsCredentials(credentials)) {
      throw const CloudFailure(CloudFailureKind.invalidCredentials);
    }
  }

  CloudAdapter createAdapter(
    CloudEndpoint endpoint,
    CloudCredentials credentials, {
    CloudReadLimits? limits,
    DateTime Function()? clock,
    http.Client Function()? clientFactory,
  }) {
    validateCredentials(credentials);
    return _adapterBuilder(
      endpoint,
      credentials,
      limits: limits,
      clock: clock,
      clientFactory: clientFactory,
    );
  }

  String encodeCredentials(CloudCredentials credentials) {
    validateCredentials(credentials);
    return jsonEncode({
      'version': 1,
      'provider': provider.name,
      ...switch (credentials) {
        KeyHashCredentials() => {
          'key': credentials.key,
          'hash': credentials.hash,
        },
        SolusVm2Credentials() => {'token': credentials.token},
      },
    });
  }

  CloudCredentials decodeCredentials(String raw) {
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      if (value['version'] != 1 || value['provider'] != provider.name) {
        throw const CloudFailure(CloudFailureKind.invalidCredentials);
      }
      return switch (credentialKind) {
        CloudCredentialKind.keyHash => createCredentials(
          key: value['key'] as String,
          hash: value['hash'] as String,
        ),
        CloudCredentialKind.token => createCredentials(
          token: value['token'] as String,
        ),
      };
    } catch (_) {
      // Parser and type errors can include raw secret input. Do not expose them.
      throw const CloudFailure(CloudFailureKind.invalidCredentials);
    }
  }

  String templateInfo(AppLocalizations l10n) => _templateInfo(l10n);
  String endpointValidation(AppLocalizations l10n) => _endpointValidation(l10n);
  String endpointInfo(AppLocalizations l10n) => _endpointInfo(l10n);
  String credentialsInfo(AppLocalizations l10n) => _credentialsInfo(l10n);
  String? resourceCompletionInfo(AppLocalizations l10n) =>
      _resourceCompletionInfo(l10n);
}
