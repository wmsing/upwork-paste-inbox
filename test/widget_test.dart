import 'package:flutter_test/flutter_test.dart';
import 'package:upwork_easy/job.dart';

void main() {
  test('looksLikeUrl', () {
    expect(looksLikeUrl('https://www.upwork.com/jobs/~abc'), isTrue);
    expect(looksLikeUrl('not a url'), isFalse);
  });
}
