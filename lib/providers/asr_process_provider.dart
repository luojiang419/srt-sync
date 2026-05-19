import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/asr_project.dart';
import '../models/media_file.dart';
import '../services/asr_batch_service.dart';
import '../services/database_service.dart';
import '../services/sherpa_onnx_service.dart';
import 'settings_provider.dart';

class AsrProcessState {
  final bool isRunning;
  final bool isCancelled;
  final double overallProgress;
  final int usedConcurrency;
  final List<AsrFileProgress> fileProgresses;
  final AsrBatchResult? result;
  final String? error;

  const AsrProcessState({
    this.isRunning = false,
    this.isCancelled = false,
    this.overallProgress = 0.0,
    this.usedConcurrency = 0,
    this.fileProgresses = const [],
    this.result,
    this.error,
  });

  AsrProcessState copyWith({
    bool? isRunning,
    bool? isCancelled,
    double? overallProgress,
    int? usedConcurrency,
    List<AsrFileProgress>? fileProgresses,
    AsrBatchResult? result,
    String? error,
  }) {
    return AsrProcessState(
      isRunning: isRunning ?? this.isRunning,
      isCancelled: isCancelled ?? this.isCancelled,
      overallProgress: overallProgress ?? this.overallProgress,
      usedConcurrency: usedConcurrency ?? this.usedConcurrency,
      fileProgresses: fileProgresses ?? this.fileProgresses,
      result: result ?? this.result,
      error: error,
    );
  }

  int get completedCount => fileProgresses
      .where(
        (p) =>
            p.status == AsrFileStatus.completed ||
            p.status == AsrFileStatus.skipped,
      )
      .length;

  int get failedCount =>
      fileProgresses.where((p) => p.status == AsrFileStatus.failed).length;

  int get queuedCount =>
      fileProgresses.where((p) => p.status == AsrFileStatus.queued).length;

  int get runningCount => fileProgresses
      .where(
        (p) =>
            p.status == AsrFileStatus.extracting ||
            p.status == AsrFileStatus.recognizing ||
            p.status == AsrFileStatus.saving,
      )
      .length;

  AsrFileProgress? get currentFile => fileProgresses
      .where(
        (p) =>
            p.status != AsrFileStatus.pending &&
            p.status != AsrFileStatus.queued &&
            p.status != AsrFileStatus.completed &&
            p.status != AsrFileStatus.skipped &&
            p.status != AsrFileStatus.cancelled &&
            p.status != AsrFileStatus.failed,
      )
      .firstOrNull;
}

class AsrProcessNotifier extends AsyncNotifier<AsrProcessState> {
  @override
  AsrProcessState build() => const AsrProcessState();

  Future<List<MediaFile>> _getRecognizableFiles(String projectId) async {
    final videos = await DatabaseService.getMediaFiles(
      projectId,
      type: MediaType.video,
    );
    final audios = await DatabaseService.getMediaFiles(
      projectId,
      type: MediaType.audio,
    );
    return [...videos, ...audios];
  }

  List<MediaFile> _filterTargetFiles(
    List<MediaFile> files,
    List<String>? targetFileIds,
  ) {
    if (targetFileIds == null || targetFileIds.isEmpty) {
      return files;
    }

    final idSet = targetFileIds.toSet();
    return files.where((file) => idSet.contains(file.id)).toList();
  }

  Future<List<AsrFileProgress>> _buildInitialBatchProgresses(
    List<MediaFile> files, {
    required bool skipExisting,
  }) async {
    if (!skipExisting) {
      return files
          .map(
            (file) => AsrFileProgress(
              mediaFileId: file.id,
              fileName: file.filePath.split(RegExp(r'[/\\]')).last,
              status: AsrFileStatus.queued,
            ),
          )
          .toList();
    }

    final progresses = <AsrFileProgress>[];
    for (final file in files) {
      final clips = await DatabaseService.getSubtitleClips(file.id);
      if (clips.isNotEmpty) {
        progresses.add(
          AsrFileProgress(
            mediaFileId: file.id,
            fileName: file.filePath.split(RegExp(r'[/\\]')).last,
            status: AsrFileStatus.completed,
            progress: 1.0,
            segments: clips
                .map(
                  (c) => AsrSegment(
                    startTime: c.startMs / 1000.0,
                    endTime: c.endMs / 1000.0,
                    text: c.text,
                  ),
                )
                .toList(),
          ),
        );
        continue;
      }

      progresses.add(
        AsrFileProgress(
          mediaFileId: file.id,
          fileName: file.filePath.split(RegExp(r'[/\\]')).last,
          status: AsrFileStatus.queued,
        ),
      );
    }

    return progresses;
  }

