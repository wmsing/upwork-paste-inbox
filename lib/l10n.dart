/// Bilingual UI copy: English(中文)
String bi(String en, String zh) => '$en($zh)';

abstract final class S {
  static final appTitle = bi('Upwork Paste Inbox', '粘贴箱');
  static final settings = bi('Settings', '设置');
  static final paste = bi('Paste', '粘贴');
  static final pasteJob = bi('Paste job', '粘贴职位');
  /// English-only onboarding copy (portfolio / first-run).
  static const emptyInbox =
      'Add your first job:\n'
      '1. Upwork → open Job details\n'
      '2. Select all & copy (⌘A, ⌘C)\n'
      '3. Tap Paste below';
  static const pasteHowTo =
      'Upwork: Job details → select all → copy, then paste here.';
  static final duplicateSnack = bi(
    'Same posting already saved — opened existing',
    '已存在相同职位，已打开原记录',
  );
  static final bodyLabel = bi(
    'Body (copy all from Job details)',
    '正文（Job details 全选复制）',
  );
  static final sourceUrlLabel = bi('Source URL (optional)', '来源链接（可选）');
  static final titleOptional =
      bi('Title (optional, default first line)', '标题（可选，默认首行）');
  static final cancel = bi('Cancel', '取消');
  static final saveToInbox = bi('Save', '入库');
  static final analyze = bi('Analyze', '分析');
  static final delete = bi('Delete', '删除');
  static final copyAll = bi('Copy all', '复制全部');
  static final copiedSnack =
      bi('Copied to clipboard', '已复制到剪贴板');
  static final listTitle = bi('List title', '列表标题');
  static final saveTitle = bi('Save title', '保存标题');
  static final tabBookmarked = bi('Bookmarked', '收藏');
  static final bookmark = bi('Bookmark', '收藏');
  static final unbookmark = bi('Remove bookmark', '取消收藏');
  static final emptyTab = bi('Nothing in this tab', '此分类暂无职位');
  static final link = bi('Link', '链接');
  static final openOnUpwork = bi('Open on Upwork', '在 Upwork 打开');
  static const analyzeSetupIntro =
      'Analyze uses your local Ollama to:\n'
      '• Key facts first (Connects, hours, pay, competition, client)\n'
      '• Short bullet summaries in English and 中文 (ADHD-friendly scan)\n\n'
      'Enter your Ollama model name below.';
  static final analyzeSetupTitle = bi('Set up analysis', '配置分析');
  static final setLater = bi('Later', '稍后');
  static final openSettings = bi('Open Settings', '打开设置');
  static final saveAndAnalyze = bi('Save & Analyze', '保存并分析');
  static final keyFacts = bi('Key facts', '要点');
  static final summaryZh = bi('Summary (ZH)', '中文摘要');
  static final summaryEn = bi('Summary (EN)', 'English summary');
  static final match = bi('Match', '匹配');
  static final original = bi('Original text', '原文');
  static final originalLangEn = bi('EN', '英文');
  static final originalLangZh = bi('ZH', '中文');
  static final translateToZh = bi('Translate to 中文', '翻译成中文');
  static String translateFailed(Object e) =>
      bi('Translation failed: $e', '翻译失败: $e');
  static final tabSummary = bi('Summary', '摘要');
  static final tabOriginal = bi('Original', '原文');
  static final summaryEmpty =
      bi('Tap Analyze to generate summary', '点「分析」生成摘要');
  static final skipReason = bi('Skip reason', '跳过原因');
  static final skipNote = bi('Note (optional)', '备注（可选）');
  static final considerApplying = bi('Consider applying', '可考虑投');
  static final considerReason = bi('Reason (optional)', '原因（可选）');
  static String considerLine(String? note) {
    final base = bi('Consider applying', '可考虑投');
    if (note != null && note.isNotEmpty) return '$base — $note';
    return base;
  }
  static final ok = bi('OK', '确定');
  static final save = bi('Save', '保存');
  static final modelName = bi('Model name', '模型名');
  static final ollamaBaseUrl = bi('Ollama Base URL', 'Ollama 地址');
  static final savedSearches = bi('Saved search', '已存搜索');
  static final savedSearchHint = bi(
    'Open your Upwork job search in the browser (logged in)',
    '在浏览器打开你的 Upwork 职位搜索（使用已登录会话）',
  );
  static final savedSearchesEmpty = bi(
    'No search link saved yet.\nTap below to paste a URL from Upwork Find Work.',
    '还没有保存搜索链接。\n点下方按钮粘贴 Upwork 筛选页链接。',
  );
  static final savedSearchUrl = bi('Search URL', '搜索链接');
  static final saveSearchLink = bi('Save search link', '保存搜索链接');
  static final updateSearchLink = bi('Update search link', '更新搜索链接');
  static final openSavedSearch = bi('Open in browser', '在浏览器打开');
  static final removeSavedSearch = bi('Remove search link', '移除搜索链接');
  static final removeSavedSearchBody = bi(
    'Remove the saved Upwork search link from this app.',
    '将从本应用移除已保存的 Upwork 搜索链接。',
  );
  static String openSearchFailed(Object e) =>
      bi('Could not open link: $e', '无法打开链接: $e');
  static final clearPrefs = bi('Clear app preferences', '清除应用偏好');
  static final clearPrefsTitle =
      bi('Clear preferences?', '清除偏好数据？');
  static final clearPrefsBody = bi(
    'Clears your saved search link and Ollama settings. '
    'Jobs already in your inbox are kept.',
    '将清除已存搜索链接与 Ollama 设置。收件箱里已保存的职位不会删除。',
  );
  static final clearPrefsHint = bi(
    'Restore saved search link and Ollama settings to defaults.',
    '将已存搜索链接与 Ollama 设置恢复为默认状态。',
  );
  static final clearPrefsConfirm = bi('Clear', '清除');
  static final clearPrefsDone =
      bi('Preferences cleared', '偏好数据已清除');
  static String analyzeFailed(Object e) =>
      bi('Analysis failed: $e', '分析失败: $e');
  static String skipLine(String preset, String? note) {
    final base = bi('Skip', '跳过');
    if (note != null && note.isNotEmpty) return '$base: $preset — $note';
    return '$base: $preset';
  }
}
