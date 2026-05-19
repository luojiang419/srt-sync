import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:asr_tools/models/anchor_pair.dart';
import 'package:asr_tools/models/asr_project.dart';
import 'package:asr_tools/models/media_file.dart';
import 'package:asr_tools/models/source_layout_item.dart';
import 'package:asr_tools/models/subtitle_clip.dart';
import 'package:asr_tools/models/subtitle_file.dart';
import 'package:asr_tools/models/sync_review_detail.dart';
import 'package:asr_tools/models/sync_result.dart';
import 'package:asr_tools/services/database_service.dart';
import 'package:asr_tools/services/subtitle_match_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('manual-anchor-match-');
    await DatabaseService.init(
      overridePath: p.join(tempDir.path, 'manual-anchor-test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'manual anchor preview resolves aggregate subtitle into concrete audio',
    () async {
      final seed = await _seedScenario(
        aggregateStartMs: 12000,
        aggregateEndMs: 12600,
        videoClipStartMs: 2000,
        videoDurationMs: 4000,
        audioDurationsMs: const [10000, 10000],
      );

      final preview = await SubtitleMatchService.previewManualAnchorMatch(
        projectId: seed.projectId,
        videoClipId: seed.videoClipId,
        aggregateAudioClipId: seed.aggregateAudioClipId,
      );

      expect(preview.canMatch, isTrue);
      expect(preview.targetAudioFile?.id, seed.audio2Id);
      expect(preview.audioSourceInMs, 0);
      expect(preview.audioSourceOutMs, 4000);
      expect(preview.sourceClamped, isFalse);
      expect(preview.audioTooShort, isFalse);

      final updated = await SubtitleMatchService.manualAnchorMatch(
        syncResultId: seed.syncResultId,
        projectId: seed.projectId,
        videoClipId: seed.videoClipId,
        aggregateAudioClipId: seed.aggregateAudioClipId,
      );

      expect(updated.audioFileId, seed.audio2Id);
      expect(updated.method, SyncMethod.manual);
      expect(updated.reviewStatus, SyncReviewStatus.accepted);
      expect(updated.status, SyncStatus.autoAccepted);
      expect(updated.anchorCount, 1);

      final stored = await DatabaseService.getSyncResultById(seed.syncResultId);
      expect(stored?.audioFileId, seed.audio2Id);
      expect(stored?.audioSourceInMs, 0);
      expect(stored?.audioSourceOutMs, 4000);
    },
  );

  test(
    'manual anchor preview clamps negative source in and marks sourceClamped',
    () async {
      final seed = await _seedScenario(
        aggregateStartMs: 500,
        aggregateEndMs: 900,
        videoClipStartMs: 2000,
        videoDurationMs: 4000,
        audioDurationsMs: const [10000, 10000],
      );

      final preview = await SubtitleMatchService.previewManualAnchorMatch(
        projectId: seed.projectId,
        videoClipId: seed.videoClipId,
        aggregateAudioClipId: seed.aggregateAudioClipId,
      );

      expect(preview.canMatch, isTrue);
      expect(preview.targetAudioFile?.id, seed.audio1Id);
      expect(preview.audioSourceInMs, 0);
      expect(preview.audioSourceOutMs, 4000);
      expect(preview.sourceClamped, isTrue);
      expect(preview.audioTooShort, isFalse);
      expect(preview.status, SyncStatus.sourceClamped);
    },
  );

  test(
    'manual anchor preview trims short audio tail and marks audioTooShort',
    () async {
      final seed = await _seedScenario(
        aggregateStartMs: 2500,
        aggregateEndMs: 2900,
        videoClipStartMs: 100,
        videoDurationMs: 4000,
        audioDurationsMs: const [3000, 10000],
      );

      final preview = await SubtitleMatchService.previewManualAnchorMatch(
        projectId: seed.projectId,
        videoClipId: seed.videoClipId,
        aggregateAudioClipId: seed.aggregateAudioClipId,
      );

      expect(preview.canMatch, isTrue);
      expect(preview.targetAudioFile?.id, seed.audio1Id);
      expect(preview.audioSourceInMs, 2400);
      expect(preview.audioSourceOutMs, 3000);
      expect(preview.sourceClamped, isFalse);
      expect(preview.audioTooShort, isTrue);
      expect(preview.status, SyncStatus.audioTooShort);
    },
  );

  test(
    'manual anchor preview rejects non-aggregate subtitle clips and missing layouts',
    () async {
      final seed = await _seedScenario(
        aggregateStartMs: 12000,
        aggregateEndMs: 12600,
        videoClipStartMs: 2000,
        videoDurationMs: 4000,
        audioDurationsMs: const [10000, 10000],
        addAudioLayouts: false,
      );

      final noLayoutPreview =
          await SubtitleMatchService.previewManualAnchorMatch(
            projectId: seed.projectId,
            videoClipId: seed.videoClipId,
            aggregateAudioClipId: seed.aggregateAudioClipId,
          );
      expect(noLayoutPreview.canMatch, isFalse);
      expect(noLayoutPreview.error, contains('音频布局'));

      final seededWithLayouts = await _seedScenario(
        projectId: 'project-2',
        syncResultId: 'sync-2',
        videoClipId: 'video-clip-2',
        aggregateAudioClipId: 'agg-clip-2',
        localAudioClipId: 'local-audio-clip-2',
        aggregateStartMs: 12000,
        aggregateEndMs: 12600,
        videoClipStartMs: 2000,
        videoDurationMs: 4000,
        audioDurationsMs: const [10000, 10000],
      );

      final localPreview = await SubtitleMatchService.previewManualAnchorMatch(
        projectId: seededWithLayouts.projectId,
        videoClipId: seededWithLayouts.videoClipId,
        aggregateAudioClipId: seededWithLayouts.localAudioClipId,
      );
      expect(localPreview.canMatch, isFalse);
      expect(localPreview.error, contains('整轨总字幕'));
    },
  );

  test(
    'resolve review anchors maps local audio anchors to aggregate subtitles and sorts by main anchor priority',
    () {
      final now = DateTime(2026, 5, 18, 10, 0);
      final detail = SyncReviewDetail(
        syncResult: SyncResult(
          id: 'sync-review-1',
          projectId: 'project-review-1',
          videoFileId: 'video-1',
          audioFileId: 'audio-1',
          videoDurationMs: 5000,
          timelineStartMs: 0,
          timelineEndMs: 5000,
          audioSourceInMs: 1300,
          audioSourceOutMs: 6300,
          confidence: 0.8,
          status: SyncStatus.mediumConfidence,
          method: SyncMethod.subtitleOnly,
          createdAt: now,
        ),
        videoFile: MediaFile(
          id: 'video-1',
          projectId: 'project-review-1',
          filePath: r'G:\video\C1001.mp4',
          type: MediaType.video,
          durationMs: 5000,
          createdAt: now,
        ),
        audioFile: MediaFile(
          id: 'audio-1',
          projectId: 'project-review-1',
          filePath: r'G:\audio\A1001.wav',
          type: MediaType.audio,
          durationMs: 10000,
          createdAt: now,
        ),
        audioCandidates: const [],
        videoSubtitles: const [
          SubtitleClip(
            id: 'video-clip-1',
            mediaFileId: 'video-1',
            startMs: 1000,
            endMs: 1300,
            localStartMs: 1000,
            localEndMs: 1300,
            text: '第一句',
            normalizedText: '第一句',
            sortOrder: 0,
          ),
          SubtitleClip(
            id: 'video-clip-2',
            mediaFileId: 'video-1',
            startMs: 3800,
            endMs: 4100,
            localStartMs: 3800,
            localEndMs: 4100,
            text: '第二句',
            normalizedText: '第二句',
            sortOrder: 1,
          ),
        ],
        audioSubtitles: const [
          SubtitleClip(
            id: 'local-audio-clip-2',
            mediaFileId: 'audio-1',
            startMs: 5000,
            endMs: 5300,
            globalStartMs: 5000,
            globalEndMs: 5300,
            localStartMs: 5000,
            localEndMs: 5300,
            text: '第二句',
            normalizedText: '第二句',
            sortOrder: 0,
          ),
        ],
        aggregateAudioSubtitleFile: SubtitleFile(
          id: 'subtitle-aggregate-1',
          projectId: 'project-review-1',
          filePath: r'G:\subtitle\all_audio.srt',
          mediaType: MediaType.audio,
          sourceType: SubtitleSourceType.aggregate,
          status: SubtitleFileStatus.split,
          cueCount: 2,
          createdAt: now,
        ),
        aggregateAudioSubtitles: const [
          SubtitleClip(
            id: 'aggregate-clip-1',
            subtitleFileId: 'subtitle-aggregate-1',
            startMs: 2600,
            endMs: 2900,
            globalStartMs: 2600,
            globalEndMs: 2900,
            text: '第一句',
            normalizedText: '第一句',
            sortOrder: 0,
          ),
          SubtitleClip(
            id: 'aggregate-clip-2',
            subtitleFileId: 'subtitle-aggregate-1',
            startMs: 5000,
            endMs: 5300,
            globalStartMs: 5000,
            globalEndMs: 5300,
            text: '第二句',
            normalizedText: '第二句',
            sortOrder: 1,
          ),
        ],
        anchorPairs: const [
          AnchorPair(
            id: 'anchor-1',
            syncResultId: 'sync-review-1',
            videoClipId: 'video-clip-1',
            audioClipId: 'aggregate-clip-1',
            videoTimeMs: 1000,
            audioTimeMs: 2600,
            offsetMs: 1600,
            similarity: 0.85,
          ),
          AnchorPair(
            id: 'anchor-2',
            syncResultId: 'sync-review-1',
            videoClipId: 'video-clip-2',
            audioClipId: 'local-audio-clip-2',
            videoTimeMs: 3800,
            audioTimeMs: 5000,
            offsetMs: 1200,
            similarity: 0.90,
          ),
          AnchorPair(
            id: 'anchor-missing',
            syncResultId: 'sync-review-1',
            videoClipId: 'video-clip-2',
            audioClipId: 'local-audio-clip-missing',
            videoTimeMs: 2200,
            audioTimeMs: 3450,
            offsetMs: 1250,
            similarity: 0.99,
          ),
        ],
      );

      final resolved = SubtitleMatchService.resolveReviewAnchors(detail);

      expect(resolved, hasLength(2));
      expect(resolved.first.videoClipId, 'video-clip-2');
      expect(resolved.first.aggregateAudioClipId, 'aggregate-clip-2');
      expect(resolved.first.audioGlobalTimeMs, 5000);
      expect(resolved.last.videoClipId, 'video-clip-1');
      expect(resolved.last.aggregateAudioClipId, 'aggregate-clip-1');
    },
  );
}

