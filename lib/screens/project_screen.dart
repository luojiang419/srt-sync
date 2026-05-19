import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/asr_project.dart';
import '../providers/asr_process_provider.dart';
import '../providers/match_provider.dart';
import '../providers/project_detail_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/timeline_provider.dart';
import '../widgets/step_import.dart';
import '../widgets/step_match.dart';
import '../widgets/step_timeline.dart';
import '../widgets/theme_mode_toggle_button.dart';

/// 工程功能模块定义
class ProjectModuleDef {
  final String title;
  final String subtitle;
  final IconData icon;

  const ProjectModuleDef({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class ProjectAdvanceAction {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final Future<void> Function()? onPressed;

  const ProjectAdvanceAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    this.onPressed,
  });
}

const List<ProjectModuleDef> projectModules = [
  ProjectModuleDef(
    title: 'project_step_import',
    subtitle: 'project_step_import_desc',
    icon: Icons.folder_open,
  ),
  ProjectModuleDef(
    title: 'project_step_match',
    subtitle: 'project_step_match_desc',
    icon: Icons.compare_arrows,
  ),
  ProjectModuleDef(
    title: 'project_step_timeline',
    subtitle: 'project_step_timeline_desc',
    icon: Icons.timeline,
  ),
];

/// 工程操作页面
class ProjectScreen extends ConsumerStatefulWidget {
  final String projectId;

  const ProjectScreen({super.key, required this.projectId});

