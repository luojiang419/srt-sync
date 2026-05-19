import 'subtitle_clip.dart';
import 'sync_result.dart';

/// 时间线数据模型，描述一条视频与对应音频在时间线中的关系。
class TimelineData {
  final String syncResultId;
  final String videoFileId;
  final String? audioFileId;
  final String videoFileName;
  final String audioFileName;
  final String videoFilePath;
  final String audioFilePath;
  final bool videoHasEmbeddedAudio;
  final int videoStartMs;
  final int videoEndMs;
  final int timelineStartMs;
  final int timelineEndMs;
  final int audioOriginalDurationMs;
  final int audioTrimStartMs;
  final int audioTrimEndMs;
  final int offsetMs;
  final double confidence;
  final String status;
  final String method;
  final String markerText;
  final int anchorCount;
  final bool sourceClamped;
  final bool audioTooShort;
  final SyncReviewStatus reviewStatus;
  final int? reviewedAtMs;
  final String? reviewNote;
  final String? trimmedAudioPath;
  final List<SubtitleClip> videoSubtitles;
  final List<SubtitleClip> audioSubtitles;

  const TimelineData({
    required this.syncResultId,
    required this.videoFileId,
    this.audioFileId,
    required this.videoFileName,
    this.audioFileName = '',
    this.videoFilePath = '',
    this.audioFilePath = '',
    this.videoHasEmbeddedAudio = false,
    this.videoStartMs = 0,
    required this.videoEndMs,
    this.timelineStartMs = 0,
    this.timelineEndMs = 0,
    this.audioOriginalDurationMs = 0,
    this.audioTrimStartMs = 0,
    this.audioTrimEndMs = 0,
    this.offsetMs = 0,
    this.confidence = 0,
    this.status = '',
    this.method = '',
    this.markerText = '',
    this.anchorCount = 0,
    this.sourceClamped = false,
    this.audioTooShort = false,
    this.reviewStatus = SyncReviewStatus.pending,
    this.reviewedAtMs,
    this.reviewNote,
    this.trimmedAudioPath,
    this.videoSubtitles = const [],
    this.audioSubtitles = const [],
  });

  TimelineData copyWith({
    int? videoStartMs,
    int? videoEndMs,
    int? timelineStartMs,
    int? timelineEndMs,
    int? audioOriginalDurationMs,
    int? audioTrimStartMs,
    int? audioTrimEndMs,
    int? offsetMs,
    double? confidence,
    String? status,
    String? method,
    String? markerText,
    int? anchorCount,
    bool? sourceClamped,
    bool? audioTooShort,
    SyncReviewStatus? reviewStatus,
    int? reviewedAtMs,
    bool clearReviewedAtMs = false,
    String? reviewNote,
    bool clearReviewNote = false,
    String? trimmedAudioPath,
    bool? videoHasEmbeddedAudio,
    List<SubtitleClip>? videoSubtitles,
    List<SubtitleClip>? audioSubtitles,
  }) {
    return TimelineData(
      syncResultId: syncResultId,
      videoFileId: videoFileId,
      audioFileId: audioFileId,
      videoFileName: videoFileName,
      audioFileName: audioFileName,
      videoFilePath: videoFilePath,
      audioFilePath: audioFilePath,
      videoHasEmbeddedAudio:
          videoHasEmbeddedAudio ?? this.videoHasEmbeddedAudio,
      videoStartMs: videoStartMs ?? this.videoStartMs,
      videoEndMs: videoEndMs ?? this.videoEndMs,
      timelineStartMs: timelineStartMs ?? this.timelineStartMs,
      timelineEndMs: timelineEndMs ?? this.timelineEndMs,
      audioOriginalDurationMs:
          audioOriginalDurationMs ?? this.audioOriginalDurationMs,
      audioTrimStartMs: audioTrimStartMs ?? this.audioTrimStartMs,
      audioTrimEndMs: audioTrimEndMs ?? this.audioTrimEndMs,
      offsetMs: offsetMs ?? this.offsetMs,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      method: method ?? this.method,
      markerText: markerText ?? this.markerText,
      anchorCount: anchorCount ?? this.anchorCount,
      sourceClamped: sourceClamped ?? this.sourceClamped,
      audioTooShort: audioTooShort ?? this.audioTooShort,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewedAtMs: clearReviewedAtMs
          ? null
          : reviewedAtMs ?? this.reviewedAtMs,
      reviewNote: clearReviewNote ? null : reviewNote ?? this.reviewNote,
      trimmedAudioPath: trimmedAudioPath ?? this.trimmedAudioPath,
      videoSubtitles: videoSubtitles ?? this.videoSubtitles,
      audioSubtitles: audioSubtitles ?? this.audioSubtitles,
    );
  }

  int get videoDurationMs => videoEndMs - videoStartMs;
  int get audioDurationMs => audioTrimEndMs - audioTrimStartMs;
  bool get needsReview => reviewStatus == SyncReviewStatus.pending;
  bool get hasTrimmedAudio =>
      trimmedAudioPath != null && trimmedAudioPath!.isNotEmpty;
  String get effectiveAudioPath =>
      hasTrimmedAudio ? trimmedAudioPath! : audioFilePath;
  int get effectiveAudioSourceInMs => hasTrimmedAudio ? 0 : audioTrimStartMs;
  int get effectiveAudioSourceOutMs =>
      effectiveAudioSourceInMs + audioDurationMs;
  int get effectiveAudioFileDurationMs =>
      hasTrimmedAudio ? audioDurationMs : audioOriginalDurationMs;
}
