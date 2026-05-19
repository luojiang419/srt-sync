import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_theme.dart';
import '../core/snackbar_util.dart';
import '../providers/match_provider.dart';
import '../providers/project_detail_provider.dart';
import '../providers/timeline_provider.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import 'timeline_preview.dart';

class StepTimeline extends ConsumerStatefulWidget {
  final String projectId;

  const StepTimeline({super.key, required this.projectId});

  @override
  ConsumerState<StepTimeline> createState() => _StepTimelineState();
}

class _StepTimelineState extends ConsumerState<StepTimeline> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(timelineProvider.notifier).buildTimeline(widget.projectId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncTimeline = ref.watch(timelineProvider);
    final matchState = ref.watch(matchProvider).valueOrNull;
    return asyncTimeline.when(
      data: (state) => _buildContent(context, state, matchState),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('时间线加载失败: $e')),
    );
  }

  Widget _buildContent(
    BuildContext context,
    TimelineState state,
    MatchState? matchState,
  ) {
    final pendingCount = matchState?.pendingCount ?? state.reviewCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(state, matchState),
        Divider(height: 1, color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chip('时间线', '${state.totalCount}', AppTheme.highlight),
              _chip(
                '总时长',
                _formatTotalDuration(state.totalDurationMs),
                AppTheme.accent,
              ),
              _chip('待复核', '${state.reviewCount}', AppTheme.warning),
              if (state.exportPath != null)
                _chip('导出', state.exportPath!, AppTheme.success),
            ],
          ),
        ),
        if (pendingCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                ref.read(projectDetailProvider.notifier).setActiveSection(1);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.warning.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '当前仍有 $pendingCount 条待复核结果，导出内容可能包含低置信度合板。点击返回第 3 步继续复核。',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                ),
              ),
            ),
          ),
        if (state.isTrimming) _buildTrimProgress(state),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TimelinePreview(timelineList: state.timelineList),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(TimelineState state, MatchState? matchState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: AppTheme.surface,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '时间线与导出',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          OutlinedButton.icon(
            onPressed: state.isBuilding ? null : _rebuild,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重建时间线'),
          ),
          ElevatedButton.icon(
            onPressed: state.isExporting || state.timelineList.isEmpty
                ? null
                : () => _exportXml(ExportPreset.compact, matchState),
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('导出精简版 XML'),
          ),
          OutlinedButton.icon(
            onPressed: state.isExporting || state.timelineList.isEmpty
                ? null
                : () => _exportXml(ExportPreset.review, matchState),
            icon: const Icon(Icons.fact_check, size: 16),
            label: const Text('导出审片版 XML'),
          ),
          OutlinedButton.icon(
            onPressed: state.timelineList.isEmpty
                ? null
                : () => _exportCsv(matchState),
            icon: const Icon(Icons.table_chart_outlined, size: 16),
            label: const Text('导出 CSV'),
          ),
          OutlinedButton.icon(
            onPressed: state.timelineList.isEmpty
                ? null
                : () => _exportSrt(matchState),
            icon: const Icon(Icons.subtitles, size: 16),
            label: const Text('导出分素材 SRT'),
          ),
          OutlinedButton.icon(
            onPressed: state.isTrimming || state.timelineList.isEmpty
                ? null
                : _startTrim,
            icon: const Icon(Icons.content_cut, size: 16),
            label: const Text('裁切试听音频'),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTrimProgress(TimelineState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '正在裁切试听音频: ${state.currentTrimFile ?? ""}',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: state.trimProgress),
        ],
      ),
    );
  }

  void _rebuild() {
    ref.read(timelineProvider.notifier).buildTimeline(widget.projectId);
  }

  Future<void> _startTrim() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择裁切试听音频输出目录',
    );
    if (dir == null) return;
    await ref.read(timelineProvider.notifier).batchTrim(dir);
  }

  Future<void> _exportXml(ExportPreset preset, MatchState? matchState) async {
    final shouldContinue = await _confirmExportIfNeeded(matchState);
    if (!shouldContinue) return;

    final projectName =
        ref.read(projectDetailProvider).valueOrNull?.project?.name ??
        'ASR Timeline';
    final rawBaseName = await _promptXmlExportBaseName(
      preset: preset,
      defaultName: projectName,
    );
    if (rawBaseName == null || !mounted) return;

    final baseName = ExportService.sanitizeExportBaseName(
      rawBaseName,
      fallbackName: projectName,
    );
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择 ${preset.label} XML 导出目录',
    );
    if (dir == null) return;
    final outputPath = '$dir\\$baseName';
    await ref
        .read(timelineProvider.notifier)
        .exportXml(outputPath, preset: preset);
  }

  Future<String?> _promptXmlExportBaseName({
    required ExportPreset preset,
    required String defaultName,
  }) async {
    final controller = TextEditingController(text: defaultName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置${preset.label} XML 名称'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('将同时生成同名基底的 .xml 和 .fcpxml 文件。'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '导出名称',
                  hintText: '请输入导出名称',
                ),
                onSubmitted: (value) {
                  Navigator.of(context).pop(value);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('下一步'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _exportCsv(MatchState? matchState) async {
    final shouldContinue = await _confirmExportIfNeeded(matchState);
    if (!shouldContinue) return;
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择 CSV 导出目录',
    );
    if (dir == null) return;
    final outputPath = '$dir\\${widget.projectId}_sync_report.csv';
    await ref.read(timelineProvider.notifier).exportCsv(outputPath);
    if (mounted) {
      SnackbarUtil.success(context, '已导出 CSV 报告');
    }
  }

  Future<void> _exportSrt(MatchState? matchState) async {
    final shouldContinue = await _confirmExportIfNeeded(matchState);
    if (!shouldContinue) return;
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择 SRT 导出目录',
    );
    if (dir == null) return;

    final timelineState = ref.read(timelineProvider).valueOrNull;
    if (timelineState == null) return;

    var exported = 0;
    for (final timeline in timelineState.timelineList) {
      final clips = await DatabaseService.getSubtitleClips(
        timeline.videoFileId,
      );
      if (clips.isEmpty) continue;
      final rows = clips
          .map(
            (clip) => {
              'start_ms': clip.startMs,
              'end_ms': clip.endMs,
              'text': clip.text,
            },
          )
          .toList();
      final baseName = p.basenameWithoutExtension(timeline.videoFileName);
      await ExportService.exportSrt(rows, '$dir\\$baseName.srt');
      exported++;
    }

    if (!mounted) return;
    if (exported > 0) {
      SnackbarUtil.success(context, '已导出 $exported 份分素材字幕');
    } else {
      SnackbarUtil.warning(context, '当前没有可导出的分素材字幕');
    }
  }

  Future<bool> _confirmExportIfNeeded(MatchState? matchState) async {
    final pendingCount = matchState?.pendingCount ?? 0;
    if (pendingCount <= 0) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出前确认'),
        content: Text(
          '当前仍有 $pendingCount 条待复核结果。\n\n'
          '已接受：${matchState?.acceptedCount ?? 0}\n'
          '已移除：${matchState?.rejectedCount ?? 0}\n\n'
          '如果继续导出，这些待复核结果会一起进入时间线和导出文件。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              ref.read(projectDetailProvider.notifier).setActiveSection(1);
            },
            child: const Text('返回复核'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('仍然导出'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String _formatTotalDuration(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }
}
