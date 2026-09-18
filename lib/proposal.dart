import 'l10n.dart';

class ProposalDraft {
  ProposalDraft({
    required this.id,
    required this.jobId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String jobId;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProposalDraft.fromRow(Map<String, Object?> row) => ProposalDraft(
        id: row['id']! as String,
        jobId: row['job_id']! as String,
        title: row['title']! as String,
        body: row['body']! as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
      );

  ProposalDraft copyWith({
    String? title,
    String? body,
    DateTime? updatedAt,
  }) =>
      ProposalDraft(
        id: id,
        jobId: jobId,
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

String defaultProposalTitle() => bi('Proposal draft', '提案草稿');
