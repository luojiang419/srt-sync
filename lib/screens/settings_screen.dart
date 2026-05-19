import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/snackbar_util.dart';
import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../services/sherpa_onnx_service.dart';
import '../widgets/theme_mode_toggle_button.dart';

/// 设置页面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSettings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Text(context.loc.t('settings_title')),
        actions: const [ThemeModeToggleButton(), SizedBox(width: 8)],
      ),
      body: asyncSettings.when(
        data: (settings) => _buildSettings(context, ref, settings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${context.loc.t('error')}: $e')),
      ),
    );
  }

  Widget _buildSettings(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== 外部工具路径 =====
              _sectionHeader(context.loc.t('settings_ffmpeg')),
              const SizedBox(height: 16),
              _pathTile(
                context: context,
                icon: Icons.movie_creation_outlined,
                title: context.loc.t('settings_ffmpeg'),
                subtitle: settings.ffmpegPath.isEmpty
                    ? '未配置'
                    : settings.ffmpegPath,
                onTap: () async {
                  final result = await FilePicker.platform.getDirectoryPath(
                    dialogTitle: '选择 FFmpeg 目录',
                  );
                  if (result != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .save(settings.copyWith(ffmpegPath: result));
                    SnackbarUtil.success(
                      context,
                      context.loc.t('settings_saved'),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _pathTile(
                context: context,
                icon: Icons.mic_outlined,
                title: context.loc.t('settings_sherpa'),
                subtitle: settings.sherpaOnnxPath.isEmpty
                    ? '未配置'
                    : settings.sherpaOnnxPath,
                onTap: () async {
                  final result = await FilePicker.platform.getDirectoryPath(
                    dialogTitle: '选择 sherpa-onnx 目录',
                  );
                  if (result != null) {
                    ref
                        .read(settingsProvider.notifier)
                        .save(settings.copyWith(sherpaOnnxPath: result));
                    SnackbarUtil.success(
                      context,
                      context.loc.t('settings_saved'),
                    );
                  }
                },
              ),

              const SizedBox(height: 32),

              // ===== 网络配置 =====
              _sectionHeader('网络配置'),
              const SizedBox(height: 16),
              _buildProxyTile(context, ref, settings),

              const SizedBox(height: 32),

              // ===== 界面语言 =====
              _sectionHeader(context.loc.t('settings_language')),
              const SizedBox(height: 16),
              _buildLocaleTile(context, ref, settings),
              const SizedBox(height: 12),
              _buildThemeTile(context, ref, settings),

              const SizedBox(height: 32),

              // ===== ASR 配置 =====
              _sectionHeader('ASR 配置'),
              const SizedBox(height: 16),
              _buildModelSelectTile(context, ref, settings),
              const SizedBox(height: 12),
              _buildVadModeTile(context, ref, settings),
              const SizedBox(height: 12),
              _buildLanguageTile(context, ref, settings),
              const SizedBox(height: 12),
              _buildConcurrencyTile(context, ref, settings),

              const SizedBox(height: 32),

              // ===== VAD 参数说明 =====
              _sectionHeader('VAD 参数预设'),
              const SizedBox(height: 12),
              _buildVadInfoCard(context),

              const SizedBox(height: 32),

              // ===== 关于 =====
              _sectionHeader(context.loc.t('settings_about')),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.highlight,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${context.loc.t('app_title')} v1.1.9',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.loc.t('settings_description'),
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _pathTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.highlight, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.folder_open, color: AppTheme.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProxyTile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final controller = TextEditingController(text: settings.proxyAddress);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.vpn_lock, color: AppTheme.highlight, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.loc.t('settings_proxy'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    settings.hasProxy ? '当前: ${settings.proxyAddress}' : '未配置',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              child: TextField(
                controller: controller,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'host:port',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check, size: 18),
                    tooltip: '保存',
                    onPressed: () {
                      ref
                          .read(settingsProvider.notifier)
                          .save(
                            settings.copyWith(
                              proxyAddress: controller.text.trim(),
                            ),
                          );
                      SnackbarUtil.success(
                        context,
                        context.loc.t('settings_saved'),
                      );
                    },
                  ),
                ),
                onSubmitted: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .save(settings.copyWith(proxyAddress: value.trim()));
                  SnackbarUtil.success(
                    context,
                    context.loc.t('settings_saved'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocaleTile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.language, color: AppTheme.highlight, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.loc.t('settings_language'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '切换应用显示语言',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: settings.locale,
              dropdownColor: AppTheme.surface,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: 'zh',
                  child: Text(context.loc.t('settings_language_zh')),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(context.loc.t('settings_language_en')),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .save(settings.copyWith(locale: v));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.dark_mode_outlined, color: AppTheme.highlight, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.loc.t('settings_theme'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    settings.themeMode == 'dark'
                        ? context.loc.t('settings_theme_dark')
                        : context.loc.t('settings_theme_light'),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: settings.themeMode,
              dropdownColor: AppTheme.surface,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: 'dark',
                  child: Text(context.loc.t('settings_theme_dark')),
                ),
                DropdownMenuItem(
                  value: 'light',
                  child: Text(context.loc.t('settings_theme_light')),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(settingsProvider.notifier).setThemeMode(v);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelectTile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    // 检测可用模型
    final env = settings.sherpaOnnxPath.isNotEmpty
        ? SherpaOnnxService.checkEnv(
            settings.sherpaOnnxPath,
            settings.asrModelId,
          )
        : null;

    final models = <DropdownMenuItem<String>>[
      if (env?.hasFireRedAsr == true)
        const DropdownMenuItem(
          value: 'fire-red-asr',
          child: Text('FireRed-ASR'),
        ),
      if (env?.hasParaformerZh == true)
        const DropdownMenuItem(
          value: 'paraformer-zh',
          child: Text('Paraformer-zh'),
        ),
    ];

    // 如果没有可用模型，显示提示
    if (models.isEmpty) {
      models.add(const DropdownMenuItem(value: 'none', child: Text('未检测到模型')));
    }

    final currentValue = models.any((m) => m.value == settings.asrModelId)
        ? settings.asrModelId
        : models.first.value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.model_training, color: AppTheme.highlight, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ASR 模型',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '选择语音识别模型，影响准确率和速度',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: currentValue,
              dropdownColor: AppTheme.surface,
              underline: const SizedBox.shrink(),
              items: models,
              onChanged: (v) {
                if (v != null && v != 'none') {
                  ref
                      .read(settingsProvider.notifier)
                      .save(settings.copyWith(asrModelId: v));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVadModeTile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.tune, color: AppTheme.highlight, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VAD 模式',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '长音频模式适合长时间连续录音',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: settings.vadMode,
              dropdownColor: AppTheme.surface,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'standard', child: Text('标准模式')),
                DropdownMenuItem(value: 'long_audio', child: Text('长音频模式')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .save(settings.copyWith(vadMode: v));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageTile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.translate, color: AppTheme.highlight, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '识别语言',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'auto 自动检测中文/英文/日文/韩文/粤语',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: settings.asrLanguage,
              dropdownColor: AppTheme.surface,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('自动检测')),
                DropdownMenuItem(value: 'zh', child: Text('中文')),
                DropdownMenuItem(value: 'en', child: Text('英文')),
                DropdownMenuItem(value: 'ja', child: Text('日文')),
                DropdownMenuItem(value: 'ko', child: Text('韩文')),
                DropdownMenuItem(value: 'yue', child: Text('粤语')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .save(settings.copyWith(asrLanguage: v));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConcurrencyTile(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    final isManual = settings.asrConcurrencyMode == 'manual';
    final hint = isManual
        ? context.loc.t('settings_asr_concurrency_manual_hint')
        : context.loc.t('settings_asr_concurrency_auto_hint');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.hub_outlined, color: AppTheme.highlight, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.loc.t('settings_asr_concurrency'),
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.loc.t('settings_asr_concurrency_desc'),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<String>(
              value: settings.asrConcurrencyMode,
              dropdownColor: AppTheme.surface,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(
                  value: 'auto',
                  child: Text(context.loc.t('settings_asr_concurrency_auto')),
                ),
                DropdownMenuItem(
                  value: 'manual',
                  child: Text(context.loc.t('settings_asr_concurrency_manual')),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref
                      .read(settingsProvider.notifier)
                      .save(settings.copyWith(asrConcurrencyMode: v));
                }
              },
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: DropdownButtonFormField<int>(
                initialValue: settings.asrMaxConcurrency,
                dropdownColor: AppTheme.surface,
                decoration: InputDecoration(
                  labelText: context.loc.t('settings_asr_concurrency_count'),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                items: [
                  for (
                    int i = AppConstants.minAsrConcurrency;
                    i <= AppConstants.maxAsrConcurrency;
                    i++
                  )
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: isManual
                    ? (v) {
                        if (v != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .save(settings.copyWith(asrMaxConcurrency: v));
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVadInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _vadParamRow('参数', '标准模式', '长音频模式', isHeader: true),
            Divider(color: AppTheme.border, height: 16),
            _vadParamRow(
              'VAD阈值',
              '${AppConstants.vadStandard.threshold}',
              '${AppConstants.vadLongAudio.threshold}',
            ),
            _vadParamRow(
              '最小静默(秒)',
              '${AppConstants.vadStandard.minSilenceDuration}',
              '${AppConstants.vadLongAudio.minSilenceDuration}',
            ),
            _vadParamRow(
              '最大语音(秒)',
              '${AppConstants.vadStandard.maxSpeechDuration}',
              '${AppConstants.vadLongAudio.maxSpeechDuration}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _vadParamRow(
    String label,
    String standard,
    String longAudio, {
    bool isHeader = false,
  }) {
    final style = isHeader
        ? TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          )
        : TextStyle(color: AppTheme.textPrimary, fontSize: 13);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: style)),
          SizedBox(
            width: 80,
            child: Text(standard, style: style, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 80,
            child: Text(longAudio, style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
