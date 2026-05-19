import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core/constants.dart';
import 'app_data_service.dart';
import 'ffmpeg_service.dart';

/// 带超时的进程执行结果
class _TimedProcessResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool timedOut;

  const _TimedProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    this.timedOut = false,
  });
}

class AsrCancelledException implements Exception {
  final String message;

  const AsrCancelledException([this.message = 'ASR 识别已取消']);

  @override
  String toString() => message;
}

/// 启动进程并带超时强制终止能力
/// 如果进程在 [timeout] 内未完成，自动 kill 并返回 timedOut=true
Future<_TimedProcessResult> _runProcessWithTimeout(
  String executable,
  List<String> arguments, {
  Encoding stdoutEncoding = const SystemEncoding(),
  Encoding stderrEncoding = const SystemEncoding(),
  Duration timeout = const Duration(minutes: 10),
}) async {
  final process = await Process.start(executable, arguments);

  final stdoutBuf = <int>[];
  final stderrBuf = <int>[];

  final stdoutSub = process.stdout.listen(stdoutBuf.addAll);
  final stderrSub = process.stderr.listen(stderrBuf.addAll);

  bool completed = false;

  try {
    final exitCode = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        completed = false;
        print('[Process] 超时终止: $executable (>${timeout.inSeconds}s)');
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    completed = true;

    await stdoutSub.cancel();
    await stderrSub.cancel();

    return _TimedProcessResult(
      exitCode: exitCode,
      stdout: stdoutEncoding.decode(stdoutBuf),
      stderr: stderrEncoding.decode(stderrBuf),
    );
  } catch (e) {
    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (!completed) {
      return _TimedProcessResult(
        exitCode: -1,
        stdout: stdoutEncoding.decode(stdoutBuf),
        stderr: stderrEncoding.decode(stderrBuf),
        timedOut: true,
      );
    }
    rethrow;
  }
}

/// ASR 识别段落
class AsrSegment {
  final double startTime; // 秒
  final double endTime; // 秒
  final String text;

