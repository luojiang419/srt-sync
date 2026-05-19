import 'package:flutter/material.dart';
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
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime(2026, 5, 18, 11, 0);
      final currentAudio = MediaFile(
        id: 'audio-1',
        projectId: 'project-1',
        filePath: r'G:\audio\A0001.wav',
        type: MediaType.audio,
        durationMs: 10000,
        layoutStartMs: 0,
        layoutEndMs: 10000,
        createdAt: now,
      );
      final matchedAudio = MediaFile(
        id: 'audio-2',
        projectId: 'project-1',
        filePath: r'G:\audio\A0002.wav',
        type: MediaType.audio,
        durationMs: 10000,
        layoutStartMs: 10000,
        layoutEndMs: 20000,
        createdAt: now,
      );
      final detail = SyncReviewDetail(
        syncResult: SyncResult(
          id: 'sync-1',
          projectId: 'project-1',
          videoFileId: 'video-1',
          audioFileId: currentAudio.id,
          videoDurationMs: 4000,
          timelineStartMs: 0,
          timelineEndMs: 4000,
          audioSourceInMs: 0,
          audioSourceOutMs: 4000,
          confidence: 0.55,
          status: SyncStatus.needsReview,
          method: SyncMethod.subtitleOnly,
          reviewStatus: SyncReviewStatus.pending,
          createdAt: now,
        ),
        videoFile: MediaFile(
          id: 'video-1',
          projectId: 'project-1',
          filePath: r'G:\video\C0008.mp4',
          type: MediaType.video,
          durationMs: 4000,
          layoutStartMs: 0,
          layoutEndMs: 4000,
          createdAt: now,
        ),
        audioFile: currentAudio,
        audioCandidates: [currentAudio, matchedAudio],
        videoSubtitles: const [
          SubtitleClip(
            id: 'video-clip-1',
            mediaFileId: 'video-1',
            startMs: 200,
            endMs: 800,
            localStartMs: 200,
            localEndMs: 800,
            text: '视频第一条不匹配',
            normalizedText: '视频第一条不匹配',
            sortOrder: 0,
          ),
          SubtitleClip(
            id: 'video-clip-2',
            mediaFileId: 'video-1',
            startMs: 1000,
            endMs: 1600,
            localStartMs: 1000,
            localEndMs: 1600,
            text: '视频第二条准备收声',
            normalizedText: '视频第二条准备收声',
            sortOrder: 1,
          ),
        ],
        audioSubtitles: const [
          SubtitleClip(
            id: 'audio-local-clip-1',
            mediaFileId: 'audio-1',
            startMs: 1500,
            endMs: 1900,
            localStartMs: 1500,
            localEndMs: 1900,
            text: '音频第一段本地字幕',
            normalizedText: '音频第一段本地字幕',
            sortOrder: 0,
          ),
          SubtitleClip(
            id: 'audio-local-clip-2',
            mediaFileId: 'audio-1',
            startMs: 1200,
            endMs: 1800,
            globalStartMs: 11200,
            globalEndMs: 11800,
            localStartMs: 1200,
            localEndMs: 1800,
            text: '音频第二段本地字幕',
            normalizedText: '音频第二段本地字幕',
            sortOrder: 1,
          ),
        ],
        aggregateAudioSubtitleFile: SubtitleFile(
          id: 'subtitle-1',
          projectId: 'project-1',
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
            subtitleFileId: 'subtitle-1',
            startMs: 1500,
            endMs: 1900,
            globalStartMs: 1500,
            globalEndMs: 1900,
            text: '音频总轨第一条不匹配',
            normalizedText: '音频总轨第一条不匹配',
            sortOrder: 0,
          ),
          SubtitleClip(
            id: 'aggregate-clip-2',
            subtitleFileId: 'subtitle-1',
            startMs: 11200,
            endMs: 11800,
            globalStartMs: 11200,
            globalEndMs: 11800,
            text: '音频总轨第二条准备收声',
            normalizedText: '音频总轨第二条准备收声',
            sortOrder: 1,
          ),
        ],
        anchorPairs: const [
          AnchorPair(
            id: 'anchor-1',
            syncResultId: 'sync-1',
            videoClipId: 'video-clip-1',
            audioClipId: 'aggregate-clip-1',
            videoTimeMs: 200,
            audioTimeMs: 400,
            offsetMs: 200,
            similarity: 0.82,
          ),
          AnchorPair(
            id: 'anchor-2',
            syncResultId: 'sync-1',
            videoClipId: 'video-clip-2',
            audioClipId: 'audio-local-clip-2',
            videoTimeMs: 1000,
            audioTimeMs: 2200,
            offsetMs: 1200,
            similarity: 0.95,
          ),
        ],
      );

      Future<ManualAnchorMatchPreview> previewResolver({
        required String projectId,
        required String videoClipId,
        required String aggregateAudioClipId,
      }) async {
        if (aggregateAudioClipId == 'aggregate-clip-1') {
          return ManualAnchorMatchPreview(
            targetAudioFile: currentAudio,
            audioSourceInMs: 100,
            audioSourceOutMs: 4100,
            sourceClamped: false,
            audioTooShort: false,
            status: SyncStatus.autoAccepted,
            notes: '锚点一预览成功',
          );
        }
        return ManualAnchorMatchPreview(
          targetAudioFile: matchedAudio,
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
                      showDialog<void>(
                        context: context,
                        builder: (_) => SyncReviewDialog(
                          projectId: 'project-1',
                          syncResultId: 'sync-1',
                          previewResolver: previewResolver,
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
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('合板详情与复核'), findsOneWidget);
      expect(find.text('音频总字幕'), findsOneWidget);
      expect(find.text('总字幕: all_audio.srt'), findsOneWidget);
      expect(find.text('音频总轨第二条准备收声'), findsOneWidget);
      expect(find.text('合板锚点 1/2'), findsOneWidget);

      final disabledMatchButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '匹配'),
      );
      expect(disabledMatchButton.onPressed, isNull);

      await tester.enterText(find.byType(TextField), '准备');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('视频命中 1 / 音频命中 1'), findsOneWidget);
      expect(find.text('关键词结果 1 条'), findsNWidgets(2));
      expect(find.text('视频第一条不匹配'), findsNothing);
      expect(find.text('音频总轨第一条不匹配'), findsNothing);

      await tester.tap(find.text('视频第二条准备收声'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('返回关键词列表'), findsOneWidget);
      expect(find.text('视频第一条不匹配'), findsOneWidget);
      expect(find.text('音频总轨第一条不匹配'), findsNothing);

      await tester.tap(find.text('返回关键词列表'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('关键词结果 1 条'), findsNWidgets(2));
      expect(find.text('视频第一条不匹配'), findsNothing);

      await tester.tap(find.text('音频总轨第二条准备收声'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('返回关键词列表'), findsOneWidget);
      expect(find.text('音频总轨第一条不匹配'), findsOneWidget);
      expect(find.text('视频第一条不匹配'), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, '合板锚点 1/2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final enabledByAnchorButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '匹配'),
      );
      expect(enabledByAnchorButton.onPressed, isNotNull);
      expect(find.text('锚点一预览成功'), findsOneWidget);
      expect(find.text('视频命中 1 / 音频命中 1'), findsOneWidget);
      expect(find.text('返回关键词列表'), findsNWidgets(2));
      expect(find.text('视频第一条不匹配'), findsWidgets);
      expect(find.text('音频总轨第一条不匹配'), findsWidgets);

      await tester.tap(find.widgetWithText(OutlinedButton, '合板锚点 1/2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('合板锚点 2/2'), findsOneWidget);
      final enabledMatchButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '匹配'),
      );
      expect(enabledMatchButton.onPressed, isNotNull);
      expect(find.text('A0002.wav'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
