import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../services/app_data_service.dart';

/// 应用设置
class AppSettings {
  final String ffmpegPath;
  final String sherpaOnnxPath;
  final String modelPath;
  final String proxyAddress;
  final String vadMode; // 'standard' | 'long_audio'
  final String asrLanguage;
  final String asrModelId; // 'fire-red-asr' | 'paraformer-zh'
  final String asrConcurrencyMode; // 'auto' | 'manual'
  final int asrMaxConcurrency; // 1 ~ 4
  final String locale; // 'zh' | 'en'
  final String themeMode; // 'dark' | 'light'
  final String projectNavigationStyle; // 'menu' | 'dock'
  final double? windowX;
  final double? windowY;
  final double? windowWidth;
  final double? windowHeight;

  const AppSettings({
    this.ffmpegPath = r'G:\data\app\DIT\ffmpeg',
    this.sherpaOnnxPath = r'G:\data\app\DIT\sherpa-onnx',
    this.modelPath = '',
    this.proxyAddress = '192.168.0.211:7890',
    this.vadMode = 'long_audio',
    this.asrLanguage = 'auto',
    this.asrModelId = 'fire-red-asr',
    this.asrConcurrencyMode = AppConstants.defaultAsrConcurrencyMode,
    this.asrMaxConcurrency = AppConstants.defaultAsrMaxConcurrency,
    this.locale = 'zh',
    this.themeMode = 'dark',
    this.projectNavigationStyle = 'menu',
    this.windowX,
    this.windowY,
    this.windowWidth,
    this.windowHeight,
  });

  bool get hasWindowGeometry =>
      windowX != null &&
      windowY != null &&
      windowWidth != null &&
      windowHeight != null;

  bool get hasProxy => proxyAddress.isNotEmpty;

  String get proxyUrl => 'http://$proxyAddress';

  AppSettings copyWith({
    String? ffmpegPath,
    String? sherpaOnnxPath,
    String? modelPath,
    String? proxyAddress,
    String? vadMode,
    String? asrLanguage,
    String? asrModelId,
    String? asrConcurrencyMode,
    int? asrMaxConcurrency,
    String? locale,
    String? themeMode,
    String? projectNavigationStyle,
    double? windowX,
    double? windowY,
    double? windowWidth,
    double? windowHeight,
  }) {
    return AppSettings(
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      sherpaOnnxPath: sherpaOnnxPath ?? this.sherpaOnnxPath,
      modelPath: modelPath ?? this.modelPath,
      proxyAddress: proxyAddress ?? this.proxyAddress,
      vadMode: vadMode ?? this.vadMode,
      asrLanguage: asrLanguage ?? this.asrLanguage,
      asrModelId: asrModelId ?? this.asrModelId,
      asrConcurrencyMode: asrConcurrencyMode ?? this.asrConcurrencyMode,
      asrMaxConcurrency: asrMaxConcurrency ?? this.asrMaxConcurrency,
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      projectNavigationStyle:
          projectNavigationStyle ?? this.projectNavigationStyle,
      windowX: windowX ?? this.windowX,
      windowY: windowY ?? this.windowY,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
    );
  }

  Map<String, dynamic> toMap() => {
    'ffmpeg_path': ffmpegPath,
    'sherpa_onnx_path': sherpaOnnxPath,
    'model_path': modelPath,
    'proxy_address': proxyAddress,
    'vad_mode': vadMode,
    'asr_language': asrLanguage,
    'asr_model_id': asrModelId,
    'asr_concurrency_mode': asrConcurrencyMode,
    'asr_max_concurrency': asrMaxConcurrency,
    'locale': locale,
    'theme_mode': themeMode,
    'project_navigation_style': projectNavigationStyle,
    'window_x': windowX,
    'window_y': windowY,
    'window_width': windowWidth,
    'window_height': windowHeight,
  };

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
    ffmpegPath: map['ffmpeg_path'] as String? ?? r'G:\data\app\DIT\ffmpeg',
    sherpaOnnxPath:
        map['sherpa_onnx_path'] as String? ?? r'G:\data\app\DIT\sherpa-onnx',
    modelPath: map['model_path'] as String? ?? '',
    proxyAddress: map['proxy_address'] as String? ?? '192.168.0.211:7890',
    vadMode: map['vad_mode'] as String? ?? 'long_audio',
    asrLanguage: map['asr_language'] as String? ?? 'auto',
    asrModelId: switch (map['asr_model_id'] as String?) {
      'paraformer-zh' => 'paraformer-zh',
      _ => 'fire-red-asr',
    },
    asrConcurrencyMode: switch (map['asr_concurrency_mode'] as String?) {
      'manual' => 'manual',
      _ => AppConstants.defaultAsrConcurrencyMode,
    },
    asrMaxConcurrency:
        ((map['asr_max_concurrency'] as num?)?.toInt() ??
                AppConstants.defaultAsrMaxConcurrency)
            .clamp(
              AppConstants.minAsrConcurrency,
              AppConstants.maxAsrConcurrency,
            ),
    locale: map['locale'] as String? ?? 'zh',
    themeMode: (map['theme_mode'] as String?) == 'light' ? 'light' : 'dark',
    projectNavigationStyle:
        (map['project_navigation_style'] as String?) == 'dock'
        ? 'dock'
        : 'menu',
    windowX: (map['window_x'] as num?)?.toDouble(),
    windowY: (map['window_y'] as num?)?.toDouble(),
    windowWidth: (map['window_width'] as num?)?.toDouble(),
    windowHeight: (map['window_height'] as num?)?.toDouble(),
  );
}

/// 设置持久化 Notifier
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  AppSettings build() {
    Future.microtask(() => _load());
    return const AppSettings();
  }

  Future<void> _load() async {
    try {
      final file = File(await AppDataService.settingsFilePath());
      if (await file.exists()) {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        state = AsyncData(AppSettings.fromMap(json));
      } else {
        state = const AsyncData(AppSettings());
      }
    } catch (_) {
      state = const AsyncData(AppSettings());
    }
  }

  Future<void> save(AppSettings settings) async {
    state = AsyncData(settings);
    try {
      final file = File(await AppDataService.settingsFilePath());
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(settings.toMap()));
    } catch (_) {}
  }

  Future<void> setProjectNavigationStyle(String style) async {
    final current = state.valueOrNull ?? const AppSettings();
    await save(
      current.copyWith(
        projectNavigationStyle: style == 'dock' ? 'dock' : 'menu',
      ),
    );
  }

  Future<void> toggleProjectNavigationStyle() async {
    final current = state.valueOrNull ?? const AppSettings();
    final nextStyle = current.projectNavigationStyle == 'dock'
        ? 'menu'
        : 'dock';
    await save(current.copyWith(projectNavigationStyle: nextStyle));
  }

  Future<void> setThemeMode(String mode) async {
    final current = state.valueOrNull ?? const AppSettings();
    await save(current.copyWith(themeMode: mode == 'light' ? 'light' : 'dark'));
  }

  Future<void> toggleThemeMode() async {
    final current = state.valueOrNull ?? const AppSettings();
    final nextMode = current.themeMode == 'light' ? 'dark' : 'light';
    await save(current.copyWith(themeMode: nextMode));
  }
}

/// 设置 Provider
final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
