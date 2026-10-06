import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'cloud_models.dart';

class CloudReadLimits {
  CloudReadLimits({
    this.requestTimeout = const Duration(seconds: 15),
    this.operationTimeout = const Duration(seconds: 90),
    this.responseBytes = 1024 * 1024,
    this.totalBytes = 16 * 1024 * 1024,
    this.pages = 200,
    this.items = 10000,
  }) {
    if (requestTimeout <= Duration.zero ||
        operationTimeout <= Duration.zero ||
        responseBytes < 1 ||
        totalBytes < 1 ||
        pages < 1 ||
        items < 1) {
      throw ArgumentError('读取限制必须大于 0');
    }
  }
  final Duration requestTimeout, operationTimeout;
  final int responseBytes, totalBytes, pages, items;
}

/// One Key/Hash corresponds to one VPS; no account inventory or inferred ID.
class SolusVm1Adapter implements CloudAdapter {
  SolusVm1Adapter({
    required this.endpoint,
    required this.credentials,
    CloudReadLimits? limits,
    DateTime Function()? clock,
    http.Client Function()? clientFactory,
  }) : _limits = limits ?? CloudReadLimits(),
       _clock = clock ?? DateTime.now,
       _clientFactory = clientFactory ?? http.Client.new;
  final CloudEndpoint endpoint;
  final SolusVm1Credentials credentials;
  final CloudReadLimits _limits;
  final DateTime Function() _clock;
  final http.Client Function() _clientFactory;

  @override
  Future<CloudSnapshot> read({required CloudCancellation cancellation}) async {
    final session = _ReadSession(_limits, cancellation, _clientFactory);
    final request =
        http.MultipartRequest('POST', endpoint.uri('/api/client/command.php'))
          ..fields.addAll({
            'key': credentials.key,
            'hash': credentials.hash,
            'action': 'status',
          });
    final body = await session.send(request, responseLimit: 16 * 1024);
    final power = _v1Power(body);
    session.check();
    final now = _clock().toUtc();
    return CloudSnapshot(
      provider: CloudProvider.solusVm1,
      completedAt: now,
      instances: [CloudInstance(observedAt: now, power: power)],
    );
  }
}

class SolusVm2Adapter implements CloudAdapter {
  SolusVm2Adapter({
    required this.endpoint,
    required this.credentials,
    CloudReadLimits? limits,
    DateTime Function()? clock,
    http.Client Function()? clientFactory,
  }) : _limits = limits ?? CloudReadLimits(),
       _clock = clock ?? DateTime.now,
       _clientFactory = clientFactory ?? http.Client.new;
  final CloudEndpoint endpoint;
  final SolusVm2Credentials credentials;
  final CloudReadLimits _limits;
  final DateTime Function() _clock;
  final http.Client Function() _clientFactory;

  @override
  Future<CloudSnapshot> read({required CloudCancellation cancellation}) async {
    final session = _ReadSession(_limits, cancellation, _clientFactory);
    final account = await _get(session, '/api/v1/account');
    final accountId = _id(_object(account['data'])['id']);
    final projects = <CloudProject>[];
    final instances = <CloudInstance>[];
    final projectIds = <int>{};
    final serverIds = <int>{};
    await _eachPage(session, '/api/v1/projects', (data) {
      for (final value in data) {
        final row = _object(value);
        final id = _id(row['id']);
        if (!projectIds.add(id)) _invalid();
        projects.add(CloudProject(id: id, name: _label(row['name'])));
      }
    });
    for (final project in projects) {
      await _eachPage(session, '/api/v1/projects/${project.id}/servers', (
        data,
      ) {
        final now = _clock().toUtc();
        for (final value in data) {
          final instance = _v2Instance(_object(value), project, now);
          // IDs are global in the documented server resource. A repeated ID
          // (even across project pages) means the discovery is inconsistent.
          if (!serverIds.add(instance.serverId!)) _invalid();
          instances.add(instance);
        }
      });
    }
    session.check();
    return CloudSnapshot(
      provider: CloudProvider.solusVm2,
      completedAt: _clock().toUtc(),
      remoteAccountId: accountId,
      projects: projects,
      instances: instances,
    );
  }

