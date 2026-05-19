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

/// 工程详情状态
class ProjectDetailState {
  final AsrProject? project;
  final List<MediaFile> videoFiles;
  final List<MediaFile> audioFiles;
  final List<SubtitleFile> videoSubtitleFiles;
  final List<SubtitleFile> audioSubtitleFiles;
  final int activeSectionIndex;
  final bool isLoading;
  final String? error;
  final bool isScanning;

  const ProjectDetailState({
    this.project,
    this.videoFiles = const [],
    this.audioFiles = const [],
    this.videoSubtitleFiles = const [],
    this.audioSubtitleFiles = const [],
    this.activeSectionIndex = 0,
    this.isLoading = false,
    this.error,
    this.isScanning = false,
  });

  ProjectDetailState copyWith({
    AsrProject? project,
    List<MediaFile>? videoFiles,
    List<MediaFile>? audioFiles,
    List<SubtitleFile>? videoSubtitleFiles,
    List<SubtitleFile>? audioSubtitleFiles,
    int? activeSectionIndex,
    bool? isLoading,
    String? error,
    bool? isScanning,
  }) {
    return ProjectDetailState(
      project: project ?? this.project,
      videoFiles: videoFiles ?? this.videoFiles,
      audioFiles: audioFiles ?? this.audioFiles,
      videoSubtitleFiles: videoSubtitleFiles ?? this.videoSubtitleFiles,
      audioSubtitleFiles: audioSubtitleFiles ?? this.audioSubtitleFiles,
      activeSectionIndex: activeSectionIndex ?? this.activeSectionIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isScanning: isScanning ?? this.isScanning,
    );
  }

  int get recommendedSectionIndex {
    if (project == null) return 0;
    switch (project!.status) {
      case ProjectStatus.created:
        return 0;
      case ProjectStatus.imported:
      case ProjectStatus.recognizing:
        return 1;
      case ProjectStatus.recognized:
        return 2;
      case ProjectStatus.matched:
      case ProjectStatus.timeline:
      case ProjectStatus.completed:
        return 3;
    }
  }
}

class ProjectDetailNotifier extends AsyncNotifier<ProjectDetailState> {
  static const _uuid = Uuid();

  @override
  ProjectDetailState build() => const ProjectDetailState();

  Future<void> loadProject(String projectId) async {
    state = AsyncData(
      state.valueOrNull?.copyWith(isLoading: true) ??
          const ProjectDetailState(isLoading: true),
    );
    try {
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

      final previousActiveIndex = state.valueOrNull?.activeSectionIndex;
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
          activeSectionIndex: previousActiveIndex ?? recommendedIndex,
        ),
      );
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
    await DatabaseService.deleteMediaFiles(
      s!.project!.id,
      type: MediaType.video,
    );
    state = AsyncData(s.copyWith(videoFiles: []));
    await importVideoDirectory(directoryPath);
  }

  Future<void> reimportAudioDirectory(String directoryPath) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    await DatabaseService.deleteMediaFiles(
      s!.project!.id,
      type: MediaType.audio,
    );
    state = AsyncData(s.copyWith(audioFiles: []));
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

    if (mediaType == MediaType.video) {
      state = AsyncData(
        s.copyWith(videoSubtitleFiles: [...s.videoSubtitleFiles, ...created]),
      );
    } else {
      state = AsyncData(
        s.copyWith(audioSubtitleFiles: [...s.audioSubtitleFiles, ...created]),
      );
    }
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
    await DatabaseService.updateSubtitleFile(
      target.copyWith(sourceType: sourceType),
    );
    await loadProject(target.projectId);
  }

  Future<void> removeSubtitleFile(String subtitleFileId) async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    await DatabaseService.deleteSubtitleFileById(subtitleFileId);
    await loadProject(s!.project!.id);
  }

  Future<void> reorderMedia(MediaType type, List<String> orderedIds) async {
    final s = state.valueOrNull;
    if (s?.project == null || orderedIds.isEmpty) return;
    final source = type == MediaType.video ? s!.videoFiles : s!.audioFiles;
    final map = {for (final file in source) file.id: file};
    final updated = <MediaFile>[];
    for (var index = 0; index < orderedIds.length; index++) {
      final file = map[orderedIds[index]];
      if (file == null) continue;
      updated.add(file.copyWith(sortIndex: index));
    }
    if (updated.isEmpty) return;
    await DatabaseService.updateMediaFiles(updated);
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

  Future<void> confirmImport() async {
    final s = state.valueOrNull;
    if (s?.project == null) return;
    if (s!.videoFiles.isEmpty ||
        s.audioFiles.isEmpty ||
        s.videoSubtitleFiles.isEmpty ||
        s.audioSubtitleFiles.isEmpty) {
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
      await DatabaseService.insertMediaFiles(mediaFiles);
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
    await DatabaseService.insertMediaFiles([...newVideos, ...newAudios]);
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
      output.add(
        MediaFile(
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
        ),
      );
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
}

final projectDetailProvider =
    AsyncNotifierProvider<ProjectDetailNotifier, ProjectDetailState>(
      ProjectDetailNotifier.new,
    );
