import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'job.dart';
import 'l10n.dart';
import 'ollama.dart';
import 'posting_clean.dart';
import 'settings.dart';
import 'store.dart';

TextStyle _onboardingTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleMedium!.copyWith(
        fontSize: 18,
        height: 1.5,
      );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await JobStore.open();
  final settings = await AppSettings.load();
  runApp(UpworkEasyApp(store: store, settings: settings));
}

class UpworkEasyApp extends StatelessWidget {
  const UpworkEasyApp({super.key, required this.store, required this.settings});

  final JobStore store;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: S.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: InboxPage(store: store, settings: settings),
    );
  }
}

class InboxPage extends StatefulWidget {
  const InboxPage({super.key, required this.store, required this.settings});

  final JobStore store;
  final AppSettings settings;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<Job> _jobs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    _jobs = await widget.store.listInbox();
    setState(() => _loading = false);
  }

  Future<void> _openPaste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final initialBody = clip?.text ?? '';
    final initialUrl = looksLikeUrl(initialBody.trim()) ? initialBody.trim() : '';

    final result = await showDialog<_PasteResult>(
      context: context,
      builder: (ctx) => _PasteDialog(
        initialBody: looksLikeUrl(initialBody.trim()) ? '' : initialBody,
        initialUrl: initialUrl,
      ),
    );
    if (result == null) return;

    final fp = postingFingerprint(result.body);
    final existing = await widget.store.byFingerprint(fp);
    final job = await widget.store.insertPosting(
      body: result.body,
      sourceUrl: result.sourceUrl,
      displayTitle: result.title,
    );
    await _reload();
    if (!mounted) return;
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.duplicateSnack)),
      );
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailPage(
          store: widget.store,
          settings: widget.settings,
          jobId: job.id,
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(settings: widget.settings),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _jobs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      S.emptyInbox,
                      textAlign: TextAlign.center,
                      style: _onboardingTextStyle(context),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: _jobs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final job = _jobs[i];
                    return Dismissible(
                      key: ValueKey(job.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: Text(
                          S.delete,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      onDismissed: (_) {
                        final id = job.id;
                        setState(
                          () => _jobs.removeWhere((j) => j.id == id),
                        );
                        widget.store.delete(id);
                      },
                      child: ListTile(
                        title: Text(job.displayTitle),
                        subtitle: Text(job.statusLabel()),
                        trailing: job.status == ReadinessStatus.unread
                            ? const Icon(Icons.fiber_manual_record,
                                size: 12, color: Colors.orange)
                            : null,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => JobDetailPage(
                                store: widget.store,
                                settings: widget.settings,
                                jobId: job.id,
                              ),
                            ),
                          );
                          await _reload();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPaste,
        icon: const Icon(Icons.content_paste),
        label: Text(S.paste),
      ),
    );
  }
}

class _PasteResult {
  _PasteResult({required this.body, this.sourceUrl, this.title});
  final String body;
  final String? sourceUrl;
  final String? title;
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog({required this.initialBody, required this.initialUrl});

  final String initialBody;
  final String initialUrl;

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  late final TextEditingController _body;
  late final TextEditingController _url;
  late final TextEditingController _title;

  @override
  void initState() {
    super.initState();
    final cleaned = cleanPostingBody(widget.initialBody);
    _body = TextEditingController(text: cleaned);
    _url = TextEditingController(text: widget.initialUrl);
    _title = TextEditingController(
      text: cleaned.isEmpty ? '' : defaultDisplayTitle(cleaned),
    );
  }

  @override
  void dispose() {
    _body.dispose();
    _url.dispose();
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.pasteJob),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.pasteHowTo,
                style: _onboardingTextStyle(context),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: S.bodyLabel,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                decoration: InputDecoration(
                  labelText: S.sourceUrlLabel,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: S.titleOptional,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
            final body = cleanPostingBody(_body.text);
            if (body.isEmpty) return;
            Navigator.pop(
              context,
              _PasteResult(
                body: body,
                sourceUrl: _url.text.trim().isEmpty ? null : _url.text.trim(),
                title: _title.text.trim().isEmpty ? null : _title.text.trim(),
              ),
            );
          },
          child: Text(S.saveToInbox),
        ),
      ],
    );
  }
}

class JobDetailPage extends StatefulWidget {
  const JobDetailPage({
    super.key,
    required this.store,
    required this.settings,
    required this.jobId,
  });

