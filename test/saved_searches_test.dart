import 'package:flutter_test/flutter_test.dart';
import 'package:upwork_easy/saved_searches.dart';

void main() {
  test('legacy list migrates first url', () {
    const raw =
        '[{"id":"a","name":"X","url":"https://www.upwork.com/nx/search/jobs?q=x"}]';
    expect(
      urlFromLegacySavedSearches(raw),
      'https://www.upwork.com/nx/search/jobs?q=x',
    );
  });

  test('legacy empty', () {
    expect(urlFromLegacySavedSearches(null), isNull);
    expect(urlFromLegacySavedSearches('[]'), isNull);
  });
}
