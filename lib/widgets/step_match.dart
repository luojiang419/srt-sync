import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../models/media_file.dart';
import '../models/sync_result.dart';
import '../providers/match_provider.dart';
import '../providers/project_detail_provider.dart';
import 'match_result_tile.dart';
import 'sync_review_dialog.dart';

enum MatchReviewFilter {
  pending('待复核'),
  all('全部'),
  accepted('已接受'),
  rejected('已移除');

  final String label;
  const MatchReviewFilter(this.label);
}

class StepMatch extends ConsumerStatefulWidget {
  final String projectId;

  const StepMatch({super.key, required this.projectId});

  @override
  ConsumerState<StepMatch> createState() => _StepMatchState();
}

class _StepMatchState extends ConsumerState<StepMatch> {
  MatchReviewFilter? _selectedFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(matchProvider.notifier).loadMatchResults(widget.projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(matchProvider);
    final projectState = ref.watch(projectDetailProvider).valueOrNull;

    return asyncState.when(
      data: (state) => _buildContent(state, projectState),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('错误: $e')),
    );
  }

  Widget _buildContent(MatchState state, ProjectDetailState? projectState) {
    final mediaById = {
      for (final file in [
        ...?projectState?.videoFiles,
        ...?projectState?.audioFiles,
      ])
        file.id: file,
    };
    final effectiveFilter =
        _selectedFilter ??
        (state.pendingCount > 0
            ? MatchReviewFilter.pending
            : MatchReviewFilter.all);
    final visibleResults = _filterResults(state.syncResults, effectiveFilter);
    final pendingResults = _filterResults(
      state.syncResults,
      MatchReviewFilter.pending,
    );
    final nextPending = pendingResults.isEmpty ? null : pendingResults.first;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: state.isMatching,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    if (state.isMatching) ...[
                      SizedBox(
                        width: 220,
                        child: LinearProgressIndicator(value: state.progress),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        state.currentVideo == null
                            ? state.stageLabel
                            : '${state.stageLabel} · ${state.currentVideo}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(matchProvider.notifier).cancelMatching();
                        },
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text('取消合板'),
                      ),
                    ] else
                      ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(matchProvider.notifier)
                              .startMatching(widget.projectId);
                        },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          state.syncResults.isEmpty ? '一键合板' : '重新合板',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '点击卡片查看合板依据、字幕分栏和锚点详情。低置信度结果会进入待复核工作台。',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                if (state.error != null)
                  Text(
                    state.error!,
                    style: TextStyle(color: AppTheme.error, fontSize: 12),
                  )
                else if (state.isCancelled)
                  Text(
                    '本次合板已取消。',
                    style: TextStyle(color: AppTheme.warning, fontSize: 12),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatChip(
                      label: '阶段',
                      value: state.stageLabel,
                      color: AppTheme.highlight,
                    ),
                    _StatChip(
                      label: '结果',
                      value: '${state.syncResults.length}',
                      color: AppTheme.highlight,
                    ),
                    _StatChip(
                      label: '待复核',
                      value: '${state.pendingCount}',
                      color: AppTheme.warning,
                    ),
                    _StatChip(
                      label: '已接受',
                      value: '${state.acceptedCount}',
                      color: AppTheme.success,
                    ),
                    _StatChip(
                      label: '已移除',
                      value: '${state.rejectedCount}',
                      color: AppTheme.error,
                    ),
                    _StatChip(
                      label: '未匹配视频',
                      value: '${state.unmatchedVideos.length}',
                      color: AppTheme.error,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '复核筛选',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<MatchReviewFilter>(
                      segments: MatchReviewFilter.values
                          .map(
                            (filter) => ButtonSegment<MatchReviewFilter>(
                              value: filter,
                              label: Text(filter.label),
                            ),
                          )
                          .toList(),
                      selected: {effectiveFilter},
                      onSelectionChanged: (value) {
                        setState(() {
                          _selectedFilter = value.first;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: visibleResults.isEmpty && !state.isMatching
                            ? Center(
                                child: Text(
                                  effectiveFilter == MatchReviewFilter.pending
                                      ? '当前没有待复核结果。'
                                      : '当前筛选下没有可显示的结果。',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: visibleResults.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final result = visibleResults[index];
                                  final video = mediaById[result.videoFileId];
                                  if (video == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final audio = result.audioFileId == null
                                      ? null
                                      : mediaById[result.audioFileId!];
                                  final isRejected =
                                      result.reviewStatus ==
                                      SyncReviewStatus.rejected;
                                  return MatchResultTile(
                                    result: result,
                                    videoFile: video,
                                    audioFile: audio,
                                    onOpenDetail: () => _openReviewDialog(
                                      results: visibleResults,
                                      initialIndex: index,
                                      filter: effectiveFilter,
                                    ),
                                    onSecondaryAction: () async {
                                      if (isRejected) {
                                        await ref
                                            .read(matchProvider.notifier)
                                            .restoreReview(
                                              result.id,
                                              widget.projectId,
                                            );
                                      } else {
                                        await ref
                                            .read(matchProvider.notifier)
                                            .rejectReview(
                                              result.id,
                                              widget.projectId,
                                            );
                                      }
                                    },
                                    secondaryTooltip: isRejected
                                        ? '恢复结果'
                                        : '标记移除',
                                    secondaryIcon: isRejected
                                        ? Icons.restore
                                        : Icons.remove_circle_outline,
                                  );
                                },
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
                                  '复核队列摘要',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _StatChip(
                                      label: '待复核',
                                      value: '${state.pendingCount}',
                                      color: AppTheme.warning,
                                    ),
                                    _StatChip(
                                      label: '已接受',
                                      value: '${state.acceptedCount}',
                                      color: AppTheme.success,
                                    ),
                                    _StatChip(
                                      label: '已移除',
                                      value: '${state.rejectedCount}',
                                      color: AppTheme.error,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: state.pendingCount > 0
                                        ? AppTheme.warning.withValues(
                                            alpha: 0.12,
                                          )
                                        : AppTheme.success.withValues(
                                            alpha: 0.12,
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: state.pendingCount > 0
                                          ? AppTheme.warning.withValues(
                                              alpha: 0.35,
                                            )
                                          : AppTheme.success.withValues(
                                              alpha: 0.35,
                                            ),
                                    ),
                                  ),
                                  child: Text(
                                    state.pendingCount > 0
                                        ? '当前导出风险：仍有 ${state.pendingCount} 条待复核结果，时间线和导出会带着这些结果继续走。'
                                        : '当前没有待复核结果，可以直接进入时间线与导出。',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: nextPending == null
                                        ? null
                                        : () => _openReviewDialog(
                                            results: pendingResults,
                                            initialIndex: 0,
                                            filter: MatchReviewFilter.pending,
                                          ),
                                    icon: const Icon(
                                      Icons.rate_review,
                                      size: 16,
                                    ),
                                    label: const Text('打开下一条待复核'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        state.unmatchedVideos.isNotEmpty &&
                                            projectState
                                                    ?.audioFiles
                                                    .isNotEmpty ==
                                                true
                                        ? () => _showManualMatchDialog(
                                            state.unmatchedVideos,
                                            projectState!.audioFiles,
                                          )
                                        : null,
                                    icon: const Icon(Icons.add_link, size: 16),
                                    label: const Text('为未匹配视频手动匹配'),
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
          ),
        ),
        if (state.isMatching)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.10),
              alignment: Alignment.center,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.stageLabel,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: state.progress),
                    const SizedBox(height: 10),
                    Text(
                      state.currentVideo == null
                          ? '正在后台处理...'
                          : state.currentVideo!,
                      textAlign: TextAlign.center,
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
      ],
    );
  }

  List<SyncResult> _filterResults(
    List<SyncResult> results,
    MatchReviewFilter filter,
  ) {
    switch (filter) {
      case MatchReviewFilter.pending:
        return results
            .where((item) => item.reviewStatus == SyncReviewStatus.pending)
            .toList();
      case MatchReviewFilter.accepted:
        return results
            .where((item) => item.reviewStatus == SyncReviewStatus.accepted)
            .toList();
      case MatchReviewFilter.rejected:
        return results
            .where((item) => item.reviewStatus == SyncReviewStatus.rejected)
            .toList();
      case MatchReviewFilter.all:
        return results;
    }
  }

  Future<void> _openReviewDialog({
    required List<SyncResult> results,
    required int initialIndex,
    required MatchReviewFilter filter,
  }) async {
    if (results.isEmpty) return;
    final clampedIndex = initialIndex.clamp(0, results.length - 1);
    final sequenceIds = results.map((item) => item.id).toList(growable: false);

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SyncReviewPage(
          projectId: widget.projectId,
          syncResultId: sequenceIds[clampedIndex],
          reviewSequenceIds: sequenceIds,
          initialIndex: clampedIndex,
          sequenceMode: _toSequenceMode(filter),
        ),
      ),
    );
  }

  SyncReviewDialogSequenceMode _toSequenceMode(MatchReviewFilter filter) {
    switch (filter) {
      case MatchReviewFilter.pending:
        return SyncReviewDialogSequenceMode.pending;
      case MatchReviewFilter.all:
        return SyncReviewDialogSequenceMode.all;
      case MatchReviewFilter.accepted:
        return SyncReviewDialogSequenceMode.accepted;
      case MatchReviewFilter.rejected:
        return SyncReviewDialogSequenceMode.rejected;
    }
  }

  Future<void> _showManualMatchDialog(
    List<MediaFile> videos,
    List<MediaFile> audios,
  ) async {
    String? selectedVideoId = videos.first.id;
    String? selectedAudioId = audios.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('为未匹配视频手动匹配'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('视频素材'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedVideoId,
                  items: videos
                      .map(
                        (video) => DropdownMenuItem(
                          value: video.id,
                          child: Text(
                            video.filePath.split(RegExp(r'[/\\]')).last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedVideoId = value),
                ),
                const SizedBox(height: 12),
                const Text('音频素材'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedAudioId,
                  items: audios
                      .map(
                        (audio) => DropdownMenuItem(
                          value: audio.id,
                          child: Text(
                            audio.filePath.split(RegExp(r'[/\\]')).last,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedAudioId = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true ||
        selectedVideoId == null ||
        selectedAudioId == null) {
      return;
    }

    await ref
        .read(matchProvider.notifier)
        .manualMatch(
          projectId: widget.projectId,
          videoFileId: selectedVideoId!,
          audioFileId: selectedAudioId!,
        );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
