import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'job.dart';
import 'l10n.dart';

const _urlKey = 'saved_search_url';
const _legacyListKey = 'saved_searches_v1';

/// First URL from legacy multi-entry JSON, if any.
String? urlFromLegacySavedSearches(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final decoded = jsonDecode(raw);
  if (decoded is! List || decoded.isEmpty) return null;
  final first = decoded.first;
  if (first is! Map<String, dynamic>) return null;
  final url = first['url'];
  return url is String && url.trim().isNotEmpty ? url.trim() : null;
}

class SavedSearches {
  SavedSearches(this._prefs);

  final SharedPreferences _prefs;

  static Future<SavedSearches> load() async =>
      SavedSearches(await SharedPreferences.getInstance());

  Future<String?> url() async {
    final direct = _prefs.getString(_urlKey)?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    return urlFromLegacySavedSearches(_prefs.getString(_legacyListKey));
  }

  Future<void> setUrl(String url) async {
    final trimmed = url.trim();
    await _prefs.setString(_urlKey, trimmed);
    await _prefs.remove(_legacyListKey);
  }

  Future<void> clearUrl() async {
    await _prefs.remove(_urlKey);
    await _prefs.remove(_legacyListKey);
  }
}

Future<void> openSearchInBrowser(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !looksLikeUrl(url)) {
    throw ArgumentError('Invalid URL');
  }
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw StateError('Could not open browser');
  }
}

class SavedSearchesPage extends StatefulWidget {
  const SavedSearchesPage({super.key, required this.searches});

  final SavedSearches searches;

  @override
  State<SavedSearchesPage> createState() => _SavedSearchesPageState();
}

class _SavedSearchesPageState extends State<SavedSearchesPage> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    _url = await widget.searches.url();
    setState(() => _loading = false);
  }

  Future<void> _open() async {
    final url = _url;
    if (url == null) return;
    try {
      await openSearchInBrowser(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.openSearchFailed(e))),
      );
    }
  }

  Future<void> _editLink() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SavedSearchUrlDialog(initial: _url ?? ''),
    );
    if (result == null) return;
    await widget.searches.setUrl(result);
    await _reload();
  }

  Future<void> _clearLink() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.removeSavedSearch),
        content: Text(S.removeSavedSearchBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.searches.clearUrl();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.savedSearches)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_url == null)
                    Expanded(
                      child: Center(
                        child: Text(
                          S.savedSearchesEmpty,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      S.savedSearchUrl,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SelectableText(_url!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _open,
                      icon: const Icon(Icons.open_in_browser),
                      label: Text(S.openSavedSearch),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _editLink,
                    icon: const Icon(Icons.link),
                    label: Text(
                      _url == null ? S.saveSearchLink : S.updateSearchLink,
                    ),
                  ),
                  if (_url != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _clearLink,
                      child: Text(S.removeSavedSearch),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SavedSearchUrlDialog extends StatefulWidget {
  const _SavedSearchUrlDialog({required this.initial});

  final String initial;

  @override
  State<_SavedSearchUrlDialog> createState() => _SavedSearchUrlDialogState();
}

class _SavedSearchUrlDialogState extends State<_SavedSearchUrlDialog> {
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.saveSearchLink),
      content: SizedBox(
        width: 520,
        child: TextField(
          controller: _url,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          decoration: InputDecoration(
            labelText: S.savedSearchUrl,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: () {
            final url = _url.text.trim();
            if (!looksLikeUrl(url)) return;
            Navigator.pop(context, url);
          },
          child: Text(S.save),
        ),
      ],
    );
  }
}
