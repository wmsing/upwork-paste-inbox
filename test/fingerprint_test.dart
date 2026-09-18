import 'package:flutter_test/flutter_test.dart';
import 'package:upwork_easy/job.dart';

void main() {
  test('fingerprint ignores extra whitespace', () {
    expect(
      postingFingerprint('Hello\n\n  world'),
      postingFingerprint('Hello world'),
    );
  });

  test('default title uses first non-empty line', () {
    expect(
      defaultDisplayTitle('\n\nFix Flutter app\nMore'),
      'Fix Flutter app',
    );
  });

  test('default title skips underscore separators', () {
    expect(
      defaultDisplayTitle('___\n___\nSenior Flutter Developer'),
      'Senior Flutter Developer',
    );
  });
}