  Future<Map<String, dynamic>> _get(
    _ReadSession session,
    String path, {
    int? page,
  }) async {
    // Private, closed read allowlist; IDs only arrive from validated projects.
    if (!(path == '/api/v1/account' && page == null) &&
        !((path == '/api/v1/projects' ||
                RegExp(r'^/api/v1/projects/[1-9][0-9]*/servers$')
                    .hasMatch(path)) &&
            page != null &&
            page > 0)) {
      _invalid();
    }
    final request = http.Request('GET', endpoint.uri(path, page: page))
      ..headers.addAll({
        'Authorization': 'Bearer ${credentials.token}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      });
    final body = await session.send(request);
    try {
      final value = jsonDecode(body);
      _boundJson(value);
      return _object(value);
    } on CloudFailure {
      rethrow;
    } catch (_) {
      _invalid();
    }
  }

  Future<void> _eachPage(
    _ReadSession session,
    String path,
    void Function(List<dynamic>) consume,
  ) async {
    int? page = 1;
    while (page != null) {
      final response = await _get(session, path, page: page);
      final data = response['data'];
      if (data is! List) _invalid();
      session.countItems(data.length);
      final next = _nextPage(response, endpoint.uri(path, page: page), page);
      consume(data);
      session.check();
      page = next;
    }
  }
}

/// Per-operation budget, with per-request clients so aborting an operation can
/// never close another account's active request. Default clients retain strict
/// platform TLS and hostname verification. No redirect is followed, even same
/// origin; no retry or endpoint discovery ever resends credentials.
class _ReadSession {
  _ReadSession(this.limits, this.cancellation, this.clientFactory);
  final CloudReadLimits limits;
  final CloudCancellation cancellation;
  final http.Client Function() clientFactory;
  final watch = Stopwatch()..start();
  int requests = 0, bytes = 0, items = 0;
  void check() {
    cancellation.throwIfCancelled();
    if (watch.elapsed >= limits.operationTimeout) {
      throw const CloudFailure(CloudFailureKind.timeout);
    }
  }

  void countItems(int count) {
    items += count;
    if (items > limits.items) {
      throw const CloudFailure(CloudFailureKind.inventoryTooLarge);
    }
  }

  Future<String> send(http.BaseRequest request, {int? responseLimit}) async {
    final responseBytes = math.min(
      responseLimit ?? limits.responseBytes,
      limits.responseBytes,
    );
    check();
    if (kIsWeb) throw const CloudFailure(CloudFailureKind.unsupportedPlatform);
    if (++requests > limits.pages) {
      throw const CloudFailure(CloudFailureKind.inventoryTooLarge);
    }
    request.followRedirects = false;
    request.maxRedirects = 0;
    request.persistentConnection = false;
    http.Client? client;
    StreamSubscription<List<int>>? subscription;
    final completed = Completer<String>();
    final body = <int>[];
    void finish({String? value, CloudFailure? failure}) {
      if (completed.isCompleted) return;
      if (failure != null) {
        completed.completeError(failure);
      } else {
        completed.complete(value!);
      }
      unawaited(subscription?.cancel());
      client?.close();
    }

    final timer = Timer(
      Duration(
        microseconds: math.min(
          limits.requestTimeout.inMicroseconds,
          (limits.operationTimeout - watch.elapsed).inMicroseconds,
        ),
      ),
      () => finish(failure: const CloudFailure(CloudFailureKind.timeout)),
    );
    final removeListener = cancellation.onCancel(
      () => finish(failure: const CloudFailure(CloudFailureKind.cancelled)),
    );
    Future<void> run() async {
      try {
        if (completed.isCompleted) return;
        client = clientFactory();
        final response = await client!.send(request);
        if (completed.isCompleted) {
          // Consume/cancel late response streams without exposing their data.
          await response.stream.listen((_) {}).cancel();
          return;
        }
        final code = response.statusCode;
        if (code >= 300 && code < 400) {
          throw const CloudFailure(CloudFailureKind.redirect);
        }
        if (code == 401) {
          throw const CloudFailure(CloudFailureKind.unauthorized);
        }
        if (code == 403) throw const CloudFailure(CloudFailureKind.forbidden);
        if (code == 429) throw const CloudFailure(CloudFailureKind.rateLimited);
        if (code < 200 || code >= 300) {
          throw const CloudFailure(CloudFailureKind.unavailable);
        }
        if ((response.contentLength ?? 0) > responseBytes ||
            (response.contentLength ?? 0) + bytes > limits.totalBytes) {
          throw const CloudFailure(CloudFailureKind.responseTooLarge);
        }
        subscription = response.stream.listen(
          (chunk) {
            if (completed.isCompleted) return;
            bytes += chunk.length;
            if (body.length + chunk.length > responseBytes ||
                bytes > limits.totalBytes) {
              finish(
                failure: const CloudFailure(CloudFailureKind.responseTooLarge),
              );
            } else {
              body.addAll(chunk);
            }
          },
          onError: (Object _, StackTrace _) {
            finish(failure: const CloudFailure(CloudFailureKind.connection));
          },
          onDone: () {
            try {
              check();
              finish(value: utf8.decode(body));
            } on CloudFailure catch (failure) {
              finish(failure: failure);
            } catch (_) {
              finish(
                failure: const CloudFailure(CloudFailureKind.invalidResponse),
              );
            }
          },
        );
      } on CloudFailure catch (failure) {
        finish(failure: failure);
      } catch (_) {
        finish(failure: const CloudFailure(CloudFailureKind.connection));
      }
    }

    unawaited(run());
    try {
      return await completed.future;
    } finally {
      timer.cancel();
      removeListener();
    }
  }
}

Never _invalid() => throw const CloudFailure(CloudFailureKind.invalidResponse);
Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) _invalid();
  return value;
}

