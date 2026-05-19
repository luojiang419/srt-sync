class MatchCandidate {
  final String id;
  final String projectId;
  final String videoFileId;
  final String audioFileId;
  final String videoWindowId;
  final String audioWindowId;
  final double textScore;
  final double contextScore;
  final double anchorScore;
  final double uniquenessScore;
  final double metadataScore;
  final double neighborScore;
  final double totalScore;
  final int fallbackOffsetMs;
  final DateTime createdAt;

  const MatchCandidate({
    required this.id,
    required this.projectId,
    required this.videoFileId,
    required this.audioFileId,
    required this.videoWindowId,
    required this.audioWindowId,
    required this.textScore,
    required this.contextScore,
    required this.anchorScore,
    required this.uniquenessScore,
    required this.metadataScore,
    required this.neighborScore,
    required this.totalScore,
    this.fallbackOffsetMs = 0,
    required this.createdAt,
  });

  factory MatchCandidate.fromMap(Map<String, dynamic> map) {
    return MatchCandidate(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      videoFileId: map['video_file_id'] as String,
      audioFileId: map['audio_file_id'] as String,
      videoWindowId: map['video_window_id'] as String,
      audioWindowId: map['audio_window_id'] as String,
      textScore: (map['text_score'] as num?)?.toDouble() ?? 0.0,
      contextScore: (map['context_score'] as num?)?.toDouble() ?? 0.0,
      anchorScore: (map['anchor_score'] as num?)?.toDouble() ?? 0.0,
      uniquenessScore: (map['uniqueness_score'] as num?)?.toDouble() ?? 0.0,
      metadataScore: (map['metadata_score'] as num?)?.toDouble() ?? 0.0,
      neighborScore: (map['neighbor_score'] as num?)?.toDouble() ?? 0.0,
      totalScore: (map['total_score'] as num?)?.toDouble() ?? 0.0,
      fallbackOffsetMs: map['fallback_offset_ms'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'video_file_id': videoFileId,
    'audio_file_id': audioFileId,
    'video_window_id': videoWindowId,
    'audio_window_id': audioWindowId,
    'text_score': textScore,
    'context_score': contextScore,
    'anchor_score': anchorScore,
    'uniqueness_score': uniquenessScore,
    'metadata_score': metadataScore,
    'neighbor_score': neighborScore,
    'total_score': totalScore,
    'fallback_offset_ms': fallbackOffsetMs,
    'created_at': createdAt.millisecondsSinceEpoch,
  };
}
