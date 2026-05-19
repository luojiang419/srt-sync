import 'dart:io';
import 'dart:convert';

import 'package:path/path.dart' as p;

class MediaProbeInfo {
  final int durationMs;
  final double? frameRate;
  final int? sampleRate;
  final int? channels;
  final int? width;
  final int? height;
  final bool hasEmbeddedAudio;
  final int? fileSize;
  final int? modifiedAtMs;

  const MediaProbeInfo({
    required this.durationMs,
    this.frameRate,
    this.sampleRate,
    this.channels,
    this.width,
    this.height,
    this.hasEmbeddedAudio = false,
    this.fileSize,
    this.modifiedAtMs,
  });
}

/// FFmpeg/ffprobe 服务
class FfmpegService {
  FfmpegService._();

  static String _ffmpegDir = '';

  /// 设置 FFmpeg 目录（由 app.dart 从 settings 注入）
  static void setFfmpegDir(String dir) {
    // 优先使用直接路径，若找不到可执行文件则尝试 bin 子目录
    if (File(p.join(dir, 'ffmpeg.exe')).existsSync()) {
      _ffmpegDir = dir;
    } else if (File(p.join(dir, 'bin', 'ffmpeg.exe')).existsSync()) {
      _ffmpegDir = p.join(dir, 'bin');
    } else {
      _ffmpegDir = dir;
    }
  }

  static String get _ffmpeg => p.join(_ffmpegDir, 'ffmpeg.exe');
  static String get _ffprobe => p.join(_ffmpegDir, 'ffprobe.exe');

  /// ffmpeg 可执行文件公共路径
  static String get ffmpegPath => _ffmpeg;

  /// 获取媒体文件时长（毫秒）
  static Future<int> getDuration(String filePath) async {
    final info = await probeMedia(filePath);
    return info.durationMs;
  }

  static Future<MediaProbeInfo> probeMedia(String filePath) async {
    final result = await Process.run(
      _ffprobe,
      [
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_entries',
        'format=duration,size:stream=index,codec_type,width,height,avg_frame_rate,sample_rate,channels',
        filePath,
      ],
      stdoutEncoding: const SystemEncoding(),
      stderrEncoding: const SystemEncoding(),
    );

    if (result.exitCode != 0) {
      throw Exception('ffprobe 执行失败: ${result.stderr}');
    }

    final payload = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final format = payload['format'] as Map<String, dynamic>? ?? const {};
    final streams = (payload['streams'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final durationSec = double.tryParse('${format['duration'] ?? ''}');
    if (durationSec == null) {
      throw Exception('无法解析时长: ${result.stdout}');
    }

    Map<String, dynamic>? videoStream;
    Map<String, dynamic>? audioStream;
    for (final stream in streams) {
      final codecType = '${stream['codec_type'] ?? ''}';
      if (codecType == 'video' && videoStream == null) {
        videoStream = stream;
      }
      if (codecType == 'audio' && audioStream == null) {
        audioStream = stream;
      }
    }

    return MediaProbeInfo(
      durationMs: (durationSec * 1000).round(),
      frameRate: _parseFrameRate(videoStream?['avg_frame_rate'] as String?),
      sampleRate: int.tryParse('${audioStream?['sample_rate'] ?? ''}'),
      channels: audioStream?['channels'] as int?,
      width: videoStream?['width'] as int?,
      height: videoStream?['height'] as int?,
      hasEmbeddedAudio: audioStream != null,
      fileSize: int.tryParse('${format['size'] ?? ''}'),
      modifiedAtMs: File(filePath).existsSync()
          ? File(filePath).lastModifiedSync().millisecondsSinceEpoch
          : null,
    );
  }

  /// 提取 16kHz 单声道 WAV（用于 ASR 输入）
  static Future<String> extractWav(String inputPath, String outputPath) async {
    final result = await Process.run(
      _ffmpeg,
      [
        '-i',
        inputPath,
        '-ar',
        '16000',
        '-ac',
        '1',
        '-c:a',
        'pcm_s16le',
        '-y',
        outputPath,
      ],
      stdoutEncoding: const SystemEncoding(),
      stderrEncoding: const SystemEncoding(),
    );

    if (result.exitCode != 0) {
      throw Exception('ffmpeg WAV 提取失败: ${result.stderr}');
    }
    return outputPath;
  }

  /// 裁切音频文件
  static Future<void> trimAudio({
    required String inputPath,
    required String outputPath,
    required String startTime,
    required String duration,
  }) async {
    final result = await Process.run(
      _ffmpeg,
      [
        '-i',
        inputPath,
        '-ss',
        startTime,
        '-t',
        duration,
        '-c',
        'copy',
        '-y',
        outputPath,
      ],
      stdoutEncoding: const SystemEncoding(),
      stderrEncoding: const SystemEncoding(),
    );

    if (result.exitCode != 0) {
      throw Exception('音频裁切失败: ${result.stderr}');
    }
  }

  /// 裁切音频并转为 WAV（按毫秒级精度）
  static Future<void> trimAndConvert({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
  }) async {
    final result = await Process.run(
      _ffmpeg,
      [
        '-i',
        inputPath,
        '-ss',
        _formatTimeFromMs(startMs),
        '-to',
        _formatTimeFromMs(endMs),
        '-ar',
        '48000',
        '-ac',
        '2',
        '-c:a',
        'pcm_s16le',
        '-y',
        outputPath,
      ],
      stdoutEncoding: const SystemEncoding(),
      stderrEncoding: const SystemEncoding(),
    );

    if (result.exitCode != 0) {
      throw Exception('音频裁切转换失败: ${result.stderr}');
    }
  }

  /// 毫秒转 HH:MM:SS.mmm
  static String _formatTimeFromMs(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final millis = ms % 1000;
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }

  static double? _parseFrameRate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '0/0') return null;
    if (!raw.contains('/')) {
      return double.tryParse(raw);
    }
    final parts = raw.split('/');
    if (parts.length != 2) return null;
    final numerator = double.tryParse(parts[0]);
    final denominator = double.tryParse(parts[1]);
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    return numerator / denominator;
  }
}
