/// 路径常量、匹配阈值参数、VAD 参数预设
class AppConstants {
  AppConstants._();

  // ========== 数据库 ==========
  static const String dbName = 'asr_tools.db';
  static const int dbVersion = 4;

  // ========== 文件扩展名过滤 ==========
  static const Set<String> videoExtensions = {
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.mxf',
    '.wmv',
    '.flv',
    '.webm',
  };
  static const Set<String> audioExtensions = {
    '.wav',
    '.mp3',
    '.aac',
    '.flac',
    '.ogg',
    '.wma',
    '.m4a',
  };

  // ========== 匹配算法阈值 ==========
  static const int matchWindowSize = 3;
  static const List<int> subtitleWindowSizes = [1, 3, 5, 7];
  static const double matchSimilarityThreshold = 0.85;
  static const double matchConfidenceHigh = 0.9;
  static const double matchConfidenceMedium = 0.7;
  static const double matchConfidenceLow = 0.45;
  static const int subtitleSplitMinDurationMs = 200;
  static const double subtitleBoundaryKeepRatio = 0.7;
  static const int topKCandidates = 5;
  static const double matchMaxLengthDiffRatio = 0.55;
  static const double matchPrefilterDiceThreshold = 0.18;
  static const int matchMaxHitsPerWindowPerAudio = 8;
  static const int matchMaxHitsPerAudio = 48;
  static const int anchorSearchRadiusMs = 45000;
  static const int anchorMaxCandidatesPerCue = 3;
  static const Set<String> lowValuePhrases = {
    '嗯',
    '啊',
    '哦',
    '好',
    '行',
    '操',
    '我操',
    '可以',
    '开始',
    '等一下',
  };

  // ========== VAD 参数预设 ==========
  static const VadPreset vadStandard = VadPreset(
    name: '标准模式',
    threshold: 0.5,
    minSilenceDuration: 0.25,
    minSpeechDuration: 0.25,
    maxSpeechDuration: 5.0,
  );

  static const VadPreset vadLongAudio = VadPreset(
    name: '长音频模式',
    threshold: 0.4,
    minSilenceDuration: 0.5,
    minSpeechDuration: 0.25,
    maxSpeechDuration: 30.0,
  );

  // ========== ASR 语言 ==========
  static const String defaultAsrLanguage = 'auto';
  static const String defaultAsrModel = 'fire-red-asr';
  static const String defaultAsrConcurrencyMode = 'auto';
  static const int defaultAsrMaxConcurrency = 2;
  static const int minAsrConcurrency = 1;
  static const int maxAsrConcurrency = 4;

  // ========== 超长音频分片 ==========
  static const double longChunkDurationSec = 30.0;
  static const double longChunkOverlapSec = 2.0;
}

/// VAD 参数预设
class VadPreset {
  final String name;
  final double threshold;
  final double minSilenceDuration;
  final double minSpeechDuration;
  final double maxSpeechDuration;

  const VadPreset({
    required this.name,
    required this.threshold,
    required this.minSilenceDuration,
    required this.minSpeechDuration,
    required this.maxSpeechDuration,
  });

  /// 转换为 sherpa-onnx 命令行参数
  List<String> toCliArgs() => [
    '--vad-threshold=$threshold',
    '--vad-min-silence-duration=$minSilenceDuration',
    '--vad-min-speech-duration=$minSpeechDuration',
    '--vad-max-speech-duration=$maxSpeechDuration',
  ];
}
