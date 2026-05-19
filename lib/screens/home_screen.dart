import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_theme.dart';
import '../core/snackbar_util.dart';
import '../l10n/app_localizations.dart';
import '../models/asr_project.dart';
import '../providers/project_list_provider.dart';
import '../widgets/project_card.dart';
import '../widgets/theme_mode_toggle_button.dart';

/// 排序模式
enum SortMode { updatedDesc, updatedAsc, nameAsc, createdDesc }

/// 首页 - 工程卡片列表
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  SortMode _sortMode = SortMode.updatedDesc;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_filter, color: AppTheme.highlight, size: 24),
              const SizedBox(width: 8),
              Text(
                context.loc.t('app_title'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 200,
        actions: [
          // 搜索/排序
          if (_isSearching)
            SizedBox(
              width: 200,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: context.loc.t('home_search_hint'),
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                      });
                    },
                  ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索',
              onPressed: () => setState(() => _isSearching = true),
            ),
          // 排序
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortMode.updatedDesc,
                child: Text(context.loc.t('home_sort_updated_new')),
              ),
              PopupMenuItem(
                value: SortMode.updatedAsc,
                child: Text(context.loc.t('home_sort_updated_old')),
              ),
              PopupMenuItem(
                value: SortMode.nameAsc,
                child: Text(context.loc.t('home_sort_name')),
              ),
              PopupMenuItem(
                value: SortMode.createdDesc,
                child: Text(context.loc.t('home_sort_created')),
              ),
            ],
          ),
          const ThemeModeToggleButton(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: asyncState.when(
        data: (state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return _buildError(context, state.error!);
          }
          final filtered = _filterAndSort(state.projects);
          if (filtered.isEmpty) {
            if (_searchQuery.isNotEmpty) {
              return _buildSearchEmpty(context);
            }
            return _buildEmpty(context);
          }
          return _buildProjectGrid(context, ref, filtered);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(context.locp('home_error', {'error': e.toString()})),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        tooltip: context.loc.t('home_create'),
        backgroundColor: AppTheme.highlight,
        icon: const Icon(Icons.add),
        label: Text(context.loc.t('home_create')),
      ),
    );
  }

  /// 过滤和排序
  List<AsrProject> _filterAndSort(List<AsrProject> projects) {
    var result = projects;
    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((p) => p.name.toLowerCase().contains(q)).toList();
    }
    // 排序
    switch (_sortMode) {
      case SortMode.updatedDesc:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      case SortMode.updatedAsc:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      case SortMode.nameAsc:
        result.sort((a, b) => a.name.compareTo(b.name));
      case SortMode.createdDesc:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return result;
  }

  /// 空状态
  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 72,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 20),
          Text(
            context.loc.t('home_empty_title'),
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.loc.t('home_empty_subtitle'),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// 搜索无结果
  Widget _buildSearchEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            context.locp('home_search_no_result', {'query': _searchQuery}),
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 56, color: AppTheme.error),
          const SizedBox(height: 16),
          Text(
            context.locp('home_load_error', {'error': error}),
            style: TextStyle(color: AppTheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(projectListProvider.notifier).loadProjects(),
            child: Text(context.loc.t('retry')),
          ),
        ],
      ),
    );
  }

  /// 工程卡片网格
  Widget _buildProjectGrid(
    BuildContext context,
    WidgetRef ref,
    List<AsrProject> projects,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 280,
          mainAxisExtent: 180,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          return ProjectCard(project: projects[index]);
        },
      ),
    );
  }

  /// 新建工程弹窗
  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_circle_outline, color: AppTheme.highlight, size: 22),
            const SizedBox(width: 8),
            Text(context.loc.t('create_project_title')),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.loc.t('create_project_name'),
              hintText: context.loc.t('create_project_name_hint'),
            ),
            onSubmitted: (value) => _doCreate(context, ctx, ref, value),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.loc.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => _doCreate(context, ctx, ref, controller.text),
            child: Text(context.loc.t('create')),
          ),
        ],
      ),
    );
  }

  void _doCreate(
    BuildContext parentContext,
    BuildContext dialogContext,
    WidgetRef ref,
    String name,
  ) {
    if (name.trim().isEmpty) return;
    Navigator.pop(dialogContext);
    try {
      ref.read(projectListProvider.notifier).createProject(name.trim());
      SnackbarUtil.success(
        parentContext,
        parentContext.loc.t('home_project_created'),
      );
    } catch (e) {
      SnackbarUtil.error(parentContext, '${parentContext.loc.t('error')}: $e');
    }
  }
}
