import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/asr_project.dart';
import '../models/media_file.dart';
import '../models/subtitle_file.dart';
import '../services/database_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/media_scan_service.dart';
import '../services/subtitle_prepare_service.dart';
import '../services/video_thumbnail_service.dart';

const _stateFieldUnchanged = Object();

/// 工程详情状态
class ProjectDetailState {
  final AsrProject? project;
  final List<MediaFile> videoFiles;
  final List<MediaFile> audioFiles;
  final List<SubtitleFile> videoSubtitleFiles;
  final List<SubtitleFile> audioSubtitleFiles;
  final Map<String, int> preparedSubtitleCountByMediaId;
  final int activeSectionIndex;
  final bool isLoading;
  final String? error;
  final bool isScanning;
  final bool isPreparingSubtitles;
  final SubtitlePrepareSummary? prepareSummary;
  final String? prepareError;

  const ProjectDetailState({
    this.project,
    this.videoFiles = const [],
    this.audioFiles = const [],
    this.videoSubtitleFiles = const [],
    this.audioSubtitleFiles = const [],
    this.preparedSubtitleCountByMediaId = const {},
    this.activeSectionIndex = 0,
    this.isLoading = false,
    this.error,
    this.isScanning = false,
    this.isPreparingSubtitles = false,
    this.prepareSummary,
    this.prepareError,
  });

  ProjectDetailState copyWith({
    AsrProject? project,
    List<MediaFile>? videoFiles,
    List<MediaFile>? audioFiles,
    List<SubtitleFile>? videoSubtitleFiles,
    List<SubtitleFile>? audioSubtitleFiles,
    Map<String, int>? preparedSubtitleCountByMediaId,
    int? activeSectionIndex,
    bool? isLoading,
    String? error,
    bool? isScanning,
    bool? isPreparingSubtitles,
    Object? prepareSummary = _stateFieldUnchanged,
    Object? prepareError = _stateFieldUnchanged,
  }) {
    return ProjectDetailState(
      project: project ?? this.project,
      videoFiles: videoFiles ?? this.videoFiles,
      audioFiles: audioFiles ?? this.audioFiles,
      videoSubtitleFiles: videoSubtitleFiles ?? this.videoSubtitleFiles,
      audioSubtitleFiles: audioSubtitleFiles ?? this.audioSubtitleFiles,
      preparedSubtitleCountByMediaId:
          preparedSubtitleCountByMediaId ?? this.preparedSubtitleCountByMediaId,
      activeSectionIndex: activeSectionIndex ?? this.activeSectionIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isScanning: isScanning ?? this.isScanning,
      isPreparingSubtitles: isPreparingSubtitles ?? this.isPreparingSubtitles,
      prepareSummary: identical(prepareSummary, _stateFieldUnchanged)
          ? this.prepareSummary
          : prepareSummary as SubtitlePrepareSummary?,
      prepareError: identical(prepareError, _stateFieldUnchanged)
          ? this.prepareError
          : prepareError as String?,
    );
  }

  int get recommendedSectionIndex {
    if (project == null) return 0;
    switch (project!.status) {
      case ProjectStatus.created:
        return 0;
      case ProjectStatus.imported:
      case ProjectStatus.recognizing:
        return 0;
      case ProjectStatus.recognized:
        return 1;
      case ProjectStatus.matched:
      case ProjectStatus.timeline:
      case ProjectStatus.completed:
        return 2;
    }
  }
}

class ProjectDetailNotifier extends AsyncNotifier<ProjectDetailState> {
  static const _uuid = Uuid();
  bool _isBackfillingVideoThumbnails = false;

  @override
  ProjectDetailState build() => const ProjectDetailState();

