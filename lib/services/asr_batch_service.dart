import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/media_file.dart';
import '../models/subtitle_clip.dart';
import 'database_service.dart';
import 'ffmpeg_service.dart';
import 'sherpa_onnx_service.dart';

class AsrFileProgress {
  final String mediaFileId;
  final String fileName;
  final AsrFileStatus status;
  final double progress;
  final String? errorMessage;
  final List<AsrSegment> segments;

  const AsrFileProgress({
    required this.mediaFileId,
    required this.fileName,
    this.status = AsrFileStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
    this.segments = const [],
  });

  AsrFileProgress copyWith({
    AsrFileStatus? status,
    double? progress,
    String? errorMessage,
    List<AsrSegment>? segments,
  }) {
    return AsrFileProgress(
      mediaFileId: mediaFileId,
      fileName: fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      segments: segments ?? this.segments,
    );
  }
}

enum AsrFileStatus {
  pending('待识别'),
  queued('排队中'),
  extracting('提取音频'),
  recognizing('识别中'),
  saving('保存中'),
  completed('已完成'),
  skipped('已跳过'),
  cancelled('已取消'),
  failed('失败');

  final String label;
  const AsrFileStatus(this.label);
}

typedef AsrProgressCallback = void Function(AsrFileProgress fileProgress);

class AsrBatchService {
  AsrBatchService._();

  static const _uuid = Uuid();
  static Future<void> _subtitleWriteQueue = Future.value();

  static Future<AsrBatchResult> batchRecognize({
    required List<MediaFile> mediaFiles,
    required String sherpaOnnxPath,
    String modelId = AppConstants.defaultAsrModel,
    VadPreset vadPreset = AppConstants.vadLongAudio,
    String language = AppConstants.defaultAsrLanguage,
    String concurrencyMode = AppConstants.defaultAsrConcurrencyMode,
    int maxConcurrency = AppConstants.defaultAsrMaxConcurrency,
    bool skipExisting = true,
    AsrProgressCallback? onProgress,
    bool Function()? onCancel,
  }) async {
    final env = SherpaOnnxService.checkEnv(sherpaOnnxPath, modelId);
    if (env == null) {
      return AsrBatchResult(
        totalFiles: mediaFiles.length,
        completedFiles: 0,
        failedFiles: 0,
        skippedFiles: 0,
        usedConcurrency: 0,
        error: 'sherpa-onnx 环境未就绪，请检查路径和模型配置',
      );
    }

    int completed = 0;
    int failed = 0;
    int skipped = 0;
    bool cancelled = false;
    int nextIndex = 0;
    final errors = <String>[];

    final effectiveConcurrency = await resolveConcurrency(
      sherpaOnnxPath: sherpaOnnxPath,
      concurrencyMode: concurrencyMode,
      maxConcurrency: maxConcurrency,
      totalFiles: mediaFiles.length,
    );

    final wavDir = await Directory.systemTemp.createTemp('asr_wav_');

    try {
      bool isCancelled() {
        if (cancelled) return true;
        if (onCancel == null) return false;
        final requested = onCancel();
        if (requested) {
          cancelled = true;
        }
        return cancelled;
      }

      MediaFile? takeNextFile() {
        if (isCancelled() || nextIndex >= mediaFiles.length) {
          return null;
        }
        final file = mediaFiles[nextIndex];
        nextIndex++;
        return file;
      }

      Future<void> processFile(MediaFile file) async {
        final fileName = p.basename(file.filePath);

        try {
          final existingClips = await DatabaseService.getSubtitleClips(file.id);
          if (skipExisting && existingClips.isNotEmpty) {
            skipped++;
            if (file.subtitleStatus != SubtitleStatus.completed) {
              await DatabaseService.updateMediaFile(
                file.copyWith(subtitleStatus: SubtitleStatus.completed),
              );
            }
            onProgress?.call(
              AsrFileProgress(
                mediaFileId: file.id,
                fileName: fileName,
                status: AsrFileStatus.skipped,
                progress: 1.0,
              ),
            );
            return;
          }

          await DatabaseService.updateMediaFile(
            file.copyWith(subtitleStatus: SubtitleStatus.processing),
          );

          final segments = await _recognizeSingleFile(
            file: file,
            env: env,
            sherpaOnnxPath: sherpaOnnxPath,
            modelId: modelId,
            vadPreset: vadPreset,
            language: language,
            wavDir: wavDir.path,
            onProgress: onProgress,
            onCancel: isCancelled,
          );

          onProgress?.call(
            AsrFileProgress(
              mediaFileId: file.id,
              fileName: fileName,
              status: AsrFileStatus.saving,
              progress: 0.9,
            ),
          );

          await _saveSegmentsToDb(file.id, segments);

          await DatabaseService.updateMediaFile(
            file.copyWith(subtitleStatus: SubtitleStatus.completed),
          );

          completed++;
          onProgress?.call(
            AsrFileProgress(
              mediaFileId: file.id,
              fileName: fileName,
              status: AsrFileStatus.completed,
              progress: 1.0,
              segments: segments,
            ),
          );
        } on AsrCancelledException catch (e) {
          cancelled = true;
          await DatabaseService.updateMediaFile(
            file.copyWith(subtitleStatus: SubtitleStatus.pending),
          );
          onProgress?.call(
            AsrFileProgress(
              mediaFileId: file.id,
              fileName: fileName,
              status: AsrFileStatus.cancelled,
              progress: 0.0,
              errorMessage: e.toString(),
            ),
          );
        } catch (e) {
          failed++;
          errors.add('$fileName: $e');

          await DatabaseService.updateMediaFile(
            file.copyWith(subtitleStatus: SubtitleStatus.failed),
          );

          onProgress?.call(
            AsrFileProgress(
              mediaFileId: file.id,
              fileName: fileName,
              status: AsrFileStatus.failed,
              progress: 0.0,
              errorMessage: e.toString(),
            ),
          );
        } finally {
          final fileTempDir = Directory(p.join(wavDir.path, file.id));
          if (fileTempDir.existsSync()) {
            await fileTempDir.delete(recursive: true);
          }
        }
      }

      Future<void> runWorker() async {
        while (true) {
          final file = takeNextFile();
          if (file == null) {
            return;
          }
          await processFile(file);
        }
      }

      await Future.wait([
        for (int i = 0; i < effectiveConcurrency; i++) runWorker(),
      ]);
    } finally {
      if (wavDir.existsSync()) {
        await wavDir.delete(recursive: true);
      }
    }

    return AsrBatchResult(
      totalFiles: mediaFiles.length,
      completedFiles: completed,
      failedFiles: failed,
      skippedFiles: skipped,
      usedConcurrency: effectiveConcurrency,
      cancelled: cancelled,
      errors: errors,
    );
  }

