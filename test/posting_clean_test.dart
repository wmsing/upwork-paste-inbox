import 'package:flutter_test/flutter_test.dart';
import 'package:upwork_easy/posting_clean.dart';

void main() {
  test('truncates at client recent history', () {
    const raw = '''
Fix our Flutter app
Need maintenance

Skills: Flutter

Client's recent history (4)
Some old job
''';
    final out = cleanPostingBody(raw);
    expect(out.contains('recent history'), isFalse);
    expect(out.contains('Fix our Flutter'), isTrue);
  });

  test('drops similar jobs tail', () {
    const raw = 'Title\nDesc\n\nSimilar jobs\nFoo';
    expect(cleanPostingBody(raw), 'Title\nDesc');
  });

  test('keeps About the client and Activity on this job', () {
    const raw = '''
Job title
Body text

About the client
Payment verified

Activity on this job
Proposals: 5 to 10

Client's recent history (4)
Old listing
''';
    final out = cleanPostingBody(raw);
    expect(out.contains('About the client'), isTrue);
    expect(out.contains('Activity on this job'), isTrue);
    expect(out.contains('Proposals:'), isTrue);
    expect(out.contains('recent history'), isFalse);
    expect(out.contains('Old listing'), isFalse);
  });
}
