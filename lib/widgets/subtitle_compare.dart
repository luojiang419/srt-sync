import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_theme.dart';
import '../models/media_file.dart';
import '../models/subtitle_clip.dart';
import '../providers/match_provider.dart';

class SubtitleCompareDialog extends ConsumerWidget {
  final MediaFile videoFile;
  final MediaFile audioFile;

  const SubtitleCompareDialog({
    super.key,
    required this.videoFile,
    required this.audioFile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoClipsAsync = ref.watch(subtitleClipsProvider(videoFile.id));
    final audioClipsAsync = ref.watch(subtitleClipsProvider(audioFile.id));

    return Dialog(
      child: Container(
        width: 980,
        height: 640,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '字幕对比',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFileInfo(),
            const SizedBox(height: 16),
            Divider(color: AppTheme.border),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _buildSubtitlePanel(
                      title: '视频字幕',
                      clipsAsync: videoClipsAsync,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSubtitlePanel(
                      title: '音频字幕',
                      clipsAsync: audioClipsAsync,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfo() {
    return Row(
      children: [
        Expanded(
          child: _fileInfoCard(
            icon: Icons.videocam,
            label: p.basename(videoFile.filePath),
          ),
        ),
        const SizedBox(width: 16),
        Icon(Icons.compare_arrows, color: AppTheme.highlight),
        const SizedBox(width: 16),
        Expanded(
          child: _fileInfoCard(
            icon: Icons.audiotrack,
            label: p.basename(audioFile.filePath),
          ),
        ),
      ],
    );
  }

  Widget _fileInfoCard({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.highlight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlePanel({
    required String title,
    required AsyncValue<List<SubtitleClip>> clipsAsync,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Divider(height: 1, color: AppTheme.border),
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
                return _buildSubtitleList(clips);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleList(List<SubtitleClip> clips) {
    return ListView.separated(
      itemCount: clips.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: AppTheme.border),
      itemBuilder: (context, index) {
        final clip = clips[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                width: 96,
                child: Text(
                  '${_formatTime(clip.startMs)} -> ${_formatTime(clip.endMs)}',
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
    final minutes = (ms ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
