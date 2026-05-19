import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';

class ThemeModeToggleButton extends ConsumerWidget {
  const ThemeModeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final isLightMode = settings.themeMode == 'light';
    final tooltip = isLightMode
        ? context.loc.t('settings_theme_switch_to_dark')
        : context.loc.t('settings_theme_switch_to_light');

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: tooltip,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: isLightMode ? 0.72 : 1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: IconButton(
            tooltip: tooltip,
            onPressed: () =>
                ref.read(settingsProvider.notifier).toggleThemeMode(),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween<double>(begin: 0.85, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                isLightMode
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
                key: ValueKey(settings.themeMode),
                color: isLightMode ? AppTheme.textPrimary : AppTheme.highlight,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
