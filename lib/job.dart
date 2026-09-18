import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'l10n.dart';

enum ReadinessStatus { unread, read, applied, skipped }

enum SkipPreset { notFlutter, budget, timezone, closed, other }

enum MatchTier { strong, maybe, pass }

ReadinessStatus readinessFromDb(String v) =>
    ReadinessStatus.values.byName(v);

SkipPreset? skipPresetFromDb(String? v) =>
    v == null ? null : SkipPreset.values.byName(v);

MatchTier? matchTierFromDb(String? v) =>
    v == null ? null : MatchTier.values.byName(v);

String postingFingerprint(String body) {
  final normalized = body.trim().replaceAll(RegExp(r'\s+'), ' ');
  return sha256.convert(utf8.encode(normalized)).toString();
}

bool isPoorTitleLine(String line) {
  final t = line.trim();
  if (t.isEmpty) return true;
  if (looksLikeUrl(t)) return true;
  // Upwork copy often starts with "___" or dash rules before the job title.
  if (RegExp(r'^[_\-–—·•=\s]+$').hasMatch(t)) return true;
  return false;
}

String defaultDisplayTitle(String body) {
  for (final line in body.split('\n')) {
    final t = line.trim();
    if (isPoorTitleLine(t)) continue;
    return t.length > 120 ? '${t.substring(0, 120)}…' : t;
  }
  return bi('Untitled posting', '未命名职位');
}

bool looksLikeUrl(String s) {
  final t = s.trim();
  return t.startsWith('http://') || t.startsWith('https://');
}

class Job {
  Job({
    required this.id,
    required this.displayTitle,
    required this.body,
    this.sourceUrl,
    required this.fingerprint,
    required this.status,
    this.skipPreset,
    this.skipNote,
    this.summaryEn,
    this.summaryZh,
    this.matchTier,
    this.matchReasons = const [],
    this.keyFacts = const [],
    this.analyzedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String displayTitle;
  final String body;
  final String? sourceUrl;
  final String fingerprint;
  final ReadinessStatus status;
  final SkipPreset? skipPreset;
  final String? skipNote;
  final String? summaryEn;
  final String? summaryZh;
  final MatchTier? matchTier;
  final List<String> matchReasons;
  final List<String> keyFacts;
  final DateTime? analyzedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasAnalysis =>
      summaryEn != null ||
      summaryZh != null ||
      matchTier != null ||
      keyFacts.isNotEmpty;

  factory Job.fromRow(Map<String, Object?> row) {
    final reasonsRaw = row['match_reasons'] as String?;
    final factsRaw = row['key_facts'] as String?;
    return Job(
      id: row['id']! as String,
      displayTitle: row['display_title']! as String,
      body: row['body']! as String,
      sourceUrl: row['source_url'] as String?,
      fingerprint: row['fingerprint']! as String,
      status: readinessFromDb(row['status']! as String),
      skipPreset: skipPresetFromDb(row['skip_preset'] as String?),
      skipNote: row['skip_note'] as String?,
      summaryEn: row['summary_en'] as String?,
      summaryZh: row['summary_zh'] as String?,
      matchTier: matchTierFromDb(row['match_tier'] as String?),
      matchReasons: reasonsRaw == null || reasonsRaw.isEmpty
          ? []
          : (jsonDecode(reasonsRaw) as List).cast<String>(),
      keyFacts: factsRaw == null || factsRaw.isEmpty
          ? []
          : (jsonDecode(factsRaw) as List).cast<String>(),
      analyzedAt: row['analyzed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['analyzed_at']! as int),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
    );
  }

  String statusLabel() => readinessLabel(status);

  static String readinessLabel(ReadinessStatus status) {
    switch (status) {
      case ReadinessStatus.unread:
        return bi('Unread', '未读');
      case ReadinessStatus.read:
        return bi('Read', '已读');
      case ReadinessStatus.applied:
        return bi('Applied', '已投');
      case ReadinessStatus.skipped:
        return bi('Skipped', '跳过');
    }
  }

  String? matchTierLabel() {
    switch (matchTier) {
      case MatchTier.strong:
        return bi('Strong fit', '强匹配');
      case MatchTier.maybe:
        return bi('Maybe', '可考虑');
      case MatchTier.pass:
        return bi('Pass', '不建议');
      case null:
        return null;
    }
  }

  static String skipPresetLabel(SkipPreset p) {
    switch (p) {
      case SkipPreset.notFlutter:
        return bi('Not Flutter', '非 Flutter');
      case SkipPreset.budget:
        return bi('Budget', '预算');
      case SkipPreset.timezone:
        return bi('Timezone', '时区');
      case SkipPreset.closed:
        return bi('Closed', '已关闭');
      case SkipPreset.other:
        return bi('Other', '其他');
    }
  }

  /// Plain text for clipboard / sharing.
  String toShareableText() {
    final buf = StringBuffer();
    buf.writeln(displayTitle);
    if (sourceUrl != null) buf.writeln('URL: $sourceUrl');
    buf.writeln('Status: ${statusLabel()}');
    if (keyFacts.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- Key facts ---');
      for (final f in keyFacts) {
        buf.writeln('• $f');
      }
    }
    if (summaryZh != null) {
      buf.writeln();
      buf.writeln('--- Summary (ZH) ---');
      buf.writeln(summaryZh);
    }
    if (summaryEn != null) {
      buf.writeln();
      buf.writeln('--- Summary (EN) ---');
      buf.writeln(summaryEn);
    }
    if (matchTier != null) {
      buf.writeln();
      buf.writeln('Match: ${matchTierLabel()}');
      for (final r in matchReasons) {
        buf.writeln('• $r');
      }
    }
    buf.writeln();
    buf.writeln('--- Posting ---');
    buf.writeln(body);
    return buf.toString().trim();
  }
}
