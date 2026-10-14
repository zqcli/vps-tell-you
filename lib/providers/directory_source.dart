import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Public provider directory: raw GitHub first, jsDelivr as the mirror for
/// networks where raw.githubusercontent.com is unreachable. A
/// `--dart-define=VPS_CATALOG_BASE=<url>` replaces both (testing).
const kDirectoryBases = [
  'https://raw.githubusercontent.com/zqcli/vps-tell-you/dev/catalog/',
  'https://cdn.jsdelivr.net/gh/zqcli/vps-tell-you@dev/catalog/',
];
const _baseOverride = String.fromEnvironment('VPS_CATALOG_BASE');

List<Uri> defaultDirectoryBases() => [
  for (final base in _baseOverride.isEmpty ? kDirectoryBases : [_baseOverride])
    Uri.parse(base.endsWith('/') ? base : '$base/'),
];

/// A response to `GET {base}index.json`.
class IndexFetch {
  const IndexFetch.notModified() : body = null, etag = null;
  const IndexFetch.body(String this.body, {this.etag});

  /// `null` when the server answered 304 to the conditional request.
  final String? body;
  final String? etag;
  bool get notModified => body == null;
}

class DirectoryFetchException implements Exception {
  const DirectoryFetchException(this.detail);
  final String detail;
  @override
  String toString() => 'DirectoryFetchException: $detail';
}

/// Where directory files come from. One call talks to one base URL; trying the
/// next mirror is the caller's decision.
abstract interface class DirectorySource {
  List<Uri> get bases;

  /// Fetches `index.json`; [etag] makes the request conditional.
  Future<IndexFetch> fetchIndex(Uri base, {String? etag});

  /// Fetches a file below [base] (a logo) of at most [maxBytes].
  Future<Uint8List> fetchFile(Uri base, String path, {required int maxBytes});
}

/// [DirectorySource] over HTTPS. The client, bases and timeout are injectable;
/// requests carry no cookies, credentials or identifiers.
class HttpDirectorySource implements DirectorySource {
  HttpDirectorySource({
    http.Client? client,
    List<Uri>? bases,
    this.timeout = const Duration(seconds: 10),
    this.maxIndexBytes = 1024 * 1024,
  }) : _client = client ?? http.Client(),
       bases = bases ?? defaultDirectoryBases();

  final http.Client _client;
  @override
  final List<Uri> bases;
  final Duration timeout;
  final int maxIndexBytes;

  Future<http.StreamedResponse> _get(Uri uri, Map<String, String> headers) {
    final request = http.Request('GET', uri)..headers.addAll(headers);
    return _client.send(request).timeout(timeout);
  }

  /// Reads at most [max] bytes; fails as soon as more arrive.
  Future<Uint8List> _read(http.StreamedResponse response, int max) async {
    final declared = response.contentLength;
    if (declared != null && declared > max) {
      throw const DirectoryFetchException('too large');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(timeout)) {
      bytes.add(chunk);
      if (bytes.length > max) throw const DirectoryFetchException('too large');
    }
    return bytes.takeBytes();
  }

  @override
  Future<IndexFetch> fetchIndex(Uri base, {String? etag}) async {
    final response = await _get(base.resolve('index.json'), {
      'Accept': 'application/json',
      'If-None-Match': ?etag,
    });
    if (response.statusCode == 304 && etag != null) {
      await response.stream.drain<void>();
      return const IndexFetch.notModified();
    }
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw DirectoryFetchException('HTTP ${response.statusCode}');
    }
    final bytes = await _read(response, maxIndexBytes);
    final String text;
    try {
      text = const Utf8Decoder().convert(bytes);
    } on FormatException {
      throw const DirectoryFetchException('not UTF-8');
    }
    final received = response.headers.entries
        .where((e) => e.key.toLowerCase() == 'etag')
        .map((e) => e.value)
        .firstOrNull;
    return IndexFetch.body(text, etag: received);
  }

  @override
  Future<Uint8List> fetchFile(
    Uri base,
    String path, {
    required int maxBytes,
  }) async {
    final response = await _get(base.resolve(path), {'Accept': 'image/png'});
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw DirectoryFetchException('HTTP ${response.statusCode}');
    }
    return _read(response, maxBytes);
  }
}
