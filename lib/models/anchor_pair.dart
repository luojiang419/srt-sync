class AnchorPair {
  final String id;
  final String syncResultId;
  final String videoClipId;
  final String audioClipId;
  final int videoTimeMs;
  final int audioTimeMs;
  final int offsetMs;
  final double similarity;

  const AnchorPair({
    required this.id,
    required this.syncResultId,
    required this.videoClipId,
    required this.audioClipId,
    required this.videoTimeMs,
    required this.audioTimeMs,
    required this.offsetMs,
    required this.similarity,
  });

  factory AnchorPair.fromMap(Map<String, dynamic> map) {
    return AnchorPair(
      id: map['id'] as String,
      syncResultId: map['sync_result_id'] as String,
      videoClipId: map['video_clip_id'] as String,
      audioClipId: map['audio_clip_id'] as String,
      videoTimeMs: map['video_time_ms'] as int? ?? 0,
      audioTimeMs: map['audio_time_ms'] as int? ?? 0,
      offsetMs: map['offset_ms'] as int? ?? 0,
      similarity: (map['similarity'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'sync_result_id': syncResultId,
    'video_clip_id': videoClipId,
    'audio_clip_id': audioClipId,
    'video_time_ms': videoTimeMs,
    'audio_time_ms': audioTimeMs,
    'offset_ms': offsetMs,
    'similarity': similarity,
  };
}
