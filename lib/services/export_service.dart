import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import '../models/timeline_data.dart';

enum ExportPreset {
  compact('精简版'),
  review('审片版');

  final String label;
  const ExportPreset(this.label);
}

/// XML 导出服务
///
/// 支持两种导出格式：
/// - FCPXML (Final Cut Pro XML) — 可被 Final Cut Pro / Premiere Pro 导入
/// - xmeml (Premiere Pro XML) — DaVinci Resolve 原生支持，推荐用于 DaVinci
class ExportService {
  ExportService._();

  static const _fps = 24;

  static String sanitizeExportBaseName(
    String rawName, {
    String fallbackName = 'ASR Timeline',
  }) {
    String sanitize(String value) {
      final normalized = value
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll(RegExp(r'\s+'), ' ');
      if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(normalized)) {
        return '';
      }
      return normalized;
    }

    final normalized = sanitize(rawName);
    if (normalized.isNotEmpty) {
      return normalized;
    }

    final normalizedFallback = sanitize(fallbackName);
    if (normalizedFallback.isNotEmpty) {
      return normalizedFallback;
    }

    return 'ASR Timeline';
  }

  // ==================== FCPXML 导出 ====================

  /// 导出为 FCPXML 1.8 格式
  static Future<void> exportFcpxml(
    List<TimelineData> timelineList,
    String outputPath, {
    String projectName = 'ASR Timeline',
    ExportPreset preset = ExportPreset.compact,
  }) async {
    final builder = XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'fcpxml',
      nest: () {
        builder.attribute('version', '1.8');

        // Resources: format + asset
        builder.element(
          'resources',
          nest: () {
            final addedAssets = <String>{};

            builder.element(
              'format',
              nest: () {
                builder.attribute('id', 'f_video');
                builder.attribute('name', 'FFVideoFormat1080p24');
                builder.attribute('frameDuration', '100/2400s');
                builder.attribute('width', '1920');
                builder.attribute('height', '1080');
              },
            );

            for (final timeline in timelineList) {
              if (!addedAssets.contains(timeline.videoFileId)) {
                builder.element(
                  'asset',
                  nest: () {
                    builder.attribute('id', 'a_${timeline.videoFileId}');
                    builder.attribute('name', timeline.videoFileName);
                    builder.attribute(
                      'src',
                      _toFileUri(timeline.videoFilePath),
                    );
                    builder.attribute('hasVideo', '1');
                    builder.attribute(
                      'hasAudio',
                      timeline.videoHasEmbeddedAudio ? '1' : '0',
                    );
                    if (timeline.videoHasEmbeddedAudio) {
                      builder.attribute('audioSources', '1');
                      builder.attribute('audioChannels', '2');
                      builder.attribute('audioRate', '48000');
                    }
                    builder.element(
                      'media-rep',
                      nest: () {
                        builder.attribute('kind', 'original-media');
                        builder.attribute(
                          'src',
                          _toFileUri(timeline.videoFilePath),
                        );
                      },
                    );
                  },
                );
                addedAssets.add(timeline.videoFileId);
              }

              final audioFileId = timeline.audioFileId;
              if (audioFileId != null &&
                  timeline.effectiveAudioPath.isNotEmpty &&
                  !addedAssets.contains(audioFileId)) {
                builder.element(
                  'asset',
                  nest: () {
                    builder.attribute('id', 'a_$audioFileId');
                    builder.attribute('name', timeline.audioFileName);
                    builder.attribute(
                      'src',
                      _toFileUri(timeline.effectiveAudioPath),
                    );
                    builder.attribute('hasVideo', '0');
                    builder.attribute('hasAudio', '1');
                    builder.attribute('audioSources', '1');
                    builder.attribute('audioChannels', '2');
                    builder.attribute('audioRate', '48000');
                    builder.element(
                      'media-rep',
                      nest: () {
                        builder.attribute('kind', 'original-media');
                        builder.attribute(
                          'src',
                          _toFileUri(timeline.effectiveAudioPath),
                        );
                      },
                    );
                  },
                );
                addedAssets.add(audioFileId);
              }
            }
          },
        );

        builder.element(
          'library',
          nest: () {
            builder.attribute('location', '');

            builder.element(
              'event',
              nest: () {
                builder.attribute('name', projectName);

                builder.element(
                  'project',
                  nest: () {
                    builder.attribute('name', projectName);

                    builder.element(
                      'sequence',
                      nest: () {
                        builder.attribute('format', 'f_video');

                        // 计算总帧数（逐个累加避免累积误差）
                        int totalFrames = 0;
                        for (final t in timelineList) {
                          totalFrames += _msToFrames(t.videoDurationMs);
                        }
                        builder.attribute(
                          'duration',
                          _framesToTimecode(totalFrames),
                        );
                        builder.attribute('tcStart', '0s');
                        builder.attribute('tcFormat', 'NDF');

                        // Spine (主视频轨道)
                        final videoPositions = <String, int>{};
                        builder.element(
                          'spine',
                          nest: () {
                            int currentFrame = 0;

                            for (final timeline in timelineList) {
                              final durFrames = _msToFrames(
                                timeline.videoDurationMs,
                              );
                              videoPositions[timeline.videoFileId] =
                                  currentFrame;

                              builder.element(
                                'asset-clip',
                                nest: () {
                                  builder.attribute(
                                    'ref',
                                    'a_${timeline.videoFileId}',
                                  );
                                  builder.attribute(
                                    'name',
                                    timeline.videoFileName,
                                  );
                                  builder.attribute(
                                    'offset',
                                    _framesToTimecode(currentFrame),
                                  );
                                  builder.attribute(
                                    'duration',
                                    _framesToTimecode(durFrames),
                                  );
                                  builder.attribute(
                                    'start',
                                    _framesToTimecode(
                                      _msToFrames(timeline.videoStartMs),
                                    ),
                                  );
                                  if (preset == ExportPreset.review) {
                                    builder.element(
                                      'marker',
                                      nest: () {
                                        builder.attribute('start', '0s');
                                        builder.attribute('duration', '0s');
                                        builder.attribute(
                                          'value',
                                          _markerValue(timeline),
                                        );
                                      },
                                    );
                                  }
                                },
                              );

                              currentFrame += durFrames;
                            }
                          },
                        );

                        for (final timeline in timelineList) {
                          if (!_hasEmbeddedAudio(timeline)) {
                            continue;
                          }
                          final startFrame =
                              videoPositions[timeline.videoFileId]!;
                          final durFrames = _msToFrames(
                            timeline.videoDurationMs,
                          );
                          builder.element(
                            'audio',
                            nest: () {
                              builder.attribute(
                                'ref',
                                'a_${timeline.videoFileId}',
                              );
                              builder.attribute('name', timeline.videoFileName);
                              builder.attribute(
                                'offset',
                                _framesToTimecode(startFrame),
                              );
                              builder.attribute(
                                'duration',
                                _framesToTimecode(durFrames),
                              );
                              builder.attribute('start', '0s');
                              builder.attribute('lane', '-1');
                              builder.attribute('srcCh', '1,2');
                              builder.attribute('outCh', 'L,R');
                            },
                          );
                        }

                        for (final timeline in timelineList) {
                          if (!_hasExternalAudio(timeline)) {
                            continue;
                          }
                          final audioStartFrame =
                              videoPositions[timeline.videoFileId]! +
                              _msToFrames(timeline.offsetMs);
                          final audioDurFrames = _msToFrames(
                            timeline.audioDurationMs,
                          );

                          builder.element(
                            'audio',
                            nest: () {
                              builder.attribute(
                                'ref',
                                'a_${timeline.audioFileId}',
                              );
                              builder.attribute('name', timeline.audioFileName);
                              builder.attribute(
                                'offset',
                                _framesToTimecode(audioStartFrame),
                              );
                              builder.attribute(
                                'duration',
                                _framesToTimecode(audioDurFrames),
                              );
                              builder.attribute(
                                'start',
                                _framesToTimecode(
                                  _msToFrames(
                                    timeline.effectiveAudioSourceInMs,
                                  ),
                                ),
                              );
                              builder.attribute('lane', '-2');
                              builder.attribute('srcCh', '1,2');
                              builder.attribute('outCh', 'L,R');
                            },
                          );
                        }
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );

    final document = builder.buildDocument();
    final xmlString = document.toXmlString(pretty: true, indent: '  ');

    final file = File(outputPath);
    await file.writeAsString(xmlString);
  }

  // ==================== Premiere Pro XML (xmeml) 导出 ====================

  /// 导出为 Premiere Pro XML (xmeml) 格式
  /// DaVinci Resolve 原生支持此格式，推荐用于 DaVinci 导入
  /// 格式参考 DaVinci Resolve 导出的 xmeml，确保最大兼容性
  static Future<void> exportXmeml(
    List<TimelineData> timelineList,
    String outputPath, {
    String projectName = 'ASR Timeline',
    ExportPreset preset = ExportPreset.compact,
  }) async {
    final buf = StringBuffer();

    // 为每个 clip 分配唯一 id（参考 DaVinci 格式: "FileName N"）
    int idSeq = 0;
    final videoClipIds = <String, String>{}; // videoFileId -> clip id
    final embeddedAudioClipIds =
        <String, String>{}; // videoFileId -> audio clip id
    final externalAudioClipIds =
        <String, String>{}; // videoFileId -> audio clip id
    final videoFileIds = <String, String>{}; // videoFileId -> file id
    final externalAudioFileIds =
        <String, String>{}; // videoFileId -> audio file id

    for (final t in timelineList) {
      final base = _safeId(t.videoFileName);
      videoClipIds[t.videoFileId] = '$base $idSeq';
      idSeq++;
      videoFileIds[t.videoFileId] = '$base $idSeq';
      idSeq++;
      if (_hasEmbeddedAudio(t)) {
        embeddedAudioClipIds[t.videoFileId] = '$base $idSeq';
        idSeq++;
      }
      if (_hasExternalAudio(t)) {
        externalAudioClipIds[t.videoFileId] = '$base $idSeq';
        idSeq++;
        final aBase = _safeId(t.audioFileName);
        externalAudioFileIds[t.videoFileId] = '$aBase $idSeq';
        idSeq++;
      }
    }

    // 计算视频轨道位置
    int currentFrame = 0;
    final videoPositions = <String, int>{};
    for (final t in timelineList) {
      videoPositions[t.videoFileId] = currentFrame;
      currentFrame += _msToFrames(t.videoDurationMs);
    }
    final totalDuration = currentFrame;

    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<!DOCTYPE xmeml>');
    buf.writeln('<xmeml version="5">');
    buf.writeln('  <sequence>');
    buf.writeln('    <name>$projectName</name>');
    buf.writeln('    <duration>$totalDuration</duration>');
    buf.writeln('    <rate>');
    buf.writeln('      <timebase>$_fps</timebase>');
    buf.writeln('      <ntsc>FALSE</ntsc>');
    buf.writeln('    </rate>');
    buf.writeln('    <in>-1</in>');
    buf.writeln('    <out>-1</out>');
    buf.writeln('    <timecode>');
    buf.writeln('      <string>01:00:00:00</string>');
    buf.writeln('      <frame>90000</frame>');
    buf.writeln('      <displayformat>NDF</displayformat>');
    buf.writeln('      <rate>');
    buf.writeln('        <timebase>$_fps</timebase>');
    buf.writeln('        <ntsc>FALSE</ntsc>');
    buf.writeln('      </rate>');
    buf.writeln('    </timecode>');
    buf.writeln('    <media>');

    // ---- Video Track ----
    buf.writeln('      <video>');
    buf.writeln('        <track>');

    for (final t in timelineList) {
      final startFrame = videoPositions[t.videoFileId]!;
      final durFrames = _msToFrames(t.videoDurationMs);
      final endFrame = startFrame + durFrames;
      final clipId = videoClipIds[t.videoFileId]!;
      final fileId = videoFileIds[t.videoFileId]!;
      final embeddedAudioClipId = embeddedAudioClipIds[t.videoFileId];
      final externalAudioClipId = externalAudioClipIds[t.videoFileId];

      buf.writeln('          <clipitem id="$clipId">');
      buf.writeln('            <name>${_xmlEscape(t.videoFileName)}</name>');
      buf.writeln('            <duration>$durFrames</duration>');
      buf.writeln('            <rate>');
      buf.writeln('              <timebase>$_fps</timebase>');
      buf.writeln('              <ntsc>FALSE</ntsc>');
      buf.writeln('            </rate>');
      buf.writeln('            <start>$startFrame</start>');
      buf.writeln('            <end>$endFrame</end>');
      buf.writeln('            <enabled>TRUE</enabled>');
      buf.writeln('            <in>0</in>');
      buf.writeln('            <out>$durFrames</out>');
      buf.writeln('            <file id="$fileId">');
      buf.writeln('              <duration>$durFrames</duration>');
      buf.writeln('              <rate>');
      buf.writeln('                <timebase>$_fps</timebase>');
      buf.writeln('                <ntsc>FALSE</ntsc>');
      buf.writeln('              </rate>');
      buf.writeln('              <name>${_xmlEscape(t.videoFileName)}</name>');
      buf.writeln(
        '              <pathurl>${_toFileUri(t.videoFilePath)}</pathurl>',
      );
      buf.writeln('              <timecode>');
      buf.writeln('                <string>01:00:00:00</string>');
      buf.writeln('                <displayformat>NDF</displayformat>');
      buf.writeln('                <rate>');
      buf.writeln('                  <timebase>$_fps</timebase>');
      buf.writeln('                  <ntsc>FALSE</ntsc>');
      buf.writeln('                </rate>');
      buf.writeln('              </timecode>');
      buf.writeln('              <media>');
      buf.writeln('                <video>');
      buf.writeln('                  <duration>$durFrames</duration>');
      buf.writeln('                  <samplecharacteristics>');
      buf.writeln('                    <width>1920</width>');
      buf.writeln('                    <height>1080</height>');
      buf.writeln('                  </samplecharacteristics>');
      buf.writeln('                </video>');
      buf.writeln('                <audio>');
      buf.writeln('                  <channelcount>2</channelcount>');
      buf.writeln('                </audio>');
      buf.writeln('              </media>');
      buf.writeln('            </file>');
      buf.writeln('            <compositemode>normal</compositemode>');
      buf.writeln('            <link>');
      buf.writeln('              <linkclipref>$clipId</linkclipref>');
      buf.writeln('            </link>');
      if (embeddedAudioClipId != null) {
        buf.writeln('            <link>');
        buf.writeln(
          '              <linkclipref>$embeddedAudioClipId</linkclipref>',
        );
        buf.writeln('            </link>');
      }
      if (externalAudioClipId != null) {
        buf.writeln('            <link>');
        buf.writeln(
          '              <linkclipref>$externalAudioClipId</linkclipref>',
        );
        buf.writeln('            </link>');
      }
      if (preset == ExportPreset.review) {
        buf.writeln('            <marker>');
        buf.writeln(
          '              <name>${_xmlEscape(_markerValue(t))}</name>',
        );
        buf.writeln('              <in>0</in>');
        buf.writeln('              <out>0</out>');
        buf.writeln('            </marker>');
      }
      buf.writeln('            <comments/>');
      buf.writeln('          </clipitem>');
    }

    buf.writeln('          <enabled>TRUE</enabled>');
    buf.writeln('          <locked>FALSE</locked>');
    buf.writeln('        </track>');
    buf.writeln('        <format>');
    buf.writeln('          <samplecharacteristics>');
    buf.writeln('            <width>1920</width>');
    buf.writeln('            <height>1080</height>');
    buf.writeln('            <pixelaspectratio>square</pixelaspectratio>');
    buf.writeln('            <rate>');
    buf.writeln('              <timebase>$_fps</timebase>');
    buf.writeln('              <ntsc>FALSE</ntsc>');
    buf.writeln('            </rate>');
    buf.writeln('          </samplecharacteristics>');
    buf.writeln('        </format>');
    buf.writeln('      </video>');

    // ---- Audio Tracks ----
    buf.writeln('      <audio>');
    final hasEmbeddedTrack = timelineList.any(_hasEmbeddedAudio);
    if (hasEmbeddedTrack) {
      buf.writeln('        <track>');
      for (final t in timelineList) {
        if (!_hasEmbeddedAudio(t)) {
          continue;
        }
        final startFrame = videoPositions[t.videoFileId]!;
        final durFrames = _msToFrames(t.videoDurationMs);
        final endFrame = startFrame + durFrames;
        final audioClipId = embeddedAudioClipIds[t.videoFileId]!;
        final videoClipId = videoClipIds[t.videoFileId]!;
        final videoFileId = videoFileIds[t.videoFileId]!;
        final sourceInFrames = _msToFrames(t.videoStartMs);
        final sourceOutFrames = sourceInFrames + durFrames;

        buf.writeln('          <clipitem id="$audioClipId">');
        buf.writeln('            <name>${_xmlEscape(t.videoFileName)}</name>');
        buf.writeln('            <duration>$durFrames</duration>');
        buf.writeln('            <rate>');
        buf.writeln('              <timebase>$_fps</timebase>');
        buf.writeln('              <ntsc>FALSE</ntsc>');
        buf.writeln('            </rate>');
        buf.writeln('            <start>$startFrame</start>');
        buf.writeln('            <end>$endFrame</end>');
        buf.writeln('            <enabled>TRUE</enabled>');
        buf.writeln('            <in>$sourceInFrames</in>');
        buf.writeln('            <out>$sourceOutFrames</out>');
        buf.writeln('            <file id="$videoFileId"/>');
        buf.writeln('            <sourcetrack>');
        buf.writeln('              <mediatype>audio</mediatype>');
        buf.writeln('              <trackindex>1</trackindex>');
        buf.writeln('            </sourcetrack>');
        buf.writeln('            <link>');
        buf.writeln('              <linkclipref>$videoClipId</linkclipref>');
        buf.writeln('              <mediatype>video</mediatype>');
        buf.writeln('            </link>');
        buf.writeln('            <link>');
        buf.writeln('              <linkclipref>$audioClipId</linkclipref>');
        buf.writeln('            </link>');
        buf.writeln('            <comments/>');
        buf.writeln('          </clipitem>');
      }
      buf.writeln('          <enabled>TRUE</enabled>');
      buf.writeln('          <locked>FALSE</locked>');
      buf.writeln('        </track>');
    }

    final hasExternalTrack = timelineList.any(_hasExternalAudio);
    if (hasExternalTrack) {
      buf.writeln('        <track>');

      for (final t in timelineList) {
        if (!_hasExternalAudio(t)) {
          continue;
        }
        final startFrame =
            videoPositions[t.videoFileId]! + _msToFrames(t.offsetMs);
        final durFrames = _msToFrames(t.audioDurationMs);
        final endFrame = startFrame + durFrames;
        final audioClipId = externalAudioClipIds[t.videoFileId]!;
        final videoClipId = videoClipIds[t.videoFileId]!;
        final audioFileId = externalAudioFileIds[t.videoFileId]!;
        final sourceInFrames = _msToFrames(t.effectiveAudioSourceInMs);
        final sourceOutFrames = sourceInFrames + durFrames;
        final sourceDurationFrames = _msToFrames(
          t.effectiveAudioFileDurationMs,
        );

        buf.writeln('          <clipitem id="$audioClipId">');
        buf.writeln('            <name>${_xmlEscape(t.audioFileName)}</name>');
        buf.writeln('            <duration>$durFrames</duration>');
        buf.writeln('            <rate>');
        buf.writeln('              <timebase>$_fps</timebase>');
        buf.writeln('              <ntsc>FALSE</ntsc>');
        buf.writeln('            </rate>');
        buf.writeln('            <start>$startFrame</start>');
        buf.writeln('            <end>$endFrame</end>');
        buf.writeln('            <enabled>TRUE</enabled>');
        buf.writeln('            <in>$sourceInFrames</in>');
        buf.writeln('            <out>$sourceOutFrames</out>');
        buf.writeln('            <file id="$audioFileId">');
        buf.writeln('              <duration>$sourceDurationFrames</duration>');
        buf.writeln('              <rate>');
        buf.writeln('                <timebase>$_fps</timebase>');
        buf.writeln('                <ntsc>FALSE</ntsc>');
        buf.writeln('              </rate>');
        buf.writeln(
          '              <name>${_xmlEscape(t.audioFileName)}</name>',
        );
        buf.writeln(
          '              <pathurl>${_toFileUri(t.effectiveAudioPath)}</pathurl>',
        );
        buf.writeln('              <media>');
        buf.writeln('                <audio>');
        buf.writeln('                  <samplecharacteristics>');
        buf.writeln('                    <depth>16</depth>');
        buf.writeln('                    <samplerate>48000</samplerate>');
        buf.writeln('                  </samplecharacteristics>');
        buf.writeln('                  <channelcount>2</channelcount>');
        buf.writeln('                </audio>');
        buf.writeln('              </media>');
        buf.writeln('            </file>');
        buf.writeln('            <sourcetrack>');
        buf.writeln('              <mediatype>audio</mediatype>');
        buf.writeln('              <trackindex>1</trackindex>');
        buf.writeln('            </sourcetrack>');
        buf.writeln('            <link>');
        buf.writeln('              <linkclipref>$videoClipId</linkclipref>');
        buf.writeln('              <mediatype>video</mediatype>');
        buf.writeln('            </link>');
        buf.writeln('            <link>');
        buf.writeln('              <linkclipref>$audioClipId</linkclipref>');
        buf.writeln('            </link>');
        buf.writeln('            <comments/>');
        buf.writeln('          </clipitem>');
      }

      buf.writeln('          <enabled>TRUE</enabled>');
      buf.writeln('          <locked>FALSE</locked>');
      buf.writeln('        </track>');
    }

    buf.writeln('      </audio>');
    buf.writeln('    </media>');
    buf.writeln('  </sequence>');
    buf.writeln('</xmeml>');

    final file = File(outputPath);
    await file.writeAsString(buf.toString());
  }

  /// 文件名转安全 id (去掉扩展名中的点)
  static String _safeId(String fileName) {
    return fileName.replaceAll('.', '_');
  }

  static String _markerValue(TimelineData timeline) {
    if (timeline.markerText.isNotEmpty) {
      return timeline.markerText;
    }
    return '${timeline.status} ${(timeline.confidence * 100).toStringAsFixed(0)}%';
  }

  static bool _hasEmbeddedAudio(TimelineData timeline) {
    return timeline.videoHasEmbeddedAudio && timeline.videoDurationMs > 0;
  }

  static bool _hasExternalAudio(TimelineData timeline) {
    return timeline.audioFileId != null &&
        timeline.effectiveAudioPath.isNotEmpty &&
        timeline.audioDurationMs > 0;
  }

  /// XML 特殊字符转义
  static String _xmlEscape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // ==================== SRT 导出 ====================

  /// 导出为 SRT 字幕文件
  static Future<void> exportSrt(
    List<Map<String, dynamic>> clips,
    String outputPath,
  ) async {
    final buffer = StringBuffer();
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      buffer.writeln('${i + 1}');
      buffer.writeln(
        '${_formatSrtTime(clip['start_ms'] as int)} --> ${_formatSrtTime(clip['end_ms'] as int)}',
      );
      buffer.writeln(clip['text'] as String);
      buffer.writeln();
    }

    final file = File(outputPath);
    await file.writeAsString(buffer.toString());
  }

  static Future<void> exportCsvReport(
    List<TimelineData> timelineList,
    String outputPath,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'video_file,audio_file,confidence,status,method,source_in_ms,source_out_ms,anchors,needs_review,review_status,reviewed_at_ms,marker',
    );
    for (final timeline in timelineList) {
      buffer.writeln(
        [
          _csvCell(timeline.videoFileName),
          _csvCell(timeline.audioFileName),
          timeline.confidence.toStringAsFixed(4),
          _csvCell(timeline.status),
          _csvCell(timeline.method),
          '${timeline.audioTrimStartMs}',
          '${timeline.audioTrimEndMs}',
          '${timeline.anchorCount}',
          timeline.needsReview ? '1' : '0',
          _csvCell(timeline.reviewStatus.name),
          '${timeline.reviewedAtMs ?? ''}',
          _csvCell(timeline.markerText),
        ].join(','),
      );
    }
    await File(outputPath).writeAsString(buffer.toString());
  }

  // ==================== 工具方法 ====================

  /// 本地路径转 file URI（匹配 PR 导出格式: file://localhost/ + percent-encoding）
  static String _toFileUri(String path) {
    final normalized = path.replaceAll('\\', '/');
    final encoded = _percentEncodePath(normalized);
    return 'file://localhost/$encoded';
  }

  /// Percent-encode 路径，保留 / 和 unreserved 字符
  static String _percentEncodePath(String path) {
    final buf = StringBuffer();
    for (int i = 0; i < path.length; i++) {
      final c = path.codeUnitAt(i);
      if ((c >= 0x41 && c <= 0x5A) || // A-Z
          (c >= 0x61 && c <= 0x7A) || // a-z
          (c >= 0x30 && c <= 0x39) || // 0-9
          c == 0x2D || // -
          c == 0x2E || // .
          c == 0x5F || // _
          c == 0x7E || // ~
          c == 0x2F) {
        // /
        buf.writeCharCode(c);
      } else {
        for (final b in utf8.encode(path.substring(i, i + 1))) {
          buf.write('%');
          buf.write(b.toRadixString(16).padLeft(2, '0'));
        }
      }
    }
    return buf.toString();
  }

  /// 毫秒转帧数 (round)
  static int _msToFrames(int ms) {
    return (ms * _fps / 1000).round();
  }

  /// 帧数转 FCPXML 时间码 (如 "758100/2400s")
  static String _framesToTimecode(int frames) {
    return '${frames * 100}/2400s';
  }

  /// SRT 时间格式化
  static String _formatSrtTime(int ms) {
    final h = (ms ~/ 3600000).toString().padLeft(2, '0');
    final m = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final millis = (ms % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$millis';
  }

  static String _csvCell(String value) {
    return '"${value.replaceAll('"', '""')}"';
  }
}
