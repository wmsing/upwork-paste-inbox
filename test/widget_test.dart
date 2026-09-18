import 'package:flutter_test/flutter_test.dart';
import 'package:upwork_easy/job.dart';

void main() {
  test('looksLikeUrl', () {
    expect(looksLikeUrl('https://www.upwork.com/jobs/~abc'), isTrue);
    expect(looksLikeUrl('not a url'), isFalse);
  });

  test('upworkJobUrlFromPosting', () {
    expect(
      upworkJobUrlFromPosting(
        'See https://www.upwork.com/jobs/~0123abcd/details',
      ),
      'https://www.upwork.com/jobs/~0123abcd/details',
    );
    expect(
      jobUpworkLink(
        Job(
          id: '1',
          displayTitle: 't',
          body: 'https://www.upwork.com/nx/jobs/~x',
          fingerprint: 'f',
          status: ReadinessStatus.unread,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      ),
      'https://www.upwork.com/nx/jobs/~x',
    );
  });
}
