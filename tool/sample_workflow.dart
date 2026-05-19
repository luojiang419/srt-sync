import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:asr_tools/core/constants.dart';
import 'package:asr_tools/models/asr_project.dart';
import 'package:asr_tools/models/media_file.dart';
import 'package:asr_tools/services/asr_batch_service.dart';
import 'package:asr_tools/services/audio_align_service.dart';
import 'package:asr_tools/services/database_service.dart';
import 'package:asr_tools/services/export_service.dart';
import 'package:asr_tools/services/ffmpeg_service.dart';
import 'package:asr_tools/services/media_scan_service.dart';
import 'package:asr_tools/services/subtitle_match_service.dart';

const _videoDir = r'G:\data\260224-元数据脚本测试\1_Video\220822shipin';
const _audioDir = r'G:\data\260224-元数据脚本测试\2_Audio\220822yinpin';
const _ffmpegDir = r'G:\data\app\DIT\ffmpeg';
const _sherpaOnnxDir = r'G:\data\app\DIT\sherpa-onnx';
const _outputDir = r'G:\data\app\ASR-tools\测试合板';

Future<void> main(List<String> args) async {
  final videoLimit = _readIntOption(args, 'video-limit');
  final audioLimit = _readIntOption(args, 'audio-limit');
  final concurrencyMode =
      _readStringOption(args, 'concurrency-mode') ??
      AppConstants.defaultAsrConcurrencyMode;
  final concurrency =
      _readIntOption(args, 'concurrency') ??
      AppConstants.defaultAsrMaxConcurrency;

  FfmpegService.setFfmpegDir(_ffmpegDir);
  await DatabaseService.init();

  final now = DateTime.now();
  final projectId = const Uuid().v4();
  final project = AsrProject(
    id: projectId,
    name: 'sample-workflow-${now.millisecondsSinceEpoch}',
    videoDirectory: _videoDir,
    audioDirectory: _audioDir,
    status: ProjectStatus.imported,
    createdAt: now,
    updatedAt: now,
  );
  await DatabaseService.insertProject(project);

  stdout.writeln('1/5 导入样例素材...');
  final videoCount = await _importDirectory(
    projectId,
    _videoDir,
    MediaType.video,
    limit: videoLimit,
  );
  final audioCount = await _importDirectory(
    projectId,
    _audioDir,
    MediaType.audio,
    limit: audioLimit,
  );
  stdout.writeln('   视频: $videoCount 个  音频: $audioCount 个');

  stdout.writeln('2/5 执行 ASR...');
  stdout.writeln('   并发模式: $concurrencyMode  并发数: $concurrency');
  final mediaFiles = await DatabaseService.getMediaFiles(projectId);
  final asrResult = await AsrBatchService.batchRecognize(
    mediaFiles: mediaFiles,
    sherpaOnnxPath: _sherpaOnnxDir,
    modelId: AppConstants.defaultAsrModel,
    vadPreset: AppConstants.vadLongAudio,
    language: AppConstants.defaultAsrLanguage,
    concurrencyMode: concurrencyMode,
    maxConcurrency: concurrency,
    skipExisting: false,
    onProgress: (progress) {
      stdout.writeln(
        '   [ASR] ${progress.fileName} -> ${progress.status.label} ${(progress.progress * 100).toStringAsFixed(0)}%',
      );
    },
  );
  stdout.writeln(
    '   ASR 完成: completed=${asrResult.completedFiles}, skipped=${asrResult.skippedFiles}, failed=${asrResult.failedFiles}, cancelled=${asrResult.cancelled}, usedConcurrency=${asrResult.usedConcurrency}',
  );
  if (asrResult.failedFiles > 0 || asrResult.cancelled) {
    throw Exception('样例流程中止：ASR 未全部成功完成');
  }

  stdout.writeln('3/5 执行字幕匹配...');
  final results = await SubtitleMatchService.matchProject(
    projectId: projectId,
    onProgress: (update) {
      stdout.writeln(
        '   [MATCH] ${update.stage} ${update.current}/${update.total} ${update.currentVideo ?? ''} ${(update.progress * 100).toStringAsFixed(0)}%',
      );
    },
  );
  stdout.writeln(
    '   匹配结果: total=${results.length}, matched=${results.where((item) => item.audioFileId != null).length}',
  );
  for (final result in results) {
    final video = await DatabaseService.getMediaFileById(result.videoFileId);
    final audio = result.audioFileId == null
        ? null
        : await DatabaseService.getMediaFileById(result.audioFileId!);
    stdout.writeln(
      '   ${p.basename(video?.filePath ?? result.videoFileId)} <-> ${p.basename(audio?.filePath ?? result.audioFileId ?? 'NO_MATCH')} | confidence=${result.confidence.toStringAsFixed(3)} | sourceIn=${result.audioSourceInMs ?? -1}ms | status=${result.status.label}',
    );
  }
  if (results.where((item) => item.audioFileId != null).isEmpty) {
    throw Exception('样例流程中止：没有可用于时间线的匹配结果');
  }

  stdout.writeln('4/5 构建时间线...');
  final timeline = await AudioAlignService.buildTimeline(projectId);
  if (timeline.isEmpty) {
    throw Exception('样例流程中止：时间线为空');
  }
  for (final row in timeline) {
    stdout.writeln(
      '   ${row.videoFileName} <= ${row.audioFileName} | offset=${row.offsetMs}ms | trim=${row.audioTrimStartMs}-${row.audioTrimEndMs}',
    );
  }

  stdout.writeln('5/5 导出 XML...');
  final outputBase = p.join(
    _outputDir,
    'sample_workflow_v${videoCount}_a${audioCount}_c${asrResult.usedConcurrency}',
  );
  await ExportService.exportXmeml(timeline, '$outputBase.xml');
  await ExportService.exportFcpxml(timeline, '$outputBase.fcpxml');
  stdout.writeln('   已导出: $outputBase.xml');
  stdout.writeln('   已导出: $outputBase.fcpxml');
}

Future<int> _importDirectory(
  String projectId,
  String directoryPath,
  MediaType type, {
  int? limit,
}) async {
  final files = await MediaScanService.scanDirectory(directoryPath, type);
  final selected = limit == null ? files : files.take(limit).toList();
  final now = DateTime.now();

  for (final file in selected) {
    final durationMs = await FfmpegService.getDuration(file.path);
    await DatabaseService.insertMediaFile(
      MediaFile(
        id: const Uuid().v4(),
        projectId: projectId,
        filePath: file.path,
        type: type,
        durationMs: durationMs,
        createdAt: now,
      ),
    );
  }

  return selected.length;
}

String? _readStringOption(List<String> args, String name) {
  final inlinePrefix = '--$name=';
  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith(inlinePrefix)) {
      return arg.substring(inlinePrefix.length);
    }
    if (arg == '--$name' && i + 1 < args.length) {
      return args[i + 1];
    }
  }
  return null;
}

int? _readIntOption(List<String> args, String name) {
  final raw = _readStringOption(args, name);
  if (raw == null) return null;
  return int.tryParse(raw);
}
