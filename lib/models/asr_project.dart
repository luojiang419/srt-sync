/// 工程状态枚举
enum ProjectStatus {
  created('已创建'),
  imported('已导入'),
  recognizing('识别中'),
  recognized('已识别'),
  matched('已匹配'),
  timeline('已生成时间线'),
  completed('已完成');

  final String label;
  const ProjectStatus(this.label);
}

/// ASR 工程模型
class AsrProject {
  final String id;
  final String name;
  final String? videoDirectory;
  final String? audioDirectory;
  final ProjectStatus status;
  final String asrLanguage;
  final String asrModel;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AsrProject({
    required this.id,
    required this.name,
    this.videoDirectory,
    this.audioDirectory,
    this.status = ProjectStatus.created,
    this.asrLanguage = 'auto',
    this.asrModel = 'fire-red-asr',
    required this.createdAt,
    required this.updatedAt,
  });

  AsrProject copyWith({
    String? name,
    String? videoDirectory,
    String? audioDirectory,
    ProjectStatus? status,
    String? asrLanguage,
    String? asrModel,
    DateTime? updatedAt,
  }) {
    return AsrProject(
      id: id,
      name: name ?? this.name,
      videoDirectory: videoDirectory ?? this.videoDirectory,
      audioDirectory: audioDirectory ?? this.audioDirectory,
      status: status ?? this.status,
      asrLanguage: asrLanguage ?? this.asrLanguage,
      asrModel: asrModel ?? this.asrModel,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AsrProject.fromMap(Map<String, dynamic> map) {
    return AsrProject(
      id: map['id'] as String,
      name: map['name'] as String,
      videoDirectory: map['video_directory'] as String?,
      audioDirectory: map['audio_directory'] as String?,
      status: ProjectStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ProjectStatus.created,
      ),
      asrLanguage: map['asr_language'] as String? ?? 'auto',
      asrModel: switch (map['asr_model'] as String?) {
        'paraformer-zh' => 'paraformer-zh',
        _ => 'fire-red-asr',
      },
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'video_directory': videoDirectory,
    'audio_directory': audioDirectory,
    'status': status.name,
    'asr_language': asrLanguage,
    'asr_model': asrModel,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };
}
