import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'saved_searches.dart';

class AppSettings {
  static const defaultBaseUrl = 'http://127.0.0.1:11434';
  static const modelHint = 'qwen3:4b-instruct';
  static const suggestedModels = ['qwen3:4b-instruct', 'qwen3.5:9b'];

  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async =>
      AppSettings(await SharedPreferences.getInstance());

  String get ollamaBaseUrl =>
      _prefs.getString('ollama_base_url') ?? defaultBaseUrl;

  /// Empty until user sets a model (first install).
  String get ollamaModel => _prefs.getString('ollama_model')?.trim() ?? '';

  bool get hasOllamaModel => ollamaModel.isNotEmpty;

  Future<void> setOllamaBaseUrl(String v) =>
      _prefs.setString('ollama_base_url', v.trim());

  Future<void> setOllamaModel(String v) =>
      _prefs.setString('ollama_model', v.trim());

  /// Wipes all SharedPreferences (saved searches, Ollama settings, etc.).
  Future<void> clearAllPreferences() => _prefs.clear();
}

/// One-tap fill for common Ollama model tags.
class ModelQuickPick extends StatelessWidget {
  const ModelQuickPick({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in AppSettings.suggestedModels)
          ActionChip(
            label: Text(m),
            onPressed: () {
              controller.text = m;
              controller.selection =
                  TextSelection.collapsed(offset: m.length);
            },
          ),
      ],
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _base;
  late final TextEditingController _model;

  @override
  void initState() {
    super.initState();
    _base = TextEditingController(text: widget.settings.ollamaBaseUrl);
    _model = TextEditingController(text: widget.settings.ollamaModel);
  }

  @override
  void dispose() {
    _base.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmark_outline),
            title: Text(S.savedSearches),
            subtitle: Text(S.savedSearchHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final searches = await SavedSearches.load();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SavedSearchesPage(searches: searches),
                ),
              );
            },
          ),
          const Divider(height: 32),
          TextField(
            controller: _base,
            decoration: InputDecoration(
              labelText: S.ollamaBaseUrl,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: InputDecoration(
              labelText: S.modelName,
              hintText: AppSettings.modelHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ModelQuickPick(controller: _model),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await widget.settings.setOllamaBaseUrl(_base.text);
              await widget.settings.setOllamaModel(_model.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(S.save),
          ),
          const SizedBox(height: 32),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            S.clearPrefsHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(S.clearPrefsTitle),
                  content: Text(S.clearPrefsBody),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(S.cancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(S.clearPrefsConfirm),
                    ),
                  ],
                ),
              );
              if (ok != true || !context.mounted) return;
              await widget.settings.clearAllPreferences();
              setState(() {
                _base.text = AppSettings.defaultBaseUrl;
                _model.clear();
              });
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.clearPrefsDone)),
              );
            },
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(S.clearPrefs),
          ),
        ],
      ),
    );
  }
}
