import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/anchor_pair.dart';
import '../models/match_candidate.dart';
import '../models/media_file.dart';
import '../models/source_layout_item.dart';
import '../models/subtitle_clip.dart';
import '../models/subtitle_window.dart';
import '../models/sync_result.dart';
import '../models/sync_review_detail.dart';
import 'database_service.dart';

class MatchProgressUpdate {
  final String stage;
  final int current;
  final int total;
  final String? currentVideo;
  final double progress;

  const MatchProgressUpdate({
    required this.stage,
    required this.current,
    required this.total,
    this.currentVideo,
    required this.progress,
  });
}

typedef MatchProgressCallback = void Function(MatchProgressUpdate update);

class MatchExecutionController {
  void Function()? _cancel;
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void bindCancel(void Function() cancel) {
    _cancel = cancel;
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancel?.call();
  }
}

class MatchCancelledException implements Exception {
  const MatchCancelledException();

  @override
  String toString() => 'MatchCancelledException';
}

class MatchSubtitlePreview {
  final List<SubtitleClip> videoClips;
  final List<SubtitleClip> audioClips;
  final double similarity;
  final int offsetMs;
  final bool hasEvidence;
  final int anchorCount;

  const MatchSubtitlePreview({
    required this.videoClips,
    required this.audioClips,
    required this.similarity,
    required this.offsetMs,
    required this.hasEvidence,
    required this.anchorCount,
  });

  const MatchSubtitlePreview.empty()
    : videoClips = const [],
      audioClips = const [],
      similarity = 0.0,
      offsetMs = 0,
      hasEvidence = false,
      anchorCount = 0;
}

class ManualAnchorMatchPreview {
  final MediaFile? targetAudioFile;
  final int? audioSourceInMs;
  final int? audioSourceOutMs;
  final bool sourceClamped;
  final bool audioTooShort;
  final SyncStatus? status;
  final String notes;
  final String? error;

  const ManualAnchorMatchPreview({
    required this.targetAudioFile,
    required this.audioSourceInMs,
    required this.audioSourceOutMs,
    required this.sourceClamped,
    required this.audioTooShort,
    required this.status,
    required this.notes,
    this.error,
  });

  const ManualAnchorMatchPreview.error({
    required this.error,
    required this.notes,
  }) : targetAudioFile = null,
       audioSourceInMs = null,
       audioSourceOutMs = null,
       sourceClamped = false,
       audioTooShort = false,
       status = null;

  bool get canMatch =>
      error == null &&
      targetAudioFile != null &&
      audioSourceInMs != null &&
      audioSourceOutMs != null;
}

class ReviewAnchorJumpTarget {
  final String videoClipId;
  final String aggregateAudioClipId;
  final double similarity;
  final int offsetMs;
  final int videoTimeMs;
  final int audioGlobalTimeMs;

  const ReviewAnchorJumpTarget({
    required this.videoClipId,
    required this.aggregateAudioClipId,
    required this.similarity,
    required this.offsetMs,
    required this.videoTimeMs,
    required this.audioGlobalTimeMs,
  });
}

class LimitedCandidateEntry<T> {
  final String windowKey;
  final T value;
  final double score;

  const LimitedCandidateEntry({
    required this.windowKey,
    required this.value,
    required this.score,
  });
}

class LimitedCandidateBucket<T> {
  final int perWindowLimit;
  final int totalLimit;
  final List<LimitedCandidateEntry<T>> _entries = [];
  final Map<String, List<LimitedCandidateEntry<T>>> _entriesByWindow = {};

  LimitedCandidateBucket({
    required this.perWindowLimit,
    required this.totalLimit,
  });

  int get totalCount => _entries.length;

  int countForWindow(String windowKey) =>
      _entriesByWindow[windowKey]?.length ?? 0;

  List<LimitedCandidateEntry<T>> get entriesSortedByScoreDesc {
    final copy = [..._entries];
    copy.sort((a, b) => b.score.compareTo(a.score));
    return copy;
  }

  void add({
    required String windowKey,
    required T value,
    required double score,
  }) {
    final windowEntries = _entriesByWindow.putIfAbsent(
      windowKey,
      () => <LimitedCandidateEntry<T>>[],
    );
    if (windowEntries.length >= perWindowLimit) {
      final lowest = _minEntry(windowEntries);
      if (lowest == null || score <= lowest.score) {
        return;
      }
      _removeEntry(lowest);
    }

    final entry = LimitedCandidateEntry<T>(
      windowKey: windowKey,
      value: value,
      score: score,
    );
    _entries.add(entry);
    windowEntries.add(entry);

    if (_entries.length > totalLimit) {
      final lowest = _minEntry(_entries);
      if (lowest != null) {
        _removeEntry(lowest);
      }
    }
  }

  LimitedCandidateEntry<T>? _minEntry(List<LimitedCandidateEntry<T>> source) {
    if (source.isEmpty) return null;
    LimitedCandidateEntry<T> lowest = source.first;
    for (final item in source.skip(1)) {
      if (item.score < lowest.score) {
        lowest = item;
      }
    }
    return lowest;
  }

  void _removeEntry(LimitedCandidateEntry<T> entry) {
    _entries.remove(entry);
    final windowEntries = _entriesByWindow[entry.windowKey];
    windowEntries?.remove(entry);
    if (windowEntries != null && windowEntries.isEmpty) {
      _entriesByWindow.remove(entry.windowKey);
    }
  }
}

class SubtitleMatchService {
  SubtitleMatchService._();

  static const _uuid = Uuid();

  static bool passesCheapPrefilter(
    String left,
    String right, {
    double maxLengthDiffRatio = AppConstants.matchMaxLengthDiffRatio,
    double minDiceScore = AppConstants.matchPrefilterDiceThreshold,
  }) {
    final leftPrepared = _PreparedText.fromText(left);
    final rightPrepared = _PreparedText.fromText(right);
    return _evaluateCheapPrefilterPrepared(
          leftPrepared,
          rightPrepared,
          maxLengthDiffRatio: maxLengthDiffRatio,
          minDiceScore: minDiceScore,
        ) !=
        null;
  }

  static List<int> selectAnchorCandidateLocalStarts({
    required int videoLocalStartMs,
    required List<int> audioLocalStartMs,
    required int fallbackOffsetMs,
    int radiusMs = AppConstants.anchorSearchRadiusMs,
  }) {
    final targetMs = videoLocalStartMs + fallbackOffsetMs;
    final localMatches = audioLocalStartMs
        .where((value) => (value - targetMs).abs() <= radiusMs)
        .toList();
    return localMatches.isNotEmpty
        ? localMatches
        : List<int>.from(audioLocalStartMs);
  }

