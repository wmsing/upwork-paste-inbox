/// Strips common Upwork paste noise (footer, client history, similar jobs).
String cleanPostingBody(String raw) {
  final lines = raw.split('\n');
  final kept = <String>[];
  for (final line in lines) {
    final t = line.trim();
    if (startsNoiseTail(t)) break;
    if (isNoiseLine(t)) continue;
    kept.add(line);
  }
  return kept
      .join('\n')
      .trim()
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

bool startsNoiseTail(String trimmedLine) {
  if (trimmedLine.isEmpty) return false;
  for (final re in _tailStart) {
    if (re.hasMatch(trimmedLine)) return true;
  }
  return false;
}

bool isNoiseLine(String trimmedLine) {
  if (trimmedLine.isEmpty) return false;
  for (final re in _dropLine) {
    if (re.hasMatch(trimmedLine)) return true;
  }
  return false;
}

// ponytail: heuristic list; extend when new Upwork UI crumbs show up in paste
final _tailStart = [
  RegExp(r"client'?s recent history", caseSensitive: false),
  RegExp(r'^similar jobs\b', caseSensitive: false),
  RegExp(r'^other open jobs by this client', caseSensitive: false),
  RegExp(r'^footer\b', caseSensitive: false),
];

final _dropLine = [
  RegExp(r'^©\s*\d{4}\s*upwork', caseSensitive: false),
  RegExp(r'^terms of service', caseSensitive: false),
  RegExp(r'^privacy policy', caseSensitive: false),
];
