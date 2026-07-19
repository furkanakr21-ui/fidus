import 'package:fidus/shared/services/supabase_pagination.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('loadAllSupabasePages', () {
    test('returns all rows beyond the PostgREST default page size', () async {
      final source = List<int>.generate(2505, (index) => index);
      final requestedRanges = <(int, int)>[];

      final result = await loadAllSupabasePages((from, to) async {
        requestedRanges.add((from, to));
        if (from >= source.length) return [];
        final endExclusive = (to + 1).clamp(0, source.length);
        return source.sublist(from, endExclusive);
      });

      expect(result, source);
      expect(requestedRanges, [(0, 999), (1000, 1999), (2000, 2999)]);
    });

    test(
      'performs the final empty request for an exact page multiple',
      () async {
        final source = List<int>.generate(2000, (index) => index);
        var calls = 0;

        final result = await loadAllSupabasePages((from, to) async {
          calls += 1;
          if (from >= source.length) return [];
          return source.sublist(from, (to + 1).clamp(0, source.length));
        });

        expect(result, source);
        expect(calls, 3);
      },
    );

    test('rejects an invalid page size', () {
      expect(
        () => loadAllSupabasePages<int>((_, _) async => [], pageSize: 0),
        throwsArgumentError,
      );
    });
  });

  group('chunked', () {
    test('keeps every item while limiting each chunk', () {
      final chunks = chunked(
        List<int>.generate(405, (index) => index),
        200,
      ).toList();

      expect(chunks.map((chunk) => chunk.length), [200, 200, 5]);
      expect(
        chunks.expand((chunk) => chunk),
        List<int>.generate(405, (i) => i),
      );
    });

    test('does not emit chunks for an empty list', () {
      expect(chunked<int>(const [], 200), isEmpty);
    });
  });
}
