import 'dart:convert';

import 'package:http/http.dart' as http;

import 'job.dart';

class AnalysisResult {
  AnalysisResult({
    required this.summaryEn,
    required this.summaryZh,
    required this.keyFacts,
    required this.tier,
    required this.reasons,
  });

  final String summaryEn;
  final String summaryZh;
  final List<String> keyFacts;
  final MatchTier tier;
  final List<String> reasons;
}

/// Models often emit literal "\\n" inside one JSON string instead of real newlines.
String normalizeModelNewlines(String text) => text.replaceAll(r'\n', '\n');

/// One visual line per bullet; strips leading • - *
List<String> summaryBulletLines(String text) {
  final normalized = normalizeModelNewlines(text).trim();
  final out = <String>[];
  for (final line in normalized.split(RegExp(r'\r?\n'))) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final pieces = RegExp(r'•').allMatches(t).length > 1
        ? t.split(RegExp(r'•\s*')).where((s) => s.trim().isNotEmpty)
        : [t];
    for (final piece in pieces) {
      final cleaned = piece.trim().replaceFirst(RegExp(r'^[•\-*]\s*'), '');
      if (cleaned.isNotEmpty) out.add(cleaned);
    }
  }
  return out;
}

String _summaryField(Object? raw) {
  if (raw is List) {
    return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).join('\n');
  }
  return normalizeModelNewlines(raw?.toString() ?? '');
}

String extractJsonObject(String raw) {
  final start = raw.indexOf('{');
  final end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw FormatException('模型未返回 JSON');
  }
  return raw.substring(start, end + 1);
}

Future<AnalysisResult> analyzePosting({
  required String baseUrl,
  required String model,
  required String body,
}) async {
  final base =
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  final uri = Uri.parse('$base/v1/chat/completions');
  const system = '''
You summarize Upwork-style job postings for a freelancer with ADHD: scannable in under 30 seconds.
Also judge fit for long-term Flutter app maintenance (ongoing fixes/releases, not one-off native rewrites).

Reply with ONLY one JSON object, no markdown fences:
{"key_facts":["..."],"summary_en":"...","summary_zh":"...","match_tier":"strong|maybe|pass","match_reasons":["..."]}

key_facts: 4–8 bilingual scan lines. Format: EnglishLabel: EnglishValue(中文)
Examples: "Payment type: Hourly(小时计)", "Connects: 16(需16 Connects)", "Duration: 1-3 months(1-3个月)", "Payment verified: Yes(已验证)".
Cover when present: Connects; hours/week; pay type; duration; proposals/interviewing/invites; client hire rate; payment verified.
If missing use "Not stated(未说明)".

summary_en / summary_zh: REQUIRED. Use a JSON array of 3–5 strings (one bullet each), NOT one string with \\n. English bullets: short, max ~14 words. Chinese: same meaning, natural 中文.
Example: "summary_zh":["维护生产 Flutter 应用","修复崩溃与依赖","每周10–15小时"]
If you must use one string, use real newline characters inside JSON, never the two-character sequence backslash-n.

match_reasons: 2–4 short bullets (why this tier for Flutter maintenance).
match_tier: strong = clear Flutter maintenance/ongoing; maybe = partial/unclear; pass = poor fit.
''';
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'model': model,
      'stream': false,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': body},
      ],
    }),
  );
  if (res.statusCode != 200) {
    throw StateError('Ollama ${res.statusCode}: ${res.body}');
  }
  final decoded = jsonDecode(res.body) as Map<String, dynamic>;
  final content =
      (decoded['choices'] as List).first['message']['content'] as String;
  final obj = jsonDecode(extractJsonObject(content)) as Map<String, dynamic>;
  final tier = MatchTier.values.byName(obj['match_tier'] as String);
  final reasons =
      (obj['match_reasons'] as List).map((e) => e.toString()).toList();
  final facts = obj['key_facts'] == null
      ? <String>[]
      : (obj['key_facts'] as List).map((e) => e.toString()).toList();
  return AnalysisResult(
    summaryEn: _summaryField(obj['summary_en']),
    summaryZh: _summaryField(obj['summary_zh']),
    keyFacts: facts,
    tier: tier,
    reasons: reasons,
  );
}

Future<String> translatePostingToZh({
  required String baseUrl,
  required String model,
  required String body,
}) async {
  final base =
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  final uri = Uri.parse('$base/v1/chat/completions');
  const system = '''
Translate the user's Upwork job posting from English to Simplified Chinese (简体中文).
Keep line breaks and section structure. Do not add commentary.
Reply with the translation only, no markdown fences.
''';
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'model': model,
      'stream': false,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': body},
      ],
    }),
  );
  if (res.statusCode != 200) {
    throw StateError('Ollama ${res.statusCode}: ${res.body}');
  }
  final decoded = jsonDecode(res.body) as Map<String, dynamic>;
  final content =
      (decoded['choices'] as List).first['message']['content'] as String;
  return normalizeModelNewlines(content).trim();
}