class _SeededScenario {
  final String projectId;
  final String syncResultId;
  final String videoClipId;
  final String aggregateAudioClipId;
  final String localAudioClipId;
  final String audio1Id;
  final String audio2Id;

  const _SeededScenario({
    required this.projectId,
    required this.syncResultId,
    required this.videoClipId,
    required this.aggregateAudioClipId,
    required this.localAudioClipId,
    required this.audio1Id,
    required this.audio2Id,
  });
}

Future<_SeededScenario> _seedScenario({
  String projectId = 'project-1',
  String syncResultId = 'sync-1',
  String videoClipId = 'video-clip-1',
  String aggregateAudioClipId = 'agg-clip-1',
  String localAudioClipId = 'local-audio-clip-1',
  required int aggregateStartMs,
  required int aggregateEndMs,
  required int videoClipStartMs,
  required int videoDurationMs,
  required List<int> audioDurationsMs,
  bool addAudioLayouts = true,
}) async {
  final now = DateTime(2026, 5, 18, 10, 0);
  final videoFileId = 'video-$projectId';
  final audio1Id = 'audio-1-$projectId';
  final audio2Id = 'audio-2-$projectId';
  final aggregateSubtitleFileId = 'audio-subtitle-aggregate-$projectId';

  await DatabaseService.insertProject(
    AsrProject(id: projectId, name: '手动匹配测试', createdAt: now, updatedAt: now),
  );

  final videoFile = MediaFile(
    id: videoFileId,
    projectId: projectId,
    filePath: r'G:\video\C0001.mp4',
    type: MediaType.video,
    durationMs: videoDurationMs,
    layoutStartMs: 0,
    layoutEndMs: videoDurationMs,
    subtitleStatus: SubtitleStatus.completed,
    createdAt: now,
  );
  final audio1 = MediaFile(
    id: audio1Id,
    projectId: projectId,
    filePath: r'G:\audio\A0001.wav',
    type: MediaType.audio,
    durationMs: audioDurationsMs[0],
    layoutStartMs: 0,
    layoutEndMs: audioDurationsMs[0],
    subtitleStatus: SubtitleStatus.completed,
    createdAt: now,
  );
  final audio2 = MediaFile(
    id: audio2Id,
    projectId: projectId,
    filePath: r'G:\audio\A0002.wav',
    type: MediaType.audio,
    durationMs: audioDurationsMs[1],
    layoutStartMs: audioDurationsMs[0],
    layoutEndMs: audioDurationsMs[0] + audioDurationsMs[1],
    subtitleStatus: SubtitleStatus.completed,
    createdAt: now,
  );
  await DatabaseService.insertMediaFiles([videoFile, audio1, audio2]);

  if (addAudioLayouts) {
    await DatabaseService.replaceSourceLayouts(projectId, MediaType.audio, [
      SourceLayoutItem(
        id: 'layout-a1-$projectId',
        projectId: projectId,
        mediaId: audio1Id,
        mediaType: MediaType.audio,
        sortIndex: 0,
        layoutStartMs: 0,
        layoutEndMs: audioDurationsMs[0],
        durationMs: audioDurationsMs[0],
        createdAt: now,
      ),
      SourceLayoutItem(
        id: 'layout-a2-$projectId',
        projectId: projectId,
        mediaId: audio2Id,
        mediaType: MediaType.audio,
        sortIndex: 1,
        layoutStartMs: audioDurationsMs[0],
        layoutEndMs: audioDurationsMs[0] + audioDurationsMs[1],
        durationMs: audioDurationsMs[1],
        createdAt: now,
      ),
    ]);
  }

  await DatabaseService.insertSubtitleFile(
    SubtitleFile(
      id: aggregateSubtitleFileId,
      projectId: projectId,
      filePath: r'G:\subtitle\all_audio.srt',
      mediaType: MediaType.audio,
      sourceType: SubtitleSourceType.aggregate,
      status: SubtitleFileStatus.split,
      cueCount: 2,
      createdAt: now,
    ),
  );

  await DatabaseService.insertSubtitleClips([
    SubtitleClip(
      id: videoClipId,
      mediaFileId: videoFileId,
      sourceKind: 'local',
      startMs: videoClipStartMs,
      endMs: videoClipStartMs + 600,
      globalStartMs: videoClipStartMs,
      globalEndMs: videoClipStartMs + 600,
      localStartMs: videoClipStartMs,
      localEndMs: videoClipStartMs + 600,
      text: '船尾现在开始',
      normalizedText: '船尾现在开始',
      sortOrder: 0,
    ),
    SubtitleClip(
      id: aggregateAudioClipId,
      subtitleFileId: aggregateSubtitleFileId,
      sourceKind: 'aggregate',
      startMs: aggregateStartMs,
      endMs: aggregateEndMs,
      globalStartMs: aggregateStartMs,
      globalEndMs: aggregateEndMs,
      text: '船尾现在开始',
      normalizedText: '船尾现在开始',
      sortOrder: 0,
    ),
    SubtitleClip(
      id: localAudioClipId,
      subtitleFileId: aggregateSubtitleFileId,
      mediaFileId: audio2Id,
      sourceKind: 'derived',
      startMs: 2000,
      endMs: 2600,
      globalStartMs: aggregateStartMs,
      globalEndMs: aggregateEndMs,
      localStartMs: 2000,
      localEndMs: 2600,
      text: '船尾现在开始',
      normalizedText: '船尾现在开始',
      sortOrder: 0,
    ),
  ]);

  await DatabaseService.replaceSyncResults(projectId, [
    SyncResult(
      id: syncResultId,
      projectId: projectId,
      videoFileId: videoFileId,
      audioFileId: audio1Id,
      videoDurationMs: videoDurationMs,
      timelineStartMs: 0,
      timelineEndMs: videoDurationMs,
      audioSourceInMs: 0,
      audioSourceOutMs: videoDurationMs,
      confidence: 0.48,
      status: SyncStatus.needsReview,
      method: SyncMethod.subtitleOnly,
      reviewStatus: SyncReviewStatus.pending,
      createdAt: now,
    ),
  ]);

  return _SeededScenario(
    projectId: projectId,
    syncResultId: syncResultId,
    videoClipId: videoClipId,
    aggregateAudioClipId: aggregateAudioClipId,
    localAudioClipId: localAudioClipId,
    audio1Id: audio1Id,
    audio2Id: audio2Id,
  );
}
