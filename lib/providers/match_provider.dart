import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/asr_project.dart';
import '../models/media_file.dart';
import '../models/subtitle_clip.dart';
import '../models/sync_review_detail.dart';
import '../models/sync_result.dart';
import '../services/database_service.dart';
import '../services/subtitle_match_service.dart';

class MatchState {
  final bool isMatching;
  final bool isCancelled;
  final double progress;
  final String stageLabel;
  final String? currentVideo;
  final List<SyncResult> syncResults;
  final List<MediaFile> unmatchedVideos;
  final List<MediaFile> unmatchedAudios;
  final String? error;

  const MatchState({
    this.isMatching = false,
    this.isCancelled = false,
    this.progress = 0.0,
    this.stageLabel = '待开始',
    this.currentVideo,
    this.syncResults = const [],
    this.unmatchedVideos = const [],
    this.unmatchedAudios = const [],
    this.error,
  });

  MatchState copyWith({
    bool? isMatching,
    bool? isCancelled,
    double? progress,
    String? stageLabel,
    String? currentVideo,
    List<SyncResult>? syncResults,
    List<MediaFile>? unmatchedVideos,
    List<MediaFile>? unmatchedAudios,
    String? error,
  }) {
    return MatchState(
      isMatching: isMatching ?? this.isMatching,
      isCancelled: isCancelled ?? this.isCancelled,
      progress: progress ?? this.progress,
      stageLabel: stageLabel ?? this.stageLabel,
      currentVideo: currentVideo,
      syncResults: syncResults ?? this.syncResults,
      unmatchedVideos: unmatchedVideos ?? this.unmatchedVideos,
      unmatchedAudios: unmatchedAudios ?? this.unmatchedAudios,
      error: error,
    );
  }

  int get highConfidenceCount => syncResults
      .where(
        (item) =>
            !item.isRejected &&
            item.confidence >= 0.9 &&
            item.audioFileId != null,
      )
      .length;

  int get mediumConfidenceCount => syncResults
      .where(
        (item) =>
            item.confidence >= 0.7 &&
            item.confidence < 0.9 &&
            !item.isRejected &&
            item.audioFileId != null,
      )
      .length;

  int get lowConfidenceCount => syncResults
      .where(
        (item) =>
            !item.isRejected &&
            item.audioFileId != null &&
            item.confidence < 0.7,
      )
      .length;

  int get needsReviewCount =>
      syncResults.where((item) => item.needsReview).length;
  int get acceptedCount => syncResults
      .where((item) => item.reviewStatus == SyncReviewStatus.accepted)
      .length;
  int get rejectedCount => syncResults
      .where((item) => item.reviewStatus == SyncReviewStatus.rejected)
      .length;
  int get pendingCount => syncResults
      .where((item) => item.reviewStatus == SyncReviewStatus.pending)
      .length;
  int get matchedCount => syncResults
      .where((item) => item.audioFileId != null && !item.isRejected)
      .length;
}

class MatchNotifier extends AsyncNotifier<MatchState> {
  MatchExecutionController? _controller;

  @override
  MatchState build() => const MatchState();

