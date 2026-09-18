import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'job.dart';
import 'posting_clean.dart';

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
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE jobs (
              id TEXT PRIMARY KEY,
              display_title TEXT NOT NULL,
              body TEXT NOT NULL,
              source_url TEXT,
              fingerprint TEXT NOT NULL UNIQUE,
              status TEXT NOT NULL,
              skip_preset TEXT,
              skip_note TEXT,
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
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('ALTER TABLE jobs ADD COLUMN key_facts TEXT');
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

  Map<String, Object?> _toRow(Job job) => {
        'id': job.id,
        'display_title': job.displayTitle,
        'body': job.body,
        'source_url': job.sourceUrl,
        'fingerprint': job.fingerprint,
        'status': job.status.name,
        'skip_preset': job.skipPreset?.name,
        'skip_note': job.skipNote,
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

extension JobCopy on Job {
  Job copyWith({
    String? displayTitle,
    ReadinessStatus? status,
    SkipPreset? skipPreset,
    String? skipNote,
    String? summaryEn,
    String? summaryZh,
    MatchTier? matchTier,
    List<String>? matchReasons,
    List<String>? keyFacts,
    DateTime? analyzedAt,
    DateTime? updatedAt,
    bool clearSkip = false,
    bool clearAnalysis = false,
  }) {
    return Job(
      id: id,
      displayTitle: displayTitle ?? this.displayTitle,
      body: body,
      sourceUrl: sourceUrl,
      fingerprint: fingerprint,
      status: status ?? this.status,
      skipPreset: clearSkip ? null : (skipPreset ?? this.skipPreset),
      skipNote: clearSkip ? null : (skipNote ?? this.skipNote),
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