  @override
  ConsumerState<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends ConsumerState<ProjectScreen> {
  bool _isAdvancing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(projectDetailProvider.notifier).loadProject(widget.projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(projectDetailProvider);
    final settings =
        ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
    final asrState = ref.watch(asrProcessProvider).valueOrNull;
    final matchState = ref.watch(matchProvider).valueOrNull;
    final timelineState = ref.watch(timelineProvider).valueOrNull;

    return asyncState.when(
      data: (state) {
        if (state.isLoading || state.project == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final project = state.project!;
        final isDockStyle = settings.projectNavigationStyle == 'dock';
        final advanceAction = _buildAdvanceAction(
          context,
          state,
          asrState: asrState,
          matchState: matchState,
          timelineState: timelineState,
        );

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/'),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(project.name, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 12),
                _buildStatusPill(
                  _statusLabel(context, project.status),
                  _statusColor(project.status),
                ),
              ],
            ),
            actions: [
              const ThemeModeToggleButton(),
              TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined, size: 18),
                label: Text(context.loc.t('nav_home')),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final contentPadding = constraints.maxWidth < 1180
                  ? const EdgeInsets.fromLTRB(18, 18, 18, 18)
                  : const EdgeInsets.fromLTRB(24, 20, 24, 20);

              if (isDockStyle) {
                return _buildContentShell(
                  context,
                  state,
                  padding: contentPadding,
                  advanceAction: advanceAction,
                  matchState: matchState,
                  isDockStyle: true,
                );
              }

              final sidebarWidth = constraints.maxWidth < 860
                  ? 220.0
                  : constraints.maxWidth < 1180
                  ? 248.0
                  : 296.0;

              return Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: sidebarWidth,
                    child: _buildSidebar(
                      context,
                      state,
                      isDockStyle: isDockStyle,
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppTheme.border,
                  ),
                  Expanded(
                    child: _buildContentShell(
                      context,
                      state,
                      padding: contentPadding,
                      advanceAction: advanceAction,
                      matchState: matchState,
                      isDockStyle: isDockStyle,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text(context.locp('load_failed', {'error': '$e'}))),
      ),
    );
  }

  ProjectAdvanceAction _buildAdvanceAction(
    BuildContext context,
    ProjectDetailState state, {
    required AsrProcessState? asrState,
    required MatchState? matchState,
    required TimelineState? timelineState,
  }) {
    final notifier = ref.read(projectDetailProvider.notifier);
    final projectStatus = state.project!.status;

    switch (state.activeSectionIndex) {
      case 0:
        final enabled = _hasReachedStatus(
          projectStatus,
          ProjectStatus.recognized,
        );
        return ProjectAdvanceAction(
          label: context.loc.t('project_next_step'),
          icon: Icons.arrow_forward_rounded,
          color: AppTheme.highlight,
          enabled: enabled,
          onPressed: () async => notifier.setActiveSection(1),
        );
      case 1:
        final enabled =
            !(matchState?.isMatching ?? false) &&
            (_hasReachedStatus(projectStatus, ProjectStatus.matched) ||
                ((matchState?.matchedCount ?? 0) > 0));
        return ProjectAdvanceAction(
          label: context.loc.t('project_next_step'),
          icon: Icons.arrow_forward_rounded,
          color: AppTheme.highlight,
          enabled: enabled,
          onPressed: () async {
            if (!_hasReachedStatus(projectStatus, ProjectStatus.matched)) {
              await notifier.confirmMatched();
            }
            notifier.setActiveSection(2);
          },
        );
      case 2:
      default:
        final isCompleted = projectStatus == ProjectStatus.completed;
        final enabled =
            !isCompleted && (timelineState?.timelineList.isNotEmpty ?? false);
        return ProjectAdvanceAction(
          label: isCompleted
              ? context.loc.t('project_completed_action')
              : context.loc.t('project_complete_project'),
          icon: isCompleted ? Icons.check_circle : Icons.task_alt,
          color: AppTheme.success,
          enabled: enabled,
          onPressed: () async {
            await notifier.completeProject();
          },
        );
    }
  }

  bool _hasReachedStatus(ProjectStatus current, ProjectStatus target) =>
      current.index >= target.index;

  Widget _buildSidebar(
    BuildContext context,
    ProjectDetailState state, {
    required bool isDockStyle,
  }) {
    return _buildStandardSidebar(context, state);
  }

  Widget _buildStandardSidebar(BuildContext context, ProjectDetailState state) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: _buildProjectSummaryCard(state),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.loc.t('project_sidebar_title'),
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.loc.t('project_sidebar_hint'),
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              itemCount: projectModules.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildStandardModuleTile(context, state, index);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildWorkspaceOverviewCard(context, state),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStyleToggleButton(context, isDockStyle: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSummaryCard(ProjectDetailState state) {
    final project = state.project!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusPill(
                _statusLabel(context, project.status),
                _statusColor(project.status),
              ),
              _buildStatusPill(
                '${context.loc.t('card_videos')} ${state.videoFiles.length}',
                AppTheme.highlight,
              ),
              _buildStatusPill(
                '${context.loc.t('card_audios')} ${state.audioFiles.length}',
                AppTheme.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandardModuleTile(
    BuildContext context,
    ProjectDetailState state,
    int index,
  ) {
    final module = projectModules[index];
    final isSelected = index == state.activeSectionIndex;
    final isCompleted = _isModuleCompleted(state, index);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            ref.read(projectDetailProvider.notifier).setActiveSection(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.highlight.withValues(alpha: 0.1)
                : AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.highlight : AppTheme.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.highlight.withValues(alpha: 0.16)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  module.icon,
                  color: isSelected
                      ? AppTheme.highlight
                      : AppTheme.textSecondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.loc.t(module.title),
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.loc.t(module.subtitle),
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.82),
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isSelected)
                _buildStatusPill(
                  context.loc.t('project_current'),
                  AppTheme.highlight,
                )
              else if (isCompleted)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.check_circle,
                    color: AppTheme.success,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDockModuleButton(
    BuildContext context,
    ProjectDetailState state,
    int index,
  ) {
    final module = projectModules[index];
    final isSelected = index == state.activeSectionIndex;
    final isCompleted = _isModuleCompleted(state, index);

    return Tooltip(
      message: context.loc.t(module.title),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              ref.read(projectDetailProvider.notifier).setActiveSection(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 112,
            height: 76,
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : AppTheme.border.withValues(alpha: 0.9),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.highlight.withValues(alpha: 0.28),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        module.icon,
                        size: 24,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          context.loc.t(module.title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.card, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceOverviewCard(
    BuildContext context,
    ProjectDetailState state,
  ) {
    final activeModule = projectModules[state.activeSectionIndex];
    final completedCount = _completedModuleCount(state);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.loc.t('project_workspace_overview'),
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildOverviewRow(
            icon: activeModule.icon,
            label: context.loc.t('project_workspace_active'),
            value: context.loc.t(activeModule.title),
          ),
          const SizedBox(height: 10),
          _buildOverviewRow(
            icon: Icons.checklist_rounded,
            label: context.loc.t('project_workspace_progress'),
            value: context.locp('project_workspace_progress_value', {
              'done': '$completedCount',
              'total': '${projectModules.length}',
            }),
          ),
          const SizedBox(height: 10),
          _buildOverviewRow(
            icon: Icons.flag_outlined,
            label: context.loc.t('project_workspace_status'),
            value: _statusLabel(context, state.project!.status),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: AppTheme.highlight),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStyleToggleButton(
    BuildContext context, {
    required bool isDockStyle,
  }) {
    final toggle = ref
        .read(settingsProvider.notifier)
        .toggleProjectNavigationStyle;

    if (isDockStyle) {
      return Tooltip(
        message: context.loc.t('project_switch_to_menu_style'),
        child: OutlinedButton(
          onPressed: toggle,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Icon(Icons.view_sidebar_outlined, size: 20),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: toggle,
      icon: const Icon(Icons.dock_outlined, size: 18),
      label: Text(context.loc.t('project_switch_to_dock_style')),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildContentShell(
    BuildContext context,
    ProjectDetailState state, {
    required EdgeInsets padding,
    required ProjectAdvanceAction advanceAction,
    required MatchState? matchState,
    required bool isDockStyle,
  }) {
    final module = projectModules[state.activeSectionIndex];
    final hideModuleHeader = state.activeSectionIndex == 1;

    return Column(
      children: [
        if (!hideModuleHeader) ...[
          Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.loc.t(module.title),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.loc.t(module.subtitle),
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.86),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    _buildStatusPill(
                      _statusLabel(context, state.project!.status),
                      _statusColor(state.project!.status),
                    ),
                    _buildStatusPill(
                      '${context.loc.t('card_videos')} ${state.videoFiles.length}',
                      AppTheme.highlight,
                    ),
                    _buildStatusPill(
                      '${context.loc.t('card_audios')} ${state.audioFiles.length}',
                      AppTheme.accent,
                    ),
                    if (_isModuleCompleted(state, state.activeSectionIndex))
                      _buildStatusPill(
                        context.loc.t('status_completed'),
                        AppTheme.success,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
        ],
        Expanded(child: _buildModuleContent(state)),
        _buildBottomActionBar(
          context,
          advanceAction,
          state,
          matchState: matchState,
          isDockStyle: isDockStyle,
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    ProjectAdvanceAction action,
    ProjectDetailState state, {
    required MatchState? matchState,
    required bool isDockStyle,
  }) {
    final isEnabled =
        action.enabled && !_isAdvancing && !state.isPreparingSubtitles;

    if (isDockStyle) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.center,
              child: _buildDockInfoBar(context, state),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompactDock = constraints.maxWidth < 920;
                if (isCompactDock) {
                  return Column(
                    children: [
                      Center(child: _buildBottomDock(context, state)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildBottomActionButtons(
                          action,
                          isEnabled,
                          state,
                          matchState,
                        ),
                      ),
                    ],
                  );
                }

                return SizedBox(
                  height: 84,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(child: _buildBottomDock(context, state)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _buildBottomActionButtons(
                          action,
                          isEnabled,
                          state,
                          matchState,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Spacer(),
          _buildBottomActionButtons(action, isEnabled, state, matchState),
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons(
    ProjectAdvanceAction action,
    bool isEnabled,
    ProjectDetailState state,
    MatchState? matchState,
  ) {
    final prepareAction = _buildPrepareActionButton(state);
    final matchAction = _buildMatchActionButton(state, matchState);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prepareAction != null) ...[
          prepareAction,
          const SizedBox(width: 12),
        ],
        if (matchAction != null) ...[matchAction, const SizedBox(width: 12)],
        _buildAdvanceButton(action, isEnabled),
      ],
    );
  }

  Widget? _buildPrepareActionButton(ProjectDetailState state) {
    if (state.activeSectionIndex != 0) {
      return null;
    }

    final canPrepare =
        _hasCompleteImports(state) &&
        !state.isPreparingSubtitles &&
        !_isAdvancing;

    return OutlinedButton.icon(
      onPressed: canPrepare
          ? () => ref
                .read(projectDetailProvider.notifier)
                .prepareProjectSubtitles()
          : null,
      icon: state.isPreparingSubtitles
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_fix_high, size: 18),
      label: Text(state.isPreparingSubtitles ? '准备中...' : '反解字幕并建立索引'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget? _buildMatchActionButton(
    ProjectDetailState state,
    MatchState? matchState,
  ) {
    if (state.activeSectionIndex != 1) {
      return null;
    }

    final currentMatchState = matchState ?? const MatchState();
    if (currentMatchState.isMatching) {
      return OutlinedButton.icon(
        onPressed: () => ref.read(matchProvider.notifier).cancelMatching(),
        icon: const Icon(Icons.stop, size: 16),
        label: const Text('取消合板'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () {
        ref.read(matchProvider.notifier).startMatching(widget.projectId);
      },
      icon: const Icon(Icons.auto_awesome, size: 18),
      label: Text(currentMatchState.syncResults.isEmpty ? '一键合板' : '重新合板'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildDockInfoBar(BuildContext context, ProjectDetailState state) {
    final activeModule = projectModules[state.activeSectionIndex];
    final project = state.project!;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.center,
      children: [
        _buildDockCapsule(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  project.name.trim().isEmpty
                      ? 'A'
                      : project.name.trim().substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  project.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildStatusPill(
          _statusLabel(context, project.status),
          _statusColor(project.status),
        ),
        _buildStatusPill(
          '${context.loc.t('card_videos')} ${state.videoFiles.length}',
          AppTheme.highlight,
        ),
        _buildStatusPill(
          '${context.loc.t('card_audios')} ${state.audioFiles.length}',
          AppTheme.accent,
        ),
        _buildStatusPill(
          context.locp('project_workspace_progress_value', {
            'done': '${_completedModuleCount(state)}',
            'total': '${projectModules.length}',
          }),
          AppTheme.warning,
        ),
        _buildDockCapsule(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(activeModule.icon, size: 16, color: AppTheme.highlight),
              const SizedBox(width: 8),
              Text(
                context.loc.t(activeModule.title),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _buildStyleToggleButton(context, isDockStyle: true),
      ],
    );
  }

  Widget _buildDockCapsule({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }

  Widget _buildAdvanceButton(ProjectAdvanceAction action, bool isEnabled) {
    return ElevatedButton.icon(
      onPressed: isEnabled ? () => _handleAdvanceAction(action) : null,
      icon: _isAdvancing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(action.icon, size: 18),
      label: Text(action.label),
      style: ElevatedButton.styleFrom(
        backgroundColor: action.color,
        disabledBackgroundColor: AppTheme.border,
        disabledForegroundColor: AppTheme.textSecondary.withValues(alpha: 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildBottomDock(BuildContext context, ProjectDetailState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.highlight.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(projectModules.length, (index) {
            return Padding(
              padding: EdgeInsets.only(
                right: index == projectModules.length - 1 ? 0 : 10,
              ),
              child: _buildDockModuleButton(context, state, index),
            );
          }),
        ),
      ),
    );
  }

  Future<void> _handleAdvanceAction(ProjectAdvanceAction action) async {
    final callback = action.onPressed;
    if (callback == null) return;

    setState(() => _isAdvancing = true);
    try {
      await callback();
    } finally {
      if (mounted) {
        setState(() => _isAdvancing = false);
      }
    }
  }

  Widget _buildModuleContent(ProjectDetailState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey(state.activeSectionIndex),
        child: _moduleWidget(state),
      ),
    );
  }

  Widget _moduleWidget(ProjectDetailState state) {
    switch (state.activeSectionIndex) {
      case 0:
        return StepImport(
          projectId: widget.projectId,
          isPreparingSubtitles: state.isPreparingSubtitles,
          prepareSummary: state.prepareSummary,
          prepareError: state.prepareError,
        );
      case 1:
        return StepMatch(projectId: widget.projectId);
      case 2:
        return StepTimeline(projectId: widget.projectId);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  int _completedModuleCount(ProjectDetailState state) {
    if (state.project?.status == ProjectStatus.completed) {
      return projectModules.length;
    }

    return List<int>.generate(
      projectModules.length,
      (index) => index,
    ).where((index) => _isModuleCompleted(state, index)).length;
  }

  bool _isModuleCompleted(ProjectDetailState state, int index) {
    if (state.project?.status == ProjectStatus.completed) {
      return true;
    }
    return index < state.recommendedSectionIndex;
  }

  bool _hasCompleteImports(ProjectDetailState state) {
    return state.videoFiles.isNotEmpty &&
        state.audioFiles.isNotEmpty &&
        state.videoSubtitleFiles.isNotEmpty &&
        state.audioSubtitleFiles.isNotEmpty;
  }

  Color _statusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.created:
        return AppTheme.textSecondary;
      case ProjectStatus.imported:
        return AppTheme.warning;
      case ProjectStatus.recognizing:
        return const Color(0xFF42A5F5);
      case ProjectStatus.recognized:
        return const Color(0xFFAB47BC);
      case ProjectStatus.matched:
        return const Color(0xFF26C6DA);
      case ProjectStatus.timeline:
        return const Color(0xFF66BB6A);
      case ProjectStatus.completed:
        return AppTheme.success;
    }
  }

  String _statusLabel(BuildContext context, ProjectStatus status) {
    switch (status) {
      case ProjectStatus.created:
        return context.loc.t('status_created');
      case ProjectStatus.imported:
        return context.loc.t('status_imported');
      case ProjectStatus.recognizing:
        return context.loc.t('status_recognizing');
      case ProjectStatus.recognized:
        return context.loc.t('status_recognized');
      case ProjectStatus.matched:
        return context.loc.t('status_matched');
      case ProjectStatus.timeline:
        return context.loc.t('status_timeline');
      case ProjectStatus.completed:
        return context.loc.t('status_completed');
    }
  }
}
