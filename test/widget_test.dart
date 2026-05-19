import 'package:flutter_test/flutter_test.dart';

import 'package:asr_tools/core/extensions.dart';
import 'package:asr_tools/models/media_file.dart';

void main() {
  test('string path helpers parse file names and extensions', () {
    const path = r'G:\data\clip\C0449.mp4';

    expect(path.fileName, 'C0449.mp4');
    expect(path.fileNameWithoutExtension, 'C0449');
    expect(path.fileExtension, '.mp4');
  });

  test(
    'media file copyWith updates subtitle status and preserves identity',
    () {
      final file = MediaFile(
        id: 'media-1',
        projectId: 'project-1',
        filePath: r'G:\data\audio\ZOOM0021_LR.mp3',
        type: MediaType.audio,
        durationMs: 1200,
        createdAt: DateTime(2026, 4, 23),
      );
      final updated = file.copyWith(subtitleStatus: SubtitleStatus.completed);

      expect(updated.id, file.id);
      expect(updated.projectId, file.projectId);
      expect(updated.subtitleStatus, SubtitleStatus.completed);
      expect(updated.filePath, file.filePath);
    },
  );

  test('media file toMap/fromMap preserves thumbnail path', () {
    final file = MediaFile(
      id: 'video-1',
      projectId: 'project-1',
      filePath: r'G:\data\video\C0001.mp4',
      type: MediaType.video,
      thumbnailPath: r'G:\data\thumbs\video-1.jpg',
      createdAt: DateTime(2026, 5, 20),
    );

    final restored = MediaFile.fromMap(file.toMap());

    expect(restored.thumbnailPath, r'G:\data\thumbs\video-1.jpg');
    expect(restored.filePath, file.filePath);
    expect(restored.type, MediaType.video);
  });
}