  List<AsrFileProgress> _normalizeFinalProgresses(
    List<AsrFileProgress> progresses,
  ) {
    return progresses.map((progress) {
      switch (progress.status) {
        case AsrFileStatus.queued:
        case AsrFileStatus.extracting:
        case AsrFileStatus.recognizing:
        case AsrFileStatus.saving:
          return progress.copyWith(
            status: AsrFileStatus.pending,
            progress: 0.0,
            errorMessage: null,
          );
        default:
          return progress;
      }
    }).toList();
  }

  Future<void> _updateProjectStatusAfterBatch(
    String projectId,
    AsrBatchResult result,
  ) async {
    final project = await DatabaseService.getProject(projectId);
    if (project == null) return;

    final hasUnrecognized = await hasUnrecognizedFiles(projectId);
    final status =
        (!result.cancelled && result.failedFiles == 0 && !hasUnrecognized)
        ? ProjectStatus.recognized
        : ProjectStatus.recognizing;

    await DatabaseService.updateProject(
      project.copyWith(status: status, updatedAt: DateTime.now()),
    );
  }

  Future<void> _runBatchRecognize(
    String projectId, {
    required bool skipExisting,
    List<String>? targetFileIds,
  }) async {
    final previousState = state.valueOrNull;
    state = const AsyncData(AsrProcessState(isRunning: true));

    try {
      final project = await DatabaseService.getProject(projectId);
      if (project == null) {
        state = AsyncData(const AsrProcessState(error: '工程不存在'));
        return;
      }

      await DatabaseService.updateProject(
        project.copyWith(
          status: ProjectStatus.recognizing,
          updatedAt: DateTime.now(),
        ),
      );

      final files = _filterTargetFiles(
        await _getRecognizableFiles(projectId),
        targetFileIds,
      );
      if (files.isEmpty) {
        state = AsyncData(const AsrProcessState(error: '没有可识别的媒体文件'));
        return;
      }

      final settings =
          ref.read(settingsProvider).valueOrNull ?? const AppSettings();
      final vadPreset = settings.vadMode == 'standard'
          ? AppConstants.vadStandard
          : AppConstants.vadLongAudio;
      final env = SherpaOnnxService.checkEnv(
        settings.sherpaOnnxPath,
        settings.asrModelId,
      );
      final effectiveConcurrency = env == null
          ? 0
          : await AsrBatchService.resolveConcurrency(
              sherpaOnnxPath: settings.sherpaOnnxPath,
              concurrencyMode: settings.asrConcurrencyMode,
              maxConcurrency: settings.asrMaxConcurrency,
              totalFiles: files.length,
            );
      final progresses = await _buildInitialBatchProgresses(
        files,
        skipExisting: skipExisting,
      );

      state = AsyncData(
        AsrProcessState(
          isRunning: true,
          usedConcurrency: effectiveConcurrency,
          fileProgresses: progresses,
        ),
      );

      final result = await AsrBatchService.batchRecognize(
        mediaFiles: files,
        sherpaOnnxPath: settings.sherpaOnnxPath,
        modelId: settings.asrModelId,
        vadPreset: vadPreset,
        language: settings.asrLanguage,
        concurrencyMode: settings.asrConcurrencyMode,
        maxConcurrency: settings.asrMaxConcurrency,
        skipExisting: skipExisting,
        onProgress: _onFileProgress,
        onCancel: () => state.valueOrNull?.isCancelled == true,
      );

      await _updateProjectStatusAfterBatch(projectId, result);

      final finalProgresses = _normalizeFinalProgresses(
        state.valueOrNull?.fileProgresses ?? progresses,
      );
      final overallProgress = result.cancelled
          ? _calculateOverallProgress(finalProgresses)
          : 1.0;

      state = AsyncData(
        AsrProcessState(
          isRunning: false,
          isCancelled: result.cancelled,
          overallProgress: overallProgress,
          usedConcurrency: result.usedConcurrency,
          fileProgresses: finalProgresses,
          result: result,
          error: result.error,
        ),
      );
    } catch (e) {
      state = AsyncData(
        AsrProcessState(
          isRunning: false,
          error: e.toString(),
          usedConcurrency: previousState?.usedConcurrency ?? 0,
          fileProgresses: previousState?.fileProgresses ?? const [],
        ),
      );
    }
  }

