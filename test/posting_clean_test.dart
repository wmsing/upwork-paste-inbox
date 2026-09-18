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

  test('drops open job in new window action line', () {
    const raw = '''
Open job in a new window
Senior Flutter Developer
Job description
''';
    expect(cleanPostingBody(raw), 'Senior Flutter Developer\nJob description');
  });

  test('drops contract-to-hire explainer', () {
    const raw = '''
Job title
Summary
Hello

Contract-to-hire opportunity
This lets talent know that this job could become full time.
Learn more

Scope:
Work details
''';
    final out = cleanPostingBody(raw);
    expect(out.contains('Contract-to-hire'), isFalse);
    expect(out.contains('Learn more'), isFalse);
    expect(out.contains('Scope:'), isTrue);
  });

  test('original display bolds section headers', () {
    const body = '''
Summary
Intro line
Scope:
Details
''';
    final lines = originalDisplayLines(body);
    expect(lines[0].isSectionHeader, isTrue);
    expect(lines[1].isSectionHeader, isFalse);
    expect(lines[2].isSectionHeader, isTrue);
  });

  test('section header after blank line gets gapBefore', () {
    const body = '''
Intro

Summary
Body
''';
    final lines = originalDisplayLines(body);
    final summary = lines.firstWhere((l) => l.text == 'Summary');
    expect(summary.gapBefore, isTrue);
  });

  test('bold activity and proposal lines', () {
    expect(isPostingSectionHeader('Proposals:'), isTrue);
    expect(isPostingSectionHeader('Interviewing:'), isTrue);
    expect(isPostingSectionHeader('Invites sent:'), isTrue);
    expect(
      isPostingSectionHeader('Send a proposal for: 16 Connects'),
      isTrue,
    );
    expect(isPostingSectionHeader('About the client'), isTrue);
    expect(isPostingSectionHeader('Job link'), isTrue);
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
