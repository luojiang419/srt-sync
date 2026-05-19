import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'providers/settings_provider.dart';
import 'services/ffmpeg_service.dart';

class AsrToolsApp extends ConsumerStatefulWidget {
  const AsrToolsApp({super.key});

  @override
  ConsumerState<AsrToolsApp> createState() => _AsrToolsAppState();
}

class _AsrToolsAppState extends ConsumerState<AsrToolsApp> {
  @override
  void initState() {
    super.initState();
    WindowGeometryListener.attach();
  }

  @override
  void dispose() {
    WindowGeometryListener.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();

    // 注入 FFmpeg 路径
    if (settings.ffmpegPath.isNotEmpty) {
      FfmpegService.setFfmpegDir(settings.ffmpegPath);
    }

    final locale = Locale(
      settings.locale == 'en' ? 'en' : 'zh',
      settings.locale == 'en' ? 'US' : 'CN',
    );

    final themeMode = settings.themeMode == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
    AppTheme.syncThemeMode(settings.themeMode);

    return MaterialApp.router(
      title: 'ASR合板工具',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
    );
  }
}
