import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/timeline_data.dart';
import '../services/audio_align_service.dart';
import '../services/export_service.dart';

class TimelineState {
  final List<TimelineData> timelineList;
  final bool isBuilding;
  final bool isTrimming;
  final bool isExporting;
  final double trimProgress;
  final String? currentTrimFile;
  final String? exportPath;
  final String? error;

  const TimelineState({
    this.timelineList = const [],
    this.isBuilding = false,
    this.isTrimming = false,
    this.isExporting = false,
    this.trimProgress = 0,
    this.currentTrimFile,
    this.exportPath,
    this.error,
  });

  TimelineState copyWith({
    List<TimelineData>? timelineList,
    bool? isBuilding,
    bool? isTrimming,
    bool? isExporting,
    double? trimProgress,
    String? currentTrimFile,
    String? exportPath,
    String? error,
  }) {
    return TimelineState(
      timelineList: timelineList ?? this.timelineList,
      isBuilding: isBuilding ?? this.isBuilding,
      isTrimming: isTrimming ?? this.isTrimming,
      isExporting: isExporting ?? this.isExporting,
      trimProgress: trimProgress ?? this.trimProgress,
      currentTrimFile: currentTrimFile ?? this.currentTrimFile,
      exportPath: exportPath ?? this.exportPath,
      error: error,
    );
  }

  int get totalCount => timelineList.length;
  int get totalDurationMs =>
      timelineList.fold(0, (sum, item) => sum + item.videoDurationMs);
  int get reviewCount => timelineList.where((item) => item.needsReview).length;
}

class TimelineNotifier extends AsyncNotifier<TimelineState> {
  @override
  TimelineState build() => const TimelineState();

  Future<void> buildTimeline(String projectId) async {
    state = AsyncData(
      state.valueOrNull?.copyWith(isBuilding: true, error: null) ??
          const TimelineState(isBuilding: true),
    );
    try {
      final timelineList = await AudioAlignService.buildTimeline(projectId);
      state = AsyncData(TimelineState(timelineList: timelineList));
    } catch (e) {
      state = AsyncData(TimelineState(error: e.toString()));
    }
  }

  Future<void> batchTrim(String outputDir) async {
    final current = state.valueOrNull;
    if (current == null || current.timelineList.isEmpty) return;

    state = AsyncData(
      current.copyWith(isTrimming: true, trimProgress: 0, error: null),
    );

    try {
      final outputs = await AudioAlignService.batchTrimAudio(
        current.timelineList,
        outputDir,
        onProgress: (processed, total, fileName) {
          final latest = state.valueOrNull;
          if (latest != null) {
            state = AsyncData(
              latest.copyWith(
                trimProgress: processed / total,
                currentTrimFile: fileName,
              ),
            );
          }
        },
      );

      final trimmedTimeline = List.generate(current.timelineList.length, (
        index,
      ) {
        final output = index < outputs.length ? outputs[index] : '';
        if (output.isEmpty) return current.timelineList[index];
        return current.timelineList[index].copyWith(trimmedAudioPath: output);
      });

      state = AsyncData(
        (state.valueOrNull ?? const TimelineState()).copyWith(
          isTrimming: false,
          trimProgress: 1.0,
          timelineList: trimmedTimeline,
        ),
      );
    } catch (e) {
      state = AsyncData(
        (state.valueOrNull ?? const TimelineState()).copyWith(
          isTrimming: false,
          error: e.toString(),
        ),
      );
    }
  }

  Future<void> exportXml(
    String outputPath, {
    required ExportPreset preset,
  }) async {
    final current = state.valueOrNull;
    if (current == null || current.timelineList.isEmpty) return;

    state = AsyncData(current.copyWith(isExporting: true, error: null));

    try {
      final dir = p.dirname(outputPath);
      final baseName = p.basenameWithoutExtension(outputPath);

      final xmemlPath = p.join(dir, '$baseName.xml');
      await ExportService.exportXmeml(
        current.timelineList,
        xmemlPath,
        preset: preset,
      );

      final fcpxmlPath = p.join(dir, '$baseName.fcpxml');
      await ExportService.exportFcpxml(
        current.timelineList,
        fcpxmlPath,
        preset: preset,
      );

      state = AsyncData(
        current.copyWith(isExporting: false, exportPath: xmemlPath),
      );
    } catch (e) {
      state = AsyncData(
        current.copyWith(isExporting: false, error: e.toString()),
      );
    }
  }

  Future<void> exportCsv(String outputPath) async {
    final current = state.valueOrNull;
    if (current == null || current.timelineList.isEmpty) return;
    await ExportService.exportCsvReport(current.timelineList, outputPath);
    state = AsyncData(current.copyWith(exportPath: outputPath));
  }

  void clearError() {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(error: null));
    }
  }
}

final timelineProvider = AsyncNotifierProvider<TimelineNotifier, TimelineState>(
  TimelineNotifier.new,
);