  static Future<int> resolveConcurrency({
    required String sherpaOnnxPath,
    required String concurrencyMode,
    required int maxConcurrency,
    required int totalFiles,
  }) async {
    if (totalFiles <= 0) return 0;

    final manual = maxConcurrency.clamp(
      AppConstants.minAsrConcurrency,
      AppConstants.maxAsrConcurrency,
    );

    if (concurrencyMode == 'manual') {
      return manual.clamp(AppConstants.minAsrConcurrency, totalFiles);
    }

    final cudaAvailable = await SherpaOnnxService.detectCudaSupport(
      sherpaOnnxPath,
    );
    final auto = cudaAvailable ? 1 : AppConstants.defaultAsrMaxConcurrency;
    return auto.clamp(AppConstants.minAsrConcurrency, totalFiles);
  }

  static Future<List<AsrSegment>> _recognizeSingleFile({
    required MediaFile file,
    required SherpaOnnxEnv env,
    required String sherpaOnnxPath,
    required String modelId,
    required VadPreset vadPreset,
    required String language,
    required String wavDir,
    AsrProgressCallback? onProgress,
    bool Function()? onCancel,
  }) async {
    final fileName = p.basename(file.filePath);
    final fileTempDir = Directory(p.join(wavDir, file.id));
    if (!fileTempDir.existsSync()) {
      await fileTempDir.create(recursive: true);
    }
    final wavPath = p.join(fileTempDir.path, 'input.wav');

    onProgress?.call(
      AsrFileProgress(
        mediaFileId: file.id,
        fileName: fileName,
        status: AsrFileStatus.extracting,
        progress: 0.05,
      ),
    );

    await FfmpegService.extractWav(file.filePath, wavPath);
    if (onCancel != null && onCancel()) {
      throw const AsrCancelledException();
    }

    onProgress?.call(
      AsrFileProgress(
        mediaFileId: file.id,
        fileName: fileName,
        status: AsrFileStatus.recognizing,
        progress: 0.15,
      ),
    );

    return SherpaOnnxService.recognize(
      wavPath: wavPath,
      env: env,
      baseDir: sherpaOnnxPath,
      modelId: modelId,
      vadPreset: vadPreset,
      language: language,
      onCancel: onCancel,
      onSegmentProgress: (segProgress) {
        final fileProgress = 0.15 + segProgress * 0.7;
        onProgress?.call(
          AsrFileProgress(
            mediaFileId: file.id,
            fileName: fileName,
            status: AsrFileStatus.recognizing,
            progress: fileProgress,
          ),
        );
      },
    );
  }

