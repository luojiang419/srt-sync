import 'media_file.dart';

class SourceLayoutItem {
  final String id;
  final String projectId;
  final String mediaId;
  final MediaType mediaType;
  final int sortIndex;
  final int layoutStartMs;
  final int layoutEndMs;
  final int durationMs;
  final DateTime createdAt;

  const SourceLayoutItem({
    required this.id,
    required this.projectId,
    required this.mediaId,
    required this.mediaType,
    required this.sortIndex,
    required this.layoutStartMs,
    required this.layoutEndMs,
    required this.durationMs,
    required this.createdAt,
  });

  factory SourceLayoutItem.fromMap(Map<String, dynamic> map) {
    return SourceLayoutItem(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      mediaId: map['media_id'] as String,
      mediaType: map['media_type'] == 'video'
          ? MediaType.video
          : MediaType.audio,
      sortIndex: map['sort_index'] as int? ?? 0,
      layoutStartMs: map['layout_start_ms'] as int? ?? 0,
      layoutEndMs: map['layout_end_ms'] as int? ?? 0,
      durationMs: map['duration_ms'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'media_id': mediaId,
    'media_type': mediaType.name,
    'sort_index': sortIndex,
    'layout_start_ms': layoutStartMs,
    'layout_end_ms': layoutEndMs,
    'duration_ms': durationMs,
    'created_at': createdAt.millisecondsSinceEpoch,
  };
}
