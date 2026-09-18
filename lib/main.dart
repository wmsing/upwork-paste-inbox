import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'job.dart';
import 'l10n.dart';
import 'ollama.dart';
import 'posting_clean.dart';
import 'saved_searches.dart';
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

enum _InboxTab { unread, considering, applied, bookmarked, read, skipped }

extension on _InboxTab {
  String get label {
    switch (this) {
      case _InboxTab.unread:
        return Job.readinessLabel(ReadinessStatus.unread);
      case _InboxTab.considering:
        return Job.readinessLabel(ReadinessStatus.considering);
      case _InboxTab.applied:
        return Job.readinessLabel(ReadinessStatus.applied);
      case _InboxTab.bookmarked:
        return S.tabBookmarked;
      case _InboxTab.read:
        return Job.readinessLabel(ReadinessStatus.read);
      case _InboxTab.skipped:
        return Job.readinessLabel(ReadinessStatus.skipped);
    }
  }

  bool matches(Job job) {
    switch (this) {
      case _InboxTab.unread:
        return job.status == ReadinessStatus.unread;
      case _InboxTab.considering:
        return job.status == ReadinessStatus.considering;
      case _InboxTab.applied:
        return job.status == ReadinessStatus.applied;
      case _InboxTab.bookmarked:
        return job.bookmarked;
      case _InboxTab.read:
        return job.status == ReadinessStatus.read;
      case _InboxTab.skipped:
        return job.status == ReadinessStatus.skipped;
    }
  }
}

class InboxPage extends StatefulWidget {
  const InboxPage({super.key, required this.store, required this.settings});

  final JobStore store;
  final AppSettings settings;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage>
    with SingleTickerProviderStateMixin {
  List<Job> _jobs = [];
  String? _savedSearchUrl;
  bool _loading = true;
  late final TabController _inboxTabs;

  @override
  void initState() {
    super.initState();
    _inboxTabs = TabController(length: _InboxTab.values.length, vsync: this)
      ..addListener(() {
        if (!_inboxTabs.indexIsChanging) setState(() {});
      });
    _reload();
  }

  @override
  void dispose() {
    _inboxTabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final searches = await SavedSearches.load();
    final savedUrl = await searches.url();
    _jobs = await widget.store.listInbox();
    setState(() {
      _savedSearchUrl = savedUrl;
      _loading = false;
    });
  }

  Future<void> _openSavedSearch() async {
    final url = _savedSearchUrl;
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
          focusTitleOnOpen: existing == null,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _toggleBookmark(Job job) async {
    await widget.store.save(job.copyWith(bookmarked: !job.bookmarked));
    await _reload();
  }

  Future<void> _openJobOnUpwork(Job job) async {
    final url = jobUpworkLink(job);
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

  @override
  Widget build(BuildContext context) {
    final tab = _InboxTab.values[_inboxTabs.index];
    final visible = _jobs.where(tab.matches).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(S.appTitle),
        bottom: TabBar(
          controller: _inboxTabs,
          isScrollable: true,
          tabs: [for (final t in _InboxTab.values) Tab(text: t.label)],
        ),
        actions: [
          if (_savedSearchUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: S.openSavedSearch,
              onPressed: _openSavedSearch,
            ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: S.savedSearches,
            onPressed: () async {
              final searches = await SavedSearches.load();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SavedSearchesPage(searches: searches),
                ),
              );
              await _reload();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(settings: widget.settings),
                ),
              );
              await _reload();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _jobs.isEmpty && tab == _InboxTab.unread
                          ? S.emptyInbox
                          : S.emptyTab,
                      textAlign: TextAlign.center,
                      style: _onboardingTextStyle(context),
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final job = visible[i];
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (jobUpworkLink(job) != null)
                              IconButton(
                                icon: const Icon(Icons.open_in_new),
                                tooltip: S.openOnUpwork,
                                onPressed: () => _openJobOnUpwork(job),
                              ),
                            IconButton(
                              icon: Icon(
                                job.bookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                              tooltip: job.bookmarked
                                  ? S.unbookmark
                                  : S.bookmark,
                              onPressed: () => _toggleBookmark(job),
                            ),
                            if (job.status == ReadinessStatus.unread)
                              const Icon(Icons.fiber_manual_record,
                                  size: 12, color: Colors.orange),
                          ],
                        ),
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
    this.focusTitleOnOpen = false,
  });

