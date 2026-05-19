import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:asr_tools/models/asr_project.dart';
import 'package:asr_tools/models/media_file.dart';
import 'package:asr_tools/models/sync_result.dart';
import 'package:asr_tools/services/audio_align_service.dart';
import 'package:asr_tools/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio-align-test-');
    await DatabaseService.init(
      overridePath: p.join(tempDir.path, 'audio-align-test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'buildTimeline carries embedded audio visibility from source video',
    () async {
      final now = DateTime(2026, 5, 20, 10);
      final project = AsrProject(
        id: 'project-1',
        name: '测试工程',
        createdAt: now,
        updatedAt: now,
      );
      await DatabaseService.insertProject(project);
      await DatabaseService.insertMediaFiles([
        MediaFile(
          id: 'video-1',
          projectId: project.id,
          filePath: r'G:\video\C0001.mp4',
          type: MediaType.video,
          durationMs: 4000,
          hasEmbeddedAudio: true,
          createdAt: now,
        ),
        MediaFile(
          id: 'audio-1',
          projectId: project.id,
          filePath: r'G:\audio\A0001.wav',
          type: MediaType.audio,
          durationMs: 5000,
          createdAt: now,
        ),
      ]);
      await DatabaseService.replaceSyncResults(project.id, [
        SyncResult(
          id: 'sync-1',
          projectId: project.id,
          videoFileId: 'video-1',
          audioFileId: 'audio-1',
          videoDurationMs: 4000,
          timelineStartMs: 0,
          timelineEndMs: 4000,
          audioSourceInMs: 300,
          audioSourceOutMs: 4300,
          confidence: 0.9,
          status: SyncStatus.autoAccepted,
          method: SyncMethod.subtitleOnly,
          createdAt: now,
        ),
      ]);

      final timelineList = await AudioAlignService.buildTimeline(project.id);

      expect(timelineList, hasLength(1));
      expect(timelineList.first.videoHasEmbeddedAudio, isTrue);
      expect(timelineList.first.audioFilePath, r'G:\audio\A0001.wav');
    },
  );
}