  Future<void> _syncProjectStatus(String projectId) async {
    final project = await DatabaseService.getProject(projectId);
    if (project == null) return;
    final results = await DatabaseService.getSyncResults(projectId);
    final nextStatus = results.any((item) => item.audioFileId != null)
        ? ProjectStatus.matched
        : ProjectStatus.recognized;

    if (project.status != nextStatus) {
      await DatabaseService.updateProject(
        project.copyWith(status: nextStatus, updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> loadMatchResults(String projectId) async {
    try {
      final syncResults = await DatabaseService.getSyncResults(projectId);
      final unmatchedVideos = await SubtitleMatchService.getUnmatchedVideos(
        projectId,
      );
      final unmatchedAudios = await SubtitleMatchService.getUnmatchedAudios(
        projectId,
      );

      state = AsyncData(
        MatchState(
          syncResults: syncResults,
          unmatchedVideos: unmatchedVideos,
          unmatchedAudios: unmatchedAudios,
          stageLabel: syncResults.isEmpty ? '待开始' : '已完成',
        ),
      );
    } catch (e) {
      state = AsyncData(MatchState(error: e.toString()));
    }
  }

  Future<void> startMatching(String projectId) async {
    _controller = MatchExecutionController();
    final previous = state.valueOrNull ?? const MatchState();
    state = AsyncData(
      previous.copyWith(
        isMatching: true,
        isCancelled: false,
        progress: 0.01,
        stageLabel: '加载索引',
        currentVideo: null,
        error: null,
      ),
    );
    try {
      await SubtitleMatchService.matchProject(
        projectId: projectId,
        controller: _controller,
        onProgress: (update) {
          final currentState = state.valueOrNull;
          state = AsyncData(
            currentState?.copyWith(
                  isMatching: true,
                  isCancelled: false,
                  progress: update.progress,
                  stageLabel: update.stage,
                  currentVideo: update.currentVideo,
                  error: null,
                ) ??
                MatchState(
                  isMatching: true,
                  progress: update.progress,
                  stageLabel: update.stage,
                  currentVideo: update.currentVideo,
                ),
          );
        },
      );
      await _syncProjectStatus(projectId);
      await loadMatchResults(projectId);
      final currentState = state.valueOrNull ?? const MatchState();
      state = AsyncData(
        currentState.copyWith(
          isMatching: false,
          isCancelled: false,
          progress: 1.0,
          stageLabel: '已完成',
          currentVideo: null,
        ),
      );
      _controller = null;
    } catch (e) {
      final wasCancelled =
          e is MatchCancelledException || _controller?.isCancelled == true;
      _controller = null;
      state = AsyncData(
        previous.copyWith(
          isMatching: false,
          isCancelled: wasCancelled,
          progress: 0.0,
          stageLabel: wasCancelled ? '已取消' : '执行失败',
          currentVideo: null,
          error: wasCancelled ? null : e.toString(),
        ),
      );
    }
  }

  void cancelMatching() {
    _controller?.cancel();
  }

  Future<void> deleteMatch(String syncResultId, String projectId) async {
    await SubtitleMatchService.deleteSyncResult(syncResultId, projectId);
    await _syncProjectStatus(projectId);
    await loadMatchResults(projectId);
  }

  Future<void> manualMatch({
    required String projectId,
    required String videoFileId,
    required String audioFileId,
  }) async {
    await SubtitleMatchService.createManualMatch(
      projectId: projectId,
      videoFileId: videoFileId,
      audioFileId: audioFileId,
    );
    await _syncProjectStatus(projectId);
    await loadMatchResults(projectId);
  }

  Future<SyncReviewDetail?> loadReviewDetail(String syncResultId) {
    return SubtitleMatchService.getSyncReviewDetail(syncResultId);
  }

  Future<void> acceptReview(String syncResultId, String projectId) async {
    await SubtitleMatchService.acceptReview(syncResultId);
    await loadMatchResults(projectId);
  }

  Future<void> rejectReview(String syncResultId, String projectId) async {
    await SubtitleMatchService.rejectReview(syncResultId);
    await _syncProjectStatus(projectId);
    await loadMatchResults(projectId);
  }

  Future<void> restoreReview(String syncResultId, String projectId) async {
    await SubtitleMatchService.restoreReview(syncResultId);
    await loadMatchResults(projectId);
  }

  Future<void> manualRematch({
    required String syncResultId,
    required String projectId,
    required String audioFileId,
  }) async {
    await SubtitleMatchService.manualRematch(
      syncResultId: syncResultId,
      audioFileId: audioFileId,
    );
    await _syncProjectStatus(projectId);
    await loadMatchResults(projectId);
  }

  Future<void> manualAnchorMatch({
    required String syncResultId,
    required String projectId,
    required String videoClipId,
    required String aggregateAudioClipId,
  }) async {
    await SubtitleMatchService.manualAnchorMatch(
      syncResultId: syncResultId,
      projectId: projectId,
      videoClipId: videoClipId,
      aggregateAudioClipId: aggregateAudioClipId,
    );
    await _syncProjectStatus(projectId);
    await loadMatchResults(projectId);
  }
}

final matchProvider = AsyncNotifierProvider<MatchNotifier, MatchState>(
  MatchNotifier.new,
);

final subtitleClipsProvider = FutureProvider.family<List<SubtitleClip>, String>(
  (ref, mediaFileId) async {
    return DatabaseService.getSubtitleClips(mediaFileId);
  },
);

final syncReviewDetailProvider =
    FutureProvider.family<SyncReviewDetail?, String>((ref, syncResultId) async {
      return ref.read(matchProvider.notifier).loadReviewDetail(syncResultId);
    });
