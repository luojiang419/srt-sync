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

  test('media file copyWith updates subtitle status and preserves identity', () {
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
  });
}