  static Future<void> _saveSegmentsToDb(
    String mediaFileId,
    List<AsrSegment> segments,
  ) async {
    await _runSerializedSubtitleWrite(() async {
      await DatabaseService.deleteSubtitleClips(mediaFileId);

      final clips = <SubtitleClip>[];
      for (int i = 0; i < segments.length; i++) {
        final seg = segments[i];
        clips.add(
          SubtitleClip(
            id: _uuid.v4(),
            mediaFileId: mediaFileId,
            startMs: (seg.startTime * 1000).round(),
            endMs: (seg.endTime * 1000).round(),
            text: seg.text,
            sortOrder: i,
          ),
        );
      }

      if (clips.isNotEmpty) {
        await DatabaseService.insertSubtitleClips(clips);
      }
    });
  }

  static Future<T> _runSerializedSubtitleWrite<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    _subtitleWriteQueue = _subtitleWriteQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  static Future<void> reRecognizeFile({
    required MediaFile file,
    required String sherpaOnnxPath,
    String modelId = AppConstants.defaultAsrModel,
    VadPreset vadPreset = AppConstants.vadLongAudio,
    String language = AppConstants.defaultAsrLanguage,
    AsrProgressCallback? onProgress,
  }) async {
    final env = SherpaOnnxService.checkEnv(sherpaOnnxPath, modelId);
    if (env == null) {
      throw Exception('sherpa-onnx 环境未就绪');
    }

    final wavDir = await Directory.systemTemp.createTemp('asr_rerecog_');

    try {
      await DatabaseService.deleteSubtitleClips(file.id);
      await DatabaseService.updateMediaFile(
        file.copyWith(subtitleStatus: SubtitleStatus.processing),
      );

      final segments = await _recognizeSingleFile(
        file: file,
        env: env,
        sherpaOnnxPath: sherpaOnnxPath,
        modelId: modelId,
        vadPreset: vadPreset,
        language: language,
        wavDir: wavDir.path,
        onProgress: onProgress,
      );

      await _saveSegmentsToDb(file.id, segments);

      await DatabaseService.updateMediaFile(
        file.copyWith(subtitleStatus: SubtitleStatus.completed),
      );
    } catch (e) {
      await DatabaseService.updateMediaFile(
        file.copyWith(subtitleStatus: SubtitleStatus.failed),
      );
      rethrow;
    } finally {
      if (wavDir.existsSync()) {
        await wavDir.delete(recursive: true);
      }
    }
  }
}

class AsrBatchResult {
  final int totalFiles;
  final int completedFiles;
  final int failedFiles;
  final int skippedFiles;
  final int usedConcurrency;
  final bool cancelled;
  final String? error;
  final List<String> errors;

  const AsrBatchResult({
    required this.totalFiles,
    required this.completedFiles,
    required this.failedFiles,
    required this.skippedFiles,
    this.usedConcurrency = 0,
    this.cancelled = false,
    this.error,
    this.errors = const [],
  });

  bool get isSuccess => !cancelled && failedFiles == 0 && error == null;
  bool get isPartialSuccess =>
      completedFiles > 0 && (failedFiles > 0 || cancelled || error != null);

  @override
  String toString() =>
      'BatchResult(total=$totalFiles, done=$completedFiles, fail=$failedFiles, skip=$skippedFiles, concurrency=$usedConcurrency, cancelled=$cancelled)';
}
