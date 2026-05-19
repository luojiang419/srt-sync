import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asr_tools/models/anchor_pair.dart';
import 'package:asr_tools/models/media_file.dart';
import 'package:asr_tools/models/subtitle_clip.dart';
import 'package:asr_tools/models/subtitle_file.dart';
import 'package:asr_tools/models/sync_review_detail.dart';
import 'package:asr_tools/models/sync_result.dart';
import 'package:asr_tools/providers/match_provider.dart';
import 'package:asr_tools/services/subtitle_match_service.dart';
import 'package:asr_tools/widgets/sync_review_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'review dialog shows keyword lists, supports independent return, and keeps anchor jump working during search',
    (tester) async {
      _setLargeSurface(tester);
      final detail = _buildDetail(
        syncResultId: 'sync-1',
        videoFileId: 'video-1',
        videoFileName: 'C0008.mp4',
        audioFileId: 'audio-1',
        audioFileName: 'A0001.wav',
        aggregateSubtitleName: 'all_audio.srt',
        note: '第一条说明',
      );

      Future<ManualAnchorMatchPreview> previewResolver({
        required String projectId,
        required String videoClipId,
        required String aggregateAudioClipId,
      }) async {
        if (aggregateAudioClipId.endsWith('aggregate-clip-1')) {
          return ManualAnchorMatchPreview(
            targetAudioFile: detail.audioFile,
            audioSourceInMs: 100,
            audioSourceOutMs: 4100,
            sourceClamped: false,
            audioTooShort: false,
            status: SyncStatus.autoAccepted,
            notes: '锚点一预览成功',
          );
        }
        return ManualAnchorMatchPreview(
          targetAudioFile: detail.audioCandidates.last,
          audioSourceInMs: 200,
          audioSourceOutMs: 4200,
          sourceClamped: false,
          audioTooShort: false,
          status: SyncStatus.autoAccepted,
          notes: '手动匹配预览成功',
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncReviewDetailProvider(
              'sync-1',
            ).overrideWith((ref) async => detail),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SyncReviewPage(
                            projectId: 'project-1',
                            syncResultId: 'sync-1',
                            reviewSequenceIds: const ['sync-1'],
                            initialIndex: 0,
                            sequenceMode: SyncReviewDialogSequenceMode.pending,
                            previewResolver: previewResolver,
                          ),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('合板详情与复核'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('音频总字幕'), findsOneWidget);
      expect(find.text('总字幕: all_audio.srt'), findsOneWidget);
      expect(find.text('第一条说明'), findsOneWidget);
      expect(find.text('全部锚点'), findsNothing);
      expect(find.text('合板锚点 1/2'), findsOneWidget);
      expect(find.text('锚点一预览成功'), findsOneWidget);
      expect(find.text('视频第一条不匹配 sync-1'), findsNWidgets(2));
      expect(find.text('音频总轨第一条不匹配 sync-1'), findsNWidgets(2));

      final enabledMatchButtonOnOpen = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '匹配'),
      );
      expect(enabledMatchButtonOnOpen.onPressed, isNotNull);

      await tester.enterText(find.byType(TextField), '准备收声');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('视频命中 1 / 音频命中 1'), findsOneWidget);
      expect(find.text('关键词结果 1 条'), findsNWidgets(2));

      await tester.tap(find.text('视频第二条准备收声 sync-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('返回关键词列表'), findsOneWidget);
      expect(find.text('视频第二条准备收声 sync-1'), findsWidgets);

      await tester.tap(find.text('返回关键词列表'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('关键词结果 1 条'), findsNWidgets(2));

      await tester.tap(find.text('音频总轨第二条准备收声 sync-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('返回关键词列表'), findsOneWidget);
      expect(find.text('音频总轨第二条准备收声 sync-1'), findsWidgets);
      expect(find.text('手动匹配预览成功'), findsOneWidget);
      expect(find.text('合板锚点 2/2'), findsOneWidget);
      expect(find.text('视频第二条准备收声 sync-1'), findsWidgets);
      expect(find.text('音频总轨第二条准备收声 sync-1'), findsWidgets);

      await tester.tap(find.text('合板锚点 2/2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final enabledByAnchorButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '匹配'),
      );
      expect(enabledByAnchorButton.onPressed, isNotNull);
      expect(find.text('锚点一预览成功'), findsOneWidget);
      expect(find.text('合板锚点 1/2'), findsOneWidget);
      expect(find.text('视频命中 1 / 音频命中 1'), findsOneWidget);
      expect(find.text('返回关键词列表'), findsNWidgets(2));
      expect(find.text('视频第一条不匹配 sync-1'), findsWidgets);
      expect(find.text('音频总轨第一条不匹配 sync-1'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'review dialog stays open on barrier tap, supports prev/next buttons and keyboard navigation, and ignores arrows while search is focused',
    (tester) async {
      _setLargeSurface(tester);
      _seedTestDetails();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [matchProvider.overrideWith(TestMatchNotifier.new)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SyncReviewPage(
                            projectId: 'project-1',
                            syncResultId: 'sync-1',
                            reviewSequenceIds: _detailOrder,
                            initialIndex: 0,
                            sequenceMode: SyncReviewDialogSequenceMode.all,
                            previewResolver: _previewResolver,
                          ),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('第一条说明'), findsOneWidget);
      expect(find.byType(SyncReviewPage), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);

      final previousButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '上一条'),
      );
      expect(previousButton.onPressed, isNull);

      await tester.tapAt(const Offset(12, 12));
      await tester.pumpAndSettle();
      expect(find.byType(SyncReviewPage), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, '下一条'));
      await tester.pumpAndSettle();
      expect(find.text('第二条说明'), findsOneWidget);
      expect(find.text('素材 2/2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('第一条说明'), findsOneWidget);
      expect(find.text('素材 1/2'), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('第一条说明'), findsOneWidget);
      expect(find.text('素材 1/2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SyncReviewPage), findsNothing);
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'review dialog stays open after accept and advances to the next pending item',
    (tester) async {
      _setLargeSurface(tester);
      _seedTestDetails();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [matchProvider.overrideWith(TestMatchNotifier.new)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => SyncReviewPage(
                            projectId: 'project-1',
                            syncResultId: 'sync-1',
                            reviewSequenceIds: _detailOrder,
                            initialIndex: 0,
                            sequenceMode: SyncReviewDialogSequenceMode.pending,
                            previewResolver: _previewResolver,
                          ),
                        ),
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('第一条说明'), findsOneWidget);
      expect(find.text('素材 1/2'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, '接受'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(SyncReviewPage), findsOneWidget);
      expect(find.text('第二条说明'), findsOneWidget);
      expect(find.text('素材 1/1'), findsOneWidget);
    },
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

late Map<String, SyncReviewDetail> _detailsById;
late List<String> _detailOrder;

void _seedTestDetails() {
  _detailsById = {
    'sync-1': _buildDetail(
      syncResultId: 'sync-1',
      videoFileId: 'video-1',
      videoFileName: 'C0008.mp4',
      audioFileId: 'audio-1',
      audioFileName: 'A0001.wav',
      aggregateSubtitleName: 'sync_1_all_audio.srt',
      note: '第一条说明',
    ),
    'sync-2': _buildDetail(
      syncResultId: 'sync-2',
      videoFileId: 'video-2',
      videoFileName: 'C0009.mp4',
      audioFileId: 'audio-2',
      audioFileName: 'A0002.wav',
      aggregateSubtitleName: 'sync_2_all_audio.srt',
      note: '第二条说明',
    ),
  };
  _detailOrder = const ['sync-1', 'sync-2'];
}

class TestMatchNotifier extends MatchNotifier {
  @override
  MatchState build() =>
      MatchState(syncResults: _orderedSyncResults(), stageLabel: '已完成');

  @override
  Future<void> loadMatchResults(String projectId) async {}

  @override
  Future<SyncReviewDetail?> loadReviewDetail(String syncResultId) async {
    return _detailsById[syncResultId];
  }

  @override
  Future<void> acceptReview(String syncResultId, String projectId) async {
    _updateReviewStatus(syncResultId, SyncReviewStatus.accepted);
  }

  @override
  Future<void> rejectReview(String syncResultId, String projectId) async {
    _updateReviewStatus(syncResultId, SyncReviewStatus.rejected);
  }

  @override
  Future<void> restoreReview(String syncResultId, String projectId) async {
    _updateReviewStatus(syncResultId, SyncReviewStatus.pending);
  }

  @override
  Future<void> manualAnchorMatch({
    required String syncResultId,
    required String projectId,
    required String videoClipId,
    required String aggregateAudioClipId,
  }) async {
    final detail = _detailsById[syncResultId]!;
    _detailsById[syncResultId] = _copyDetail(
      detail,
      syncResult: detail.syncResult.copyWith(
        reviewStatus: SyncReviewStatus.accepted,
        method: SyncMethod.manual,
        notes: '手动匹配已完成',
      ),
    );
    state = AsyncData(
      (state.valueOrNull ?? const MatchState()).copyWith(
        syncResults: _orderedSyncResults(),
        stageLabel: '已完成',
      ),
    );
  }

  void _updateReviewStatus(String syncResultId, SyncReviewStatus status) {
    final detail = _detailsById[syncResultId]!;
    _detailsById[syncResultId] = _copyDetail(
      detail,
      syncResult: detail.syncResult.copyWith(reviewStatus: status),
    );
    state = AsyncData(
      (state.valueOrNull ?? const MatchState()).copyWith(
        syncResults: _orderedSyncResults(),
        stageLabel: '已完成',
      ),
    );
  }
}

List<SyncResult> _orderedSyncResults() =>
    _detailOrder.map((id) => _detailsById[id]!.syncResult).toList();

SyncReviewDetail _copyDetail(
  SyncReviewDetail detail, {
  required SyncResult syncResult,
}) {
  return SyncReviewDetail(
    syncResult: syncResult,
    videoFile: detail.videoFile,
    audioFile: detail.audioFile,
    audioCandidates: detail.audioCandidates,
    videoSubtitles: detail.videoSubtitles,
    audioSubtitles: detail.audioSubtitles,
    aggregateAudioSubtitleFile: detail.aggregateAudioSubtitleFile,
    aggregateAudioSubtitles: detail.aggregateAudioSubtitles,
    anchorPairs: detail.anchorPairs,
  );
}

Future<ManualAnchorMatchPreview> _previewResolver({
  required String projectId,
  required String videoClipId,
  required String aggregateAudioClipId,
}) async {
  final targetDetail = _detailsById.values.firstWhere(
    (detail) => detail.aggregateAudioSubtitles.any(
      (clip) => clip.id == aggregateAudioClipId,
    ),
  );
  final targetAudio = aggregateAudioClipId.endsWith('aggregate-clip-1')
      ? targetDetail.audioFile
      : targetDetail.audioCandidates.last;
  return ManualAnchorMatchPreview(
    targetAudioFile: targetAudio,
    audioSourceInMs: 200,
    audioSourceOutMs: 4200,
    sourceClamped: false,
    audioTooShort: false,
    status: SyncStatus.autoAccepted,
    notes: '预览成功',
  );
}

SyncReviewDetail _buildDetail({
  required String syncResultId,
  required String videoFileId,
  required String videoFileName,
  required String audioFileId,
  required String audioFileName,
  required String aggregateSubtitleName,
  required String note,
}) {
  final now = DateTime(2026, 5, 18, 11, 0);
  final primaryAudio = MediaFile(
    id: audioFileId,
    projectId: 'project-1',
    filePath: r'G:\audio\' + audioFileName,
    type: MediaType.audio,
    durationMs: 10000,
    layoutStartMs: 0,
    layoutEndMs: 10000,
    createdAt: now,
  );
  final secondaryAudio = MediaFile(
    id: '$audioFileId-alt',
    projectId: 'project-1',
    filePath: r'G:\audio\' + audioFileName.replaceFirst('.wav', '_ALT.wav'),
    type: MediaType.audio,
    durationMs: 10000,
    layoutStartMs: 10000,
    layoutEndMs: 20000,
    createdAt: now,
  );

  return SyncReviewDetail(
    syncResult: SyncResult(
      id: syncResultId,
      projectId: 'project-1',
      videoFileId: videoFileId,
      audioFileId: primaryAudio.id,
      videoDurationMs: 4000,
      timelineStartMs: 0,
      timelineEndMs: 4000,
      audioSourceInMs: 0,
      audioSourceOutMs: 4000,
      confidence: 0.55,
      status: SyncStatus.needsReview,
      method: SyncMethod.subtitleOnly,
      reviewStatus: SyncReviewStatus.pending,
      notes: note,
      createdAt: now,
    ),
    videoFile: MediaFile(
      id: videoFileId,
      projectId: 'project-1',
      filePath: r'G:\video\' + videoFileName,
      type: MediaType.video,
      durationMs: 4000,
      layoutStartMs: 0,
      layoutEndMs: 4000,
      createdAt: now,
    ),
    audioFile: primaryAudio,
    audioCandidates: [primaryAudio, secondaryAudio],
    videoSubtitles: [
      SubtitleClip(
        id: '$syncResultId-video-clip-1',
        mediaFileId: videoFileId,
        startMs: 200,
        endMs: 800,
        localStartMs: 200,
        localEndMs: 800,
        text: '视频第一条不匹配 $syncResultId',
        normalizedText: '视频第一条不匹配 $syncResultId',
        sortOrder: 0,
      ),
      SubtitleClip(
        id: '$syncResultId-video-clip-2',
        mediaFileId: videoFileId,
        startMs: 1000,
        endMs: 1600,
        localStartMs: 1000,
        localEndMs: 1600,
        text: '视频第二条准备收声 $syncResultId',
        normalizedText: '视频第二条准备收声 $syncResultId',
        sortOrder: 1,
      ),
    ],
    audioSubtitles: [
      SubtitleClip(
        id: '$syncResultId-audio-local-clip-1',
        mediaFileId: primaryAudio.id,
        startMs: 1500,
        endMs: 1900,
        localStartMs: 1500,
        localEndMs: 1900,
        text: '音频第一段本地字幕 $syncResultId',
        normalizedText: '音频第一段本地字幕 $syncResultId',
        sortOrder: 0,
      ),
      SubtitleClip(
        id: '$syncResultId-audio-local-clip-2',
        mediaFileId: primaryAudio.id,
        startMs: 1200,
        endMs: 1800,
        globalStartMs: 11200,
        globalEndMs: 11800,
        localStartMs: 1200,
        localEndMs: 1800,
        text: '音频第二段本地字幕 $syncResultId',
        normalizedText: '音频第二段本地字幕 $syncResultId',
        sortOrder: 1,
      ),
    ],
    aggregateAudioSubtitleFile: SubtitleFile(
      id: '$syncResultId-subtitle-1',
      projectId: 'project-1',
      filePath: r'G:\subtitle\' + aggregateSubtitleName,
      mediaType: MediaType.audio,
      sourceType: SubtitleSourceType.aggregate,
      status: SubtitleFileStatus.split,
      cueCount: 2,
      createdAt: now,
    ),
    aggregateAudioSubtitles: [
      SubtitleClip(
        id: '$syncResultId-aggregate-clip-1',
        subtitleFileId: '$syncResultId-subtitle-1',
        startMs: 1500,
        endMs: 1900,
        globalStartMs: 1500,
        globalEndMs: 1900,
        text: '音频总轨第一条不匹配 $syncResultId',
        normalizedText: '音频总轨第一条不匹配 $syncResultId',
        sortOrder: 0,
      ),
      SubtitleClip(
        id: '$syncResultId-aggregate-clip-2',
        subtitleFileId: '$syncResultId-subtitle-1',
        startMs: 11200,
        endMs: 11800,
        globalStartMs: 11200,
        globalEndMs: 11800,
        text: '音频总轨第二条准备收声 $syncResultId',
        normalizedText: '音频总轨第二条准备收声 $syncResultId',
        sortOrder: 1,
      ),
    ],
    anchorPairs: [
      AnchorPair(
        id: '$syncResultId-anchor-1',
        syncResultId: syncResultId,
        videoClipId: '$syncResultId-video-clip-1',
        audioClipId: '$syncResultId-aggregate-clip-1',
        videoTimeMs: 200,
        audioTimeMs: 400,
        offsetMs: 200,
        similarity: 0.82,
      ),
      AnchorPair(
        id: '$syncResultId-anchor-2',
        syncResultId: syncResultId,
        videoClipId: '$syncResultId-video-clip-2',
        audioClipId: '$syncResultId-aggregate-clip-2',
        videoTimeMs: 1000,
        audioTimeMs: 2200,
        offsetMs: 1200,
        similarity: 0.95,
      ),
    ],
  );
}
