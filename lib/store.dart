import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'job.dart';
import 'posting_clean.dart';
import 'proposal.dart';

const _uuid = Uuid();

class JobStore {
  JobStore(this._db);

  final Database _db;

  static Future<JobStore> open() async {
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final dir = await factory.getDatabasesPath();
    final path = p.join(dir, 'upwork_easy.db');
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE jobs (
              id TEXT PRIMARY KEY,
              display_title TEXT NOT NULL,
              body TEXT NOT NULL,
              body_zh TEXT,
              source_url TEXT,
              fingerprint TEXT NOT NULL UNIQUE,
              status TEXT NOT NULL,
              bookmarked INTEGER NOT NULL DEFAULT 0,
              skip_preset TEXT,
              skip_note TEXT,
              consider_note TEXT,
              summary_en TEXT,
              summary_zh TEXT,
              match_tier TEXT,
              match_reasons TEXT,
              key_facts TEXT,
              analyzed_at INTEGER,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          await _createProposalDraftsTable(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE jobs ADD COLUMN key_facts TEXT');
          }
          if (oldVersion < 3) {
            await db.execute(
              'ALTER TABLE jobs ADD COLUMN bookmarked INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion < 4) {
            await db.execute('ALTER TABLE jobs ADD COLUMN consider_note TEXT');
          }
          if (oldVersion < 5) {
            await db.execute('ALTER TABLE jobs ADD COLUMN body_zh TEXT');
          }
          if (oldVersion < 6) {
            await _createProposalDraftsTable(db);
          }
        },
      ),
    );
    return JobStore(db);
  }

  Future<void> close() => _db.close();

  Future<List<Job>> listInbox() async {
    final rows = await _db.query(
      'jobs',
      orderBy:
          "CASE status WHEN 'unread' THEN 0 ELSE 1 END, created_at DESC",
    );
    return rows.map(Job.fromRow).toList();
  }

  Future<Job?> byId(String id) async {
    final rows =
        await _db.query('jobs', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Job.fromRow(rows.first);
  }

  Future<Job?> byFingerprint(String fingerprint) async {
    final rows = await _db.query(
      'jobs',
      where: 'fingerprint = ?',
      whereArgs: [fingerprint],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Job.fromRow(rows.first);
  }

  Future<Job> insertPosting({
    required String body,
    String? sourceUrl,
    String? displayTitle,
  }) async {
    final trimmed = cleanPostingBody(body);
    if (trimmed.isEmpty) {
      throw ArgumentError('正文不能为空');
    }
    final fp = postingFingerprint(trimmed);
    final existing = await byFingerprint(fp);
    if (existing != null) return existing;

    final now = DateTime.now();
    final job = Job(
      id: _uuid.v4(),
      displayTitle: displayTitle?.trim().isNotEmpty == true
          ? displayTitle!.trim()
          : defaultDisplayTitle(trimmed),
      body: trimmed,
      sourceUrl: sourceUrl?.trim().isEmpty == true ? null : sourceUrl?.trim(),
      fingerprint: fp,
      status: ReadinessStatus.unread,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('jobs', _toRow(job));
    return job;
  }

  Future<void> save(Job job) async {
    final row = _toRow(job.copyWith(updatedAt: DateTime.now()));
    await _db.update('jobs', row, where: 'id = ?', whereArgs: [job.id]);
  }

  Future<void> delete(String id) async {
    await _db.delete('jobs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ProposalDraft>> listProposalDrafts(String jobId) async {
    final rows = await _db.query(
      'proposal_drafts',
      where: 'job_id = ?',
      whereArgs: [jobId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(ProposalDraft.fromRow).toList();
  }

  Future<ProposalDraft> insertProposalDraft({
    required String jobId,
    String? title,
    String? body,
  }) async {
    final now = DateTime.now();
    final t = title?.trim();
    final draft = ProposalDraft(
      id: _uuid.v4(),
      jobId: jobId,
      title: t != null && t.isNotEmpty ? t : defaultProposalTitle(),
      body: body ?? '',
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('proposal_drafts', _proposalRow(draft));
    return draft;
  }

  Future<void> saveProposalDraft(ProposalDraft draft) async {
    final title = draft.title.trim();
    await _db.update(
      'proposal_drafts',
      {
        'title': title.isEmpty ? defaultProposalTitle() : title,
        'body': draft.body,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [draft.id],
    );
  }

  Future<void> deleteProposalDraft(String id) async {
    await _db.delete('proposal_drafts', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _proposalRow(ProposalDraft d) => {
        'id': d.id,
        'job_id': d.jobId,
        'title': d.title,
        'body': d.body,
        'created_at': d.createdAt.millisecondsSinceEpoch,
        'updated_at': d.updatedAt.millisecondsSinceEpoch,
      };

  Map<String, Object?> _toRow(Job job) => {
        'id': job.id,
        'display_title': job.displayTitle,
        'body': job.body,
        'body_zh': job.bodyZh,
        'source_url': job.sourceUrl,
        'fingerprint': job.fingerprint,
        'status': job.status.name,
        'bookmarked': job.bookmarked ? 1 : 0,
        'skip_preset': job.skipPreset?.name,
        'skip_note': job.skipNote,
        'consider_note': job.considerNote,
        'summary_en': job.summaryEn,
        'summary_zh': job.summaryZh,
        'match_tier': job.matchTier?.name,
        'match_reasons':
            job.matchReasons.isEmpty ? null : jsonEncode(job.matchReasons),
        'key_facts':
            job.keyFacts.isEmpty ? null : jsonEncode(job.keyFacts),
        'analyzed_at': job.analyzedAt?.millisecondsSinceEpoch,
        'created_at': job.createdAt.millisecondsSinceEpoch,
        'updated_at': job.updatedAt.millisecondsSinceEpoch,
      };
}

Future<void> _createProposalDraftsTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS proposal_drafts (
      id TEXT PRIMARY KEY,
      job_id TEXT NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_proposal_drafts_job ON proposal_drafts(job_id)',
  );
}

extension JobCopy on Job {
  Job copyWith({
    String? displayTitle,
    String? bodyZh,
    ReadinessStatus? status,
    bool? bookmarked,
    SkipPreset? skipPreset,
    String? skipNote,
    String? considerNote,
    String? summaryEn,
    String? summaryZh,
    MatchTier? matchTier,
    List<String>? matchReasons,
    List<String>? keyFacts,
    DateTime? analyzedAt,
    DateTime? updatedAt,
    bool clearSkip = false,
    bool clearConsider = false,
    bool clearAnalysis = false,
  }) {
    return Job(
      id: id,
      displayTitle: displayTitle ?? this.displayTitle,
      body: body,
      bodyZh: bodyZh ?? this.bodyZh,
      sourceUrl: sourceUrl,
      fingerprint: fingerprint,
      status: status ?? this.status,
      bookmarked: bookmarked ?? this.bookmarked,
      skipPreset: clearSkip ? null : (skipPreset ?? this.skipPreset),
      skipNote: clearSkip ? null : (skipNote ?? this.skipNote),
      considerNote:
          clearConsider ? null : (considerNote ?? this.considerNote),
      summaryEn: clearAnalysis ? null : (summaryEn ?? this.summaryEn),
      summaryZh: clearAnalysis ? null : (summaryZh ?? this.summaryZh),
      matchTier: clearAnalysis ? null : (matchTier ?? this.matchTier),
      matchReasons:
          clearAnalysis ? [] : (matchReasons ?? this.matchReasons),
      keyFacts: clearAnalysis ? [] : (keyFacts ?? this.keyFacts),
      analyzedAt: clearAnalysis ? null : (analyzedAt ?? this.analyzedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
