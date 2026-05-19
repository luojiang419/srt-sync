import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_theme.dart';
import '../core/extensions.dart';
import '../models/asr_project.dart';
import '../models/media_file.dart';
import '../models/subtitle_file.dart';
import '../providers/asr_process_provider.dart';
import '../providers/project_detail_provider.dart';
import '../services/subtitle_prepare_service.dart';
import 'common/video_thumbnail_view.dart';

class StepImport extends ConsumerStatefulWidget {
  final String projectId;
  final bool isPreparingSubtitles;
  final SubtitlePrepareSummary? prepareSummary;
  final String? prepareError;

  const StepImport({
    super.key,
    required this.projectId,
    this.isPreparingSubtitles = false,
    this.prepareSummary,
    this.prepareError,
  });

  @override
  ConsumerState<StepImport> createState() => _StepImportState();
}

class _StepImportState extends ConsumerState<StepImport> {
  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(projectDetailProvider);
    final state = asyncState.valueOrNull;
    final asrState = ref.watch(asrProcessProvider).valueOrNull;
    final missingSubtitleFiles = [
      ...(state?.videoFiles ?? const []).where(
        (file) => file.subtitleStatus != SubtitleStatus.completed,
      ),
      ...(state?.audioFiles ?? const []).where(
        (file) => file.subtitleStatus != SubtitleStatus.completed,
      ),
    ];
    final showPreparedSubtitleCount =
        (state?.project?.status.index ?? -1) >= ProjectStatus.recognized.index;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '素材导入',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '按四个区域分别导入视频、音频、视频字幕和音频字幕。素材顺序就是后续总字幕反解的平铺顺序。',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          if (state != null && !state.isScanning) ...[
            _PrepareStatusPanel(
              videoCount: state.videoFiles.length,
              audioCount: state.audioFiles.length,
              videoSubtitleCount: state.videoSubtitleFiles.length,
              audioSubtitleCount: state.audioSubtitleFiles.length,
              isPreparingSubtitles: widget.isPreparingSubtitles,
              prepareSummary: widget.prepareSummary,
              prepareError: widget.prepareError,
              missingSubtitleCount: missingSubtitleFiles.length,
              asrState: asrState,
              onStartFallback:
                  missingSubtitleFiles.isEmpty || (asrState?.isRunning ?? false)
                  ? null
                  : () => _startAsrFallback(
                      missingSubtitleFiles.map((file) => file.id).toList(),
                    ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: state == null || state.isScanning
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _MediaSection(
                                title: '视频素材',
                                icon: Icons.videocam_outlined,
                                files: state.videoFiles,
                                onPickDirectory: () =>
                                    _pickDirectory(MediaType.video),
                                onPickFiles: () =>
                                    _pickMediaFiles(MediaType.video),
                                onPickManifest: () =>
                                    _pickManifest(MediaType.video),
                                onMove: (index, delta) => _shiftMedia(
                                  MediaType.video,
                                  state.videoFiles,
                                  index,
                                  delta,
                                ),
                                onDropPaths: (paths) {
                                  ref
                                      .read(projectDetailProvider.notifier)
                                      .importDroppedFiles(
                                        paths,
                                        restrictToType: MediaType.video,
                                      );
                                },
                                preparedSubtitleCountByMediaId:
                                    state.preparedSubtitleCountByMediaId,
                                showPreparedSubtitleCount:
                                    showPreparedSubtitleCount,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MediaSection(
                                title: '音频素材',
                                icon: Icons.audiotrack_outlined,
                                files: state.audioFiles,
                                onPickDirectory: () =>
                                    _pickDirectory(MediaType.audio),
                                onPickFiles: () =>
                                    _pickMediaFiles(MediaType.audio),
                                onPickManifest: () =>
                                    _pickManifest(MediaType.audio),
                                onMove: (index, delta) => _shiftMedia(
                                  MediaType.audio,
                                  state.audioFiles,
                                  index,
                                  delta,
                                ),
                                onDropPaths: (paths) {
                                  ref
                                      .read(projectDetailProvider.notifier)
                                      .importDroppedFiles(
                                        paths,
                                        restrictToType: MediaType.audio,
                                      );
                                },
                                showPreparedSubtitleCount: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _SubtitleSection(
                                title: '视频字幕',
                                icon: Icons.subtitles_outlined,
                                files: state.videoSubtitleFiles,
                                onPickFiles: () =>
                                    _pickSubtitleFiles(MediaType.video),
                                onDropPaths: (paths) {
                                  ref
                                      .read(projectDetailProvider.notifier)
                                      .importSubtitleFiles(
                                        paths,
                                        mediaType: MediaType.video,
                                      );
                                },
                                onChangeType: (file, type) {
                                  ref
                                      .read(projectDetailProvider.notifier)
                                      .updateSubtitleFileType(file.id, type);
                                },
                                onDelete: (file) {
                                  ref
                                      .read(projectDetailProvider.notifier)
                                      .removeSubtitleFile(file.id);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SubtitleSection(
                                title: '音频字幕',
                                icon: Icons.library_music_outlined,
                                files: state.audioSubtitleFiles,
                                onPickFiles: () =>
                                    _pickSubtitleFiles(MediaType.audio),
                                onDropPaths: (paths) {
                                  ref
                                      .read(projectDetailProvider.notifier)
                                      .importSubtitleFiles(
                                        paths,
                                        mediaType: MediaType.audio,
                                      );
                                },
                                onChangeType: (file, type) {
                                  ref
                                      .read(projectDetailProvider.notifier)
                                      .updateSubtitleFileType(file.id, type);
                                },
                                onDelete: (file) {
                                  ref
                                      .read(projectDetailProvider.notifier)
                                      .removeSubtitleFile(file.id);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDirectory(MediaType type) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: type == MediaType.video ? '选择视频目录' : '选择音频目录',
    );
    if (result == null) return;
    if (type == MediaType.video) {
      await ref
          .read(projectDetailProvider.notifier)
          .importVideoDirectory(result);
    } else {
      await ref
          .read(projectDetailProvider.notifier)
          .importAudioDirectory(result);
    }
  }

  Future<void> _pickMediaFiles(MediaType type) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions:
          (type == MediaType.video
                  ? const [
                      'mp4',
                      'mov',
                      'avi',
                      'mkv',
                      'mxf',
                      'wmv',
                      'flv',
                      'webm',
                    ]
                  : const ['wav', 'mp3', 'aac', 'flac', 'ogg', 'wma', 'm4a'])
              .toList(),
      dialogTitle: type == MediaType.video ? '选择视频文件' : '选择音频文件',
    );
    final paths =
        result?.files.map((file) => file.path).whereType<String>().toList() ??
        const [];
    if (paths.isEmpty) return;
    await ref
        .read(projectDetailProvider.notifier)
        .importDroppedFiles(paths, restrictToType: type);
  }

  Future<void> _pickSubtitleFiles(MediaType type) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['srt'],
      dialogTitle: type == MediaType.video ? '选择视频字幕' : '选择音频字幕',
    );
    final paths =
        result?.files.map((file) => file.path).whereType<String>().toList() ??
        const [];
    if (paths.isEmpty) return;
    await ref
        .read(projectDetailProvider.notifier)
        .importSubtitleFiles(paths, mediaType: type);
  }

  Future<void> _pickManifest(MediaType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'txt'],
      dialogTitle: type == MediaType.video
          ? '选择视频顺序 manifest'
          : '选择音频顺序 manifest',
    );
    final path = result?.files.single.path;
    if (path == null) return;
    await ref
        .read(projectDetailProvider.notifier)
        .applyManifestLayout(path, mediaType: type);
  }

  Future<void> _shiftMedia(
    MediaType type,
    List<MediaFile> files,
    int index,
    int delta,
  ) async {
    final targetIndex = index + delta;
    if (targetIndex < 0 || targetIndex >= files.length) return;
    final orderedIds = files.map((file) => file.id).toList();
    final moved = orderedIds.removeAt(index);
    orderedIds.insert(targetIndex, moved);
    await ref
        .read(projectDetailProvider.notifier)
        .reorderMedia(type, orderedIds);
  }

  Future<void> _startAsrFallback(List<String> targetFileIds) async {
    await ref
        .read(asrProcessProvider.notifier)
        .startBatchRecognize(widget.projectId, targetFileIds: targetFileIds);
    await ref
        .read(projectDetailProvider.notifier)
        .loadProject(widget.projectId);
  }
}

class _MediaSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<MediaFile> files;
  final VoidCallback onPickDirectory;
  final VoidCallback onPickFiles;
  final VoidCallback onPickManifest;
  final void Function(int index, int delta) onMove;
  final ValueChanged<List<String>> onDropPaths;
  final Map<String, int> preparedSubtitleCountByMediaId;
  final bool showPreparedSubtitleCount;

