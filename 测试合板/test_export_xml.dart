// 测试脚本：生成修正后的 FCPXML + Premiere Pro XML (xmeml)
// 修复：1) 帧重叠 2) DaVinci 兼容性 3) pathurl 格式匹配 PR
// 运行: dart run 测试合板/test_export_xml.dart

import 'dart:convert';
import 'dart:io';

const videoDir = r'G:\data\260224-元数据脚本测试\1_Video\220822shipin';
const audioDir = r'G:\data\260224-元数据脚本测试\2_Audio\220822yinpin';
const ffmpegDir = r'G:\data\app\DIT\ffmpeg\bin';
const fps = 24;

void main() async {
  // 1. 获取文件列表和时长
  final videoFiles = _listFiles(videoDir, '.mp4');
  final audioFiles = _listFiles(audioDir, '.mp3');

  print('=== 获取文件时长 ===');
  final videoDurations = <String, int>{}; // name -> ms
  final audioDurations = <String, int>{};

  for (final f in videoFiles) {
    final name = _basename(f);
    final ms = await _getDurationMs(f);
    videoDurations[name] = ms;
    print('  视频: $name => ${_msToTime(ms)}');
  }
  for (final f in audioFiles) {
    final name = _basename(f);
    final ms = await _getDurationMs(f);
    audioDurations[name] = ms;
    print('  音频: $name => ${_msToTime(ms)}');
  }

  // 2. 按时长相似度匹配（与 subtitle_match_service.dart 同逻辑）
  print('\n=== 匹配视频-音频 ===');
  final matches = _matchByDuration(videoDurations, audioDurations);
  for (final m in matches) {
    print('  ${m.video} <-> ${m.audio}  时长相似度 ${(m.similarity * 100).toStringAsFixed(0)}%');
  }

  // 3. 生成修正后的 FCPXML
  final fcpxml = _generateFcpxml(matches);
  await File(r'测试合板\asr_timeline_fixed.fcpxml').writeAsString(fcpxml);
  print('\n已导出: 测试合板/asr_timeline_fixed.fcpxml');

  // 4. 生成 Premiere Pro XML (xmeml) - DaVinci 原生支持
  final xmeml = _generateXmeml(matches);
  await File(r'测试合板\asr_timeline_v2.xml').writeAsString(xmeml);
  print('已导出: 测试合板/asr_timeline_v2.xml (xmeml 格式，修复路径)');

  print('\n完成！建议用 DaVinci 导入 xmeml 格式的 asr_timeline.xml');
}

// ==================== 匹配 ====================

class _Match {
  final String video;
  final String audio;
  final int videoDurationMs;
  final int audioDurationMs;
  final double similarity;
  _Match(this.video, this.audio, this.videoDurationMs, this.audioDurationMs, this.similarity);
}

List<_Match> _matchByDuration(Map<String, int> videos, Map<String, int> audios) {
  final scores = <(String, String, int, int, double)>[];
  for (final v in videos.entries) {
    for (final a in audios.entries) {
      final sim = _durationSimilarity(v.value, a.value);
      scores.add((v.key, a.key, v.value, a.value, sim));
    }
  }
  // 贪心分配
  scores.sort((a, b) => b.$5.compareTo(a.$5));
  final usedV = <String>{}, usedA = <String>{};
  final result = <_Match>[];
  for (final s in scores) {
    if (usedV.contains(s.$1) || usedA.contains(s.$2)) continue;
    if (s.$5 < 0.3) continue;
    result.add(_Match(s.$1, s.$2, s.$3, s.$4, s.$5));
    usedV.add(s.$1);
    usedA.add(s.$2);
  }
  return result;
}

double _durationSimilarity(int d1, int d2) {
  if (d1 == 0 || d2 == 0) return 0;
  final diff = (d1 - d2).abs();
  final maxD = d1 > d2 ? d1 : d2;
  return (1.0 - diff / maxD).clamp(0.0, 1.0);
}

// ==================== FCPXML (修正版) ====================

