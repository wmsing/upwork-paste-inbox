import 'package:flutter_test/flutter_test.dart';
import 'package:upwork_easy/ollama.dart';

void main() {
  test('summaryBulletLines strips bullet prefixes', () {
    const raw = '• First point\n- second\n* third\nplain';
    expect(summaryBulletLines(raw), [
      'First point',
      'second',
      'third',
      'plain',
    ]);
  });

  test('summaryBulletLines splits literal backslash-n and bullets', () {
    const raw = r'• 修复崩溃\n• 维护 Flutter';
    expect(summaryBulletLines(raw), ['修复崩溃', '维护 Flutter']);
  });
}
