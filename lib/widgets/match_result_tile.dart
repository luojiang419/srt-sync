import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/media_file.dart';
import '../models/sync_result.dart';
import 'common/video_thumbnail_view.dart';

class MatchResultTile extends StatelessWidget {
  final SyncResult result;
  final MediaFile videoFile;
  final MediaFile? audioFile;
  final VoidCallback onOpenDetail;
  final VoidCallback onSecondaryAction;
  final String secondaryTooltip;
  final IconData secondaryIcon;

  const MatchResultTile({
    super.key,
    required this.result,
    required this.videoFile,
    required this.audioFile,
    required this.onOpenDetail,
    required this.onSecondaryAction,
    required this.secondaryTooltip,
    required this.secondaryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(result);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onOpenDetail,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VideoThumbnailView(
                thumbnailPath: videoFile.thumbnailPath,
                width: 120,
                height: 68,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            videoFile.filePath.split(RegExp(r'[/\\]')).last,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Pill(label: result.status.label, color: color),
                        const SizedBox(width: 6),
                        _Pill(
                          label: result.reviewStatus.label,
                          color: _reviewColor(result.reviewStatus),
                        ),
                        IconButton(
                          onPressed: onSecondaryAction,
                          tooltip: secondaryTooltip,
                          icon: Icon(secondaryIcon, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      audioFile == null
                          ? '未命中外录音频'
                          : audioFile!.filePath.split(RegExp(r'[/\\]')).last,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Info(
                          label: '置信度',
                          value:
                              '${(result.confidence * 100).toStringAsFixed(0)}%',
                        ),
                        _Info(label: '锚点', value: '${result.anchorCount}'),
                        _Info(
                          label: 'Source In',
                          value: result.audioSourceInMs == null
                              ? '--'
                              : _formatMs(result.audioSourceInMs!),
                        ),
                        _Info(
                          label: 'Source Out',
                          value: result.audioSourceOutMs == null
                              ? '--'
                              : _formatMs(result.audioSourceOutMs!),
                        ),
                        if (result.needsReview) _Info(label: '复核', value: '需要'),
                      ],
                    ),
                    if ((result.notes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        result.notes!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _statusColor(SyncResult result) {
    switch (result.status) {
      case SyncStatus.autoAccepted:
        return AppTheme.success;
      case SyncStatus.mediumConfidence:
        return AppTheme.warning;
      case SyncStatus.lowConfidence:
      case SyncStatus.noSubtitle:
      case SyncStatus.noMatch:
      case SyncStatus.audioTooShort:
      case SyncStatus.sourceClamped:
      case SyncStatus.needsReview:
        return AppTheme.error;
    }
  }

  static Color _reviewColor(SyncReviewStatus status) {
    switch (status) {
      case SyncReviewStatus.notRequired:
        return AppTheme.success;
      case SyncReviewStatus.pending:
        return AppTheme.warning;
      case SyncReviewStatus.accepted:
        return AppTheme.highlight;
      case SyncReviewStatus.rejected:
        return AppTheme.error;
    }
  }

  static String _formatMs(int ms) {
    final h = (ms ~/ 3600000).toString().padLeft(2, '0');
    final m = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;

  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
    );
  }
}
