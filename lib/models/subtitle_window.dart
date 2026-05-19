import 'media_file.dart';

class SubtitleWindow {
  final String id;
  final String projectId;
  final String mediaFileId;
  final MediaType mediaType;
  final int windowSize;
  final int startMs;
  final int endMs;
  final String text;
  final String normalizedText;
  final String cueIds;
  final double uniquenessWeight;
  final DateTime createdAt;

  const SubtitleWindow({
    required this.id,
    required this.projectId,
    required this.mediaFileId,
    required this.mediaType,
    required this.windowSize,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.normalizedText,
    required this.cueIds,
    required this.uniquenessWeight,
    required this.createdAt,
  });

  List<String> get cueIdList => cueIds.isEmpty ? const [] : cueIds.split(',');

  factory SubtitleWindow.fromMap(Map<String, dynamic> map) {
    return SubtitleWindow(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      mediaFileId: map['media_file_id'] as String,
      mediaType: map['media_type'] == 'video'
          ? MediaType.video
          : MediaType.audio,
      windowSize: map['window_size'] as int? ?? 1,
      startMs: map['start_ms'] as int? ?? 0,
      endMs: map['end_ms'] as int? ?? 0,
      text: map['text'] as String? ?? '',
      normalizedText: map['normalized_text'] as String? ?? '',
      cueIds: map['cue_ids'] as String? ?? '',
      uniquenessWeight: (map['uniqueness_weight'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'media_file_id': mediaFileId,
    'media_type': mediaType.name,
    'window_size': windowSize,
    'start_ms': startMs,
    'end_ms': endMs,
    'text': text,
    'normalized_text': normalizedText,
    'cue_ids': cueIds,
    'uniqueness_weight': uniquenessWeight,
    'created_at': createdAt.millisecondsSinceEpoch,
  };
}