  static Future<List<SyncResult>> matchProject({
    required String projectId,
    MatchProgressCallback? onProgress,
    MatchExecutionController? controller,
  }) async {
    onProgress?.call(
      const MatchProgressUpdate(
        stage: '加载索引',
        current: 0,
        total: 1,
        progress: 0.01,
      ),
    );

    final payload = await _buildWorkerPayload(projectId);

    if (controller?.isCancelled == true) {
      throw const MatchCancelledException();
    }

    onProgress?.call(
      MatchProgressUpdate(
        stage: '启动后台任务',
        current: 0,
        total: (payload['videos'] as List).length,
        progress: 0.02,
      ),
    );

    final result = await _runWorker(
      payload,
      onProgress: onProgress,
      controller: controller,
    );

    if (controller?.isCancelled == true) {
      throw const MatchCancelledException();
    }

    onProgress?.call(
      MatchProgressUpdate(
        stage: '写入结果',
        current: (payload['videos'] as List).length,
        total: (payload['videos'] as List).length,
        progress: 0.98,
      ),
    );

    final candidates = (result['match_candidates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MatchCandidate.fromMap)
        .toList();
    final syncResults = (result['sync_results'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SyncResult.fromMap)
        .toList();
    final anchors = (result['anchor_pairs'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AnchorPair.fromMap)
        .toList();

    await DatabaseService.replaceMatchCandidates(projectId, candidates);
    await DatabaseService.replaceSyncResults(projectId, syncResults);
    if (anchors.isNotEmpty) {
      await DatabaseService.insertAnchorPairs(anchors);
    }

    onProgress?.call(
      MatchProgressUpdate(
        stage: '完成',
        current: syncResults.length,
        total: syncResults.length,
        progress: 1.0,
      ),
    );

    return syncResults;
  }

  static Future<MatchSubtitlePreview> buildPreview({
    required String videoFileId,
    required String audioFileId,
  }) async {
    final videoClips = await DatabaseService.getSubtitleClips(videoFileId);
    final audioClips = await DatabaseService.getSubtitleClips(audioFileId);
    final bundle = _buildAnchors(
      syncResultId: _uuid.v4(),
      videoClips: videoClips.map(_WorkerClip.fromSubtitleClip).toList(),
      audioClips: audioClips.map(_WorkerClip.fromSubtitleClip).toList(),
      fallbackOffsetMs: 0,
    );
    if (bundle.anchors.isEmpty) {
      return const MatchSubtitlePreview.empty();
    }

    final previewVideo = videoClips
        .where(
          (clip) =>
              bundle.anchors.any((anchor) => anchor.videoClipId == clip.id),
        )
        .take(4)
        .toList();
    final previewAudio = audioClips
        .where(
          (clip) =>
              bundle.anchors.any((anchor) => anchor.audioClipId == clip.id),
        )
        .take(4)
        .toList();

    return MatchSubtitlePreview(
      videoClips: previewVideo,
      audioClips: previewAudio,
      similarity: bundle.averageSimilarity,
      offsetMs: bundle.offsetMs,
      hasEvidence: true,
      anchorCount: bundle.anchors.length,
    );
  }

  static Future<List<MediaFile>> getUnmatchedVideos(String projectId) async {
    final allVideos = await DatabaseService.getMediaFiles(
      projectId,
      type: MediaType.video,
    );
    final results = await DatabaseService.getSyncResults(projectId);
    final matchedVideoIds = results
        .where((item) => !item.isRejected)
        .map((item) => item.videoFileId)
        .toSet();
    return allVideos
        .where((video) => !matchedVideoIds.contains(video.id))
        .toList();
  }

  static Future<List<MediaFile>> getUnmatchedAudios(String projectId) async {
    final allAudios = await DatabaseService.getMediaFiles(
      projectId,
      type: MediaType.audio,
    );
    final results = await DatabaseService.getSyncResults(projectId);
    final matchedAudioIds = results
        .where((item) => !item.isRejected)
        .where((item) => item.audioFileId != null)
        .map((item) => item.audioFileId!)
        .toSet();
    return allAudios
        .where((audio) => !matchedAudioIds.contains(audio.id))
        .toList();
  }

  static Future<SyncResult> createManualMatch({
    required String projectId,
    required String videoFileId,
    required String audioFileId,
  }) async {
    final video = await DatabaseService.getMediaFileById(videoFileId);
    final audio = await DatabaseService.getMediaFileById(audioFileId);
    if (video == null || audio == null) {
      throw StateError('素材不存在，无法手动匹配');
    }
    final videoClips = await DatabaseService.getSubtitleClips(videoFileId);
    final audioClips = await DatabaseService.getSubtitleClips(audioFileId);
    final bundle = _buildAnchors(
      syncResultId: _uuid.v4(),
      videoClips: videoClips.map(_WorkerClip.fromSubtitleClip).toList(),
      audioClips: audioClips.map(_WorkerClip.fromSubtitleClip).toList(),
      fallbackOffsetMs: 0,
    );

    final audioSourceInMs = math.max(bundle.offsetMs, 0);
    final audioSourceOutMs = math.min(
      (audio.durationMs ?? 0),
      audioSourceInMs + (video.durationMs ?? 0),
    );

    final result = SyncResult(
      id: bundle.syncResultId,
      projectId: projectId,
      videoFileId: videoFileId,
      audioFileId: audioFileId,
      videoDurationMs: video.durationMs ?? 0,
      timelineStartMs: video.layoutStartMs,
      timelineEndMs: video.layoutEndMs,
      audioSourceInMs: audioSourceInMs,
      audioSourceOutMs: audioSourceOutMs,
      confidence: 1.0,
      status: SyncStatus.autoAccepted,
      method: SyncMethod.manual,
      anchorCount: bundle.anchors.length,
      reviewStatus: SyncReviewStatus.accepted,
      reviewedAtMs: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now(),
    );

    final existing = await DatabaseService.getSyncResults(projectId);
    final retained =
        existing.where((item) => item.videoFileId != videoFileId).toList()
          ..add(result);
    await DatabaseService.replaceSyncResults(projectId, retained);
    if (bundle.anchors.isNotEmpty) {
      await DatabaseService.insertAnchorPairs(bundle.anchors);
    }
    return result;
  }

  static Future<SyncReviewDetail?> getSyncReviewDetail(String syncResultId) {
    return DatabaseService.getSyncReviewDetail(syncResultId);
  }

  static List<ReviewAnchorJumpTarget> resolveReviewAnchors(
    SyncReviewDetail detail,
  ) {
    if (detail.anchorPairs.isEmpty ||
        detail.videoSubtitles.isEmpty ||
        detail.aggregateAudioSubtitles.isEmpty) {
      return const [];
    }

    final videoClipIds = detail.videoSubtitles.map((clip) => clip.id).toSet();
    final aggregateById = {
      for (final clip in detail.aggregateAudioSubtitles) clip.id: clip,
    };
    final localAudioById = {
      for (final clip in detail.audioSubtitles) clip.id: clip,
    };
    final aggregateByRangeKey = <String, SubtitleClip>{};
    final aggregateByStartKey = <int, SubtitleClip>{};

    for (final clip in detail.aggregateAudioSubtitles) {
      final start = clip.globalStartMs ?? clip.startMs;
      final end = clip.globalEndMs ?? clip.endMs;
      aggregateByRangeKey.putIfAbsent('$start:$end', () => clip);
      aggregateByStartKey.putIfAbsent(start, () => clip);
    }

    final syncOffsetMs = detail.syncResult.audioSourceInMs;
    final resolved = <ReviewAnchorJumpTarget>[];

    for (final anchor in detail.anchorPairs) {
      if (!videoClipIds.contains(anchor.videoClipId)) {
        continue;
      }

      SubtitleClip? aggregateAudioClip = aggregateById[anchor.audioClipId];
      if (aggregateAudioClip == null) {
        final localAudioClip = localAudioById[anchor.audioClipId];
        if (localAudioClip == null) {
          continue;
        }
        final globalStart =
            localAudioClip.globalStartMs ?? localAudioClip.startMs;
        final globalEnd = localAudioClip.globalEndMs ?? localAudioClip.endMs;
        aggregateAudioClip =
            aggregateByRangeKey['$globalStart:$globalEnd'] ??
            aggregateByStartKey[globalStart];
      }

      if (aggregateAudioClip == null) {
        continue;
      }

      resolved.add(
        ReviewAnchorJumpTarget(
          videoClipId: anchor.videoClipId,
          aggregateAudioClipId: aggregateAudioClip.id,
          similarity: anchor.similarity,
          offsetMs: anchor.offsetMs,
          videoTimeMs: anchor.videoTimeMs,
          audioGlobalTimeMs:
              aggregateAudioClip.globalStartMs ?? aggregateAudioClip.startMs,
        ),
      );
    }

    resolved.sort((left, right) {
      final leftDistance = (left.offsetMs - (syncOffsetMs ?? left.offsetMs))
          .abs();
      final rightDistance = (right.offsetMs - (syncOffsetMs ?? right.offsetMs))
          .abs();
      final distanceCompare = leftDistance.compareTo(rightDistance);
      if (distanceCompare != 0) return distanceCompare;

      final similarityCompare = right.similarity.compareTo(left.similarity);
      if (similarityCompare != 0) return similarityCompare;

      return left.videoTimeMs.compareTo(right.videoTimeMs);
    });

    return resolved;
  }

  static Future<ManualAnchorMatchPreview> previewManualAnchorMatch({
    required String projectId,
    required String videoClipId,
    required String aggregateAudioClipId,
  }) async {
    final videoClip = await DatabaseService.getSubtitleClipById(videoClipId);
    if (videoClip == null) {
      return const ManualAnchorMatchPreview.error(
        error: '视频字幕不存在，无法预览匹配',
        notes: '未找到所选视频字幕条目',
      );
    }
    final videoFileId = videoClip.mediaFileId;
    if (videoFileId == null) {
      return const ManualAnchorMatchPreview.error(
        error: '视频字幕未绑定素材，无法预览匹配',
        notes: '所选视频字幕不是素材级字幕',
      );
    }
    final videoFile = await DatabaseService.getMediaFileById(videoFileId);
    if (videoFile == null) {
      return const ManualAnchorMatchPreview.error(
        error: '视频素材不存在，无法预览匹配',
        notes: '未找到所选视频字幕对应的视频素材',
      );
    }

    final aggregateAudioClip = await DatabaseService.getSubtitleClipById(
      aggregateAudioClipId,
    );
    if (aggregateAudioClip == null) {
      return const ManualAnchorMatchPreview.error(
        error: '音频总字幕不存在，无法预览匹配',
        notes: '未找到所选音频总字幕条目',
      );
    }

    final audioFiles = await DatabaseService.getMediaFiles(
      projectId,
      type: MediaType.audio,
    );
    final audioLayouts = await DatabaseService.getSourceLayouts(
      projectId,
      mediaType: MediaType.audio,
    );
    return _resolveManualAnchorMatchPreview(
      videoFile: videoFile,
      videoClip: videoClip,
      aggregateAudioClip: aggregateAudioClip,
      audioFiles: audioFiles,
      audioLayouts: audioLayouts,
    );
  }

  static Future<void> acceptReview(String syncResultId) async {
    final syncResult = await DatabaseService.getSyncResultById(syncResultId);
    if (syncResult == null) return;
    await DatabaseService.updateSyncResult(
      syncResult.copyWith(
        reviewStatus: SyncReviewStatus.accepted,
        reviewedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  static Future<void> rejectReview(String syncResultId) async {
    final syncResult = await DatabaseService.getSyncResultById(syncResultId);
    if (syncResult == null) return;
    await DatabaseService.updateSyncResult(
      syncResult.copyWith(
        reviewStatus: SyncReviewStatus.rejected,
        reviewedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  static Future<void> restoreReview(String syncResultId) async {
    final syncResult = await DatabaseService.getSyncResultById(syncResultId);
    if (syncResult == null) return;
    await DatabaseService.updateSyncResult(
      syncResult.copyWith(
        reviewStatus: SyncReviewStatus.pending,
        clearReviewedAtMs: true,
        clearReviewNote: true,
      ),
    );
  }

  static Future<SyncResult> manualAnchorMatch({
    required String syncResultId,
    required String projectId,
    required String videoClipId,
    required String aggregateAudioClipId,
  }) async {
    final existing = await DatabaseService.getSyncResultById(syncResultId);
    if (existing == null) {
      throw StateError('复核结果不存在，无法手动匹配');
    }

    final videoClip = await DatabaseService.getSubtitleClipById(videoClipId);
    if (videoClip == null || videoClip.mediaFileId != existing.videoFileId) {
      throw StateError('所选视频字幕不属于当前视频，无法手动匹配');
    }

    final preview = await previewManualAnchorMatch(
      projectId: projectId,
      videoClipId: videoClipId,
      aggregateAudioClipId: aggregateAudioClipId,
    );
    if (!preview.canMatch) {
      throw StateError(preview.error ?? '手动匹配预览失败');
    }

    if (await DatabaseService.getSubtitleClipById(aggregateAudioClipId) ==
        null) {
      throw StateError('所选音频总字幕不存在，无法手动匹配');
    }
    final videoAnchorMs = videoClip.localStartMs ?? videoClip.startMs;
    final audioAnchorMs = (preview.audioSourceInMs ?? 0) + videoAnchorMs;

    final updated = existing.copyWith(
      audioFileId: preview.targetAudioFile!.id,
      audioSourceInMs: preview.audioSourceInMs,
      audioSourceOutMs: preview.audioSourceOutMs,
      confidence: 1.0,
      status: preview.status ?? SyncStatus.autoAccepted,
      method: SyncMethod.manual,
      anchorCount: 1,
      sourceClamped: preview.sourceClamped,
      audioTooShort: preview.audioTooShort,
      reviewStatus: SyncReviewStatus.accepted,
      reviewedAtMs: DateTime.now().millisecondsSinceEpoch,
      clearReviewNote: true,
      notes: preview.notes,
    );
    await DatabaseService.updateSyncResult(updated);
    await DatabaseService.deleteAnchorPairs(syncResultId);
    await DatabaseService.insertAnchorPairs([
      AnchorPair(
        id: _uuid.v4(),
        syncResultId: syncResultId,
        videoClipId: videoClipId,
        audioClipId: aggregateAudioClipId,
        videoTimeMs: videoAnchorMs,
        audioTimeMs: audioAnchorMs,
        offsetMs: audioAnchorMs - videoAnchorMs,
        similarity: 1.0,
      ),
    ]);
    return updated;
  }

  static ManualAnchorMatchPreview _resolveManualAnchorMatchPreview({
    required MediaFile videoFile,
    required SubtitleClip videoClip,
    required SubtitleClip aggregateAudioClip,
    required List<MediaFile> audioFiles,
    required List<SourceLayoutItem> audioLayouts,
  }) {
    if (aggregateAudioClip.mediaFileId != null) {
      return const ManualAnchorMatchPreview.error(
        error: '所选音频字幕不是整轨总字幕，无法手动匹配',
        notes: '右侧必须选择反解前的音频总字幕条目',
      );
    }
    if (audioFiles.isEmpty || audioLayouts.isEmpty) {
      return const ManualAnchorMatchPreview.error(
        error: '工程里没有可用的音频布局，无法手动匹配',
        notes: '请先在素材导入页完成音频导入并执行字幕反解索引',
      );
    }

    final audioFileById = {for (final audio in audioFiles) audio.id: audio};
    final audioGlobalStartMs =
        aggregateAudioClip.globalStartMs ?? aggregateAudioClip.startMs;
    final audioGlobalEndMs =
        aggregateAudioClip.globalEndMs ?? aggregateAudioClip.endMs;
    final targetLayout = _pickTargetAudioLayout(
      layouts: audioLayouts,
      aggregateStartMs: audioGlobalStartMs,
      aggregateEndMs: audioGlobalEndMs,
    );
    if (targetLayout == null) {
      return const ManualAnchorMatchPreview.error(
        error: '无法从整轨字幕定位到具体音频文件',
        notes: '所选总字幕未落在任何音频布局范围内',
      );
    }

    final targetAudio = audioFileById[targetLayout.mediaId];
    if (targetAudio == null) {
      return const ManualAnchorMatchPreview.error(
        error: '匹配到的音频布局缺少音频素材',
        notes: '请检查音频素材和布局数据是否一致',
      );
    }

    final videoAnchorMs = videoClip.localStartMs ?? videoClip.startMs;
    final audioLocalAnchorMs = audioGlobalStartMs - targetLayout.layoutStartMs;
    final unclampedSourceInMs = audioLocalAnchorMs - videoAnchorMs;
    final sourceClamped = unclampedSourceInMs < 0;
    final audioSourceInMs = math.max(unclampedSourceInMs, 0);
    final videoDurationMs = math.max(videoFile.durationMs ?? 0, 0);
    final audioDurationMs = math.max(targetAudio.durationMs ?? 0, 0);
    final unclampedSourceOutMs = audioSourceInMs + videoDurationMs;
    final audioTooShort =
        audioDurationMs > 0 && unclampedSourceOutMs > audioDurationMs;
    var audioSourceOutMs = unclampedSourceOutMs;
    if (audioDurationMs > 0) {
      audioSourceOutMs = math.min(audioDurationMs, audioSourceOutMs);
    }
    if (audioSourceOutMs < audioSourceInMs) {
      audioSourceOutMs = audioSourceInMs;
    }

    final status = audioTooShort
        ? SyncStatus.audioTooShort
        : sourceClamped
        ? SyncStatus.sourceClamped
        : SyncStatus.autoAccepted;

    return ManualAnchorMatchPreview(
      targetAudioFile: targetAudio,
      audioSourceInMs: audioSourceInMs,
      audioSourceOutMs: audioSourceOutMs,
      sourceClamped: sourceClamped,
      audioTooShort: audioTooShort,
      status: status,
      notes: _buildManualAnchorNotes(
        aggregateAudioClip: aggregateAudioClip,
        targetAudio: targetAudio,
        audioSourceInMs: audioSourceInMs,
        audioSourceOutMs: audioSourceOutMs,
        sourceClamped: sourceClamped,
        audioTooShort: audioTooShort,
      ),
    );
  }

  static SourceLayoutItem? _pickTargetAudioLayout({
    required List<SourceLayoutItem> layouts,
    required int aggregateStartMs,
    required int aggregateEndMs,
  }) {
    SourceLayoutItem? bestLayout;
    var bestOverlapMs = 0;

    for (final layout in layouts) {
      final overlapStart = math.max(aggregateStartMs, layout.layoutStartMs);
      final overlapEnd = math.min(aggregateEndMs, layout.layoutEndMs);
      final overlapMs = math.max(0, overlapEnd - overlapStart);
      if (overlapMs > bestOverlapMs) {
        bestOverlapMs = overlapMs;
        bestLayout = layout;
      }
    }

    if (bestLayout != null) {
      return bestLayout;
    }

    for (final layout in layouts) {
      if (aggregateStartMs >= layout.layoutStartMs &&
          aggregateStartMs <= layout.layoutEndMs) {
        return layout;
      }
    }

    return null;
  }

  static String _buildManualAnchorNotes({
    required SubtitleClip aggregateAudioClip,
    required MediaFile targetAudio,
    required int audioSourceInMs,
    required int audioSourceOutMs,
    required bool sourceClamped,
    required bool audioTooShort,
  }) {
    final flags = <String>[];
    if (sourceClamped) {
      flags.add('起点越界已钳制');
    }
    if (audioTooShort) {
      flags.add('音频尾部不足已截断');
    }
    final suffix = flags.isEmpty ? '正常' : flags.join('，');
    final anchorTime =
        aggregateAudioClip.globalStartMs ?? aggregateAudioClip.startMs;
    return '手动匹配 | 总字幕锚点 ${_formatClock(anchorTime)} | '
        '目标音频 ${p.basename(targetAudio.filePath)} | '
        'Source In ${_formatClock(audioSourceInMs)} | '
        'Source Out ${_formatClock(audioSourceOutMs)} | '
        '$suffix';
  }

  static Future<SyncResult> manualRematch({
    required String syncResultId,
    required String audioFileId,
  }) async {
    final existing = await DatabaseService.getSyncResultById(syncResultId);
    if (existing == null) {
      throw StateError('复核结果不存在，无法重新改配');
    }
    final video = await DatabaseService.getMediaFileById(existing.videoFileId);
    final audio = await DatabaseService.getMediaFileById(audioFileId);
    if (video == null || audio == null) {
      throw StateError('素材不存在，无法重新改配');
    }

    final videoClips = await DatabaseService.getSubtitleClips(video.id);
    final audioClips = await DatabaseService.getSubtitleClips(audio.id);
    final audioWindows = (await DatabaseService.getSubtitleWindows(
      existing.projectId,
      mediaType: MediaType.audio,
    )).where((window) => window.mediaFileId == audio.id).toList();

    final workerVideo = _WorkerMedia.fromMap(video.toMap());
    final workerAudio = _WorkerMedia.fromMap(audio.toMap());
    final workerVideoClips = videoClips
        .map(_WorkerClip.fromSubtitleClip)
        .toList();
    final workerAudioClips = audioClips
        .map(_WorkerClip.fromSubtitleClip)
        .toList();
    final workerAudioWindows = audioWindows
        .map(_WorkerWindow.fromSubtitleWindow)
        .toList();
    final videoWindows = _buildVideoWindows(
      workerVideo,
      existing.projectId,
      workerVideoClips,
    );
    final groupedCandidates = _scoreCandidates(
      projectId: existing.projectId,
      video: workerVideo,
      audioMap: {workerAudio.id: workerAudio},
      audioWindowsBySize: _groupAudioWindowsBySize(workerAudioWindows),
      videoWindows: videoWindows,
      previousAudioId: existing.audioFileId,
      previousAudioSourceIn: existing.audioSourceInMs,
    );
    final candidate = groupedCandidates[audio.id];
    final bundle = _buildAnchors(
      syncResultId: existing.id,
      videoClips: workerVideoClips,
      audioClips: workerAudioClips,
      fallbackOffsetMs:
          candidate?.fallbackOffsetMs ?? existing.audioSourceInMs ?? 0,
    );

    var audioSourceInMs = math.max(bundle.offsetMs, 0);
    var audioSourceOutMs = audioSourceInMs + (video.durationMs ?? 0);
    var sourceClamped = false;
    var audioTooShort = false;
    final audioDurationMs = audio.durationMs ?? 0;
    if (bundle.offsetMs < 0) {
      sourceClamped = true;
    }
    if (audioDurationMs > 0 && audioSourceOutMs > audioDurationMs) {
      audioTooShort = true;
      audioSourceOutMs = audioDurationMs;
      if (audioSourceOutMs < audioSourceInMs) {
        audioSourceOutMs = audioSourceInMs;
      }
    }

    var confidence = candidate?.totalScore ?? existing.confidence;
    if (workerVideoClips.length < 2) {
      confidence = math.min(
        confidence,
        AppConstants.matchConfidenceMedium + 0.05,
      );
    }
    if (sourceClamped || audioTooShort) {
      confidence *= 0.88;
    }
    if (bundle.anchors.length <= 1) {
      confidence *= 0.92;
    }
    confidence = confidence.clamp(0.0, 1.0);

    final status = bundle.anchors.isEmpty
        ? SyncStatus.noMatch
        : _buildStatus(
            confidence: confidence,
            sourceClamped: sourceClamped,
            audioTooShort: audioTooShort,
            hasSubtitle: videoClips.isNotEmpty,
            hasAudio: true,
          );

    final updated = existing.copyWith(
      audioFileId: audio.id,
      audioSourceInMs: audioSourceInMs,
      audioSourceOutMs: audioSourceOutMs,
      confidence: confidence,
      status: status,
      method: SyncMethod.manual,
      anchorCount: bundle.anchors.length,
      sourceClamped: sourceClamped,
      audioTooShort: audioTooShort,
      reviewStatus: SyncReviewStatus.accepted,
      reviewedAtMs: DateTime.now().millisecondsSinceEpoch,
      notes: bundle.notes,
    );
    await DatabaseService.updateSyncResult(updated);
    await DatabaseService.deleteAnchorPairs(syncResultId);
    if (bundle.anchors.isNotEmpty) {
      await DatabaseService.insertAnchorPairs(bundle.anchors);
    }
    return updated;
  }

  static Future<void> deleteSyncResult(
    String syncResultId,
    String projectId,
  ) async {
    final existing = await DatabaseService.getSyncResults(projectId);
    final retained = existing.where((item) => item.id != syncResultId).toList();
    await DatabaseService.replaceSyncResults(projectId, retained);
  }

  static Future<Map<String, dynamic>> _buildWorkerPayload(
    String projectId,
  ) async {
    final videos = await DatabaseService.getMediaFiles(
      projectId,
      type: MediaType.video,
    );
    final audios = await DatabaseService.getMediaFiles(
      projectId,
      type: MediaType.audio,
    );
    final audioWindows = await DatabaseService.getSubtitleWindows(
      projectId,
      mediaType: MediaType.audio,
    );

    final videoClipsById = <String, List<Map<String, dynamic>>>{};
    for (final video in videos) {
      videoClipsById[video.id] = (await DatabaseService.getSubtitleClips(
        video.id,
      )).map((clip) => clip.toMap()).toList();
    }

    final audioClipsById = <String, List<Map<String, dynamic>>>{};
    for (final audio in audios) {
      audioClipsById[audio.id] = (await DatabaseService.getSubtitleClips(
        audio.id,
      )).map((clip) => clip.toMap()).toList();
    }

    return {
      'project_id': projectId,
      'videos': videos.map((video) => video.toMap()).toList(),
      'audios': audios.map((audio) => audio.toMap()).toList(),
      'audio_windows': audioWindows.map((window) => window.toMap()).toList(),
      'video_clips_by_id': videoClipsById,
      'audio_clips_by_id': audioClipsById,
    };
  }

  static Future<Map<String, dynamic>> _runWorker(
    Map<String, dynamic> payload, {
    MatchProgressCallback? onProgress,
    MatchExecutionController? controller,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<Map<String, dynamic>>();
    Isolate? worker;
    StreamSubscription<dynamic>? subscription;

    void cleanup() {
      subscription?.cancel();
      receivePort.close();
      worker?.kill(priority: Isolate.immediate);
    }

    subscription = receivePort.listen((message) {
      if (message is! Map) return;
      final type = message['type'];
      if (type == 'progress') {
        onProgress?.call(
          MatchProgressUpdate(
            stage: '${message['stage']}',
            current: message['current'] as int? ?? 0,
            total: message['total'] as int? ?? 0,
            currentVideo: message['current_video'] as String?,
            progress: (message['progress'] as num?)?.toDouble() ?? 0.0,
          ),
        );
        return;
      }
      if (type == 'done') {
        if (!completer.isCompleted) {
          completer.complete(
            (message['payload'] as Map).cast<String, dynamic>(),
          );
        }
        cleanup();
        return;
      }
      if (type == 'error') {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(message['error'] ?? '匹配 worker 执行失败'),
          );
        }
        cleanup();
      }
    });

    worker = await Isolate.spawn<Map<String, dynamic>>(_matchWorkerEntry, {
      'reply_port': receivePort.sendPort,
      'payload': payload,
    });

    controller?.bindCancel(() {
      if (!completer.isCompleted) {
        completer.completeError(const MatchCancelledException());
      }
      cleanup();
    });

    return completer.future;
  }

  static void _matchWorkerEntry(Map<String, dynamic> message) {
    final replyPort = message['reply_port'] as SendPort;
    final payload = (message['payload'] as Map).cast<String, dynamic>();
    try {
      final result = _runMatchWorkerSync(payload, replyPort);
      replyPort.send({'type': 'done', 'payload': result});
    } catch (e) {
      replyPort.send({'type': 'error', 'error': e.toString()});
    }
  }

  static Map<String, dynamic> _runMatchWorkerSync(
    Map<String, dynamic> payload,
    SendPort replyPort,
  ) {
    final projectId = payload['project_id'] as String;
    final videos = (payload['videos'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_WorkerMedia.fromMap)
        .toList();
    final audios = (payload['audios'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_WorkerMedia.fromMap)
        .toList();
    final audioWindows = (payload['audio_windows'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_WorkerWindow.fromMap)
        .toList();
    final videoClipsById = (payload['video_clips_by_id'] as Map).map(
      (key, value) => MapEntry(
        key as String,
        (value as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(_WorkerClip.fromMap)
            .toList(),
      ),
    );
    final audioClipsById = (payload['audio_clips_by_id'] as Map).map(
      (key, value) => MapEntry(
        key as String,
        (value as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(_WorkerClip.fromMap)
            .toList(),
      ),
    );

    final audioMap = {for (final audio in audios) audio.id: audio};
    final audioWindowsBySize = <int, List<_WorkerWindow>>{};
    for (final window in audioWindows) {
      audioWindowsBySize.putIfAbsent(window.windowSize, () => []).add(window);
    }

    final candidates = <Map<String, dynamic>>[];
    final syncResults = <Map<String, dynamic>>[];
    final anchors = <Map<String, dynamic>>[];

    String? previousAudioId;
    int? previousAudioSourceIn;

    for (var index = 0; index < videos.length; index++) {
      final video = videos[index];
      final videoClips = videoClipsById[video.id] ?? const <_WorkerClip>[];

      replyPort.send({
        'type': 'progress',
        'stage': '检索候选',
        'current': index + 1,
        'total': videos.length,
        'current_video': video.fileName,
        'progress': videos.isEmpty ? 0.0 : ((index + 1) / videos.length) * 0.85,
      });

      if (videoClips.isEmpty) {
        syncResults.add(
          SyncResult(
            id: _uuid.v4(),
            projectId: projectId,
            videoFileId: video.id,
            audioFileId: null,
            videoDurationMs: video.durationMs,
            timelineStartMs: video.layoutStartMs,
            timelineEndMs: video.layoutEndMs,
            confidence: 0.0,
            status: SyncStatus.noSubtitle,
            method: SyncMethod.subtitleOnly,
            reviewStatus: SyncReviewStatus.pending,
            notes: '视频没有可用字幕',
            createdAt: DateTime.now(),
          ).toMap(),
        );
        continue;
      }

      final videoWindows = _buildVideoWindows(video, projectId, videoClips);
      final groupedCandidates = _scoreCandidates(
        projectId: projectId,
        video: video,
        audioMap: audioMap,
        audioWindowsBySize: audioWindowsBySize,
        videoWindows: videoWindows,
        previousAudioId: previousAudioId,
        previousAudioSourceIn: previousAudioSourceIn,
      );
      final orderedCandidates = groupedCandidates.values.toList()
        ..sort((a, b) => b.totalScore.compareTo(a.totalScore));
      candidates.addAll(
        orderedCandidates
            .take(AppConstants.topKCandidates)
            .map((candidate) => candidate.toMap()),
      );

      if (orderedCandidates.isEmpty ||
          orderedCandidates.first.totalScore <
              AppConstants.matchConfidenceLow) {
        syncResults.add(
          SyncResult(
            id: _uuid.v4(),
            projectId: projectId,
            videoFileId: video.id,
            audioFileId: null,
            videoDurationMs: video.durationMs,
            timelineStartMs: video.layoutStartMs,
            timelineEndMs: video.layoutEndMs,
            confidence: orderedCandidates.isEmpty
                ? 0.0
                : orderedCandidates.first.totalScore,
            status: SyncStatus.noMatch,
            method: SyncMethod.subtitleOnly,
            reviewStatus: SyncReviewStatus.pending,
            notes: '未命中音频字幕库',
            createdAt: DateTime.now(),
          ).toMap(),
        );
        continue;
      }

      replyPort.send({
        'type': 'progress',
        'stage': '求锚点',
        'current': index + 1,
        'total': videos.length,
        'current_video': video.fileName,
        'progress': videos.isEmpty ? 0.0 : ((index + 1) / videos.length) * 0.9,
      });

      final best = orderedCandidates.first;
      final bestAudio = audioMap[best.audioFileId];
      final bestAudioClips = bestAudio == null
          ? const <_WorkerClip>[]
          : (audioClipsById[best.audioFileId] ?? const <_WorkerClip>[]);

      final anchorBundle = _buildAnchors(
        syncResultId: _uuid.v4(),
        videoClips: videoClips,
        audioClips: bestAudioClips,
        fallbackOffsetMs: best.fallbackOffsetMs,
      );
      var audioSourceInMs = anchorBundle.offsetMs;
      var audioSourceOutMs = audioSourceInMs + video.durationMs;

      bool sourceClamped = false;
      bool audioTooShort = false;
      if (audioSourceInMs < 0) {
        sourceClamped = true;
        audioSourceInMs = 0;
        audioSourceOutMs = video.durationMs;
      }
      final audioDurationMs = bestAudio?.durationMs ?? 0;
      if (audioDurationMs > 0 && audioSourceOutMs > audioDurationMs) {
        audioTooShort = true;
        audioSourceOutMs = audioDurationMs;
        if (audioSourceOutMs < audioSourceInMs) {
          audioSourceOutMs = audioSourceInMs;
        }
      }

      var confidence = best.totalScore;
      if (videoClips.length < 2) {
        confidence = math.min(
          confidence,
          AppConstants.matchConfidenceMedium + 0.05,
        );
      }
      if (sourceClamped || audioTooShort) {
        confidence *= 0.88;
      }
      if (anchorBundle.anchors.length <= 1) {
        confidence *= 0.92;
      }
      confidence = confidence.clamp(0.0, 1.0);

      final status = _buildStatus(
        confidence: confidence,
        sourceClamped: sourceClamped,
        audioTooShort: audioTooShort,
        hasSubtitle: true,
        hasAudio: bestAudio != null,
      );

      syncResults.add(
        SyncResult(
          id: anchorBundle.syncResultId,
          projectId: projectId,
          videoFileId: video.id,
          audioFileId: best.audioFileId,
          videoDurationMs: video.durationMs,
          timelineStartMs: video.layoutStartMs,
          timelineEndMs: video.layoutEndMs,
          audioSourceInMs: audioSourceInMs,
          audioSourceOutMs: audioSourceOutMs,
          confidence: confidence,
          status: status,
          method: SyncMethod.subtitleOnly,
          anchorCount: anchorBundle.anchors.length,
          sourceClamped: sourceClamped,
          audioTooShort: audioTooShort,
          reviewStatus: _initialReviewStatusForStatus(status),
          notes: anchorBundle.notes,
          createdAt: DateTime.now(),
        ).toMap(),
      );
      anchors.addAll(anchorBundle.anchors.map((anchor) => anchor.toMap()));

      previousAudioId = best.audioFileId;
      previousAudioSourceIn = audioSourceInMs;
    }

    return {
      'match_candidates': candidates,
      'sync_results': syncResults,
      'anchor_pairs': anchors,
    };
  }

  static Map<String, MatchCandidate> _scoreCandidates({
    required String projectId,
    required _WorkerMedia video,
    required Map<String, _WorkerMedia> audioMap,
    required Map<int, List<_WorkerWindow>> audioWindowsBySize,
    required List<_WorkerWindow> videoWindows,
    required String? previousAudioId,
    required int? previousAudioSourceIn,
  }) {
    final buckets = <String, _CandidateBucket>{};

    for (final videoWindow in videoWindows) {
      final comparableAudioWindows =
          audioWindowsBySize[videoWindow.windowSize] ?? const <_WorkerWindow>[];
      for (final audioWindow in comparableAudioWindows) {
        final prefilter = _evaluateCheapPrefilterPrepared(
          videoWindow.preparedText,
          audioWindow.preparedText,
        );
        if (prefilter == null) continue;
        final textScore = _textSimilarityPrepared(
          videoWindow.preparedText,
          audioWindow.preparedText,
          baseDice: prefilter.diceScore,
        );
        if (textScore < 0.35) continue;
        final bucket = buckets.putIfAbsent(
          audioWindow.mediaFileId,
          () => _CandidateBucket(audioWindow.mediaFileId),
        );
        bucket.addHit(
          videoWindow: videoWindow,
          audioWindow: audioWindow,
          textScore: textScore,
        );
      }
    }

    final results = <String, MatchCandidate>{};
    for (final bucket in buckets.values) {
      final audio = audioMap[bucket.audioFileId];
      if (audio == null) continue;

      final bestHit = bucket.bestHit;
      if (bestHit == null) continue;

      final contextScore = (bucket.hitCount / math.max(videoWindows.length, 1))
          .clamp(0.0, 1.0);
      final anchorScore = _anchorStabilityScore(bucket.offsets);
      final uniquenessScore = bucket.uniquenessAverage.clamp(0.0, 1.0);
      final metadataScore = _metadataScore(video, audio);
      final neighborScore = _neighborScore(
        audioFileId: bucket.audioFileId,
        offsetMs: bestHit.audioWindow.startMs - bestHit.videoWindow.startMs,
        previousAudioId: previousAudioId,
        previousAudioSourceIn: previousAudioSourceIn,
      );
      final totalScore =
          (bestHit.textScore * 0.40 +
                  contextScore * 0.20 +
                  anchorScore * 0.20 +
                  uniquenessScore * 0.10 +
                  metadataScore * 0.05 +
                  neighborScore * 0.05)
              .clamp(0.0, 1.0);

      results[bucket.audioFileId] = MatchCandidate(
        id: _uuid.v4(),
        projectId: projectId,
        videoFileId: video.id,
        audioFileId: bucket.audioFileId,
        videoWindowId: bestHit.videoWindow.id,
        audioWindowId: bestHit.audioWindow.id,
        textScore: bestHit.textScore,
        contextScore: contextScore,
        anchorScore: anchorScore,
        uniquenessScore: uniquenessScore,
        metadataScore: metadataScore,
        neighborScore: neighborScore,
        totalScore: totalScore,
        fallbackOffsetMs: bucket.bestOffsetMs,
        createdAt: DateTime.now(),
      );
    }

    return results;
  }

  static _AnchorBundle _buildAnchors({
    required String syncResultId,
    required List<_WorkerClip> videoClips,
    required List<_WorkerClip> audioClips,
    required int fallbackOffsetMs,
  }) {
    final anchors = <AnchorPair>[];
    final usedAudioIds = <String>{};
    final audioLocalStartMap = {
      for (final clip in audioClips) clip.id: clip.localStartMs,
    };

    for (final videoClip in videoClips) {
      final candidateLocalStarts = selectAnchorCandidateLocalStarts(
        videoLocalStartMs: videoClip.localStartMs,
        audioLocalStartMs: audioClips.map((clip) => clip.localStartMs).toList(),
        fallbackOffsetMs: fallbackOffsetMs,
      ).toSet();
      final localCandidates = audioClips
          .where((clip) => candidateLocalStarts.contains(clip.localStartMs))
          .toList();
      final searchSpace = localCandidates.isNotEmpty
          ? localCandidates
          : audioClips;

      final topCandidates = <_AudioClipScore>[];
      for (final audioClip in searchSpace) {
        if (usedAudioIds.contains(audioClip.id)) continue;
        final prefilter = _evaluateCheapPrefilterPrepared(
          videoClip.preparedText,
          audioClip.preparedText,
        );
        if (prefilter == null) continue;
        final score = _textSimilarityPrepared(
          videoClip.preparedText,
          audioClip.preparedText,
          baseDice: prefilter.diceScore,
        );
        if (score <= 0) continue;
        _insertTopAudioClipCandidate(
          topCandidates,
          _AudioClipScore(audioClip: audioClip, score: score),
          AppConstants.anchorMaxCandidatesPerCue,
        );
      }

      if (topCandidates.isEmpty) continue;

      final bestAudioClip = topCandidates.first.audioClip;
      final bestScore = topCandidates.first.score;
      if (bestScore < 0.78) continue;
      usedAudioIds.add(bestAudioClip.id);

      anchors.add(
        AnchorPair(
          id: _uuid.v4(),
          syncResultId: syncResultId,
          videoClipId: videoClip.id,
          audioClipId: bestAudioClip.id,
          videoTimeMs: videoClip.localStartMs,
          audioTimeMs: bestAudioClip.localStartMs,
          offsetMs: bestAudioClip.localStartMs - videoClip.localStartMs,
          similarity: bestScore,
        ),
      );
    }

    if (anchors.isEmpty) {
      return _AnchorBundle(
        syncResultId: syncResultId,
        anchors: const [],
        offsetMs: fallbackOffsetMs,
        averageSimilarity: 0.0,
        notes: '未生成可靠锚点，使用候选窗口偏移',
      );
    }

    final offsets = anchors.map((item) => item.offsetMs).toList()..sort();
    final middle = offsets.length ~/ 2;
    final median = offsets.length.isOdd
        ? offsets[middle]
        : ((offsets[middle - 1] + offsets[middle]) / 2).round();
    final averageSimilarity =
        anchors.fold<double>(0, (sum, item) => sum + item.similarity) /
        anchors.length;

    final localAnchorCount = anchors.where((anchor) {
      final audioLocalStart = audioLocalStartMap[anchor.audioClipId];
      if (audioLocalStart == null) return false;
      final target = anchor.videoTimeMs + fallbackOffsetMs;
      return (audioLocalStart - target).abs() <=
          AppConstants.anchorSearchRadiusMs;
    }).length;

    return _AnchorBundle(
      syncResultId: syncResultId,
      anchors: anchors,
      offsetMs: median,
      averageSimilarity: averageSimilarity,
      notes: 'anchors=${anchors.length}, local=$localAnchorCount',
    );
  }

  static List<_WorkerWindow> _buildVideoWindows(
    _WorkerMedia video,
    String projectId,
    List<_WorkerClip> videoClips,
  ) {
    final windows = <_WorkerWindow>[];
    for (final windowSize in AppConstants.subtitleWindowSizes) {
      if (videoClips.length < windowSize) continue;
      for (var index = 0; index <= videoClips.length - windowSize; index++) {
        final slice = videoClips.sublist(index, index + windowSize);
        final normalizedText = slice
            .map((clip) => clip.normalizedText)
            .where((text) => text.isNotEmpty)
            .join(' ');
        if (normalizedText.isEmpty) continue;
        windows.add(
          _WorkerWindow(
            id: '${projectId}_${video.id}_${windowSize}_$index',
            mediaFileId: video.id,
            startMs: slice.first.localStartMs,
            endMs: slice.last.localEndMs,
            windowSize: windowSize,
            uniquenessWeight: 1.0,
            preparedText: _PreparedText.fromText(normalizedText),
          ),
        );
      }
    }
    return windows;
  }

  static SyncStatus _buildStatus({
    required double confidence,
    required bool sourceClamped,
    required bool audioTooShort,
    required bool hasSubtitle,
    required bool hasAudio,
  }) {
    if (!hasSubtitle) return SyncStatus.noSubtitle;
    if (!hasAudio) return SyncStatus.noMatch;
    if (audioTooShort) return SyncStatus.audioTooShort;
    if (sourceClamped) return SyncStatus.sourceClamped;
    if (confidence >= AppConstants.matchConfidenceHigh) {
      return SyncStatus.autoAccepted;
    }
    if (confidence >= AppConstants.matchConfidenceMedium) {
      return SyncStatus.mediumConfidence;
    }
    return SyncStatus.lowConfidence;
  }

  static SyncReviewStatus _initialReviewStatusForStatus(SyncStatus status) {
    if (status == SyncStatus.autoAccepted) {
      return SyncReviewStatus.notRequired;
    }
    return SyncReviewStatus.pending;
  }

  static double _anchorStabilityScore(List<int> offsets) {
    if (offsets.isEmpty) return 0.0;
    if (offsets.length == 1) return 0.65;
    final sorted = [...offsets]..sort();
    final middle = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[middle].toDouble()
        : (sorted[middle - 1] + sorted[middle]) / 2;
    final deviations = sorted.map((offset) => (offset - median).abs()).toList();
    final mad = deviations.reduce((a, b) => a + b) / deviations.length;
    return (1.0 - (mad / 5000)).clamp(0.0, 1.0);
  }

  static double _metadataScore(_WorkerMedia video, _WorkerMedia audio) {
    var score = 0.0;
    if (video.directory == audio.directory) {
      score += 0.6;
    }
    final videoModified = video.modifiedAtMs;
    final audioModified = audio.modifiedAtMs;
    if (videoModified != null && audioModified != null) {
      final diff = (videoModified - audioModified).abs();
      if (diff <= const Duration(days: 1).inMilliseconds) {
        score += 0.4;
      } else if (diff <= const Duration(days: 3).inMilliseconds) {
        score += 0.2;
      }
    }
    return score.clamp(0.0, 1.0);
  }

  static double _neighborScore({
    required String audioFileId,
    required int offsetMs,
    required String? previousAudioId,
    required int? previousAudioSourceIn,
  }) {
    if (previousAudioId == null) return 0.0;
    if (previousAudioId != audioFileId) return 0.0;
    if (previousAudioSourceIn == null) return 0.6;
    final diff = (offsetMs - previousAudioSourceIn).abs();
    if (diff <= 10000) return 1.0;
    if (diff <= 30000) return 0.8;
    if (diff <= 120000) return 0.5;
    return 0.2;
  }

  static _CheapPrefilterResult? _evaluateCheapPrefilterPrepared(
    _PreparedText left,
    _PreparedText right, {
    double maxLengthDiffRatio = AppConstants.matchMaxLengthDiffRatio,
    double minDiceScore = AppConstants.matchPrefilterDiceThreshold,
  }) {
    if (left.text.isEmpty || right.text.isEmpty) return null;
    final maxLength = math.max(left.length, right.length);
    if (maxLength <= 0) return null;
    final diffRatio = (left.length - right.length).abs() / maxLength;
    if (diffRatio > maxLengthDiffRatio) return null;
    if (!_hasAnyBigramOverlap(left.bigramSet, right.bigramSet)) return null;
    final diceScore = _diceCoefficientPrepared(left, right);
    if (diceScore < minDiceScore) return null;
    return _CheapPrefilterResult(diceScore: diceScore);
  }

  static bool _hasAnyBigramOverlap(Set<String> left, Set<String> right) {
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    final smaller = left.length <= right.length ? left : right;
    final larger = identical(smaller, left) ? right : left;
    for (final gram in smaller) {
      if (larger.contains(gram)) {
        return true;
      }
    }
    return false;
  }

  static double _textSimilarityPrepared(
    _PreparedText left,
    _PreparedText right, {
    required double baseDice,
  }) {
    if (left.text == right.text) return 1.0;
    final editSimilarity =
        1.0 -
        _levenshteinDistance(left.truncatedText, right.truncatedText) /
            math.max(left.truncatedText.length, right.truncatedText.length);
    return (editSimilarity * 0.6 + baseDice * 0.4).clamp(0.0, 1.0);
  }

  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    final matrix = List.generate(
      s1.length + 1,
      (_) => List<int>.filled(s2.length + 1, 0),
    );
    for (var i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }
    for (var i = 1; i <= s1.length; i++) {
      for (var j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(math.min);
      }
    }
    return matrix[s1.length][s2.length];
  }

  static double _diceCoefficientPrepared(
    _PreparedText left,
    _PreparedText right,
  ) {
    if (left.bigrams.isEmpty || right.bigrams.isEmpty) {
      return left.text == right.text ? 1.0 : 0.0;
    }
    var overlap = 0;
    final counts = <String, int>{};
    for (final gram in left.bigrams) {
      counts.update(gram, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final gram in right.bigrams) {
      final remaining = counts[gram] ?? 0;
      if (remaining > 0) {
        counts[gram] = remaining - 1;
        overlap++;
      }
    }
    return (2 * overlap / (left.bigrams.length + right.bigrams.length)).clamp(
      0.0,
      1.0,
    );
  }

  static void _insertTopAudioClipCandidate(
    List<_AudioClipScore> candidates,
    _AudioClipScore next,
    int limit,
  ) {
    candidates.add(next);
    candidates.sort((a, b) => b.score.compareTo(a.score));
    if (candidates.length > limit) {
      candidates.removeRange(limit, candidates.length);
    }
  }

  static Map<int, List<_WorkerWindow>> _groupAudioWindowsBySize(
    List<_WorkerWindow> windows,
  ) {
    final grouped = <int, List<_WorkerWindow>>{};
    for (final window in windows) {
      grouped.putIfAbsent(window.windowSize, () => []).add(window);
    }
    return grouped;
  }

  static String _formatClock(int ms) {
    final h = (ms ~/ 3600000).toString().padLeft(2, '0');
    final m = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _WorkerMedia {
  final String id;
  final String filePath;
  final String fileName;
  final String directory;
  final int durationMs;
  final int layoutStartMs;
  final int layoutEndMs;
  final int? modifiedAtMs;

  const _WorkerMedia({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.directory,
    required this.durationMs,
    required this.layoutStartMs,
    required this.layoutEndMs,
    required this.modifiedAtMs,
  });

  factory _WorkerMedia.fromMap(Map<String, dynamic> map) {
    final filePath = map['file_path'] as String;
    return _WorkerMedia(
      id: map['id'] as String,
      filePath: filePath,
      fileName: p.basename(filePath),
      directory: p.dirname(filePath).toLowerCase(),
      durationMs: map['duration_ms'] as int? ?? 0,
      layoutStartMs: map['layout_start_ms'] as int? ?? 0,
      layoutEndMs: map['layout_end_ms'] as int? ?? 0,
      modifiedAtMs: map['modified_at_ms'] as int?,
    );
  }
}

class _WorkerClip {
  final String id;
  final int startMs;
  final int endMs;
  final int localStartMs;
  final int localEndMs;
  final String normalizedText;
  final _PreparedText preparedText;

  const _WorkerClip({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.localStartMs,
    required this.localEndMs,
    required this.normalizedText,
    required this.preparedText,
  });

  factory _WorkerClip.fromMap(Map<String, dynamic> map) {
    final normalizedText = map['normalized_text'] as String? ?? '';
    return _WorkerClip(
      id: map['id'] as String,
      startMs: map['start_ms'] as int? ?? 0,
      endMs: map['end_ms'] as int? ?? 0,
      localStartMs:
          map['local_start_ms'] as int? ?? map['start_ms'] as int? ?? 0,
      localEndMs: map['local_end_ms'] as int? ?? map['end_ms'] as int? ?? 0,
      normalizedText: normalizedText,
      preparedText: _PreparedText.fromText(normalizedText),
    );
  }

  factory _WorkerClip.fromSubtitleClip(SubtitleClip clip) {
    return _WorkerClip(
      id: clip.id,
      startMs: clip.startMs,
      endMs: clip.endMs,
      localStartMs: clip.localStartMs ?? clip.startMs,
      localEndMs: clip.localEndMs ?? clip.endMs,
      normalizedText: clip.normalizedText,
      preparedText: _PreparedText.fromText(clip.normalizedText),
    );
  }
}

class _WorkerWindow {
  final String id;
  final String mediaFileId;
  final int windowSize;
  final int startMs;
  final int endMs;
  final double uniquenessWeight;
  final _PreparedText preparedText;

  const _WorkerWindow({
    required this.id,
    required this.mediaFileId,
    required this.windowSize,
    required this.startMs,
    required this.endMs,
    required this.uniquenessWeight,
    required this.preparedText,
  });

  factory _WorkerWindow.fromMap(Map<String, dynamic> map) {
    final normalizedText = map['normalized_text'] as String? ?? '';
    return _WorkerWindow(
      id: map['id'] as String,
      mediaFileId: map['media_file_id'] as String,
      windowSize: map['window_size'] as int? ?? 1,
      startMs: map['start_ms'] as int? ?? 0,
      endMs: map['end_ms'] as int? ?? 0,
      uniquenessWeight: (map['uniqueness_weight'] as num?)?.toDouble() ?? 0.0,
      preparedText: _PreparedText.fromText(normalizedText),
    );
  }

  factory _WorkerWindow.fromSubtitleWindow(SubtitleWindow window) {
    return _WorkerWindow(
      id: window.id,
      mediaFileId: window.mediaFileId,
      windowSize: window.windowSize,
      startMs: window.startMs,
      endMs: window.endMs,
      uniquenessWeight: window.uniquenessWeight,
      preparedText: _PreparedText.fromText(window.normalizedText),
    );
  }
}

class _PreparedText {
  final String text;
  final int length;
  final String truncatedText;
  final List<String> bigrams;
  final Set<String> bigramSet;

  const _PreparedText({
    required this.text,
    required this.length,
    required this.truncatedText,
    required this.bigrams,
    required this.bigramSet,
  });

  factory _PreparedText.fromText(String text) {
    final bigrams = <String>[];
    for (var i = 0; i < text.length - 1; i++) {
      bigrams.add(text.substring(i, i + 2));
    }
    return _PreparedText(
      text: text,
      length: text.length,
      truncatedText: text.length > 240 ? text.substring(0, 240) : text,
      bigrams: bigrams,
      bigramSet: bigrams.toSet(),
    );
  }
}

class _CheapPrefilterResult {
  final double diceScore;

  const _CheapPrefilterResult({required this.diceScore});
}

class _CandidateHit {
  final _WorkerWindow videoWindow;
  final _WorkerWindow audioWindow;
  final double textScore;

  const _CandidateHit({
    required this.videoWindow,
    required this.audioWindow,
    required this.textScore,
  });
}

class _CandidateBucket {
  final String audioFileId;
  final LimitedCandidateBucket<_CandidateHit> limiter;

  _CandidateBucket(this.audioFileId)
    : limiter = LimitedCandidateBucket<_CandidateHit>(
        perWindowLimit: AppConstants.matchMaxHitsPerWindowPerAudio,
        totalLimit: AppConstants.matchMaxHitsPerAudio,
      );

  void addHit({
    required _WorkerWindow videoWindow,
    required _WorkerWindow audioWindow,
    required double textScore,
  }) {
    limiter.add(
      windowKey: videoWindow.id,
      value: _CandidateHit(
        videoWindow: videoWindow,
        audioWindow: audioWindow,
        textScore: textScore,
      ),
      score: textScore,
    );
  }

  _CandidateHit? get bestHit {
    final entries = limiter.entriesSortedByScoreDesc;
    return entries.isEmpty ? null : entries.first.value;
  }

  int get hitCount => limiter.totalCount;

  List<int> get offsets => limiter.entriesSortedByScoreDesc
      .map(
        (entry) =>
            entry.value.audioWindow.startMs - entry.value.videoWindow.startMs,
      )
      .toList();

  int get bestOffsetMs {
    final hit = bestHit;
    if (hit == null) return 0;
    return hit.audioWindow.startMs - hit.videoWindow.startMs;
  }

  double get uniquenessAverage {
    final entries = limiter.entriesSortedByScoreDesc;
    if (entries.isEmpty) return 0.0;
    return entries.fold<double>(
          0.0,
          (sum, entry) => sum + entry.value.audioWindow.uniquenessWeight,
        ) /
        entries.length;
  }
}

class _AudioClipScore {
  final _WorkerClip audioClip;
  final double score;

  const _AudioClipScore({required this.audioClip, required this.score});
}

class _AnchorBundle {
  final String syncResultId;
  final List<AnchorPair> anchors;
  final int offsetMs;
  final double averageSimilarity;
  final String notes;

  const _AnchorBundle({
    required this.syncResultId,
    required this.anchors,
    required this.offsetMs,
    required this.averageSimilarity,
    required this.notes,
  });
}