int _id(Object? value) {
  if (value is! int || value <= 0 || value > 9007199254740991) _invalid();
  return value;
}

String? _label(Object? value) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > 512 ||
      RegExp(r'[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]').hasMatch(value)) {
    return null;
  }
  return value.trim();
}

int? _positiveInt(Object? value) =>
    value is int && value > 0 && value <= 9007199254740991 ? value : null;
Map<String, dynamic> _optionalObject(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

void _boundJson(Object? root) {
  final pending = <(Object?, int)>[(root, 0)];
  var nodes = 0;
  while (pending.isNotEmpty) {
    final (value, depth) = pending.removeLast();
    if (depth > 32 || ++nodes > 50000) _invalid();
    if (value is Map) {
      for (final child in value.values) {
        pending.add((child, depth + 1));
      }
    } else if (value is List) {
      for (final child in value) {
        pending.add((child, depth + 1));
      }
    }
  }
}

CloudPower _v1Power(String body) {
  try {
    // The event pass bounds nesting before building nodes, rejects all DTDs
    // (including external entities) and does not perform network/entity lookup.
    var depth = 0, count = 0;
    for (final event in parseEvents(body, validateNesting: true)) {
      if (++count > 2048 ||
          event is XmlDoctypeEvent ||
          event is XmlProcessingEvent) {
        _invalid();
      }
      if (event is XmlStartElementEvent &&
          !event.isSelfClosing &&
          ++depth > 16) {
        _invalid();
      }
      if (event is XmlEndElementEvent) depth--;
    }
    final xml = XmlDocumentFragment.parse(body);
    var elements = xml.children.whereType<XmlElement>().toList();
    if (elements.length == 1 && elements.single.name.qualified == 'response') {
      elements = elements.single.childElements.toList();
    }
    String field(String name) {
      final matches = elements.where((e) => e.name.qualified == name).toList();
      if (matches.length != 1 || matches.single.childElements.isNotEmpty) {
        _invalid();
      }
      // Nested copies in unknown fields are ambiguous rather than authoritative.
      if (xml.descendants
              .whereType<XmlElement>()
              .where((e) => e.name.qualified == name)
              .length !=
          1) {
        _invalid();
      }
      return matches.single.innerText.trim();
    }

    final status = field('status');
    final message = field('statusmsg');
    if (status == 'error') {
      throw const CloudFailure(CloudFailureKind.apiRejected);
    }
    if (status != 'success') _invalid();
    return switch (message) {
      'online' => CloudPower.running,
      'offline' => CloudPower.stopped,
      _ => CloudPower.unknown,
    };
  } on CloudFailure {
    rethrow;
  } catch (_) {
    _invalid();
  }
}

int? _nextPage(Map<String, dynamic> response, Uri current, int page) {
  int? linkedPage;
  final linksValue = response['links'];
  final metaValue = response['meta'];
  if (linksValue != null) {
    final links = _object(linksValue);
    final next = links['next'];
    if (next != null) {
      if (next is! String || next.isEmpty || next.length > 2048) _invalid();
      try {
        // Resolve relative documented links, then validate every URL component.
        final uri = current.resolve(next);
        if (uri.scheme != 'https' ||
            uri.host != current.host ||
            uri.port != current.port ||
            uri.userInfo.isNotEmpty ||
            uri.hasFragment ||
            uri.path != current.path ||
            uri.queryParametersAll.length != 1 ||
            uri.queryParametersAll['page']?.length != 1) {
          _invalid();
        }
        final raw = uri.queryParameters['page']!;
        if (!RegExp(r'^[1-9][0-9]*$').hasMatch(raw)) _invalid();
        linkedPage = int.tryParse(raw);
        if (linkedPage != page + 1) _invalid();
      } on CloudFailure {
        rethrow;
      } catch (_) {
        _invalid();
      }
    }
  }
  if (metaValue != null) {
    final meta = _object(metaValue);
    final currentPage = _id(meta['current_page']);
    final lastPage = _id(meta['last_page']);
    if (currentPage != page || lastPage < page) _invalid();
    final expected = page < lastPage ? page + 1 : null;
    if (linkedPage != null && linkedPage != expected) _invalid();
    if (linksValue is Map &&
        linksValue.containsKey('next') &&
        linkedPage != expected) {
      _invalid();
    }
    return expected;
  }
  // Complete legacy unpaginated data is one page, regardless of array length.
  return linkedPage;
}

CloudInstance _v2Instance(
  Map<String, dynamic> row,
  CloudProject project,
  DateTime observedAt,
) {
  final id = _id(row['id']);
  final remoteProject = row['project'];
  if (remoteProject != null &&
      _id(_object(remoteProject)['id']) != project.id) {
    _invalid();
  }
  final uuid = row['uuid'];
  if (uuid != null &&
      (uuid is! String ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(uuid))) {
    _invalid();
  }
  final specifications = _optionalObject(row['specifications']);
  final disk = specifications['disk'];
  final power = row.containsKey('real_status')
      ? row['real_status']
      : row['status'];
  return CloudInstance(
    projectId: project.id,
    serverId: id,
    uuid: uuid is String ? uuid.toLowerCase() : null,
    projectName: project.name,
    name: _label(row['name']),
    observedAt: observedAt,
    power: switch (power) {
      'started' => CloudPower.running,
      'stopped' => CloudPower.stopped,
      _ => CloudPower.unknown,
    },
    suspended: row['is_suspended'] is bool ? row['is_suspended'] as bool : null,
    vcpu: _positiveInt(specifications['vcpu']),
    ramBytes: _positiveInt(specifications['ram']),
    diskGiB:
        disk is num && disk.isFinite && disk > 0 && disk <= 9007199254740991
        ? disk
        : null,
    ipv4: _ip(row, InternetAddressType.IPv4),
    ipv6: _ip(row, InternetAddressType.IPv6),
    location: _label(_optionalObject(row['location'])['name']),
    osImage: _label(
      _optionalObject(_optionalObject(row['settings'])['os_image'])['name'],
    ),
  );
}

String? _ip(Map<String, dynamic> row, InternetAddressType type) {
  final modern = _optionalObject(row['ip_addresses']);
  final key = type == InternetAddressType.IPv4 ? 'ipv4' : 'ipv6';
  final hasModern = modern.containsKey(key);
  final source = hasModern ? modern[key] : row['ips'];
  if (source is! List) return null;
  String? first;
  for (final value in source) {
    final item = _optionalObject(value);
    final raw =
        item[hasModern && type == InternetAddressType.IPv6
            ? 'primary_ip'
            : 'ip'];
    if (raw is! String || raw.contains('%')) continue;
    final address = InternetAddress.tryParse(raw);
    if (address == null || address.type != type) continue;
    first ??= address.address;
    if (item['is_primary'] == true) return address.address;
  }
  return first;
}