  const AsrSegment({
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  @override
  String toString() => '[$startTime - $endTime] $text';
}

/// GPU 检测结果
enum GpuStatus {
  unknown('未检测'),
  gpuAvailable('GPU 加速'),
  cpuOnly('CPU 模式'),
  notConfigured('未配置');

  final String label;
  const GpuStatus(this.label);
}

/// 可用 ASR 模型类型
enum AsrModelType {
  fireRedAsr('fire-red-asr', 'FireRed-ASR'),
  paraformerZh('paraformer-zh', 'Paraformer-zh');

  final String id;
  final String label;
  const AsrModelType(this.id, this.label);

  static AsrModelType fromId(String id) => AsrModelType.values.firstWhere(
    (m) => m.id == id,
    orElse: () => AsrModelType.fireRedAsr,
  );
}

/// FireRed-ASR 模型配置
class FireRedAsrConfig {
  final String encoderPath;
  final String decoderPath;
  final String tokensPath;

  const FireRedAsrConfig({
    required this.encoderPath,
    required this.decoderPath,
    required this.tokensPath,
  });
}

/// Paraformer-zh 模型配置
class ParaformerZhConfig {
  final String modelPath;
  final String tokensPath;

  const ParaformerZhConfig({required this.modelPath, required this.tokensPath});
}

/// sherpa-onnx 引擎服务
///
/// 支持 FireRed-ASR 和 Paraformer-zh
/// 处理流程：
/// 1. ffmpeg silencedetect 获取语音段时间戳
/// 2. 对每段提取 WAV
/// 3. 根据选择的模型调用 sherpa-onnx-offline.exe 识别
/// 4. 合并时间戳+文本返回
class SherpaOnnxService {
  SherpaOnnxService._();

  // ==================== 路径查找 ====================

  static String? findExecutable(String baseDir) {
    if (baseDir.isEmpty) return null;
    final candidates = Platform.isWindows
        ? [
            '$baseDir\\sherpa-onnx-offline.exe',
            '$baseDir\\bin\\sherpa-onnx-offline.exe',
          ]
        : ['$baseDir/sherpa-onnx-offline', '$baseDir/bin/sherpa-onnx-offline'];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  static String? findVadModel(String baseDir) {
    final candidates = Platform.isWindows
        ? ['$baseDir\\silero_vad.onnx', '$baseDir\\models\\silero_vad.onnx']
        : ['$baseDir/silero_vad.onnx', '$baseDir/models/silero_vad.onnx'];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  /// 查找 FireRed-ASR 模型
  static FireRedAsrConfig? findFireRedAsrModel(String baseDir) {
    final modelDirs = Platform.isWindows
        ? [
            '$baseDir\\sherpa-onnx-fire-red-asr-large-zh_en-2025-02-16',
            '$baseDir\\models\\sherpa-onnx-fire-red-asr-large-zh_en-2025-02-16',
          ]
        : [
            '$baseDir/sherpa-onnx-fire-red-asr-large-zh_en-2025-02-16',
            '$baseDir/models/sherpa-onnx-fire-red-asr-large-zh_en-2025-02-16',
          ];
    for (final dir in modelDirs) {
      if (!Directory(dir).existsSync()) continue;
      final encoder = p.join(dir, 'encoder.int8.onnx');
      final decoder = p.join(dir, 'decoder.int8.onnx');
      final tokens = p.join(dir, 'tokens.txt');
      if (File(encoder).existsSync() &&
          File(decoder).existsSync() &&
          File(tokens).existsSync()) {
        return FireRedAsrConfig(
          encoderPath: encoder,
          decoderPath: decoder,
          tokensPath: tokens,
        );
      }
    }
    return null;
  }

  /// 查找 Paraformer-zh 模型
  static ParaformerZhConfig? findParaformerZhModel(String baseDir) {
    final modelDirs = Platform.isWindows
        ? [
            '$baseDir\\sherpa-onnx-paraformer-zh-2024-03-09',
            '$baseDir\\models\\sherpa-onnx-paraformer-zh-2024-03-09',
            '$baseDir\\sherpa-onnx-paraformer-zh-2023-09-14',
            '$baseDir\\models\\sherpa-onnx-paraformer-zh-2023-09-14',
            '$baseDir\\sherpa-onnx-paraformer-zh-small-2024-03-09',
            '$baseDir\\models\\sherpa-onnx-paraformer-zh-small-2024-03-09',
            '$baseDir\\paraformer-zh',
            '$baseDir\\models\\paraformer-zh',
          ]
        : [
            '$baseDir/sherpa-onnx-paraformer-zh-2024-03-09',
            '$baseDir/models/sherpa-onnx-paraformer-zh-2024-03-09',
            '$baseDir/sherpa-onnx-paraformer-zh-2023-09-14',
            '$baseDir/models/sherpa-onnx-paraformer-zh-2023-09-14',
            '$baseDir/sherpa-onnx-paraformer-zh-small-2024-03-09',
            '$baseDir/models/sherpa-onnx-paraformer-zh-small-2024-03-09',
            '$baseDir/paraformer-zh',
            '$baseDir/models/paraformer-zh',
          ];

    for (final dir in modelDirs) {
      if (!Directory(dir).existsSync()) continue;
      final tokens = p.join(dir, 'tokens.txt');
      final modelCandidates = [
        p.join(dir, 'model.int8.onnx'),
        p.join(dir, 'model.onnx'),
      ];
      for (final model in modelCandidates) {
        if (File(model).existsSync() && File(tokens).existsSync()) {
          return ParaformerZhConfig(modelPath: model, tokensPath: tokens);
        }
      }
    }

    return null;
  }

  // ==================== GPU 自动检测（4级验证）====================

  static bool? _hasNvidiaGpu;
  static bool? _cudaAvailable;

  static Future<bool> hasNvidiaGpu() async {
    if (_hasNvidiaGpu != null) return _hasNvidiaGpu!;
    try {
      final result = await Process.run('nvidia-smi', [
        '--query-gpu=name',
        '--format=csv,noheader',
      ]);
      _hasNvidiaGpu = result.exitCode == 0;
      if (_hasNvidiaGpu!) {
        final name = (result.stdout as String?)?.trim() ?? 'Unknown';
        print('[SherpaOnnx] 检测到 NVIDIA GPU: $name');
      }
    } catch (_) {
      _hasNvidiaGpu = false;
    }
    return _hasNvidiaGpu!;
  }

  static Future<bool> detectCudaSupport(String baseDir) async {
    if (_cudaAvailable != null) return _cudaAvailable!;

    if (!await hasNvidiaGpu()) {
      print('[SherpaOnnx] 未检测到 NVIDIA GPU，CUDA 不可用');
      _cudaAvailable = false;
      return false;
    }

    final exePath = findExecutable(baseDir);
    if (exePath == null) {
      _cudaAvailable = false;
      return false;
    }
    final binDir = p.dirname(exePath);

    final cudartDll = File(p.join(binDir, 'cudart64_12.dll'));
    final cudaEpDll = File(p.join(binDir, 'onnxruntime_providers_cuda.dll'));
    if (!cudartDll.existsSync() || !cudaEpDll.existsSync()) {
      print('[SherpaOnnx] CUDA DLL 缺失');
      _cudaAvailable = false;
      return false;
    }

    final cudnnDll = File(p.join(binDir, 'cudnn64_9.dll'));
    final cudnnOpsDll = File(p.join(binDir, 'cudnn_ops64_9.dll'));
    if (!cudnnDll.existsSync() || !cudnnOpsDll.existsSync()) {
      print('[SherpaOnnx] cuDNN DLL 缺失');
      _cudaAvailable = false;
      return false;
    }

    final cufftDll = File(p.join(binDir, 'cufft64_11.dll'));
    if (!cufftDll.existsSync()) {
      print('[SherpaOnnx] cufft64_11.dll 缺失');
      _cudaAvailable = false;
      return false;
    }

    print('[SherpaOnnx] CUDA 环境检测通过，GPU 加速可用');
    _cudaAvailable = true;
    return true;
  }

  static Future<String> autoSelectProvider(String baseDir) async {
    final cudaOk = await detectCudaSupport(baseDir);
    if (cudaOk) {
      print('[SherpaOnnx] 使用 GPU (CUDA) 加速');
      return 'cuda';
    }
    print('[SherpaOnnx] 使用 CPU 模式');
    return 'cpu';
  }

  static void resetGpuCache() {
    _cudaAvailable = null;
  }

  static Future<GpuStatus> getGpuStatus(String baseDir) async {
    if (baseDir.isEmpty) return GpuStatus.notConfigured;

    final env = checkEnv(baseDir, AppConstants.defaultAsrModel);
    if (env == null) return GpuStatus.notConfigured;

    final cudaOk = await detectCudaSupport(baseDir);
    return cudaOk ? GpuStatus.gpuAvailable : GpuStatus.cpuOnly;
  }

  // ==================== 环境验证 ====================

  static SherpaOnnxEnv? checkEnv(String baseDir, String modelId) {
    final exe = findExecutable(baseDir);
    if (exe == null) return null;

    final firered = findFireRedAsrModel(baseDir);
    final paraformer = findParaformerZhModel(baseDir);

    if (firered == null && paraformer == null) return null;

    return SherpaOnnxEnv(
      exePath: exe,
      fireRedAsrConfig: firered,
      paraformerZhConfig: paraformer,
    );
  }

  /// 获取所有可用模型列表
  static List<AsrModelType> getAvailableModels(SherpaOnnxEnv env) {
    final models = <AsrModelType>[];
    if (env.fireRedAsrConfig != null) models.add(AsrModelType.fireRedAsr);
    if (env.paraformerZhConfig != null) models.add(AsrModelType.paraformerZh);
    return models;
  }

  // ==================== 识别方法 ====================

  /// 对单个 WAV 文件执行 ASR 识别
  /// [onSegmentProgress] 返回 0.0~1.0 表示分段识别进度
  static Future<List<AsrSegment>> recognize({
    required String wavPath,
    required SherpaOnnxEnv env,
    required String baseDir,
    required String modelId,
    VadPreset vadPreset = AppConstants.vadLongAudio,
    String provider = 'auto',
    String language = 'auto',
    bool useItn = true,
    int numThreads = 8,
    void Function(double progress)? onSegmentProgress,
    bool Function()? onCancel,
  }) async {
    if (!File(wavPath).existsSync()) {
      throw Exception('WAV 文件不存在: $wavPath');
    }
    if (onCancel != null && onCancel()) {
      throw const AsrCancelledException();
    }

    String effectiveProvider = provider;
    if (provider == 'auto') {
      effectiveProvider = await autoSelectProvider(baseDir);
    }
    if (onCancel != null && onCancel()) {
      throw const AsrCancelledException();
    }

    try {
      return await _recognizeImpl(
        wavPath: wavPath,
        env: env,
        baseDir: baseDir,
        modelId: modelId,
        vadPreset: vadPreset,
        provider: effectiveProvider,
        language: language,
        useItn: useItn,
        numThreads: numThreads,
        onSegmentProgress: onSegmentProgress,
        onCancel: onCancel,
      );
    } catch (e) {
      if (e is AsrCancelledException) {
        rethrow;
      }
      if (effectiveProvider == 'cuda') {
        print('[SherpaOnnx] CUDA 推理失败，自动降级到 CPU: $e');
        _cudaAvailable = false;
        return await _recognizeImpl(
          wavPath: wavPath,
          env: env,
          baseDir: baseDir,
          modelId: modelId,
          vadPreset: vadPreset,
          provider: 'cpu',
          language: language,
          useItn: useItn,
          numThreads: numThreads,
          onSegmentProgress: onSegmentProgress,
          onCancel: onCancel,
        );
      }
      rethrow;
    }
  }

  /// 核心识别实现：ffmpeg silencedetect → 分段提取 → 模型识别
  static Future<List<AsrSegment>> _recognizeImpl({
    required String wavPath,
    required SherpaOnnxEnv env,
    required String baseDir,
    required String modelId,
    required VadPreset vadPreset,
    required String provider,
    required String language,
    required bool useItn,
    required int numThreads,
    void Function(double progress)? onSegmentProgress,
    bool Function()? onCancel,
  }) async {
    final modelType = AsrModelType.fromId(modelId);

    // 验证模型可用
    if (!_isModelAvailable(env, modelType)) {
      throw Exception('模型 ${modelType.label} 未安装');
    }

    // Step 1: 用 ffmpeg silencedetect 获取语音段时间戳
    final speechSegments = await _detectSpeechSegments(
      wavPath: wavPath,
      minSilenceMs: (vadPreset.minSilenceDuration * 1000).round(),
    );
    if (onCancel != null && onCancel()) {
      throw const AsrCancelledException();
    }

    if (speechSegments.isEmpty) {
      // 没有检测到静默分段，整段识别
      final text = await _recognizeSegment(
        wavPath: wavPath,
        exePath: env.exePath,
        env: env,
        modelType: modelType,
        provider: provider,
        language: language,
        useItn: useItn,
        numThreads: numThreads,
      );
      if (text.isEmpty) return [];
      return [AsrSegment(startTime: 0.0, endTime: 0.0, text: text)];
    }

    // Step 2: 对每段用 ffmpeg 截取 WAV 并识别
    final results = <AsrSegment>[];
    final tmpDir = await AppDataService.createTempDirectory('asr_seg_');

    // 预计算总子段数（用于进度计算）
    int totalSubSegs = 0;
    for (final seg in speechSegments) {
      final d = seg.$2 - seg.$1;
      if (d < 0.3) continue;
      if (d > 60.0) {
        totalSubSegs += ((d - 0.1) / 58.0).ceil();
      } else {
        totalSubSegs++;
      }
    }

    print(
      '[SherpaOnnx] 共 ${speechSegments.length} 个语音段, $totalSubSegs 个子段，开始逐段识别...',
    );
    onSegmentProgress?.call(0.0);

    try {
      int segIndex = 0;
      for (final seg in speechSegments) {
        if (onCancel != null && onCancel()) {
          throw const AsrCancelledException();
        }
        segIndex++;
        final segDuration = seg.$2 - seg.$1;
        if (segDuration < 0.3) continue; // 跳过极短段

        if (segDuration > 60.0) {
          // 超长段：按 58 秒步进、60 秒窗口切分
          for (double t = seg.$1; t < seg.$2 - 0.1; t += 58.0) {
            if (onCancel != null && onCancel()) {
              throw const AsrCancelledException();
            }
            final end = (t + 60.0).clamp(0.0, seg.$2).toDouble();
            print(
              '[SherpaOnnx] 段 $segIndex [${t.toStringAsFixed(1)}s - ${end.toStringAsFixed(1)}s] (${results.length + 1}/$totalSubSegs)',
            );
            final tmpWav = File(
              p.join(tmpDir.path, 'seg_${results.length}.wav'),
            );
            await _extractWavSegment(wavPath, tmpWav.path, t, end);

            final text = await _recognizeSegment(
              wavPath: tmpWav.path,
              exePath: env.exePath,
              env: env,
              modelType: modelType,
              provider: provider,
              language: language,
              useItn: useItn,
              numThreads: numThreads,
            );
            if (text.isNotEmpty) {
              results.add(AsrSegment(startTime: t, endTime: end, text: text));
            }
            onSegmentProgress?.call(results.length / totalSubSegs);
          }
        } else {
          if (onCancel != null && onCancel()) {
            throw const AsrCancelledException();
          }
          print(
            '[SherpaOnnx] 段 $segIndex/${speechSegments.length} [${seg.$1.toStringAsFixed(1)}s - ${seg.$2.toStringAsFixed(1)}s] (${results.length + 1}/$totalSubSegs)',
          );
          final tmpWav = File(p.join(tmpDir.path, 'seg_${results.length}.wav'));
          await _extractWavSegment(wavPath, tmpWav.path, seg.$1, seg.$2);

          final text = await _recognizeSegment(
            wavPath: tmpWav.path,
            exePath: env.exePath,
            env: env,
            modelType: modelType,
            provider: provider,
            language: language,
            useItn: useItn,
            numThreads: numThreads,
          );
          if (text.isNotEmpty) {
            results.add(
              AsrSegment(startTime: seg.$1, endTime: seg.$2, text: text),
            );
          }
          onSegmentProgress?.call(results.length / totalSubSegs);
        }
      }
    } finally {
      try {
        await tmpDir.delete(recursive: true);
      } catch (_) {}
    }

    onSegmentProgress?.call(1.0);
    print('[SherpaOnnx] ${modelType.label} 识别完成: ${results.length} 条');
    return results;
  }

  /// 用 ffmpeg 截取 WAV 的指定时间段
  static Future<void> _extractWavSegment(
    String inputWav,
    String outputWav,
    double startSec,
    double endSec,
  ) async {
    final result = await _runProcessWithTimeout(FfmpegService.ffmpegPath, [
      '-i',
      inputWav,
      '-ss',
      startSec.toStringAsFixed(3),
      '-to',
      endSec.toStringAsFixed(3),
      '-c:a',
      'pcm_s16le',
      '-y',
      outputWav,
    ], timeout: const Duration(minutes: 2));

    if (result.timedOut) {
      throw Exception('ffmpeg 截取音频段超时（2分钟）');
    }
  }

  /// 检查模型是否可用
  static bool _isModelAvailable(SherpaOnnxEnv env, AsrModelType type) {
    switch (type) {
      case AsrModelType.fireRedAsr:
        return env.fireRedAsrConfig != null;
      case AsrModelType.paraformerZh:
        return env.paraformerZhConfig != null;
    }
  }

  static bool isModelAvailableForId(SherpaOnnxEnv env, String modelId) {
    return _isModelAvailable(env, AsrModelType.fromId(modelId));
  }

  /// 用 ffmpeg silencedetect 检测语音段（返回 (startSec, endSec) 列表）
  static Future<List<(double, double)>> _detectSpeechSegments({
    required String wavPath,
    required int minSilenceMs,
  }) async {
    final result = await _runProcessWithTimeout(FfmpegService.ffmpegPath, [
      '-i',
      wavPath,
      '-af',
      'silencedetect=noise=-30dB:d=${minSilenceMs}ms',
      '-f',
      'null',
      '-',
    ], timeout: const Duration(minutes: 3));

    if (result.timedOut) {
      throw Exception('silencedetect 超时（3分钟），音频文件可能过大');
    }

    final stderr = result.stderr;

    // 解析 silencedetect 输出
    // silence_end: xxx | silence_start: xxx
    final silenceEndRegex = RegExp(r'silence_end:\s*([\d.]+)');
    final silenceStartRegex = RegExp(r'silence_start:\s*([\d.]+)');

    final silenceEnds = silenceEndRegex
        .allMatches(stderr)
        .map((m) => double.parse(m.group(1)!))
        .toList();
    final silenceStarts = silenceStartRegex
        .allMatches(stderr)
        .map((m) => double.parse(m.group(1)!))
        .toList();

    // 获取音频总时长
    final durationRegex = RegExp(r'Duration:\s*([\d:.]+)');
    final durationMatch = durationRegex.firstMatch(stderr);
    double totalDuration = 0;
    if (durationMatch != null) {
      final parts = durationMatch.group(1)!.split(':');
      totalDuration =
          double.parse(parts[0]) * 3600 +
          double.parse(parts[1]) * 60 +
          double.parse(parts[2]);
    }

    if (silenceEnds.isEmpty && silenceStarts.isEmpty) {
      // 没有检测到静默 = 整段都是语音
      return totalDuration > 0 ? [(0.0, totalDuration)] : <(double, double)>[];
    }

    // 处理音频开头就是静默的情况
    // silencedetect 输出：silence_start < silence_end 严格配对
    // 如果第一个事件是 silence_end（音频以静默开头），先跳过前导静默
    var effectiveSilenceEnds = silenceEnds;
    var effectiveSilenceStarts = silenceStarts;
    double startPos = 0.0;

    if (silenceEnds.isNotEmpty &&
        silenceStarts.isNotEmpty &&
        silenceEnds[0] < silenceStarts[0]) {
      // 音频以静默开头，第一个 silence_end 在第一个 silence_start 之前
      startPos = silenceEnds[0];
      effectiveSilenceEnds = silenceEnds.sublist(1);
    } else if (silenceEnds.isNotEmpty && silenceStarts.isEmpty) {
      // 只有 silence_end 没有任何 silence_start，说明整段都是静默后的语音
      startPos = silenceEnds[0];
      effectiveSilenceEnds = [];
    }

    final segments = <(double, double)>[];
    double pos = startPos;

    // 遍历每个静默段的开始，语音段在两次静默之间
    for (int i = 0; i < effectiveSilenceStarts.length; i++) {
      // 添加从当前位置到静默开始的语音段
      if (effectiveSilenceStarts[i] > pos + 0.001) {
        segments.add((pos, effectiveSilenceStarts[i]));
      }
      // 跳过静默段：更新 pos 到静默结束
      if (i < effectiveSilenceEnds.length) {
        pos = effectiveSilenceEnds[i];
      } else {
        // 尾部静默，后面没有更多语音
        pos = totalDuration;
      }
    }

    // 添加最后一个静默段之后的尾部语音
    if (pos < totalDuration - 0.001) {
      segments.add((pos, totalDuration));
    }

    return segments;
  }

  /// 根据模型类型调用 sherpa-onnx-offline 识别单个片段
  static Future<String> _recognizeSegment({
    required String wavPath,
    required String exePath,
    required SherpaOnnxEnv env,
    required AsrModelType modelType,
    required String provider,
    required String language,
    required bool useItn,
    required int numThreads,
  }) async {
    switch (modelType) {
      case AsrModelType.fireRedAsr:
        return _recognizeWithFireRedAsr(
          wavPath: wavPath,
          exePath: exePath,
          config: env.fireRedAsrConfig!,
          provider: provider,
          numThreads: numThreads,
        );
      case AsrModelType.paraformerZh:
        return _recognizeWithParaformerZh(
          wavPath: wavPath,
          exePath: exePath,
          config: env.paraformerZhConfig!,
          provider: provider,
          numThreads: numThreads,
        );
    }
  }

  /// FireRed-ASR 识别
  static Future<String> _recognizeWithFireRedAsr({
    required String wavPath,
    required String exePath,
    required FireRedAsrConfig config,
    required String provider,
    required int numThreads,
  }) async {
    final args = <String>[
      '--fire-red-asr-encoder=${config.encoderPath}',
      '--fire-red-asr-decoder=${config.decoderPath}',
      '--tokens=${config.tokensPath}',
      '--model-type=fire_red_asr',
      '--provider=$provider',
      '--num-threads=$numThreads',
      wavPath,
    ];

    print('[FireRed-ASR] 运行: $exePath ${args.join(" ")}');

    final result = await _runProcessWithTimeout(
      exePath,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      timeout: const Duration(minutes: 10),
    );

    if (result.timedOut) {
      throw Exception('FireRed-ASR 推理超时（10分钟），可能是CUDA问题');
    }

    if (result.exitCode != 0) {
      throw Exception(
        'FireRed-ASR 识别失败 (退出码${result.exitCode}): ${result.stderr}',
      );
    }

    return _parseJsonTextOutput(result.stdout);
  }

  /// Paraformer-zh 识别
  static Future<String> _recognizeWithParaformerZh({
    required String wavPath,
    required String exePath,
    required ParaformerZhConfig config,
    required String provider,
    required int numThreads,
  }) async {
    final args = <String>[
      '--paraformer=${config.modelPath}',
      '--tokens=${config.tokensPath}',
      '--model-type=paraformer',
      '--provider=$provider',
      '--num-threads=$numThreads',
      wavPath,
    ];

    print('[Paraformer-zh] 运行: $exePath ${args.join(" ")}');

    final result = await _runProcessWithTimeout(
      exePath,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
      timeout: const Duration(minutes: 10),
    );

    if (result.timedOut) {
      throw Exception('Paraformer-zh 推理超时（10分钟），可能是 CUDA 问题');
    }

    if (result.exitCode != 0) {
      throw Exception(
        'Paraformer-zh 识别失败 (退出码${result.exitCode}): ${result.stderr}',
      );
    }

    return _parseJsonTextOutput(result.stdout);
  }

  /// 解析 sherpa-onnx-offline 输出中的 text 字段
  static String _parseJsonTextOutput(String output) {
    final lines = output.split('\n');
    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line.startsWith('{')) {
        try {
          final json = jsonDecode(line) as Map<String, dynamic>;
          return (json['text'] as String?) ?? '';
        } catch (_) {}
      }
    }
    return '';
  }
}

/// sherpa-onnx 环境信息
class SherpaOnnxEnv {
  final String exePath;
  final FireRedAsrConfig? fireRedAsrConfig;
  final ParaformerZhConfig? paraformerZhConfig;

  const SherpaOnnxEnv({
    required this.exePath,
    this.fireRedAsrConfig,
    this.paraformerZhConfig,
  });

  bool get hasFireRedAsr => fireRedAsrConfig != null;
  bool get hasParaformerZh => paraformerZhConfig != null;

  @override
  String toString() =>
      'SherpaOnnxEnv(exe=$exePath, firered=${hasFireRedAsr}, paraformer=${hasParaformerZh})';
}