  Future<void> loadProject(String projectId) async {
    state = AsyncData(
      state.valueOrNull?.copyWith(isLoading: true) ??
          const ProjectDetailState(isLoading: true),
    );
    try {
      final previous = state.valueOrNull;
      final project = await DatabaseService.getProject(projectId);
      if (project == null) {
        state = const AsyncData(ProjectDetailState(error: '工程不存在'));
        return;
      }

      final videos = await DatabaseService.getMediaFiles(
        projectId,
        type: MediaType.video,
      );
      final audios = await DatabaseService.getMediaFiles(
        projectId,
        type: MediaType.audio,
      );
      final videoSubtitleFiles = await DatabaseService.getSubtitleFiles(
        projectId,
        mediaType: MediaType.video,
      );
      final audioSubtitleFiles = await DatabaseService.getSubtitleFiles(
        projectId,
        mediaType: MediaType.audio,
      );
      final preparedSubtitleCountByMediaId =
          await DatabaseService.getPreparedSubtitleCountByMediaId(projectId);

      final previousActiveIndex = previous?.activeSectionIndex;
      final recommendedIndex = ProjectDetailState(
        project: project,
        videoFiles: videos,
        audioFiles: audios,
        videoSubtitleFiles: videoSubtitleFiles,
        audioSubtitleFiles: audioSubtitleFiles,
      ).recommendedSectionIndex;

      state = AsyncData(
        ProjectDetailState(
          project: project,
          videoFiles: videos,
          audioFiles: audios,
          videoSubtitleFiles: videoSubtitleFiles,
          audioSubtitleFiles: audioSubtitleFiles,
          preparedSubtitleCountByMediaId: preparedSubtitleCountByMediaId,
          activeSectionIndex: previousActiveIndex ?? recommendedIndex,
          isPreparingSubtitles: previous?.isPreparingSubtitles ?? false,
          prepareSummary: previous?.prepareSummary,
          prepareError: previous?.prepareError,
        ),
      );
      Future.microtask(() => _backfillProjectVideoThumbnails(project.id));
    } catch (e) {
      state = AsyncData(ProjectDetailState(error: e.toString()));
    }
  }

  Future<void> importVideoDirectory(String directoryPath) async {
    await _importDirectory(directoryPath, MediaType.video);
    await _updateProjectDirectories(videoDirectory: directoryPath);
  }

  Future<void> importAudioDirectory(String directoryPath) async {
    await _importDirectory(directoryPath, MediaType.audio);
    await _updateProjectDirectories(audioDirectory: directoryPath);
  }

