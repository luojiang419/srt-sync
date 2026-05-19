import 'dart:io';

import 'package:asr_tools/core/constants.dart';
import 'package:asr_tools/services/ffmpeg_service.dart';
import 'package:asr_tools/services/sherpa_onnx_service.dart';

const _audioPath =
    r'G:\data\260224-元数据脚本测试\2_Audio\220822yinpin\ZOOM0041_LR.mp3';
const _ffmpegDir = r'G:\data\app\DIT\ffmpeg';
const _sherpaDir = r'G:\data\app\DIT\sherpa-onnx';

Future<void> main() async {
  FfmpegService.setFfmpegDir(_ffmpegDir);

  final durationMs = await FfmpegService.getDuration(_audioPath);
  final wavDir = await Directory.systemTemp.createTemp('asr_compare_');
  final wavPath = '${wavDir.path}\\sample.wav';
  await FfmpegService.extractWav(_audioPath, wavPath);

  final provider = await SherpaOnnxService.autoSelectProvider(_sherpaDir);
  stdout.writeln('sample=$_audioPath');
  stdout.writeln('duration_ms=$durationMs');
  stdout.writeln('provider=$provider');

  final modelIds = ['fire-red-asr', 'paraformer-zh'];
  for (final modelId in modelIds) {
    final env = SherpaOnnxService.checkEnv(_sherpaDir, modelId);
    if (env == null || !SherpaOnnxService.isModelAvailableForId(env, modelId)) {
      stdout.writeln('MODEL|$modelId|missing');
      continue;
    }

    final watch = Stopwatch()..start();
    final segments = await SherpaOnnxService.recognize(
      wavPath: wavPath,
      env: env,
      baseDir: _sherpaDir,
      modelId: modelId,
      provider: provider,
      language: AppConstants.defaultAsrLanguage,
      vadPreset: AppConstants.vadLongAudio,
    );
    watch.stop();

    final elapsedMs = watch.elapsedMilliseconds;
    final rtf = durationMs > 0 ? elapsedMs / durationMs : 0.0;
    final text = segments.map((segment) => segment.text).join(' ').trim();
    final preview = text.length > 220 ? '${text.substring(0, 220)}...' : text;
    stdout.writeln(
      'MODEL|$modelId|elapsed_ms=$elapsedMs|rtf=${rtf.toStringAsFixed(3)}|segments=${segments.length}',
    );
    stdout.writeln('TEXT|$modelId|$preview');
  }

  await wavDir.delete(recursive: true);
}