  final JobStore store;
  final AppSettings settings;
  final String jobId;
  final bool focusTitleOnOpen;

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  Job? _job;
  bool _analyzing = false;
  bool _translatingBody = false;
  bool _originalInZh = false;
  late final TextEditingController _titleCtrl;
  late final FocusNode _titleFocus;
  bool _titleFocused = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _titleFocus = FocusNode();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Job _withEditedTitle(Job job) {
    final t = _titleCtrl.text.trim();
    if (t.isEmpty) return job;
    return job.copyWith(displayTitle: t);
  }

  Future<void> _saveTitle() async {
    final job = _job;
    if (job == null) return;
    await _save(_withEditedTitle(job));
  }

  Future<void> _load() async {
    final job = await widget.store.byId(widget.jobId);
    if (job != null) {
      _titleCtrl.text = job.displayTitle;
      if (widget.focusTitleOnOpen && !_titleFocused) {
        _titleFocused = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _titleFocus.requestFocus();
          _titleCtrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _titleCtrl.text.length,
          );
        });
      }
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
    final base = _withEditedTitle(job);
    if (status == ReadinessStatus.skipped) {
      final skip = await _pickSkip(context);
      if (skip == null) return;
      await _save(
        base.copyWith(
          status: ReadinessStatus.skipped,
          skipPreset: skip.preset,
          skipNote: skip.note,
          clearConsider: true,
        ),
      );
      return;
    }
    await _save(
      base.copyWith(
        status: status,
        clearSkip: true,
        clearConsider: status != ReadinessStatus.considering,
      ),
    );
  }

  Future<void> _markConsidering() async {
    final job = _job;
    if (job == null) return;
    final note = await _pickConsiderReason(
      context,
      initial: job.considerNote,
    );
    if (note == null || !mounted) return;
    await _save(
      _withEditedTitle(job).copyWith(
        status: ReadinessStatus.considering,
        considerNote: note.isEmpty ? null : note,
        clearSkip: true,
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    final job = _job;
    if (job == null) return;
    await _save(_withEditedTitle(job).copyWith(bookmarked: !job.bookmarked));
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

  String _originalBodyText(Job job) {
    final zh = job.bodyZh?.trim();
    if (_originalInZh && zh != null && zh.isNotEmpty) return zh;
    return job.body;
  }

  bool _hasBodyZh(Job job) {
    final zh = job.bodyZh?.trim();
    return zh != null && zh.isNotEmpty;
  }

  Future<void> _translateBody() async {
    final job = _job;
    if (job == null) return;
    if (_hasBodyZh(job)) {
      setState(() => _originalInZh = true);
      return;
    }
    if (!await _ensureOllamaModel()) return;
    setState(() => _translatingBody = true);
    try {
      final zh = await translatePostingToZh(
        baseUrl: widget.settings.ollamaBaseUrl,
        model: widget.settings.ollamaModel,
        body: job.body,
      );
      await widget.store.save(_withEditedTitle(job).copyWith(bodyZh: zh));
      if (!mounted) return;
      setState(() {
        _translatingBody = false;
        _originalInZh = true;
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _translatingBody = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.translateFailed(e))),
        );
      }
    }
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
            icon: Icon(
              job.bookmarked ? Icons.bookmark : Icons.bookmark_border,
            ),
            tooltip: job.bookmarked ? S.unbookmark : S.bookmark,
            onPressed: _toggleBookmark,
          ),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleCtrl,
                        focusNode: _titleFocus,
                        decoration: InputDecoration(
                          labelText: S.listTitle,
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _saveTitle(),
                      ),
                    ),
                    IconButton(
                      tooltip: S.saveTitle,
                      icon: const Icon(Icons.check),
                      onPressed: _saveTitle,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in ReadinessStatus.values)
                      if (s != ReadinessStatus.considering)
                        ChoiceChip(
                          label: Text(Job.readinessLabel(s)),
                          selected: job.status == s,
                          onSelected: (_) => _setStatus(s),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _markConsidering,
                  child: Text(S.considerApplying),
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
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText('${S.link}: ${job.sourceUrl}'),
                      ),
                      if (jobUpworkLink(job) != null)
                        IconButton(
                          icon: const Icon(Icons.open_in_new),
                          tooltip: S.openOnUpwork,
                          onPressed: () async {
                            try {
                              await openSearchInBrowser(jobUpworkLink(job)!);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(S.openSearchFailed(e))),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ] else if (jobUpworkLink(job) != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        try {
                          await openSearchInBrowser(jobUpworkLink(job)!);
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(S.openSearchFailed(e))),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: Text(S.openOnUpwork),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(S.originalLangEn),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(S.originalLangZh),
                      enabled: _hasBodyZh(job),
                    ),
                  ],
                  selected: {_originalInZh && _hasBodyZh(job)},
                  onSelectionChanged: (sel) {
                    final pickZh = sel.first;
                    if (pickZh && !_hasBodyZh(job)) return;
                    setState(() => _originalInZh = pickZh);
                  },
                ),
                const SizedBox(width: 12),
                if (!_hasBodyZh(job))
                  TextButton.icon(
                    onPressed: _translatingBody ? null : _translateBody,
                    icon: _translatingBody
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.translate, size: 20),
                    label: Text(S.translateToZh),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _DetailMainWithReason(
              job: job,
              originalBody: _originalBodyText(job),
              analyzing: _analyzing,
              hasAnalysis: hasAnalysis,
            ),
          ),
        ],
      ),
    );
    if (!hasAnalysis) return scaffold;
    return DefaultTabController(length: 2, child: scaffold);
  }

}

