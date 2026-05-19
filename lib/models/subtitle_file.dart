import 'media_file.dart';

enum SubtitleSourceType {
  aggregate('总字幕'),
  perClip('单素材字幕');

  final String label;
  const SubtitleSourceType(this.label);
}

enum SubtitleFileStatus {
  pending('待处理'),
  parsed('已解析'),
  split('已反解'),
  failed('失败');

  final String label;
  const SubtitleFileStatus(this.label);
}

class SubtitleFile {
  final String id;
  final String projectId;
  final String filePath;
  final MediaType mediaType;
  final SubtitleSourceType sourceType;
  final SubtitleFileStatus status;
  final int cueCount;
  final DateTime createdAt;

  const SubtitleFile({
    required this.id,
    required this.projectId,
    required this.filePath,
    required this.mediaType,
    this.sourceType = SubtitleSourceType.aggregate,
    this.status = SubtitleFileStatus.pending,
    this.cueCount = 0,
    required this.createdAt,
  });

  SubtitleFile copyWith({
    SubtitleSourceType? sourceType,
    SubtitleFileStatus? status,
    int? cueCount,
  }) {
    return SubtitleFile(
      id: id,
      projectId: projectId,
      filePath: filePath,
      mediaType: mediaType,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
      cueCount: cueCount ?? this.cueCount,
      createdAt: createdAt,
    );
  }

  factory SubtitleFile.fromMap(Map<String, dynamic> map) {
    return SubtitleFile(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      filePath: map['file_path'] as String,
      mediaType: map['media_type'] == 'video'
          ? MediaType.video
          : MediaType.audio,
      sourceType: SubtitleSourceType.values.firstWhere(
        (item) => item.name == map['source_type'],
        orElse: () => SubtitleSourceType.aggregate,
      ),
      status: SubtitleFileStatus.values.firstWhere(
        (item) => item.name == map['status'],
        orElse: () => SubtitleFileStatus.pending,
      ),
      cueCount: map['cue_count'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'file_path': filePath,
    'media_type': mediaType.name,
    'source_type': sourceType.name,
    'status': status.name,
    'cue_count': cueCount,
    'created_at': createdAt.millisecondsSinceEpoch,
  };
}
