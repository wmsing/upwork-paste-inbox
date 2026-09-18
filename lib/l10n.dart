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
  static final link = bi('Link', '链接');
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
  static final tabSummary = bi('Summary', '摘要');
  static final tabOriginal = bi('Original', '原文');
  static final summaryEmpty =
      bi('Tap Analyze to generate summary', '点「分析」生成摘要');
  static final skipReason = bi('Skip reason', '跳过原因');
  static final skipNote = bi('Note (optional)', '备注（可选）');
  static final ok = bi('OK', '确定');
  static final save = bi('Save', '保存');
  static final modelName = bi('Model name', '模型名');
  static final ollamaBaseUrl = bi('Ollama Base URL', 'Ollama 地址');
  static String analyzeFailed(Object e) =>
      bi('Analysis failed: $e', '分析失败: $e');
  static String skipLine(String preset, String? note) {
    final base = bi('Skip', '跳过');
    if (note != null && note.isNotEmpty) return '$base: $preset — $note';
    return '$base: $preset';
  }
}