  Future<void> reimportVideoDirectory(String directoryPath) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    await VideoThumbnailService.deleteProjectCache(s!.project!.id);
    await DatabaseService.deleteMediaFiles(
      s.project!.id,
      type: MediaType.video,
    );
    await _invalidatePreparedWorkflow(s.project!.id);
    await loadProject(s.project!.id);
    await importVideoDirectory(directoryPath);
  }

  Future<void> reimportAudioDirectory(String directoryPath) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    await DatabaseService.deleteMediaFiles(
      s!.project!.id,
      type: MediaType.audio,
    );
    await _invalidatePreparedWorkflow(s.project!.id);
    await loadProject(s.project!.id);
    await importAudioDirectory(directoryPath);
  }

  Future<void> importSubtitleFiles(
    List<String> filePaths, {
    required MediaType mediaType,
  }) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    final expandedPaths = await _expandInputPaths(filePaths);
    final existing = {
      ...s!.videoSubtitleFiles.map((file) => file.filePath.toLowerCase()),
      ...s.audioSubtitleFiles.map((file) => file.filePath.toLowerCase()),
    };
    final created = <SubtitleFile>[];
    for (final filePath in expandedPaths) {
      final ext = p.extension(filePath).toLowerCase();
      if (ext != '.srt') continue;
      if (existing.contains(filePath.toLowerCase())) continue;
      final subtitleFile = SubtitleFile(
        id: _uuid.v4(),
        projectId: s.project!.id,
        filePath: filePath,
        mediaType: mediaType,
        sourceType: SubtitleSourceType.aggregate,
        createdAt: DateTime.now(),
      );
      await DatabaseService.insertSubtitleFile(subtitleFile);
      created.add(subtitleFile);
      existing.add(filePath.toLowerCase());
    }

    if (created.isEmpty) {
      return;
    }

    await _invalidatePreparedWorkflow(s.project!.id);
    await loadProject(s.project!.id);
  }

  Future<void> updateSubtitleFileType(
    String subtitleFileId,
    SubtitleSourceType sourceType,
  ) async {
    final s = state.valueOrNull;
    if (s == null) return;
    final allFiles = [...s.videoSubtitleFiles, ...s.audioSubtitleFiles];
    final target = allFiles
        .where((file) => file.id == subtitleFileId)
        .firstOrNull;
    if (target == null) return;
    if (target.sourceType == sourceType) return;
    await DatabaseService.updateSubtitleFile(
      target.copyWith(sourceType: sourceType),
    );
    await _invalidatePreparedWorkflow(target.projectId);
    await loadProject(target.projectId);
  }

  Future<void> removeSubtitleFile(String subtitleFileId) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    final projectId = s!.project!.id;
    await DatabaseService.deleteSubtitleFileById(subtitleFileId);
    await _invalidatePreparedWorkflow(projectId);
    await loadProject(projectId);
  }

  Future<void> reorderMedia(MediaType type, List<String> orderedIds) async {
    final s = state.valueOrNull;
    if (s?.project == null || orderedIds.isEmpty) return;
    final source = type == MediaType.video ? s!.videoFiles : s!.audioFiles;
    final currentOrder = source.map((file) => file.id).toList(growable: false);
    if (currentOrder.length == orderedIds.length) {
      var unchanged = true;
      for (var index = 0; index < orderedIds.length; index++) {
        if (currentOrder[index] != orderedIds[index]) {
          unchanged = false;
          break;
        }
      }
      if (unchanged) return;
    }
    final map = {for (final file in source) file.id: file};
    final updated = <MediaFile>[];
    for (var index = 0; index < orderedIds.length; index++) {
      final file = map[orderedIds[index]];
      if (file == null) continue;
      updated.add(file.copyWith(sortIndex: index));
    }
    if (updated.isEmpty) return;
    await DatabaseService.updateMediaFiles(updated);
    await _invalidatePreparedWorkflow(s.project!.id);
    await loadProject(s.project!.id);
  }

  Future<void> applyManifestLayout(
    String manifestPath, {
    required MediaType mediaType,
  }) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    final mediaFiles = mediaType == MediaType.video
        ? s!.videoFiles
        : s!.audioFiles;
    final orderedNames = await _parseManifest(manifestPath);
    if (orderedNames.isEmpty) return;
    final nameToFile = {
      for (final file in mediaFiles)
        p.basename(file.filePath).toLowerCase(): file,
    };
    final orderedIds = <String>[];
    for (final name in orderedNames) {
      final match = nameToFile[name.toLowerCase()];
      if (match != null && !orderedIds.contains(match.id)) {
        orderedIds.add(match.id);
      }
    }
    for (final file in mediaFiles) {
      if (!orderedIds.contains(file.id)) {
        orderedIds.add(file.id);
      }
    }
    await reorderMedia(mediaType, orderedIds);
  }

  void setActiveSection(int sectionIndex) {
    final s = state.valueOrNull;
    if (s == null) return;
    state = AsyncData(s.copyWith(activeSectionIndex: sectionIndex));
  }

  Future<void> importDroppedFiles(
    List<String> filePaths, {
    MediaType? restrictToType,
  }) async {
    final expandedPaths = await _expandInputPaths(filePaths);
    final mediaPaths = <String>[];
    final videoSubtitlePaths = <String>[];
    final audioSubtitlePaths = <String>[];

    for (final filePath in expandedPaths) {
      final ext = p.extension(filePath).toLowerCase();
      if (AppConstants.videoExtensions.contains(ext) &&
          (restrictToType == null || restrictToType == MediaType.video)) {
        mediaPaths.add(filePath);
      } else if (AppConstants.audioExtensions.contains(ext) &&
          (restrictToType == null || restrictToType == MediaType.audio)) {
        mediaPaths.add(filePath);
      } else if (ext == '.srt') {
        if (restrictToType == MediaType.audio) {
          audioSubtitlePaths.add(filePath);
        } else if (restrictToType == MediaType.video) {
          videoSubtitlePaths.add(filePath);
        }
      }
    }

    if (mediaPaths.isNotEmpty) {
      await _importMediaFiles(mediaPaths, restrictToType: restrictToType);
    }
    if (videoSubtitlePaths.isNotEmpty) {
      await importSubtitleFiles(videoSubtitlePaths, mediaType: MediaType.video);
    }
    if (audioSubtitlePaths.isNotEmpty) {
      await importSubtitleFiles(audioSubtitlePaths, mediaType: MediaType.audio);
    }
  }

  Future<void> prepareProjectSubtitles() async {
    final current = state.valueOrNull;
    if (current?.project == null || !_hasCompleteImports(current!)) {
      return;
    }

    state = AsyncData(
      current.copyWith(isPreparingSubtitles: true, prepareError: null),
    );

    try {
      if (!_hasReachedStatus(current.project!.status, ProjectStatus.imported)) {
        await confirmImport();
      }
      final summary = await SubtitlePrepareService.prepareProject(
        current.project!.id,
      );
      await confirmRecognize();
      await loadProject(current.project!.id);
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          isPreparingSubtitles: false,
          prepareSummary: summary,
          prepareError: null,
        ),
      );
    } catch (e) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          isPreparingSubtitles: false,
          prepareError: '字幕准备失败: $e',
        ),
      );
    }
  }

  Future<void> confirmImport() async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    if (!_hasCompleteImports(s!)) {
      return;
    }

    final updated = s.project!.copyWith(
      status: ProjectStatus.imported,
      updatedAt: DateTime.now(),
    );
    await DatabaseService.updateProject(updated);
    state = AsyncData(s.copyWith(project: updated));
  }

  Future<void> confirmRecognize() async {
    final s = state.valueOrNull;
    if (s == null || s.project == null) return;
    final updated = s.project!.copyWith(
      status: ProjectStatus.recognized,
      updatedAt: DateTime.now(),
    );
    await DatabaseService.updateProject(updated);
    state = AsyncData(s.copyWith(project: updated));
  }

  Future<void> confirmMatched() async {
    final s = state.valueOrNull;
    if (s == null || s.project == null) return;
    final updated = s.project!.copyWith(
      status: ProjectStatus.matched,
      updatedAt: DateTime.now(),
    );
    await DatabaseService.updateProject(updated);
    state = AsyncData(s.copyWith(project: updated));
  }

  Future<void> completeProject() async {
    final s = state.valueOrNull;
    if (s == null || s.project == null) return;
    final updated = s.project!.copyWith(
      status: ProjectStatus.completed,
      updatedAt: DateTime.now(),
    );
    await DatabaseService.updateProject(updated);
    state = AsyncData(s.copyWith(project: updated));
  }

  Future<void> _importDirectory(
    String directoryPath,
    MediaType mediaType,
  ) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    state = AsyncData(s!.copyWith(isScanning: true));

    try {
      final files = await MediaScanService.scanDirectory(
        directoryPath,
        mediaType,
      );
      final mediaFiles = await _buildMediaFiles(
        files.map((file) => file.path).toList(),
        mediaType,
      );
      if (mediaFiles.isEmpty) {
        state = AsyncData(s.copyWith(isScanning: false));
        return;
      }
      await DatabaseService.insertMediaFiles(mediaFiles);
      await _invalidatePreparedWorkflow(s.project!.id);
      await loadProject(s.project!.id);
      state = AsyncData((state.valueOrNull ?? s).copyWith(isScanning: false));
    } catch (e) {
      state = AsyncData(s.copyWith(isScanning: false, error: e.toString()));
    }
  }

  Future<void> _importMediaFiles(
    List<String> filePaths, {
    MediaType? restrictToType,
  }) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    final existingPaths = {
      ...s!.videoFiles.map((file) => file.filePath.toLowerCase()),
      ...s.audioFiles.map((file) => file.filePath.toLowerCase()),
    };

    final videoPaths = <String>[];
    final audioPaths = <String>[];
    for (final filePath in filePaths) {
      final ext = p.extension(filePath).toLowerCase();
      if (existingPaths.contains(filePath.toLowerCase())) continue;
      if (AppConstants.videoExtensions.contains(ext) &&
          (restrictToType == null || restrictToType == MediaType.video)) {
        videoPaths.add(filePath);
      } else if (AppConstants.audioExtensions.contains(ext) &&
          (restrictToType == null || restrictToType == MediaType.audio)) {
        audioPaths.add(filePath);
      }
    }

    final newVideos = await _buildMediaFiles(videoPaths, MediaType.video);
    final newAudios = await _buildMediaFiles(audioPaths, MediaType.audio);
    final newMediaFiles = [...newVideos, ...newAudios];
    if (newMediaFiles.isEmpty) return;
    await DatabaseService.insertMediaFiles(newMediaFiles);
    await _invalidatePreparedWorkflow(s.project!.id);
    await loadProject(s.project!.id);
  }

  Future<List<MediaFile>> _buildMediaFiles(
    List<String> paths,
    MediaType type,
  ) async {
    final s = state.valueOrNull;
    if (s?.project == null) return const [];
    final existing = await DatabaseService.getMediaFiles(
      s!.project!.id,
      type: type,
    );
    var nextSortIndex = existing.length;
    final now = DateTime.now();
    final output = <MediaFile>[];
    for (final filePath in paths..sort()) {
      MediaProbeInfo? info;
      try {
        info = await FfmpegService.probeMedia(filePath);
      } catch (_) {}
      var mediaFile = MediaFile(
        id: _uuid.v4(),
        projectId: s.project!.id,
        filePath: filePath,
        type: type,
        durationMs: info?.durationMs,
        sortIndex: nextSortIndex++,
        frameRate: info?.frameRate,
        sampleRate: info?.sampleRate,
        channels: info?.channels,
        width: info?.width,
        height: info?.height,
        hasEmbeddedAudio: info?.hasEmbeddedAudio ?? false,
        fileSize: info?.fileSize,
        modifiedAtMs: info?.modifiedAtMs,
        createdAt: now,
      );
      if (type == MediaType.video) {
        final thumbnailPath = await VideoThumbnailService.ensureThumbnail(
          mediaFile,
        );
        mediaFile = mediaFile.copyWith(thumbnailPath: thumbnailPath);
      }
      output.add(mediaFile);
    }
    return output;
  }

  Future<void> _updateProjectDirectories({
    String? videoDirectory,
    String? audioDirectory,
  }) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    final updated = s!.project!.copyWith(
      videoDirectory: videoDirectory ?? s.project!.videoDirectory,
      audioDirectory: audioDirectory ?? s.project!.audioDirectory,
      updatedAt: DateTime.now(),
    );
    await DatabaseService.updateProject(updated);
    state = AsyncData(s.copyWith(project: updated));
  }

  Future<List<String>> _expandInputPaths(List<String> paths) async {
    final expanded = <String>{};
    for (final path in paths) {
      final type = await FileSystemEntity.type(path);
      if (type == FileSystemEntityType.file) {
        expanded.add(path);
        continue;
      }
      if (type == FileSystemEntityType.directory) {
        await for (final entity in Directory(path).list(recursive: true)) {
          if (entity is File) {
            expanded.add(entity.path);
          }
        }
      }
    }
    return expanded.toList()..sort();
  }

  Future<List<String>> _parseManifest(String manifestPath) async {
    final content = await File(manifestPath).readAsString();
    final trimmed = content.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.startsWith('[')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((item) => '$item').toList();
      }
    }
    return trimmed
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<void> _backfillProjectVideoThumbnails(String projectId) async {
    if (_isBackfillingVideoThumbnails) return;
    final current = state.valueOrNull;
    if (current?.project?.id != projectId) return;

    final pending = current!.videoFiles
        .where(_needsThumbnailBackfill)
        .toList(growable: false);
    if (pending.isEmpty) return;

    _isBackfillingVideoThumbnails = true;
    try {
      var updatedAny = false;
      for (final file in pending) {
        final thumbnailPath = await VideoThumbnailService.ensureThumbnail(file);
        if (thumbnailPath == null || thumbnailPath == file.thumbnailPath) {
          continue;
        }
        await DatabaseService.updateMediaFile(
          file.copyWith(thumbnailPath: thumbnailPath),
        );
        updatedAny = true;
      }
      if (updatedAny) {
        await loadProject(projectId);
      }
    } finally {
      _isBackfillingVideoThumbnails = false;
    }
  }

  bool _needsThumbnailBackfill(MediaFile file) {
    if (file.type != MediaType.video) return false;
    if (!File(file.filePath).existsSync()) return false;
    final path = file.thumbnailPath;
    if (path == null || path.trim().isEmpty) {
      return true;
    }
    return !File(path).existsSync();
  }

  bool _hasReachedStatus(ProjectStatus current, ProjectStatus target) =>
      current.index >= target.index;

  bool _hasCompleteImports(ProjectDetailState state) {
    return state.videoFiles.isNotEmpty &&
        state.audioFiles.isNotEmpty &&
        state.videoSubtitleFiles.isNotEmpty &&
        state.audioSubtitleFiles.isNotEmpty;
  }

  Future<void> _invalidatePreparedWorkflow(String projectId) async {
    await DatabaseService.clearPreparedData(projectId);

    final mediaFiles = await DatabaseService.getMediaFiles(projectId);
    if (mediaFiles.isNotEmpty) {
      await DatabaseService.updateMediaFiles(
        mediaFiles
            .map(
              (file) => file.copyWith(subtitleStatus: SubtitleStatus.pending),
            )
            .toList(growable: false),
      );
    }

    final project = await DatabaseService.getProject(projectId);
    if (project == null) return;

    final videos = mediaFiles.where((file) => file.type == MediaType.video);
    final audios = mediaFiles.where((file) => file.type == MediaType.audio);
    final videoSubtitleFiles = await DatabaseService.getSubtitleFiles(
      projectId,
      mediaType: MediaType.video,
    );
    final audioSubtitleFiles = await DatabaseService.getSubtitleFiles(
      projectId,
      mediaType: MediaType.audio,
    );

    final hasCompleteImports =
        videos.isNotEmpty &&
        audios.isNotEmpty &&
        videoSubtitleFiles.isNotEmpty &&
        audioSubtitleFiles.isNotEmpty;

    await DatabaseService.updateProject(
      project.copyWith(
        status: hasCompleteImports
            ? ProjectStatus.imported
            : ProjectStatus.created,
        updatedAt: DateTime.now(),
      ),
    );

    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        preparedSubtitleCountByMediaId: const {},
        isPreparingSubtitles: false,
        prepareSummary: null,
        prepareError: null,
      ),
    );
  }
}

final projectDetailProvider =
    AsyncNotifierProvider<ProjectDetailNotifier, ProjectDetailState>(
      ProjectDetailNotifier.new,
    );