  double _calculateOverallProgress(List<AsrFileProgress> progresses) {
    if (progresses.isEmpty) return 0.0;
    final total = progresses.map((p) => p.progress).reduce((a, b) => a + b);
    return (total / progresses.length).clamp(0.0, 1.0);
  }

  Future<void> startBatchRecognize(
    String projectId, {
    List<String>? targetFileIds,
  }) async {
    if (state.valueOrNull?.isRunning == true) return;
    final hasManualSelection =
        targetFileIds != null && targetFileIds.isNotEmpty;
    await _runBatchRecognize(
      projectId,
      skipExisting: !hasManualSelection,
      targetFileIds: targetFileIds,
    );
  }

  void _onFileProgress(AsrFileProgress progress) {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = [...current.fileProgresses];
    final index = updated.indexWhere(
      (p) => p.mediaFileId == progress.mediaFileId,
    );
    if (index >= 0) {
      updated[index] = progress;
    } else {
      updated.add(progress);
    }

    state = AsyncData(
      current.copyWith(
        fileProgresses: updated,
        overallProgress: _calculateOverallProgress(updated),
      ),
    );
  }

  void cancelRecognize() {
    final current = state.valueOrNull;
    if (current?.isRunning != true) return;
    state = AsyncData(current!.copyWith(isCancelled: true));
  }

  Future<bool> hasUnrecognizedFiles(String projectId) async {
    final files = await _getRecognizableFiles(projectId);
    if (files.isEmpty) return false;

    for (final file in files) {
      final clips = await DatabaseService.getSubtitleClips(file.id);
      if (clips.isEmpty) {
        return true;
      }
    }

    return false;
  }

  Future<void> resumeRecognize(String projectId) async {
    if (state.valueOrNull?.isRunning == true) return;
    await _runBatchRecognize(projectId, skipExisting: true);
  }

  void reset() {
    state = const AsyncData(AsrProcessState());
  }

  void removeFileProgresses(List<String> ids) {
    final current = state.valueOrNull;
    if (current == null || ids.isEmpty) return;

    final idSet = ids.toSet();
    final updated = current.fileProgresses
        .where((p) => !idSet.contains(p.mediaFileId))
        .toList();

    state = AsyncData(
      current.copyWith(
        fileProgresses: updated,
        overallProgress: _calculateOverallProgress(updated),
      ),
    );
  }

  Future<void> reRecognizeFile(String mediaFileId) async {
    final current = state.valueOrNull ?? const AsrProcessState();
    final settings =
        ref.read(settingsProvider).valueOrNull ?? const AppSettings();
    final file = await DatabaseService.getMediaFileById(mediaFileId);
    if (file == null) {
      throw Exception('文件不存在');
    }

    final vadPreset = settings.vadMode == 'standard'
        ? AppConstants.vadStandard
        : AppConstants.vadLongAudio;

    state = AsyncData(
      current.copyWith(
        fileProgresses: [
          ...current.fileProgresses.where((p) => p.mediaFileId != mediaFileId),
          AsrFileProgress(
            mediaFileId: file.id,
            fileName: file.filePath.split(RegExp(r'[/\\]')).last,
            status: AsrFileStatus.extracting,
          ),
        ],
        usedConcurrency: current.usedConcurrency == 0
            ? 1
            : current.usedConcurrency,
      ),
    );

    try {
      await AsrBatchService.reRecognizeFile(
        file: file,
        sherpaOnnxPath: settings.sherpaOnnxPath,
        modelId: settings.asrModelId,
        vadPreset: vadPreset,
        language: settings.asrLanguage,
        onProgress: _onFileProgress,
      );

      await _updateProjectStatusAfterBatch(
        file.projectId,
        const AsrBatchResult(
          totalFiles: 1,
          completedFiles: 1,
          failedFiles: 0,
          skippedFiles: 0,
          usedConcurrency: 1,
        ),
      );
    } catch (e) {
      _onFileProgress(
        AsrFileProgress(
          mediaFileId: file.id,
          fileName: file.filePath.split(RegExp(r'[/\\]')).last,
          status: AsrFileStatus.failed,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}

final asrProcessProvider =
    AsyncNotifierProvider<AsrProcessNotifier, AsrProcessState>(
      AsrProcessNotifier.new,
    );
