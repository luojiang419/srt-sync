import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/media_file.dart';
import '../models/source_layout_item.dart';
import '../models/subtitle_clip.dart';
import '../models/subtitle_file.dart';
import '../models/subtitle_window.dart';
import 'database_service.dart';

class SubtitlePrepareSummary {
  final int parsedSubtitleFiles;
  final int generatedSubtitleClips;
  final int generatedWindows;
  final int preparedVideos;
  final int preparedAudios;

  const SubtitlePrepareSummary({
    required this.parsedSubtitleFiles,
    required this.generatedSubtitleClips,
    required this.generatedWindows,
    required this.preparedVideos,
    required this.preparedAudios,
  });
}

class SubtitlePrepareService {
  SubtitlePrepareService._();

  static const _uuid = Uuid();

  static String normalizeTextForMatching(String text) {
    final normalized = _normalizeFullWidth(text).toLowerCase();
    final digitsNormalized = normalized
        .replaceAll('零', '0')
        .replaceAll('一', '1')
        .replaceAll('二', '2')
        .replaceAll('三', '3')
        .replaceAll('四', '4')
        .replaceAll('五', '5')
        .replaceAll('六', '6')
        .replaceAll('七', '7')
        .replaceAll('八', '8')
        .replaceAll('九', '9');
    return digitsNormalized
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double lowValuePhraseMultiplier(String normalizedText) {
    if (normalizedText.isEmpty) return 1.0;
    final compact = normalizedText.replaceAll(' ', '');
    if (compact.length <= 2 && AppConstants.lowValuePhrases.contains(compact)) {
      return 0.25;
    }
    if (compact.length <= 4 &&
        _isComposedOnlyOfLowValuePhrases(normalizedText)) {
      return 0.4;
    }
    return 1.0;
  }

  static Future<SubtitlePrepareSummary> prepareProject(String projectId) async {
    await DatabaseService.clearPreparedData(projectId);

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

    final preparedVideos = await _refreshLayouts(
      projectId,
      videos,
      MediaType.video,
    );
    final preparedAudios = await _refreshLayouts(
      projectId,
      audios,
      MediaType.audio,
    );

    int parsedFiles = 0;
    int generatedClips = 0;
    final allAudioLocalClips = <SubtitleClip>[];

    generatedClips += await _prepareSubtitleGroup(
      projectId: projectId,
      mediaType: MediaType.video,
      mediaFiles: preparedVideos,
      subtitleFiles: videoSubtitleFiles,
      captureAudioClipsInto: null,
      onParsed: () => parsedFiles++,
    );
    generatedClips += await _prepareSubtitleGroup(
      projectId: projectId,
      mediaType: MediaType.audio,
      mediaFiles: preparedAudios,
      subtitleFiles: audioSubtitleFiles,
      captureAudioClipsInto: allAudioLocalClips,
      onParsed: () => parsedFiles++,
    );

    final audioWindows = _buildWindows(
      projectId,
      MediaType.audio,
      allAudioLocalClips,
    );
    await DatabaseService.replaceSubtitleWindows(
      projectId,
      MediaType.audio,
      audioWindows,
    );

    return SubtitlePrepareSummary(
      parsedSubtitleFiles: parsedFiles,
      generatedSubtitleClips: generatedClips,
      generatedWindows: audioWindows.length,
      preparedVideos: preparedVideos.length,
      preparedAudios: preparedAudios.length,
    );
  }

  static Future<List<MediaFile>> _refreshLayouts(
    String projectId,
    List<MediaFile> files,
    MediaType mediaType,
  ) async {
    final sorted = [...files]
      ..sort((a, b) {
        final orderCompare = a.sortIndex.compareTo(b.sortIndex);
        if (orderCompare != 0) return orderCompare;
        return a.filePath.toLowerCase().compareTo(b.filePath.toLowerCase());
      });

    final updated = <MediaFile>[];
    final layouts = <SourceLayoutItem>[];
    var cursor = 0;
    final now = DateTime.now();

    for (var index = 0; index < sorted.length; index++) {
      final file = sorted[index];
      final duration = file.durationMs ?? 0;
      final next = file.copyWith(
        sortIndex: index,
        layoutStartMs: cursor,
        layoutEndMs: cursor + duration,
      );
      updated.add(next);
      layouts.add(
        SourceLayoutItem(
          id: _uuid.v4(),
          projectId: projectId,
          mediaId: file.id,
          mediaType: mediaType,
          sortIndex: index,
          layoutStartMs: cursor,
          layoutEndMs: cursor + duration,
          durationMs: duration,
          createdAt: now,
        ),
      );
      cursor += duration;
    }

    await DatabaseService.updateMediaFiles(updated);
    await DatabaseService.replaceSourceLayouts(projectId, mediaType, layouts);
    return updated;
  }

  static Future<int> _prepareSubtitleGroup({
    required String projectId,
    required MediaType mediaType,
    required List<MediaFile> mediaFiles,
    required List<SubtitleFile> subtitleFiles,
    required List<SubtitleClip>? captureAudioClipsInto,
    required void Function() onParsed,
  }) async {
    if (subtitleFiles.isEmpty || mediaFiles.isEmpty) return 0;

    final layouts = await DatabaseService.getSourceLayouts(
      projectId,
      mediaType: mediaType,
    );
    var generated = 0;

    for (final subtitleFile in subtitleFiles) {
      try {
        final rawCues = await _parseSrtFile(subtitleFile.filePath);
        final detectedType = _detectSourceType(
          subtitleFile,
          rawCues,
          subtitleFiles.length,
          layouts,
          mediaFiles,
        );
        final updatedSubtitleFile = subtitleFile.copyWith(
          sourceType: detectedType,
          status: detectedType == SubtitleSourceType.aggregate
              ? SubtitleFileStatus.split
              : SubtitleFileStatus.parsed,
          cueCount: rawCues.length,
        );
        await DatabaseService.updateSubtitleFile(updatedSubtitleFile);
        onParsed();

        final globalClips = <SubtitleClip>[];
        if (detectedType == SubtitleSourceType.aggregate) {
          globalClips.addAll(_buildGlobalClips(rawCues, updatedSubtitleFile));
          if (globalClips.isNotEmpty) {
            await DatabaseService.insertSubtitleClips(globalClips);
          }
        }

        final localClips = detectedType == SubtitleSourceType.aggregate
            ? _reverseSplitAggregate(
                rawCues: rawCues,
                subtitleFile: updatedSubtitleFile,
                mediaFiles: mediaFiles,
                layouts: layouts,
              )
            : _mapPerClipSubtitleFile(
                rawCues: rawCues,
                subtitleFile: updatedSubtitleFile,
                mediaFiles: mediaFiles,
              );

        if (localClips.isNotEmpty) {
          await DatabaseService.insertSubtitleClips(localClips);
          generated += localClips.length;
          if (captureAudioClipsInto != null) {
            captureAudioClipsInto.addAll(localClips);
          }
        }
      } catch (_) {
        await DatabaseService.updateSubtitleFile(
          subtitleFile.copyWith(status: SubtitleFileStatus.failed),
        );
      }
    }

    final subtitlesByMedia = <String, List<SubtitleClip>>{};
    for (final media in mediaFiles) {
      subtitlesByMedia[media.id] = await DatabaseService.getSubtitleClips(
        media.id,
      );
    }
    for (final media in mediaFiles) {
      final clips = subtitlesByMedia[media.id] ?? const <SubtitleClip>[];
      await DatabaseService.updateMediaFile(
        media.copyWith(
          subtitleStatus: clips.isNotEmpty
              ? SubtitleStatus.completed
              : SubtitleStatus.pending,
        ),
      );
    }

    return generated;
  }

  static SubtitleSourceType _detectSourceType(
    SubtitleFile subtitleFile,
    List<_ParsedCue> rawCues,
    int fileCount,
    List<SourceLayoutItem> layouts,
    List<MediaFile> mediaFiles,
  ) {
    if (subtitleFile.sourceType == SubtitleSourceType.perClip) {
      return SubtitleSourceType.perClip;
    }
    if (subtitleFile.sourceType == SubtitleSourceType.aggregate &&
        fileCount == 1) {
      return SubtitleSourceType.aggregate;
    }
    final totalSpan = rawCues.isEmpty ? 0 : rawCues.last.endMs;
    final layoutSpan = layouts.isEmpty ? 0 : layouts.last.layoutEndMs;
    if (fileCount == 1 && totalSpan > 0 && layoutSpan > 0) {
      final ratio = totalSpan / layoutSpan;
      if (ratio >= 0.6 && ratio <= 1.4) {
        return SubtitleSourceType.aggregate;
      }
    }
    final bestMedia = _bestMediaByFileName(subtitleFile.filePath, mediaFiles);
    if (bestMedia != null) {
      return SubtitleSourceType.perClip;
    }
    return fileCount == 1
        ? SubtitleSourceType.aggregate
        : SubtitleSourceType.perClip;
  }

  static List<SubtitleClip> _buildGlobalClips(
    List<_ParsedCue> rawCues,
    SubtitleFile subtitleFile,
  ) {
    return List.generate(rawCues.length, (index) {
      final cue = rawCues[index];
      return SubtitleClip(
        id: _uuid.v4(),
        subtitleFileId: subtitleFile.id,
        mediaFileId: null,
        sourceKind: 'aggregate',
        startMs: cue.startMs,
        endMs: cue.endMs,
        globalStartMs: cue.startMs,
        globalEndMs: cue.endMs,
        text: cue.text,
        normalizedText: _normalizeText(cue.text),
        sortOrder: index,
      );
    });
  }

  static List<SubtitleClip> _reverseSplitAggregate({
    required List<_ParsedCue> rawCues,
    required SubtitleFile subtitleFile,
    required List<MediaFile> mediaFiles,
    required List<SourceLayoutItem> layouts,
  }) {
    final mediaMap = {for (final media in mediaFiles) media.id: media};
    final localClips = <SubtitleClip>[];
    final orderMap = <String, int>{};

    for (final cue in rawCues) {
      final overlaps = <_CueOverlap>[];
      for (final layout in layouts) {
        final overlapStart = math.max(cue.startMs, layout.layoutStartMs);
        final overlapEnd = math.min(cue.endMs, layout.layoutEndMs);
        if (overlapEnd <= overlapStart) continue;
        overlaps.add(
          _CueOverlap(
            layout: layout,
            overlapDurationMs: overlapEnd - overlapStart,
            localStartMs: overlapStart - layout.layoutStartMs,
            localEndMs: overlapEnd - layout.layoutStartMs,
          ),
        );
      }

      if (overlaps.isEmpty) continue;

      final cueDuration = math.max(cue.endMs - cue.startMs, 1);
      overlaps.sort(
        (a, b) => b.overlapDurationMs.compareTo(a.overlapDurationMs),
      );
      final best = overlaps.first;

      if (best.overlapDurationMs / cueDuration >=
              AppConstants.subtitleBoundaryKeepRatio ||
          overlaps.length == 1) {
        final clip = _buildLocalClip(
          subtitleFile: subtitleFile,
          mediaFile: mediaMap[best.layout.mediaId]!,
          cue: cue,
          localStartMs: (cue.startMs - best.layout.layoutStartMs).clamp(
            0,
            best.layout.durationMs,
          ),
          localEndMs: (cue.endMs - best.layout.layoutStartMs).clamp(
            0,
            best.layout.durationMs,
          ),
          sortOrder: orderMap[best.layout.mediaId] ?? 0,
          sourceKind: 'derived',
        );
        if (clip.durationMs >= AppConstants.subtitleSplitMinDurationMs) {
          localClips.add(clip);
          orderMap[best.layout.mediaId] = clip.sortOrder + 1;
        }
        continue;
      }

      for (final overlap in overlaps) {
        final clip = _buildLocalClip(
          subtitleFile: subtitleFile,
          mediaFile: mediaMap[overlap.layout.mediaId]!,
          cue: cue,
          localStartMs: overlap.localStartMs,
          localEndMs: overlap.localEndMs,
          sortOrder: orderMap[overlap.layout.mediaId] ?? 0,
          sourceKind: 'derived',
        );
        if (clip.durationMs < AppConstants.subtitleSplitMinDurationMs) continue;
        localClips.add(clip);
        orderMap[overlap.layout.mediaId] = clip.sortOrder + 1;
      }
    }

    return localClips;
  }

  static List<SubtitleClip> _mapPerClipSubtitleFile({
    required List<_ParsedCue> rawCues,
    required SubtitleFile subtitleFile,
    required List<MediaFile> mediaFiles,
  }) {
    final media = _bestMediaByFileName(subtitleFile.filePath, mediaFiles);
    if (media == null) return const [];

    return List.generate(rawCues.length, (index) {
      final cue = rawCues[index];
      return SubtitleClip(
        id: _uuid.v4(),
        subtitleFileId: subtitleFile.id,
        mediaFileId: media.id,
        sourceKind: 'local',
        startMs: cue.startMs,
        endMs: cue.endMs,
        globalStartMs: cue.startMs,
        globalEndMs: cue.endMs,
        localStartMs: cue.startMs,
        localEndMs: cue.endMs,
        text: cue.text,
        normalizedText: _normalizeText(cue.text),
        sortOrder: index,
      );
    });
  }

  static MediaFile? _bestMediaByFileName(
    String subtitlePath,
    List<MediaFile> mediaFiles,
  ) {
    final subtitleName = _normalizeName(
      p.basenameWithoutExtension(subtitlePath),
    );
    MediaFile? best;
    double bestScore = 0.0;
    for (final media in mediaFiles) {
      final mediaName = _normalizeName(
        p.basenameWithoutExtension(media.filePath),
      );
      if (mediaName.isEmpty || subtitleName.isEmpty) continue;
      double score;
      if (subtitleName == mediaName) {
        score = 1.0;
      } else if (subtitleName.contains(mediaName) ||
          mediaName.contains(subtitleName)) {
        score = 0.92;
      } else {
        score = _diceCoefficient(subtitleName, mediaName);
      }
      if (score > bestScore) {
        bestScore = score;
        best = media;
      }
    }
    return bestScore >= 0.65 ? best : null;
  }

  static SubtitleClip _buildLocalClip({
    required SubtitleFile subtitleFile,
    required MediaFile mediaFile,
    required _ParsedCue cue,
    required int localStartMs,
    required int localEndMs,
    required int sortOrder,
    required String sourceKind,
  }) {
    return SubtitleClip(
      id: _uuid.v4(),
      subtitleFileId: subtitleFile.id,
      mediaFileId: mediaFile.id,
      sourceKind: sourceKind,
      startMs: localStartMs,
      endMs: localEndMs,
      globalStartMs: cue.startMs,
      globalEndMs: cue.endMs,
      localStartMs: localStartMs,
      localEndMs: localEndMs,
      text: cue.text,
      normalizedText: _normalizeText(cue.text),
      sortOrder: sortOrder,
    );
  }

  static List<SubtitleWindow> _buildWindows(
    String projectId,
    MediaType mediaType,
    List<SubtitleClip> clips,
  ) {
    final byMedia = <String, List<SubtitleClip>>{};
    for (final clip in clips) {
      final mediaId = clip.mediaFileId;
      if (mediaId == null) continue;
      byMedia.putIfAbsent(mediaId, () => []).add(clip);
    }

    final provisional = <SubtitleWindow>[];
    final frequency = <String, int>{};
    final now = DateTime.now();

    byMedia.forEach((mediaId, mediaClips) {
      mediaClips.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (final windowSize in AppConstants.subtitleWindowSizes) {
        if (mediaClips.length < windowSize) continue;
        for (var i = 0; i <= mediaClips.length - windowSize; i++) {
          final slice = mediaClips.sublist(i, i + windowSize);
          final normalizedText = slice
              .map((clip) => clip.normalizedText)
              .where((text) => text.isNotEmpty)
              .join(' ');
          if (normalizedText.isEmpty) continue;
          frequency.update(
            normalizedText,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          provisional.add(
            SubtitleWindow(
              id: _uuid.v4(),
              projectId: projectId,
              mediaFileId: mediaId,
              mediaType: mediaType,
              windowSize: windowSize,
              startMs: slice.first.localStartMs ?? slice.first.startMs,
              endMs: slice.last.localEndMs ?? slice.last.endMs,
              text: slice.map((clip) => clip.text).join(' '),
              normalizedText: normalizedText,
              cueIds: slice.map((clip) => clip.id).join(','),
              uniquenessWeight: lowValuePhraseMultiplier(normalizedText),
              createdAt: now,
            ),
          );
        }
      }
    });

    return provisional.map((window) {
      final count = frequency[window.normalizedText] ?? 1;
      return SubtitleWindow(
        id: window.id,
        projectId: window.projectId,
        mediaFileId: window.mediaFileId,
        mediaType: window.mediaType,
        windowSize: window.windowSize,
        startMs: window.startMs,
        endMs: window.endMs,
        text: window.text,
        normalizedText: window.normalizedText,
        cueIds: window.cueIds,
        uniquenessWeight: (1 / count) * window.uniquenessWeight,
        createdAt: window.createdAt,
      );
    }).toList();
  }

  static Future<List<_ParsedCue>> _parseSrtFile(String filePath) async {
    final content = await File(filePath).readAsString();
    return _parseSrt(content);
  }

  static List<_ParsedCue> _parseSrt(String content) {
    final normalized = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return const [];

    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final cues = <_ParsedCue>[];

    for (final block in blocks) {
      final lines = block
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (lines.length < 2) continue;
      final timeLine = lines.first.contains('-->')
          ? lines.first
          : (lines.length > 1 ? lines[1] : '');
      if (!timeLine.contains('-->')) continue;
      final parts = timeLine.split('-->');
      if (parts.length != 2) continue;
      final startMs = _parseSrtTime(parts[0].trim());
      final endMs = _parseSrtTime(parts[1].trim());
      if (startMs == null || endMs == null || endMs <= startMs) continue;
      final textStartIndex = lines.first.contains('-->') ? 1 : 2;
      final text = lines.sublist(textStartIndex).join(' ').trim();
      if (text.isEmpty) continue;
      cues.add(_ParsedCue(startMs: startMs, endMs: endMs, text: text));
    }

    return cues;
  }

  static int? _parseSrtTime(String raw) {
    final clean = raw.replaceAll('.', ',');
    final match = RegExp(
      r'^(\d{2}):(\d{2}):(\d{2}),(\d{3})$',
    ).firstMatch(clean);
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final s = int.parse(match.group(3)!);
    final ms = int.parse(match.group(4)!);
    return (((h * 60) + m) * 60 + s) * 1000 + ms;
  }

  static String _normalizeText(String text) {
    return normalizeTextForMatching(text);
  }

  static String _normalizeFullWidth(String input) {
    final buffer = StringBuffer();
    for (final codeUnit in input.codeUnits) {
      if (codeUnit == 0x3000) {
        buffer.writeCharCode(0x20);
      } else if (codeUnit >= 0xFF01 && codeUnit <= 0xFF5E) {
        buffer.writeCharCode(codeUnit - 0xFEE0);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static String _normalizeName(String input) {
    return _normalizeText(input).replaceAll(' ', '');
  }

  static bool _isComposedOnlyOfLowValuePhrases(String normalizedText) {
    final tokens = normalizedText
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return false;
    return tokens.every(AppConstants.lowValuePhrases.contains);
  }

  static double _diceCoefficient(String left, String right) {
    if (left.length < 2 || right.length < 2) {
      return left == right ? 1.0 : 0.0;
    }
    final leftBigrams = _bigrams(left);
    final rightBigrams = _bigrams(right);
    final counts = <String, int>{};
    var overlap = 0;
    for (final gram in leftBigrams) {
      counts.update(gram, (value) => value + 1, ifAbsent: () => 1);
    }
    for (final gram in rightBigrams) {
      final remaining = counts[gram] ?? 0;
      if (remaining > 0) {
        counts[gram] = remaining - 1;
        overlap++;
      }
    }
    return (2 * overlap / (leftBigrams.length + rightBigrams.length)).clamp(
      0.0,
      1.0,
    );
  }

  static List<String> _bigrams(String text) {
    final values = <String>[];
    for (var i = 0; i < text.length - 1; i++) {
      values.add(text.substring(i, i + 2));
    }
    return values;
  }
}

class _ParsedCue {
  final int startMs;
  final int endMs;
  final String text;

  const _ParsedCue({
    required this.startMs,
    required this.endMs,
    required this.text,
  });
}

class _CueOverlap {
  final SourceLayoutItem layout;
  final int overlapDurationMs;
  final int localStartMs;
  final int localEndMs;

  const _CueOverlap({
    required this.layout,
    required this.overlapDurationMs,
    required this.localStartMs,
    required this.localEndMs,
  });
}
