import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/subtitle_clip.dart';
import '../models/timeline_data.dart';
import '../models/sync_result.dart';
import 'database_service.dart';
import 'ffmpeg_service.dart';

class AudioAlignService {
  AudioAlignService._();

  static Future<List<TimelineData>> buildTimeline(String projectId) async {
    final syncResults = await DatabaseService.getSyncResults(projectId);
    final timelines = <TimelineData>[];

    for (final syncResult in syncResults.where((item) => !item.isRejected)) {
      final timeline = await _buildSingleTimeline(syncResult);
      if (timeline != null) {
        timelines.add(timeline);
      }
    }

    return timelines;
  }

  static Future<TimelineData?> _buildSingleTimeline(
    SyncResult syncResult,
  ) async {
    final videoFile = await DatabaseService.getMediaFileById(
      syncResult.videoFileId,
    );
    if (videoFile == null) return null;
    final audioFile = syncResult.audioFileId == null
        ? null
        : await DatabaseService.getMediaFileById(syncResult.audioFileId!);

    final videoSubtitles = await DatabaseService.getSubtitleClips(videoFile.id);
    final audioSubtitles = audioFile == null
        ? const <SubtitleClip>[]
        : await DatabaseService.getSubtitleClips(audioFile.id);

    final audioTrimStartMs = syncResult.audioSourceInMs ?? 0;
    final audioTrimEndMs = syncResult.audioSourceOutMs ?? 0;

    return TimelineData(
      syncResultId: syncResult.id,
      videoFileId: syncResult.videoFileId,
      audioFileId: syncResult.audioFileId,
      videoFileName: _fileName(videoFile.filePath),
      audioFileName: audioFile == null
          ? '未匹配音频'
          : _fileName(audioFile.filePath),
      videoFilePath: videoFile.filePath,
      audioFilePath: audioFile?.filePath ?? '',
      videoStartMs: 0,
      videoEndMs: syncResult.videoDurationMs,
      timelineStartMs: syncResult.timelineStartMs,
      timelineEndMs: syncResult.timelineEndMs,
      audioOriginalDurationMs: audioFile?.durationMs ?? 0,
      audioTrimStartMs: audioTrimStartMs,
      audioTrimEndMs: audioTrimEndMs,
      offsetMs: audioTrimStartMs,
      confidence: syncResult.confidence,
      status: syncResult.status.label,
      method: syncResult.method.name,
      markerText: _buildMarkerText(syncResult, audioFile?.filePath ?? ''),
      anchorCount: syncResult.anchorCount,
      sourceClamped: syncResult.sourceClamped,
      audioTooShort: syncResult.audioTooShort,
      reviewStatus: syncResult.reviewStatus,
      reviewedAtMs: syncResult.reviewedAtMs,
      reviewNote: syncResult.reviewNote,
      videoSubtitles: videoSubtitles,
      audioSubtitles: _mapAudioSubtitlesToTimeline(
        audioSubtitles,
        videoTimelineStartMs: syncResult.timelineStartMs,
        audioSourceInMs: syncResult.audioSourceInMs ?? 0,
      ),
    );
  }

  static List<SubtitleClip> _mapAudioSubtitlesToTimeline(
    List<SubtitleClip> clips, {
    required int videoTimelineStartMs,
    required int audioSourceInMs,
  }) {
    return clips
        .where((clip) {
          final localEnd = clip.localEndMs ?? clip.endMs;
          return localEnd >= audioSourceInMs;
        })
        .map((clip) {
          final localStart = clip.localStartMs ?? clip.startMs;
          final localEnd = clip.localEndMs ?? clip.endMs;
          final mappedStart =
              videoTimelineStartMs + (localStart - audioSourceInMs);
          final mappedEnd = videoTimelineStartMs + (localEnd - audioSourceInMs);
          return SubtitleClip(
            id: clip.id,
            subtitleFileId: clip.subtitleFileId,
            mediaFileId: clip.mediaFileId,
            sourceKind: clip.sourceKind,
            startMs: mappedStart,
            endMs: mappedEnd,
            globalStartMs: clip.globalStartMs,
            globalEndMs: clip.globalEndMs,
            localStartMs: mappedStart,
            localEndMs: mappedEnd,
            text: clip.text,
            normalizedText: clip.normalizedText,
            sortOrder: clip.sortOrder,
          );
        })
        .where((clip) => clip.endMs > clip.startMs)
        .toList();
  }

  static Future<List<String>> batchTrimAudio(
    List<TimelineData> timelineList,
    String outputDir, {
    required void Function(int current, int total, String fileName) onProgress,
  }) async {
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final results = <String>[];
    final total = timelineList.length;

    for (var i = 0; i < timelineList.length; i++) {
      final timeline = timelineList[i];
      if (timeline.audioFilePath.isEmpty || timeline.audioDurationMs <= 0) {
        results.add('');
        continue;
      }
      final outputFileName =
          '${_removeExtension(timeline.videoFileName)}_aligned.wav';
      final outputPath = p.join(outputDir, outputFileName);

      onProgress(i + 1, total, timeline.audioFileName);

      try {
        await FfmpegService.trimAndConvert(
          inputPath: timeline.audioFilePath,
          outputPath: outputPath,
          startMs: timeline.audioTrimStartMs,
          endMs: timeline.audioTrimEndMs,
        );
        results.add(outputPath);
      } catch (_) {
        results.add('');
      }
    }

    return results;
  }

  static String _buildMarkerText(SyncResult syncResult, String audioPath) {
    final fileName = audioPath.isEmpty ? '无音频' : _fileName(audioPath);
    final sourceIn = syncResult.audioSourceInMs == null
        ? '--'
        : _formatTime(syncResult.audioSourceInMs!);
    final sourceOut = syncResult.audioSourceOutMs == null
        ? '--'
        : _formatTime(syncResult.audioSourceOutMs!);
    return '${syncResult.status.label} ${(syncResult.confidence * 100).toStringAsFixed(0)}% | '
        '$fileName | $sourceIn - $sourceOut | anchors=${syncResult.anchorCount}';
  }

  static String _fileName(String path) => p.basename(path);

  static String _removeExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > 0) return fileName.substring(0, dotIndex);
    return fileName;
  }

  static String _formatTime(int ms) {
    final h = (ms ~/ 3600000).toString().padLeft(2, '0');
    final m = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
