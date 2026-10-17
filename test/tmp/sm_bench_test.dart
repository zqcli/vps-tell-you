import 'package:flutter_test/flutter_test.dart';
import 'package:vps_tell_you/core/search_match.dart';

void main() {
  test('bench', () {
    final names = [for (var i = 0; i < 3000; i++) 'Provider ${(i * 7919) % 3000} Cloud ${i % 17}é'];
    final plain = [for (var i = 0; i < 3000; i++) 'Provider ${(i * 7919) % 3000} Cloud ${i % 17}'];
    for (var r = 0; r < 3; r++) {
      var sw = Stopwatch()..start();
      (List.of(names)..sort(compareNames));
      final a = sw.elapsedMilliseconds;
      sw = Stopwatch()..start();
      (List.of(plain)..sort(compareNames));
      final b = sw.elapsedMilliseconds;
      sw = Stopwatch()..start();
      final tokens = searchTokens('provider 12 cloud');
      var n = 0;
      for (final x in names) { if (matchesTokens(searchHaystack([x]), tokens)) n++; }
      // ignore: avoid_print
      print('BENCH sort accented ${a}ms plain ${b}ms, haystack+match ${sw.elapsedMilliseconds}ms ($n)');
    }
  });
}
