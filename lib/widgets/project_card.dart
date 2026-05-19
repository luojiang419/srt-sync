import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/asr_project.dart';
import '../providers/project_list_provider.dart';

/// 工程卡片组件
class ProjectCard extends ConsumerStatefulWidget {
  final AsrProject project;

  const ProjectCard({super.key, required this.project});

  @override
  ConsumerState<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<ProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final statusColor = _statusColor(project.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? AppTheme.highlight : AppTheme.border,
              width: _isHovered ? 1.5 : 0.5,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppTheme.highlight.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go('/project/${project.id}'),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部：状态标签 + 菜单按钮
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _statusLabel(context, project.status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _buildPopupMenu(context),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 工程名称
                    Text(
                      project.name,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // 底部：创建日期
                    Text(
                      _formatDate(project.createdAt),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, size: 18, color: AppTheme.textSecondary),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (value) => _onMenuSelected(context, value),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                context.loc.t('rename'),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.folder_open, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                context.loc.t('open_project'),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
              const SizedBox(width: 8),
              Text(
                context.loc.t('delete_project'),
                style: TextStyle(color: AppTheme.error, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'rename':
        _showRenameDialog(context);
        break;
      case 'open':
        context.go('/project/${widget.project.id}');
        break;
      case 'delete':
        _showDeleteConfirm(context);
        break;
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      items: [
        PopupMenuItem(value: 'rename', child: Text(context.loc.t('rename'))),
        PopupMenuItem(
          value: 'open',
          child: Text(context.loc.t('open_project')),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(context.loc.t('delete_project')),
        ),
      ],
    ).then((value) {
      if (value != null) _onMenuSelected(context, value);
    });
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.project.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.loc.t('rename_project')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.loc.t('hint_new_name')),
          onSubmitted: (_) => _doRename(ctx, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.loc.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => _doRename(ctx, controller.text),
            child: Text(context.loc.t('confirm')),
          ),
        ],
      ),
    );
  }

  void _doRename(BuildContext dialogContext, String newName) {
    if (newName.trim().isEmpty) return;
    Navigator.pop(dialogContext);
    ref
        .read(projectListProvider.notifier)
        .renameProject(widget.project.id, newName.trim());
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.loc.t('confirm_delete')),
        content: Text(
          context.locp('delete_project_confirm', {'name': widget.project.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.loc.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(projectListProvider.notifier)
                  .deleteProject(widget.project.id);
            },
            child: Text(context.loc.t('delete')),
          ),
        ],
      ),
    );
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

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
