import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../models/media_file.dart';
import '../providers/asr_process_provider.dart';
import '../providers/project_detail_provider.dart';
import '../services/subtitle_prepare_service.dart';

class StepRecognize extends ConsumerStatefulWidget {
  final String projectId;

  const StepRecognize({super.key, required this.projectId});

  @override
  ConsumerState<StepRecognize> createState() => _StepRecognizeState();
}

class _StepRecognizeState extends ConsumerState<StepRecognize> {
  bool _isPreparing = false;
  SubtitlePrepareSummary? _summary;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectDetailProvider).valueOrNull;
    final asrState = ref.watch(asrProcessProvider).valueOrNull;

    final missingSubtitleFiles = [
      ...(projectState?.videoFiles ?? const []).where(
        (file) => file.subtitleStatus != SubtitleStatus.completed,
      ),
      ...(projectState?.audioFiles ?? const []).where(
        (file) => file.subtitleStatus != SubtitleStatus.completed,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '字幕准备',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isPreparing ? null : _prepareProject,
                icon: _isPreparing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high, size: 18),
                label: Text(_isPreparing ? '准备中...' : '反解字幕并建立索引'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '这一步会生成素材平铺表、解析总字幕、反解为单条素材字幕，并建立音频字幕窗口索引。',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                label: '视频素材',
                value: '${projectState?.videoFiles.length ?? 0}',
              ),
              _InfoChip(
                label: '音频素材',
                value: '${projectState?.audioFiles.length ?? 0}',
              ),
              _InfoChip(
                label: '视频字幕',
                value: '${projectState?.videoSubtitleFiles.length ?? 0}',
              ),
              _InfoChip(
                label: '音频字幕',
                value: '${projectState?.audioSubtitleFiles.length ?? 0}',
              ),
              if (_summary != null) ...[
                _InfoChip(
                  label: '反解字幕',
                  value: '${_summary!.generatedSubtitleClips}',
                ),
                _InfoChip(
                  label: '音频窗口',
                  value: '${_summary!.generatedWindows}',
                ),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '准备结果',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView(
                              children: [
                                _StatusRow(
                                  title: '视频字幕文件',
                                  detail:
                                      '${projectState?.videoSubtitleFiles.length ?? 0} 份',
                                ),
                                _StatusRow(
                                  title: '音频字幕文件',
                                  detail:
                                      '${projectState?.audioSubtitleFiles.length ?? 0} 份',
                                ),
                                _StatusRow(
                                  title: '已生成视频/音频平铺表',
                                  detail: _summary == null ? '等待执行' : '已完成',
                                ),
                                _StatusRow(
                                  title: '总字幕反解',
                                  detail: _summary == null
                                      ? '等待执行'
                                      : '已生成 ${_summary!.generatedSubtitleClips} 条单素材字幕',
                                ),
                                _StatusRow(
                                  title: '音频索引窗口',
                                  detail: _summary == null
                                      ? '等待执行'
                                      : '已生成 ${_summary!.generatedWindows} 个检索窗口',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '补录字幕',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '对没有字幕的素材，可继续走旧 ASR 流程作为补录，不阻塞主合板流程。',
                            style: TextStyle(
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.85,
                              ),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _InfoChip(
                            label: '待补录素材',
                            value: '${missingSubtitleFiles.length}',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  missingSubtitleFiles.isEmpty ||
                                      (asrState?.isRunning ?? false)
                                  ? null
                                  : () => _startAsrFallback(
                                      missingSubtitleFiles
                                          .map((file) => file.id)
                                          .toList(),
                                    ),
                              icon: const Icon(Icons.mic, size: 16),
                              label: Text(
                                (asrState?.isRunning ?? false)
                                    ? '补录中...'
                                    : '补录缺失字幕',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (asrState != null &&
                              asrState.fileProgresses.isNotEmpty)
                            Expanded(
                              child: ListView.separated(
                                itemCount: asrState.fileProgresses.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final progress =
                                      asrState.fileProgresses[index];
                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppTheme.border,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          progress.fileName,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        LinearProgressIndicator(
                                          value: progress.progress,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          progress.status.label,
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _prepareProject() async {
    setState(() {
      _isPreparing = true;
      _error = null;
    });
    try {
      final summary = await SubtitlePrepareService.prepareProject(
        widget.projectId,
      );
      await ref.read(projectDetailProvider.notifier).confirmRecognize();
      await ref
          .read(projectDetailProvider.notifier)
          .loadProject(widget.projectId);
      setState(() {
        _summary = summary;
      });
    } catch (e) {
      setState(() {
        _error = '字幕准备失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _startAsrFallback(List<String> targetFileIds) async {
    await ref
        .read(asrProcessProvider.notifier)
        .startBatchRecognize(widget.projectId, targetFileIds: targetFileIds);
    await ref
        .read(projectDetailProvider.notifier)
        .loadProject(widget.projectId);
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String detail;

  const _StatusRow({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
          Text(
            detail,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
