import 'dart:io';

import 'package:asr_tools/core/constants.dart';
import 'package:asr_tools/models/asr_project.dart';
import 'package:asr_tools/models/media_file.dart';
import 'package:asr_tools/services/asr_batch_service.dart';
import 'package:asr_tools/services/audio_align_service.dart';
import 'package:asr_tools/services/database_service.dart';
import 'package:asr_tools/services/export_service.dart';
import 'package:asr_tools/services/ffmpeg_service.dart';
import 'package:asr_tools/services/subtitle_match_service.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const _videoPath = r'G:\data\260224-元数据脚本测试\1_Video\220822shipin\C0459.mp4';
const _audioPath =
    r'G:\data\260224-元数据脚本测试\2_Audio\220822yinpin\ZOOM0041_LR.mp3';
const _ffmpegDir = r'G:\data\app\DIT\ffmpeg';
const _sherpaDir = r'G:\data\app\DIT\sherpa-onnx';
const _outputDir = r'G:\data\app\ASR-tools\测试合板';
const _projectName = '单条样例流程修复验证-cli';

Future<void> main() async {
  FfmpegService.setFfmpegDir(_ffmpegDir);
  await DatabaseService.init();
  await _cleanupProjects();

  final project = await _createProject();
  stdout.writeln('项目已创建: ${project.id}');

  await _insertMedia(project.id, _videoPath, MediaType.video);
  await _insertMedia(project.id, _audioPath, MediaType.audio);
  stdout.writeln('已导入 1 条视频 + 1 条音频');

  final mediaFiles = await DatabaseService.getMediaFiles(project.id);
  final asrResult = await AsrBatchService.batchRecognize(
    mediaFiles: mediaFiles,
    sherpaOnnxPath: _sherpaDir,
    modelId: AppConstants.defaultAsrModel,
    vadPreset: AppConstants.vadLongAudio,
    language: AppConstants.defaultAsrLanguage,
    skipExisting: false,
  );
  stdout.writeln(
    'ASR 结果: done=${asrResult.completedFiles}, skip=${asrResult.skippedFiles}, fail=${asrResult.failedFiles}',
  );
  if (asrResult.failedFiles > 0 || asrResult.cancelled) {
    throw Exception('ASR 未成功完成');
  }

  final results = await SubtitleMatchService.matchProject(
    projectId: project.id,
  );
  stdout.writeln('匹配结果: ${results.length} 条');
  if (results.isEmpty) {
    throw Exception('未生成任何匹配结果');
  }

  final timelineList = await AudioAlignService.buildTimeline(project.id);
  if (timelineList.isEmpty) {
    throw Exception('时间线为空');
  }

  final outputBase = p.join(_outputDir, '单条样例流程修复验证');
  await ExportService.exportXmeml(timelineList, '$outputBase.xml');
  await ExportService.exportFcpxml(timelineList, '$outputBase.fcpxml');

  stdout.writeln('已导出 XML: $outputBase.xml');
  stdout.writeln('已导出 FCPXML: $outputBase.fcpxml');
}

Future<void> _cleanupProjects() async {
  final projects = await DatabaseService.getAllProjects();
  for (final project in projects.where((item) => item.name == _projectName)) {
    await DatabaseService.deleteProject(project.id);
  }
}

Future<AsrProject> _createProject() async {
  final now = DateTime.now();
  final project = AsrProject(
    id: const Uuid().v4(),
    name: _projectName,
    videoDirectory: p.dirname(_videoPath),
    audioDirectory: p.dirname(_audioPath),
    status: ProjectStatus.created,
    createdAt: now,
    updatedAt: now,
  );
  await DatabaseService.insertProject(project);
  return project;
}

Future<void> _insertMedia(
  String projectId,
  String filePath,
  MediaType type,
) async {
  final durationMs = await FfmpegService.getDuration(filePath);
  await DatabaseService.insertMediaFile(
    MediaFile(
      id: const Uuid().v4(),
      projectId: projectId,
      filePath: filePath,
      type: type,
      durationMs: durationMs,
      createdAt: DateTime.now(),
    ),
  );
}
