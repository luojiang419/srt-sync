import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../models/subtitle_clip.dart';
import '../providers/match_provider.dart';

class SubtitleDetailDialog extends ConsumerWidget {
  final String mediaFileId;
  final String fileName;

  const SubtitleDetailDialog({
    super.key,
    required this.mediaFileId,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipsAsync = ref.watch(subtitleClipsProvider(mediaFileId));

    return Dialog(
      child: Container(
        width: 680,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            Divider(color: AppTheme.border),
            const SizedBox(height: 12),
            Expanded(
              child: clipsAsync.when(
                data: (clips) {
                  if (clips.isEmpty) {
                    return Center(
                      child: Text(
                        '暂无字幕数据',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      _buildStats(clips),
                      const SizedBox(height: 12),
                      Expanded(child: _buildSubtitleList(clips)),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.subtitles_outlined, size: 20, color: AppTheme.highlight),
        const SizedBox(width: 8),
        Text(
          '字幕内容',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            fileName,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _buildStats(List<SubtitleClip> clips) {
    final totalMs = clips.fold<int>(0, (sum, c) => sum + c.durationMs);
    final duration = Duration(milliseconds: totalMs);
    final m = (duration.inSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        _statChip('${clips.length} 段', AppTheme.highlight),
        const SizedBox(width: 8),
        _statChip('总时长 $m:$s', AppTheme.textSecondary),
      ],
    );
  }

  Widget _statChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSubtitleList(List<SubtitleClip> clips) {
    return ListView.separated(
      itemCount: clips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final clip = clips[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: Text(
                  '${_formatTime(clip.startMs)} → ${_formatTime(clip.endMs)}',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  clip.text,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatTime(int ms) {
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
