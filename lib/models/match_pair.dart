/// 匹配结果对模型
class MatchPair {
  final String id;
  final String projectId;
  final String videoFileId;
  final String audioFileId;
  final double confidence;
  final int offsetMs;
  final bool confirmed;
  final DateTime createdAt;

  const MatchPair({
    required this.id,
    required this.projectId,
    required this.videoFileId,
    required this.audioFileId,
    required this.confidence,
    this.offsetMs = 0,
    this.confirmed = false,
    required this.createdAt,
  });

  MatchPair copyWith({double? confidence, int? offsetMs, bool? confirmed}) {
    return MatchPair(
      id: id,
      projectId: projectId,
      videoFileId: videoFileId,
      audioFileId: audioFileId,
      confidence: confidence ?? this.confidence,
      offsetMs: offsetMs ?? this.offsetMs,
      confirmed: confirmed ?? this.confirmed,
      createdAt: createdAt,
    );
  }

  /// 置信度等级
  String get confidenceLabel {
    if (confidence >= 0.9) return '高';
    if (confidence >= 0.7) return '中';
    return '低';
  }

  factory MatchPair.fromMap(Map<String, dynamic> map) {
    return MatchPair(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      videoFileId: map['video_file_id'] as String,
      audioFileId: map['audio_file_id'] as String,
      confidence: map['confidence'] as double,
      offsetMs: map['offset_ms'] as int? ?? 0,
      confirmed: (map['confirmed'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'video_file_id': videoFileId,
    'audio_file_id': audioFileId,
    'confidence': confidence,
    'offset_ms': offsetMs,
    'confirmed': confirmed ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };
}
