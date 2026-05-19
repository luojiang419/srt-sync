/// 字幕片段模型
class SubtitleClip {
  final String id;
  final String? subtitleFileId;
  final String? mediaFileId;
  final String sourceKind;
  final int startMs;
  final int endMs;
  final int? globalStartMs;
  final int? globalEndMs;
  final int? localStartMs;
  final int? localEndMs;
  final String text;
  final String normalizedText;
  final int sortOrder;

  const SubtitleClip({
    required this.id,
    this.subtitleFileId,
    this.mediaFileId,
    this.sourceKind = 'local',
    required this.startMs,
    required this.endMs,
    this.globalStartMs,
    this.globalEndMs,
    this.localStartMs,
    this.localEndMs,
    required this.text,
    this.normalizedText = '',
    required this.sortOrder,
  });

  Duration get startDuration => Duration(milliseconds: startMs);
  Duration get endDuration => Duration(milliseconds: endMs);
  int get durationMs => endMs - startMs;

  factory SubtitleClip.fromMap(Map<String, dynamic> map) {
    return SubtitleClip(
      id: map['id'] as String,
      subtitleFileId: map['subtitle_file_id'] as String?,
      mediaFileId: map['media_file_id'] as String?,
      sourceKind: map['source_kind'] as String? ?? 'local',
      startMs: map['start_ms'] as int,
      endMs: map['end_ms'] as int,
      globalStartMs: map['global_start_ms'] as int?,
      globalEndMs: map['global_end_ms'] as int?,
      localStartMs: map['local_start_ms'] as int?,
      localEndMs: map['local_end_ms'] as int?,
      text: map['text'] as String,
      normalizedText: map['normalized_text'] as String? ?? '',
      sortOrder: map['sort_order'] as int,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'subtitle_file_id': subtitleFileId,
    'media_file_id': mediaFileId,
    'source_kind': sourceKind,
    'start_ms': startMs,
    'end_ms': endMs,
    'global_start_ms': globalStartMs,
    'global_end_ms': globalEndMs,
    'local_start_ms': localStartMs,
    'local_end_ms': localEndMs,
    'text': text,
    'normalized_text': normalizedText,
    'sort_order': sortOrder,
  };

  /// 转为 SRT 格式文本
  String toSrt(int index) {
    final start = _formatSrtTime(startMs);
    final end = _formatSrtTime(endMs);
    return '$index\n$start --> $end\n$text\n';
  }

  static String _formatSrtTime(int ms) {
    final h = (ms ~/ 3600000).toString().padLeft(2, '0');
    final m = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final millis = (ms % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$millis';
  }
}