  const _MediaSection({
    required this.title,
    required this.icon,
    required this.files,
    required this.onPickDirectory,
    required this.onPickFiles,
    required this.onPickManifest,
    required this.onMove,
    required this.onDropPaths,
    this.preparedSubtitleCountByMediaId = const {},
    this.showPreparedSubtitleCount = false,
  });

  @override
  State<_MediaSection> createState() => _MediaSectionState();
}

class _MediaSectionState extends State<_MediaSection> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        widget.onDropPaths(details.files.map((file) => file.path).toList());
      },
      child: Card(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragging ? AppTheme.highlight : AppTheme.border,
              width: _isDragging ? 1.8 : 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: widget.title,
                icon: widget.icon,
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onPickDirectory,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('目录'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onPickFiles,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('文件'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onPickManifest,
                      icon: const Icon(Icons.list_alt, size: 16),
                      label: const Text('Manifest'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.files.isEmpty
                    ? _EmptyHint(text: '拖拽文件或目录到这里')
                    : ListView.separated(
                        itemCount: widget.files.length,
                        separatorBuilder: (_, itemIndex) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final file = widget.files[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (file.type == MediaType.video) ...[
                                  VideoThumbnailView(
                                    thumbnailPath: file.thumbnailPath,
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.basename(file.filePath),
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '时长 ${file.durationMs?.toReadableDuration ?? "--"}  |  平铺 ${file.layoutStartMs.toReadableDuration} - ${file.layoutEndMs.toReadableDuration}',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (widget.showPreparedSubtitleCount &&
                                          file.type == MediaType.video) ...[
                                        const SizedBox(height: 8),
                                        _StatusChip(
                                          label:
                                              '字幕 ${widget.preparedSubtitleCountByMediaId[file.id] ?? 0}',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: index == 0
                                      ? null
                                      : () => widget.onMove(index, -1),
                                  tooltip: '上移',
                                  icon: const Icon(
                                    Icons.arrow_upward,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  onPressed: index == widget.files.length - 1
                                      ? null
                                      : () => widget.onMove(index, 1),
                                  tooltip: '下移',
                                  icon: const Icon(
                                    Icons.arrow_downward,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrepareStatusPanel extends StatelessWidget {
  final int videoCount;
  final int audioCount;
  final int videoSubtitleCount;
  final int audioSubtitleCount;
  final bool isPreparingSubtitles;
  final SubtitlePrepareSummary? prepareSummary;
  final String? prepareError;
  final int missingSubtitleCount;
  final AsrProcessState? asrState;
  final VoidCallback? onStartFallback;

  const _PrepareStatusPanel({
    required this.videoCount,
    required this.audioCount,
    required this.videoSubtitleCount,
    required this.audioSubtitleCount,
    required this.isPreparingSubtitles,
    required this.prepareSummary,
    required this.prepareError,
    required this.missingSubtitleCount,
    required this.asrState,
    required this.onStartFallback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '字幕反解与补录',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '先在底部执行反解建立索引；如仍有素材缺失字幕，可在这里继续走旧 ASR 补录流程。',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.84),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: onStartFallback,
                icon: const Icon(Icons.mic, size: 16),
                label: Text(
                  (asrState?.isRunning ?? false) ? '补录中...' : '补录缺失字幕',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusChip(label: '视频素材 $videoCount'),
              _StatusChip(label: '音频素材 $audioCount'),
              _StatusChip(label: '视频字幕 $videoSubtitleCount'),
              _StatusChip(label: '音频字幕 $audioSubtitleCount'),
              _StatusChip(label: '待补录素材 $missingSubtitleCount'),
              if (isPreparingSubtitles) _StatusChip(label: '建立索引中'),
              if (prepareSummary != null) ...[
                _StatusChip(
                  label: '反解字幕 ${prepareSummary!.generatedSubtitleClips}',
                ),
                _StatusChip(label: '音频窗口 ${prepareSummary!.generatedWindows}'),
              ],
            ],
          ),
          if (prepareError != null) ...[
            const SizedBox(height: 12),
            Text(
              prepareError!,
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ],
          if (asrState != null && asrState!.fileProgresses.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 132,
              child: ListView.separated(
                itemCount: asrState!.fileProgresses.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final progress = asrState!.fileProgresses[index];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progress.fileName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: progress.progress),
                        const SizedBox(height: 6),
                        Text(
                          progress.status.label,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubtitleSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<SubtitleFile> files;
  final VoidCallback onPickFiles;
  final ValueChanged<List<String>> onDropPaths;
  final void Function(SubtitleFile file, SubtitleSourceType type) onChangeType;
  final ValueChanged<SubtitleFile> onDelete;

  const _SubtitleSection({
    required this.title,
    required this.icon,
    required this.files,
    required this.onPickFiles,
    required this.onDropPaths,
    required this.onChangeType,
    required this.onDelete,
  });

  @override
  State<_SubtitleSection> createState() => _SubtitleSectionState();
}

class _SubtitleSectionState extends State<_SubtitleSection> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        widget.onDropPaths(details.files.map((file) => file.path).toList());
      },
      child: Card(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragging ? AppTheme.highlight : AppTheme.border,
              width: _isDragging ? 1.8 : 1,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: widget.title,
                icon: widget.icon,
                trailing: OutlinedButton.icon(
                  onPressed: widget.onPickFiles,
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('导入 SRT'),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.files.isEmpty
                    ? _EmptyHint(text: '拖拽 SRT 文件到这里')
                    : ListView.separated(
                        itemCount: widget.files.length,
                        separatorBuilder: (_, itemIndex) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final file = widget.files[index];
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.basename(file.filePath),
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => widget.onDelete(file),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      tooltip: '删除',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _StatusChip(label: file.status.label),
                                    const SizedBox(width: 8),
                                    _StatusChip(label: '条数 ${file.cueCount}'),
                                    const Spacer(),
                                    DropdownButton<SubtitleSourceType>(
                                      value: file.sourceType,
                                      underline: const SizedBox.shrink(),
                                      items: SubtitleSourceType.values
                                          .map(
                                            (type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type.label),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        widget.onChangeType(file, value);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.highlight, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing,
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.7),
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
    );
  }
}
