const int kSupabasePageSize = 1000;

typedef SupabasePageLoader<T> = Future<List<T>> Function(int from, int to);

Future<List<T>> loadAllSupabasePages<T>(
  SupabasePageLoader<T> loadPage, {
  int pageSize = kSupabasePageSize,
}) async {
  if (pageSize <= 0) {
    throw ArgumentError.value(
      pageSize,
      'pageSize',
      'Must be greater than zero',
    );
  }

  final rows = <T>[];
  var from = 0;
  while (true) {
    final page = await loadPage(from, from + pageSize - 1);
    rows.addAll(page);
    if (page.length < pageSize) return rows;
    from += pageSize;
  }
}

Iterable<List<T>> chunked<T>(List<T> values, int chunkSize) sync* {
  if (chunkSize <= 0) {
    throw ArgumentError.value(
      chunkSize,
      'chunkSize',
      'Must be greater than zero',
    );
  }
  for (var start = 0; start < values.length; start += chunkSize) {
    final end = (start + chunkSize).clamp(0, values.length);
    yield values.sublist(start, end);
  }
}