class _DetailMainWithReason extends StatelessWidget {
  const _DetailMainWithReason({
    required this.job,
    required this.originalBody,
    required this.analyzing,
    required this.hasAnalysis,
  });

  final Job job;
  final String originalBody;
  final bool analyzing;
  final bool hasAnalysis;

  String? get _considerReason {
    if (job.status != ReadinessStatus.considering) return null;
    final t = job.considerNote?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  Widget _mainContent() {
    if (hasAnalysis) {
      return TabBarView(
        children: [
          _SummaryTab(job: job, analyzing: analyzing),
          _OriginalTab(body: originalBody),
        ],
      );
    }
    return _OriginalTab(body: originalBody);
  }

  @override
  Widget build(BuildContext context) {
    final reason = _considerReason;
    if (reason == null) return _mainContent();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _mainContent()),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: _ReasonSidebar(
            title: S.considerApplying,
            text: reason,
          ),
        ),
      ],
    );
  }
}

class _ReasonSidebar extends StatelessWidget {
  const _ReasonSidebar({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(text),
              ),
            ),
          ],
        ),
      ),
    );
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
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium;
    final header = base?.copyWith(fontWeight: FontWeight.bold);
    final lines = originalDisplayLines(body);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(S.original, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...lines.expand((line) sync* {
          if (line.text.isEmpty) {
            yield const SizedBox(height: 8);
            return;
          }
          if (line.gapBefore) {
            yield const SizedBox(height: 16);
          }
          yield SelectableText(
            line.text,
            style: line.isSectionHeader ? header : base,
          );
          yield const SizedBox(height: 4);
        }),
      ],
    );
  }
}

class _SkipPick {
  _SkipPick(this.preset, this.note);
  final SkipPreset preset;
  final String? note;
}

Future<String?> _pickConsiderReason(
  BuildContext context, {
  String? initial,
}) {
  final noteCtrl = TextEditingController(text: initial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(S.considerApplying),
      content: TextField(
        controller: noteCtrl,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: S.considerReason,
          border: const OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, noteCtrl.text.trim()),
          child: Text(S.ok),
        ),
      ],
    ),
  );
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
