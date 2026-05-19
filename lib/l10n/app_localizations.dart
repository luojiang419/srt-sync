import 'package:flutter/material.dart';

/// 应用多语言支持
class AppLocalizations {
  final Locale locale;
  static const List<Locale> supportedLocales = [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ];

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// 翻译映射表
  static const Map<String, Map<String, String>> _localizedValues = {
    'zh': _zh,
    'en': _en,
  };

  String t(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // ========== 中文 ==========
  static const Map<String, String> _zh = {
    // 通用
    'app_title': 'ASR合板工具',
    'confirm': '确认',
    'cancel': '取消',
    'delete': '删除',
    'save': '保存',
    'close': '关闭',
    'retry': '重试',
    'success': '成功',
    'error': '错误',
    'warning': '警告',
    'loading': '加载中...',
    'no_data': '暂无数据',
    'operation_success': '操作成功',
    'operation_failed': '操作失败',

    // 导航
    'nav_home': '工程列表',
    'nav_settings': '设置',

    // 首页
    'home_title': '工程列表',
    'home_create': '新建工程',
    'home_search_hint': '搜索工程...',
    'home_empty_title': '暂无工程',
    'home_empty_subtitle': '点击右上角"新建工程"开始',
    'home_sort_updated_new': '更新时间 新→旧',
    'home_sort_updated_old': '更新时间 旧→新',
    'home_sort_name': '名称 A→Z',
    'home_sort_created': '创建时间 新→旧',
    'home_project_created': '工程已创建',
    'home_delete_confirm_title': '删除工程',
    'home_delete_confirm': '确定要删除工程「{name}」吗？此操作不可恢复。',
    'home_delete_success': '工程已删除',

    // 新建工程对话框
    'create_project_title': '新建工程',
    'create_project_name': '工程名称',
    'create_project_name_hint': '请输入工程名称',
    'create_project_name_required': '请输入工程名称',

    // 工程详情
    'project_step_import': '素材导入',
    'project_step_recognize': '字幕准备',
    'project_step_match': '一键合板',
    'project_step_timeline': '时间线与导出',
    'project_step_import_desc': '导入素材、反解字幕并建立索引',
    'project_step_recognize_desc': '反解总字幕并建立音频字幕索引',
    'project_step_match_desc': '按字幕锚点自动合板并生成异常清单',
    'project_step_timeline_desc': '检查时间线并导出 XML、CSV、SRT',
    'project_sidebar_title': '功能菜单',
    'project_sidebar_hint': '左侧选择模块，右侧显示当前模块的工作区',
    'project_current': '使用中',
    'project_recommended': '推荐',
    'project_workspace_overview': '工作区概览',
    'project_workspace_active': '当前模块',
    'project_workspace_progress': '模块进度',
    'project_workspace_status': '工程状态',
    'project_workspace_progress_value': '{done}/{total} 模块已完成',
    'project_next_step': '进入下一步',
    'project_complete_project': '完成工程',
    'project_completed_action': '工程已完成',
    'project_switch_to_dock_style': '切换为 Dock 栏样式',
    'project_switch_to_menu_style': '切换为菜单样式',
    'project_dock_bottom_title': '底部 Dock 导航',
    'project_dock_bottom_hint': '当前已启用底部 Dock 栏，模块切换入口位于软件底部，不再显示在左侧栏。',

    // 状态
    'status_created': '已创建',
    'status_imported': '已导入',
    'status_recognizing': '识别中',
    'status_recognized': '已识别',
    'status_matched': '已匹配',
    'status_timeline': '已生成',
    'status_completed': '已完成',

    // 素材导入
    'import_title': '选择素材目录',
    'import_subtitle': '支持拖放视频/音频文件到下方区域直接导入',
    'import_video_dir': '视频目录',
    'import_audio_dir': '音频目录',
    'import_select_dir': '选择目录',
    'import_change_dir': '更换目录',
    'import_file_count': '共 {count} 个文件',
    'import_empty_hint': '选择目录或拖放文件到此处',
    'import_drop_hint': '松开以导入文件',
    'import_click_hint': '点击上方按钮选择目录',
    'import_confirm_next': '标记素材模块完成',

    // ASR 识别
    'asr_title': 'ASR 语音识别',
    'asr_start': '开始识别',
    'asr_stop': '取消',
    'asr_resume': '继续识别',
    'asr_restart': '重新识别',
    'asr_cancelled_hint': '识别已中断，点击"继续识别"可从断点恢复',
    'asr_no_files': '没有可识别的音频文件',
    'asr_click_start': '点击"开始识别"按钮启动 ASR 语音识别',
    'asr_status_pending': '待识别',
    'asr_status_extracting': '提取音频',
    'asr_status_recognizing': '识别中',
    'asr_status_saving': '保存中',
    'asr_status_completed': '已完成',
    'asr_status_skipped': '已跳过',
    'asr_status_failed': '失败',
    'asr_env_not_configured': '未配置路径',
    'asr_env_error': '环境异常',
    'asr_env_detecting': '检测中...',
    'asr_env_gpu': 'GPU 加速',
    'asr_env_cpu': 'CPU 模式',
    'asr_recognizing_progress': '识别中...',
    'asr_recognize_done': '识别完成',
    'asr_all_done': '全部完成: {count} 个文件识别成功',
    'asr_partial_done': '部分完成: {done} 成功, {fail} 失败',
    'asr_recognize_failed': '识别失败',
    'asr_can_next': '可切换到字幕匹配',
    'asr_segments_found': '识别到 {count} 个段落',
    'asr_confirm_next': '标记识别模块完成',
    'asr_env_not_ready': 'sherpa-onnx 环境未就绪，请检查路径设置',

    // 字幕匹配
    'match_title': '字幕匹配',
    'match_start': '开始匹配',
    'match_restart': '重新匹配',
    'match_no_files': '没有可匹配的文件',
    'match_click_start': '点击"开始匹配"进行字幕与视频的匹配',
    'match_matching': '匹配中...',
    'match_done': '匹配完成',
    'match_result_count': '共 {count} 组匹配',
    'match_high_confidence': '高置信度',
    'match_medium_confidence': '中置信度',
    'match_low_confidence': '低置信度',
    'match_no_match': '无匹配',
    'match_compare_title': '字幕对比',
    'match_original': '原始字幕',
    'match_matched': '匹配字幕',
    'match_confirm_next': '标记匹配模块完成',

    // 时间线
    'timeline_title': '时间线生成',
    'timeline_generate': '生成时间线',
    'timeline_regenerate': '重新生成',
    'timeline_no_data': '没有可用的匹配数据',
    'timeline_click_generate': '点击"生成时间线"创建时间线',
    'timeline_generating': '生成中...',
    'timeline_done': '时间线已生成',
    'timeline_clips_count': '共 {count} 个片段',
    'timeline_export_xml': '导出 XML',
    'timeline_export_fcpxml': '导出 FCPXML',
    'timeline_export_srt': '导出 SRT',
    'timeline_export_srt_batch': '批量导出 SRT',
    'timeline_export_success': '已导出到 {path}',
    'timeline_export_srt_count': '已导出 {count} 个 SRT 字幕文件',
    'timeline_confirm_done': '标记工程已完成',
    'timeline_video': '视频',
    'timeline_subtitle': '字幕',

    // 设置
    'settings_title': '设置',
    'settings_ffmpeg': 'FFmpeg 路径',
    'settings_sherpa': 'Sherpa-ONNX 路径',
    'settings_model': 'ASR 模型目录',
    'settings_proxy': '代理地址',
    'settings_language': '语言',
    'settings_language_zh': '简体中文',
    'settings_language_en': 'English',
    'settings_theme': '主题',
    'settings_theme_dark': '深色主题',
    'settings_theme_light': '浅色主题',
    'settings_theme_switch_to_dark': '切换到深色主题',
    'settings_theme_switch_to_light': '切换到浅色主题',
    'settings_about': '关于',
    'settings_version': '版本',
    'settings_description': 'ASR 影视素材自动合板工具',
    'settings_saved': '设置已保存',
    'settings_asr_concurrency': '并发识别',
    'settings_asr_concurrency_desc': '自动模式会根据 GPU/CPU 选择稳妥并发数',
    'settings_asr_concurrency_auto': '自动',
    'settings_asr_concurrency_manual': '手动',
    'settings_asr_concurrency_count': '并发数',
    'settings_asr_concurrency_auto_hint': '自动：GPU 默认 1 路，CPU 默认 2 路',
    'settings_asr_concurrency_manual_hint': '手动：建议 1-4 路，过高可能导致抢占资源',

    // 通用组件
    'empty_no_project': '暂无工程',
    'empty_create_first': '创建第一个工程开始使用',
    'error_page_not_found': '页面未找到',
    'error_page_back_home': '返回首页',
    'error_retry': '点击重试',

    // 工程卡片
    'card_videos': '视频',
    'card_audios': '音频',
    'card_created_at': '创建于',
  };

  // ========== 英文 ==========
  static const Map<String, String> _en = {
    // General
    'app_title': 'ASR Auto-Compose',
    'confirm': 'Confirm',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'save': 'Save',
    'close': 'Close',
    'retry': 'Retry',
    'success': 'Success',
    'error': 'Error',
    'warning': 'Warning',
    'loading': 'Loading...',
    'no_data': 'No data',
    'operation_success': 'Operation succeeded',
    'operation_failed': 'Operation failed',

    // Navigation
    'nav_home': 'Projects',
    'nav_settings': 'Settings',

    // Home
    'home_title': 'Projects',
    'home_create': 'New Project',
    'home_search_hint': 'Search projects...',
    'home_empty_title': 'No Projects',
    'home_empty_subtitle': 'Click "New Project" to get started',
    'home_sort_updated_new': 'Updated New→Old',
    'home_sort_updated_old': 'Updated Old→New',
    'home_sort_name': 'Name A→Z',
    'home_sort_created': 'Created New→Old',
    'home_project_created': 'Project created',
    'home_delete_confirm_title': 'Delete Project',
    'home_delete_confirm':
        'Are you sure you want to delete "{name}"? This cannot be undone.',
    'home_delete_success': 'Project deleted',

    // Create project
    'create_project_title': 'New Project',
    'create_project_name': 'Project Name',
    'create_project_name_hint': 'Enter project name',
    'create_project_name_required': 'Please enter a project name',

    // Project detail
    'project_step_import': 'Import',
    'project_step_recognize': 'Prepare',
    'project_step_match': 'Sync',
    'project_step_timeline': 'Timeline Export',
    'project_step_import_desc':
        'Import sources, reverse subtitles, and build indexes',
    'project_step_recognize_desc':
        'Reverse split aggregate subtitles and build indexes',
    'project_step_match_desc': 'Run subtitle-anchor sync and review exceptions',
    'project_step_timeline_desc':
        'Inspect timeline and export XML, CSV, and SRT',
    'project_sidebar_title': 'Function Menu',
    'project_sidebar_hint':
        'Choose a module on the left and work in its panel on the right',
    'project_current': 'Active',
    'project_recommended': 'Recommended',
    'project_workspace_overview': 'Workspace Overview',
    'project_workspace_active': 'Active Module',
    'project_workspace_progress': 'Module Progress',
    'project_workspace_status': 'Project Status',
    'project_workspace_progress_value': '{done}/{total} modules completed',
    'project_next_step': 'Next Step',
    'project_complete_project': 'Complete Project',
    'project_completed_action': 'Project Completed',
    'project_switch_to_dock_style': 'Switch to Dock Style',
    'project_switch_to_menu_style': 'Switch to Menu Style',
    'project_dock_bottom_title': 'Bottom Dock Navigation',
    'project_dock_bottom_hint':
        'Bottom dock mode is enabled. Module switching now appears at the bottom of the app instead of the left sidebar.',

    // Status
    'status_created': 'Created',
    'status_imported': 'Imported',
    'status_recognizing': 'Recognizing',
    'status_recognized': 'Recognized',
    'status_matched': 'Matched',
    'status_timeline': 'Generated',
    'status_completed': 'Completed',

    // Import
    'import_title': 'Select Media Directory',
    'import_subtitle': 'Drag and drop video/audio files to import',
    'import_video_dir': 'Video Directory',
    'import_audio_dir': 'Audio Directory',
    'import_select_dir': 'Select Directory',
    'import_change_dir': 'Change Directory',
    'import_file_count': '{count} files',
    'import_empty_hint': 'Select directory or drag files here',
    'import_drop_hint': 'Release to import',
    'import_click_hint': 'Click button above to select directory',
    'import_confirm_next': 'Mark Import Module Complete',

    // ASR
    'asr_title': 'ASR Recognition',
    'asr_start': 'Start',
    'asr_stop': 'Stop',
    'asr_resume': 'Resume',
    'asr_restart': 'Restart',
    'asr_cancelled_hint': 'Interrupted. Click "Resume" to continue.',
    'asr_no_files': 'No audio files to recognize',
    'asr_click_start': 'Click "Start" to begin ASR recognition',
    'asr_status_pending': 'Pending',
    'asr_status_extracting': 'Extracting Audio',
    'asr_status_recognizing': 'Recognizing',
    'asr_status_saving': 'Saving',
    'asr_status_completed': 'Completed',
    'asr_status_skipped': 'Skipped',
    'asr_status_failed': 'Failed',
    'asr_env_not_configured': 'Not Configured',
    'asr_env_error': 'Error',
    'asr_env_detecting': 'Detecting...',
    'asr_env_gpu': 'GPU',
    'asr_env_cpu': 'CPU',
    'asr_recognizing_progress': 'Recognizing...',
    'asr_recognize_done': 'Done',
    'asr_all_done': 'All done: {count} files recognized',
    'asr_partial_done': 'Partial: {done} done, {fail} failed',
    'asr_recognize_failed': 'Recognition failed',
    'asr_can_next': 'Ready for subtitle matching',
    'asr_segments_found': '{count} segments found',
    'asr_confirm_next': 'Mark Recognition Module Complete',
    'asr_env_not_ready': 'sherpa-onnx not ready, check settings',

    // Match
    'match_title': 'Subtitle Matching',
    'match_start': 'Start Matching',
    'match_restart': 'Restart',
    'match_no_files': 'No files to match',
    'match_click_start': 'Click "Start Matching" to begin',
    'match_matching': 'Matching...',
    'match_done': 'Done',
    'match_result_count': '{count} matches found',
    'match_high_confidence': 'High',
    'match_medium_confidence': 'Medium',
    'match_low_confidence': 'Low',
    'match_no_match': 'No Match',
    'match_compare_title': 'Subtitle Compare',
    'match_original': 'Original',
    'match_matched': 'Matched',
    'match_confirm_next': 'Mark Matching Module Complete',

    // Timeline
    'timeline_title': 'Timeline',
    'timeline_generate': 'Generate',
    'timeline_regenerate': 'Regenerate',
    'timeline_no_data': 'No match data available',
    'timeline_click_generate': 'Click "Generate" to create timeline',
    'timeline_generating': 'Generating...',
    'timeline_done': 'Timeline generated',
    'timeline_clips_count': '{count} clips',
    'timeline_export_xml': 'Export XML',
    'timeline_export_fcpxml': 'Export FCPXML',
    'timeline_export_srt': 'Export SRT',
    'timeline_export_srt_batch': 'Batch Export SRT',
    'timeline_export_success': 'Exported to {path}',
    'timeline_export_srt_count': '{count} SRT files exported',
    'timeline_confirm_done': 'Mark Project as Complete',
    'timeline_video': 'Video',
    'timeline_subtitle': 'Subtitle',

    // Settings
    'settings_title': 'Settings',
    'settings_ffmpeg': 'FFmpeg Path',
    'settings_sherpa': 'Sherpa-ONNX Path',
    'settings_model': 'ASR Model Directory',
    'settings_proxy': 'Proxy Address',
    'settings_language': 'Language',
    'settings_language_zh': '简体中文',
    'settings_language_en': 'English',
    'settings_theme': 'Theme',
    'settings_theme_dark': 'Dark',
    'settings_theme_light': 'Light',
    'settings_theme_switch_to_dark': 'Switch to dark theme',
    'settings_theme_switch_to_light': 'Switch to light theme',
    'settings_about': 'About',
    'settings_version': 'Version',
    'settings_description': 'ASR Auto-Compose Tool',
    'settings_saved': 'Settings saved',
    'settings_asr_concurrency': 'Parallel ASR',
    'settings_asr_concurrency_desc':
        'Auto mode chooses a conservative value based on GPU or CPU',
    'settings_asr_concurrency_auto': 'Auto',
    'settings_asr_concurrency_manual': 'Manual',
    'settings_asr_concurrency_count': 'Parallelism',
    'settings_asr_concurrency_auto_hint':
        'Auto: GPU defaults to 1 worker, CPU defaults to 2',
    'settings_asr_concurrency_manual_hint':
        'Manual: 1-4 workers recommended; higher values may contend for resources',

    // Common widgets
    'empty_no_project': 'No Projects',
    'empty_create_first': 'Create your first project',
    'error_page_not_found': 'Page Not Found',
    'error_page_back_home': 'Back to Home',
    'error_retry': 'Tap to retry',

    // Project card
    'card_videos': 'Videos',
    'card_audios': 'Audios',
    'card_created_at': 'Created',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// BuildContext 扩展，简化调用
extension LocalizationsX on BuildContext {
  AppLocalizations get loc => AppLocalizations.of(this);

  /// 翻译并替换参数，如 context.locp('asr_all_done', {'count': '5'})
  String locp(String key, Map<String, String> params) {
    var text = AppLocalizations.of(this).t(key);
    for (final entry in params.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }
}
