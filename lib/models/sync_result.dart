enum SyncStatus {
  autoAccepted('自动通过'),
  mediumConfidence('中置信度'),
  lowConfidence('低置信度'),
  noSubtitle('无字幕'),
  noMatch('未匹配'),
  audioTooShort('音频过短'),
  sourceClamped('越界修正'),
  needsReview('需要复核');

  final String label;
  const SyncStatus(this.label);
}

enum SyncMethod {
  subtitleOnly('字幕锚点'),
  manual('手动指定');

  final String label;
  const SyncMethod(this.label);
}

enum SyncReviewStatus {
  notRequired('无需复核'),
  pending('待复核'),
  accepted('已接受'),
  rejected('已移除');

  final String label;
  const SyncReviewStatus(this.label);
}

class SyncResult {
  final String id;
  final String projectId;
  final String videoFileId;
  final String? audioFileId;
  final int videoDurationMs;
  final int timelineStartMs;
  final int timelineEndMs;
  final int? audioSourceInMs;
  final int? audioSourceOutMs;
  final int handleBeforeMs;
  final int handleAfterMs;
  final double confidence;
  final SyncStatus status;
  final SyncMethod method;
  final int anchorCount;
  final bool sourceClamped;
  final bool audioTooShort;
  final SyncReviewStatus reviewStatus;
  final int? reviewedAtMs;
  final String? reviewNote;
  final String? notes;
  final DateTime createdAt;

  const SyncResult({
    required this.id,
    required this.projectId,
    required this.videoFileId,
    required this.audioFileId,
    required this.videoDurationMs,
    required this.timelineStartMs,
    required this.timelineEndMs,
    this.audioSourceInMs,
    this.audioSourceOutMs,
    this.handleBeforeMs = 0,
    this.handleAfterMs = 0,
    required this.confidence,
    required this.status,
    required this.method,
    this.anchorCount = 0,
    this.sourceClamped = false,
    this.audioTooShort = false,
    this.reviewStatus = SyncReviewStatus.pending,
    this.reviewedAtMs,
    this.reviewNote,
    this.notes,
    required this.createdAt,
  });

  bool get hasAudio =>
      audioFileId != null &&
      audioSourceInMs != null &&
      audioSourceOutMs != null;
  int get audioDurationMs =>
      hasAudio ? (audioSourceOutMs! - audioSourceInMs!) : 0;
  bool get needsReview => reviewStatus == SyncReviewStatus.pending;
  bool get isRejected => reviewStatus == SyncReviewStatus.rejected;
  bool get isAccepted => reviewStatus == SyncReviewStatus.accepted;

  SyncResult copyWith({
    String? audioFileId,
    int? timelineStartMs,
    int? timelineEndMs,
    int? audioSourceInMs,
    int? audioSourceOutMs,
    double? confidence,
    SyncStatus? status,
    SyncMethod? method,
    int? anchorCount,
    bool? sourceClamped,
    bool? audioTooShort,
    SyncReviewStatus? reviewStatus,
    int? reviewedAtMs,
    bool clearReviewedAtMs = false,
    String? reviewNote,
    bool clearReviewNote = false,
    String? notes,
  }) {
    return SyncResult(
      id: id,
      projectId: projectId,
      videoFileId: videoFileId,
      audioFileId: audioFileId ?? this.audioFileId,
      videoDurationMs: videoDurationMs,
      timelineStartMs: timelineStartMs ?? this.timelineStartMs,
      timelineEndMs: timelineEndMs ?? this.timelineEndMs,
      audioSourceInMs: audioSourceInMs ?? this.audioSourceInMs,
      audioSourceOutMs: audioSourceOutMs ?? this.audioSourceOutMs,
      handleBeforeMs: handleBeforeMs,
      handleAfterMs: handleAfterMs,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      method: method ?? this.method,
      anchorCount: anchorCount ?? this.anchorCount,
      sourceClamped: sourceClamped ?? this.sourceClamped,
      audioTooShort: audioTooShort ?? this.audioTooShort,
      reviewStatus: reviewStatus ?? this.reviewStatus,
      reviewedAtMs: clearReviewedAtMs
          ? null
          : reviewedAtMs ?? this.reviewedAtMs,
      reviewNote: clearReviewNote ? null : reviewNote ?? this.reviewNote,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }

  factory SyncResult.fromMap(Map<String, dynamic> map) {
    return SyncResult(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      videoFileId: map['video_file_id'] as String,
      audioFileId: map['audio_file_id'] as String?,
      videoDurationMs: map['video_duration_ms'] as int? ?? 0,
      timelineStartMs: map['timeline_start_ms'] as int? ?? 0,
      timelineEndMs: map['timeline_end_ms'] as int? ?? 0,
      audioSourceInMs: map['audio_source_in_ms'] as int?,
      audioSourceOutMs: map['audio_source_out_ms'] as int?,
      handleBeforeMs: map['handle_before_ms'] as int? ?? 0,
      handleAfterMs: map['handle_after_ms'] as int? ?? 0,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      status: SyncStatus.values.firstWhere(
        (item) => item.name == map['status'],
        orElse: () => SyncStatus.noMatch,
      ),
      method: SyncMethod.values.firstWhere(
        (item) => item.name == map['method'],
        orElse: () => SyncMethod.subtitleOnly,
      ),
      anchorCount: map['anchor_count'] as int? ?? 0,
      sourceClamped: (map['source_clamped'] as int? ?? 0) == 1,
      audioTooShort: (map['audio_too_short'] as int? ?? 0) == 1,
      reviewStatus: _parseReviewStatus(map),
      reviewedAtMs: map['reviewed_at_ms'] as int?,
      reviewNote: map['review_note'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'video_file_id': videoFileId,
    'audio_file_id': audioFileId,
    'video_duration_ms': videoDurationMs,
    'timeline_start_ms': timelineStartMs,
    'timeline_end_ms': timelineEndMs,
    'audio_source_in_ms': audioSourceInMs,
    'audio_source_out_ms': audioSourceOutMs,
    'handle_before_ms': handleBeforeMs,
    'handle_after_ms': handleAfterMs,
    'confidence': confidence,
    'status': status.name,
    'method': method.name,
    'anchor_count': anchorCount,
    'source_clamped': sourceClamped ? 1 : 0,
    'audio_too_short': audioTooShort ? 1 : 0,
    'needs_review': needsReview ? 1 : 0,
    'review_status': reviewStatus.name,
    'reviewed_at_ms': reviewedAtMs,
    'review_note': reviewNote,
    'notes': notes,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static SyncReviewStatus _parseReviewStatus(Map<String, dynamic> map) {
    final raw = map['review_status'] as String?;
    if (raw != null) {
      return SyncReviewStatus.values.firstWhere(
        (item) => item.name == raw,
        orElse: () => SyncReviewStatus.pending,
      );
    }
    return (map['needs_review'] as int? ?? 0) == 1
        ? SyncReviewStatus.pending
        : SyncReviewStatus.notRequired;
  }
}
