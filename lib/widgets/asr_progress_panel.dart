import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/asr_batch_service.dart';

/// 单文件 ASR 进度条组件
class AsrProgressPanel extends StatelessWidget {
  final AsrFileProgress progress;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;
  final bool isSelected;
  final ValueChanged<bool>? onSelect;

  const AsrProgressPanel({
    super.key,
    required this.progress,
    this.onRetry,
    this.onTap,
    this.isSelected = false,
    this.onSelect,
  });

  bool get _canTap =>
      onTap != null &&
      (progress.status == AsrFileStatus.completed ||
          progress.status == AsrFileStatus.skipped);

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppTheme.highlight.withValues(alpha: 0.6)
        : _statusBorderColor;

    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.highlight.withValues(alpha: 0.08)
            : AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isSelected ? 1.5 : 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 选择复选框
              if (onSelect != null)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (v) => onSelect?.call(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    activeColor: AppTheme.highlight,
                  ),
                ),
              if (onSelect != null) const SizedBox(width: 8),
              Icon(_statusIcon, size: 16, color: _statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.fileName,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildStatusChip(),
              if (progress.status == AsrFileStatus.failed &&
                  onRetry != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 24,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('重试', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
              if (_canTap) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ],
            ],
          ),
          if (progress.status == AsrFileStatus.extracting ||
              progress.status == AsrFileStatus.recognizing ||
              progress.status == AsrFileStatus.saving) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress,
                minHeight: 4,
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              progress.status.label,
              style: TextStyle(color: _statusColor, fontSize: 11),
            ),
          ],
          if (progress.errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              progress.errorMessage!,
              style: TextStyle(color: AppTheme.error, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (progress.status == AsrFileStatus.completed &&
              progress.segments.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '识别到 ${progress.segments.length} 个段落',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );

    if (_canTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      );
    }
    return child;
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        progress.status.label,
        style: TextStyle(
          color: _statusColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (progress.status) {
      case AsrFileStatus.pending:
        return AppTheme.textSecondary;
      case AsrFileStatus.queued:
        return const Color(0xFF90A4AE);
      case AsrFileStatus.extracting:
      case AsrFileStatus.recognizing:
      case AsrFileStatus.saving:
        return const Color(0xFF42A5F5);
      case AsrFileStatus.completed:
        return AppTheme.success;
      case AsrFileStatus.skipped:
      case AsrFileStatus.cancelled:
        return AppTheme.warning;
      case AsrFileStatus.failed:
        return AppTheme.error;
    }
  }

  IconData get _statusIcon {
    switch (progress.status) {
      case AsrFileStatus.pending:
        return Icons.schedule;
      case AsrFileStatus.queued:
        return Icons.pending_outlined;
      case AsrFileStatus.extracting:
        return Icons.audio_file_outlined;
      case AsrFileStatus.recognizing:
        return Icons.mic;
      case AsrFileStatus.saving:
        return Icons.save_outlined;
      case AsrFileStatus.completed:
        return Icons.check_circle_outline;
      case AsrFileStatus.skipped:
        return Icons.skip_next;
      case AsrFileStatus.cancelled:
        return Icons.stop_circle_outlined;
      case AsrFileStatus.failed:
        return Icons.error_outline;
    }
  }

  Color get _statusBorderColor {
    switch (progress.status) {
      case AsrFileStatus.failed:
        return AppTheme.error.withValues(alpha: 0.3);
      case AsrFileStatus.completed:
        return AppTheme.success.withValues(alpha: 0.3);
      case AsrFileStatus.cancelled:
        return AppTheme.warning.withValues(alpha: 0.3);
      default:
        return AppTheme.border;
    }
  }
}