String _generateFcpxml(List<_Match> matches) {
  final buf = StringBuffer();
  buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buf.writeln('<fcpxml version="1.8">');
  buf.writeln('  <resources>');

  // Format
  buf.writeln('    <format id="f1" name="FFVideoFormat1080p24" frameDuration="100/2400s" width="1920" height="1080"/>');

  // Assets
  for (final m in matches) {
    final vPath = _toFileUri('$videoDir\\${m.video}');
    final aPath = _toFileUri('$audioDir\\${m.audio}');
    buf.writeln('    <asset id="a_${m.video}" name="${m.video}" src="$vPath" hasVideo="1" hasAudio="1">');
    buf.writeln('      <media-rep kind="original-media" src="$vPath"/>');
    buf.writeln('    </asset>');
    buf.writeln('    <asset id="a_${m.audio}" name="${m.audio}" src="$aPath" hasVideo="0" hasAudio="1">');
    buf.writeln('      <media-rep kind="original-media" src="$aPath"/>');
    buf.writeln('    </asset>');
  }

  buf.writeln('  </resources>');
  buf.writeln('  <library location="">');
  buf.writeln('    <event name="ASR Timeline">');
  buf.writeln('      <project name="ASR Timeline">');

  // 计算总时长
  int totalMs = 0;
  for (final m in matches) {
    totalMs += m.videoDurationMs;
  }

  buf.writeln('        <sequence format="f1" duration="${_msToFcpxmlTime(totalMs)}" tcStart="0s" tcFormat="NDF">');

  // 主视频轨道 (spine)
  buf.writeln('          <spine>');
  int cumMs = 0;
  for (final m in matches) {
    // 修正: 用累积毫秒数转帧，而非累加帧数
    final offsetFrames = _msToFramesFloor(cumMs);
    final durFrames = _msToFramesFloor(m.videoDurationMs);
    buf.writeln('            <asset-clip ref="a_${m.video}" name="${m.video}" '
        'offset="${_framesToFcpxml(offsetFrames)}" '
        'duration="${_framesToFcpxml(durFrames)}" '
        'start="${_framesToFcpxml(0)}"/>');
    cumMs += m.videoDurationMs;
  }
  buf.writeln('          </spine>');

  // 音频轨道 (直接放在 sequence 下，不用 lane 包裹)
  cumMs = 0;
  for (final m in matches) {
    final audioOffsetFrames = _msToFramesFloor(cumMs);
    final audioDurFrames = _msToFramesFloor(m.audioDurationMs);
    buf.writeln('          <asset-clip ref="a_${m.audio}" name="${m.audio}" '
        'offset="${_framesToFcpxml(audioOffsetFrames)}" '
        'duration="${_framesToFcpxml(audioDurFrames)}" '
        'start="${_framesToFcpxml(0)}"/>');
    cumMs += m.videoDurationMs;
  }

  buf.writeln('        </sequence>');
  buf.writeln('      </project>');
  buf.writeln('    </event>');
  buf.writeln('  </library>');
  buf.writeln('</fcpxml>');
  return buf.toString();
}

// ==================== Premiere Pro XML (xmeml) - DaVinci 原生支持 ====================