  final JobStore store;
  final AppSettings settings;
  final String jobId;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  Job? _job;
  bool _analyzing = false;
  late final TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final job = await widget.store.byId(widget.jobId);
    if (job != null) {
      _titleCtrl.text = job.displayTitle;
    }
    setState(() => _job = job);
  }

  Future<void> _save(Job job) async {
    await widget.store.save(job);
    await _load();
  }

  Future<void> _setStatus(ReadinessStatus status) async {
    final job = _job;
    if (job == null) return;
    if (status == ReadinessStatus.skipped) {
      final skip = await _pickSkip(context);
      if (skip == null) return;
      await _save(
        job.copyWith(
          status: ReadinessStatus.skipped,
          skipPreset: skip.preset,
          skipNote: skip.note,
        ),
      );
      return;
    }
    await _save(
      job.copyWith(
        status: status,
        clearSkip: true,
      ),
    );
  }

  Future<bool> _ensureOllamaModel() async {
    if (widget.settings.hasOllamaModel) return true;
    final modelCtrl = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.analyzeSetupTitle),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                S.analyzeSetupIntro,
                style: _onboardingTextStyle(context).copyWith(fontSize: 15),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: modelCtrl,
                decoration: InputDecoration(
                  labelText: S.modelName,
                  hintText: AppSettings.modelHint,
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              ModelQuickPick(controller: modelCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'later'),
            child: Text(S.setLater),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'settings'),
            child: Text(S.openSettings),
          ),
          FilledButton(
            onPressed: () {
              final m = modelCtrl.text.trim();
              if (m.isEmpty) return;
              Navigator.pop(ctx, m);
            },
            child: Text(S.saveAndAnalyze),
          ),
        ],
      ),
    );
    modelCtrl.dispose();
    if (!mounted || action == null || action == 'later') return false;
    if (action == 'settings') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsPage(settings: widget.settings),
        ),
      );
      return widget.settings.hasOllamaModel;
    }
    await widget.settings.setOllamaModel(action);
    return true;
  }

  Future<void> _analyze() async {
    final job = _job;
    if (job == null) return;
    if (!await _ensureOllamaModel()) return;
    setState(() => _analyzing = true);
    try {
      final result = await analyzePosting(
        baseUrl: widget.settings.ollamaBaseUrl,
        model: widget.settings.ollamaModel,
        body: job.body,
      );
      final updated = job.copyWith(
        summaryEn: result.summaryEn,
        summaryZh: result.summaryZh,
        keyFacts: result.keyFacts,
        matchTier: result.tier,
        matchReasons: result.reasons,
        analyzedAt: DateTime.now(),
      );
      await widget.store.save(updated);
      final fresh = await widget.store.byId(widget.jobId);
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _job = fresh;
        if (fresh != null) _titleCtrl.text = fresh.displayTitle;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _analyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.analyzeFailed(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    if (job == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final hasAnalysis = job.hasAnalysis;
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(job.displayTitle),
        actions: [
          IconButton(
            tooltip: S.copyAll,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: job.toShareableText()),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(S.copiedSnack)),
                );
              }
            },
          ),
          if (_analyzing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _analyze,
              child: Text(S.analyze),
            ),
        ],
        bottom: hasAnalysis
            ? TabBar(
                tabs: [
                  Tab(text: S.tabSummary),
                  Tab(text: S.tabOriginal),
                ],
              )
            : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: S.listTitle,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) =>
                      _save(job.copyWith(displayTitle: _titleCtrl.text)),
                  onTapOutside: (_) =>
                      _save(job.copyWith(displayTitle: _titleCtrl.text)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in ReadinessStatus.values)
                      ChoiceChip(
                        label: Text(Job.readinessLabel(s)),
                        selected: job.status == s,
                        onSelected: (_) => _setStatus(s),
                      ),
                  ],
                ),
                if (job.status == ReadinessStatus.skipped &&
                    job.skipPreset != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    S.skipLine(
                      Job.skipPresetLabel(job.skipPreset!),
                      job.skipNote,
                    ),
                  ),
                ],
                if (job.sourceUrl != null) ...[
                  const SizedBox(height: 8),
                  SelectableText('${S.link}: ${job.sourceUrl}'),
                ],
              ],
            ),
          ),
          Expanded(
            child: hasAnalysis
                ? TabBarView(
                    children: [
                      _SummaryTab(job: job, analyzing: _analyzing),
                      _OriginalTab(body: job.body),
                    ],
                  )
                : _OriginalTab(body: job.body),
          ),
        ],
      ),
    );
    if (!hasAnalysis) return scaffold;
    return DefaultTabController(length: 2, child: scaffold);
  }

}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.job, required this.analyzing});

  final Job job;
  final bool analyzing;

  @override
  Widget build(BuildContext context) {
    final hasSummary = job.summaryZh != null ||
        job.summaryEn != null ||
        job.keyFacts.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (analyzing)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: LinearProgressIndicator(),
          ),
        if (!hasSummary && !analyzing)
          Text(S.summaryEmpty, style: Theme.of(context).textTheme.bodyLarge),
        if (job.keyFacts.isNotEmpty) ...[
          Text(S.keyFacts, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final f in job.keyFacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText('• $f'),
            ),
          const SizedBox(height: 16),
        ],
        if (job.summaryZh != null) ...[
          Text(S.summaryZh, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final line in summaryBulletLines(job.summaryZh!))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText('• $line'),
            ),
        ],
        if (job.summaryEn != null) ...[
          const SizedBox(height: 16),
          Text(S.summaryEn, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final line in summaryBulletLines(job.summaryEn!))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText('• $line'),
            ),
        ],
      ],
    );
  }
}

class _OriginalTab extends StatelessWidget {
  const _OriginalTab({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(S.original, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SelectableText(body),
      ],
    );
  }
}

class _SkipPick {
  _SkipPick(this.preset, this.note);
  final SkipPreset preset;
  final String? note;
}

Future<_SkipPick?> _pickSkip(BuildContext context) {
  SkipPreset preset = SkipPreset.other;
  final noteCtrl = TextEditingController();
  return showDialog<_SkipPick>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.skipReason),
      content: StatefulBuilder(
        builder: (ctx, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in SkipPreset.values)
              RadioListTile<SkipPreset>(
                title: Text(Job.skipPresetLabel(p)),
                value: p,
                groupValue: preset,
                onChanged: (v) => setState(() => preset = v!),
              ),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: S.skipNote),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(
            ctx,
            _SkipPick(preset, noteCtrl.text.trim().isEmpty ? null : noteCtrl.text),
          ),
          child: Text(S.ok),
        ),
      ],
    ),
  );
}