String _generateXmeml(List<_Match> matches) {
  final buf = StringBuffer();

  // 为每个 clip 分配唯一 id（参考 DaVinci 格式: "FileName N"）
  int idSeq = 0;
  final videoClipIds = <String, String>{};
  final audioClipIds = <String, String>{};
  final videoFileIds = <String, String>{};
  final audioFileIds = <String, String>{};

  for (final m in matches) {
    final base = m.video.replaceAll('.', '_');
    videoClipIds[m.video] = '$base $idSeq'; idSeq++;
    videoFileIds[m.video] = '$base $idSeq'; idSeq++;
    audioClipIds[m.video] = '$base $idSeq'; idSeq++;
    final aBase = m.audio.replaceAll('.', '_');
    audioFileIds[m.video] = '$aBase $idSeq'; idSeq++;
  }

  // 计算视频轨道位置
  int currentFrame = 0;
  final videoPositions = <String, int>{};
  for (final m in matches) {
    videoPositions[m.video] = currentFrame;
    currentFrame += _msToFramesRound(m.videoDurationMs);
  }
  final totalDuration = currentFrame;

  buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  buf.writeln('<!DOCTYPE xmeml>');
  buf.writeln('<xmeml version="5">');
  buf.writeln('  <sequence>');
  buf.writeln('    <name>ASR Timeline</name>');
  buf.writeln('    <duration>$totalDuration</duration>');
  buf.writeln('    <rate>');
  buf.writeln('      <timebase>$fps</timebase>');
  buf.writeln('      <ntsc>FALSE</ntsc>');
  buf.writeln('    </rate>');
  buf.writeln('    <in>-1</in>');
  buf.writeln('    <out>-1</out>');
  buf.writeln('    <timecode>');
  buf.writeln('      <string>01:00:00:00</string>');
  buf.writeln('      <frame>90000</frame>');
  buf.writeln('      <displayformat>NDF</displayformat>');
  buf.writeln('      <rate>');
  buf.writeln('        <timebase>$fps</timebase>');
  buf.writeln('        <ntsc>FALSE</ntsc>');
  buf.writeln('      </rate>');
  buf.writeln('    </timecode>');
  buf.writeln('    <media>');

  // ---- Video Track ----
  buf.writeln('      <video>');
  buf.writeln('        <track>');

  for (final m in matches) {
    final startFrame = videoPositions[m.video]!;
    final durFrames = _msToFramesRound(m.videoDurationMs);
    final endFrame = startFrame + durFrames;
    final clipId = videoClipIds[m.video]!;
    final fileId = videoFileIds[m.video]!;
    final audioClipId = audioClipIds[m.video]!;
    final vPath = _toFileUri('$videoDir\\${m.video}');

    buf.writeln('          <clipitem id="$clipId">');
    buf.writeln('            <name>${m.video}</name>');
    buf.writeln('            <duration>$durFrames</duration>');
    buf.writeln('            <rate>');
    buf.writeln('              <timebase>$fps</timebase>');
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
    buf.writeln('                <timebase>$fps</timebase>');
    buf.writeln('                <ntsc>FALSE</ntsc>');
    buf.writeln('              </rate>');
    buf.writeln('              <name>${m.video}</name>');
    buf.writeln('              <pathurl>$vPath</pathurl>');
    buf.writeln('              <timecode>');
    buf.writeln('                <string>01:00:00:00</string>');
    buf.writeln('                <displayformat>NDF</displayformat>');
    buf.writeln('                <rate>');
    buf.writeln('                  <timebase>$fps</timebase>');
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
    buf.writeln('            <link>');
    buf.writeln('              <linkclipref>$audioClipId</linkclipref>');
    buf.writeln('            </link>');
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
  buf.writeln('              <timebase>$fps</timebase>');
  buf.writeln('              <ntsc>FALSE</ntsc>');
  buf.writeln('            </rate>');
  buf.writeln('          </samplecharacteristics>');
  buf.writeln('        </format>');
  buf.writeln('      </video>');

  // ---- Audio Track (所有音频在同一个 track) ----
  buf.writeln('      <audio>');
  buf.writeln('        <track>');

  for (final m in matches) {
    final startFrame = videoPositions[m.video]!;
    final durFrames = _msToFramesRound(m.audioDurationMs);
    final endFrame = startFrame + durFrames;
    final audioClipId = audioClipIds[m.video]!;
    final videoClipId = videoClipIds[m.video]!;
    final audioFileId = audioFileIds[m.video]!;
    final aPath = _toFileUri('$audioDir\\${m.audio}');

    buf.writeln('          <clipitem id="$audioClipId">');
    buf.writeln('            <name>${m.audio}</name>');
    buf.writeln('            <duration>$durFrames</duration>');
    buf.writeln('            <rate>');
    buf.writeln('              <timebase>$fps</timebase>');
    buf.writeln('              <ntsc>FALSE</ntsc>');
    buf.writeln('            </rate>');
    buf.writeln('            <start>$startFrame</start>');
    buf.writeln('            <end>$endFrame</end>');
    buf.writeln('            <enabled>TRUE</enabled>');
    buf.writeln('            <in>0</in>');
    buf.writeln('            <out>$durFrames</out>');
    buf.writeln('            <file id="$audioFileId">');
    buf.writeln('              <duration>$durFrames</duration>');
    buf.writeln('              <rate>');
    buf.writeln('                <timebase>$fps</timebase>');
    buf.writeln('                <ntsc>FALSE</ntsc>');
    buf.writeln('              </rate>');
    buf.writeln('              <name>${m.audio}</name>');
    buf.writeln('              <pathurl>$aPath</pathurl>');
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
  buf.writeln('      </audio>');
  buf.writeln('    </media>');
  buf.writeln('  </sequence>');
  buf.writeln('</xmeml>');
  return buf.toString();
}

// ==================== 工具方法 ====================

/// 毫秒转帧数 (floor，防止重叠)
int _msToFramesFloor(int ms) => (ms * fps / 1000).floor();

/// 毫秒转帧数 (round，用于 xmeml)
int _msToFramesRound(int ms) => (ms * fps / 1000).round();

/// 帧数转 FCPXML 时间码 (如 "758100/2400s")
String _framesToFcpxml(int frames) => '${frames * 100}/2400s';

/// 毫秒转 FCPXML 时间码
String _msToFcpxmlTime(int ms) => _framesToFcpxml(_msToFramesFloor(ms));

/// 本地路径转 file URI（匹配 PR 导出格式: file://localhost/ + percent-encoding）
String _toFileUri(String path) {
  final normalized = path.replaceAll('\\', '/');
  final encoded = _percentEncodePath(normalized);
  return 'file://localhost/$encoded';
}

/// Percent-encode 路径，保留 / 和 unreserved 字符
String _percentEncodePath(String path) {
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
        c == 0x2F) { // /
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

/// 获取文件时长 (毫秒)
Future<int> _getDurationMs(String filePath) async {
  final result = await Process.run(
    '$ffmpegDir/ffprobe.exe',
    ['-v', 'quiet', '-show_entries', 'format=duration',
     '-of', 'default=noprint_wrappers=1:nokey=1', filePath],
    stdoutEncoding: const SystemEncoding(),
    stderrEncoding: const SystemEncoding(),
  );
  if (result.exitCode != 0) throw Exception('ffprobe failed: ${result.stderr}');
  final sec = double.tryParse((result.stdout as String).trim());
  if (sec == null) throw Exception('Cannot parse duration: ${result.stdout}');
  return (sec * 1000).round();
}

/// 毫秒转可读时间
String _msToTime(int ms) {
  final s = ms / 1000;
  return '${s.toStringAsFixed(2)}s';
}

/// 列出目录中的文件
List<String> _listFiles(String dir, String ext) {
  return Directory(dir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith(ext))
      .map((f) => f.path)
      .toList()
    ..sort();
}

/// 获取文件名
String _basename(String path) => path.split(RegExp(r'[/\\]')).last;
