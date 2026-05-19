import 'package:flutter_test/flutter_test.dart';

import 'package:asr_tools/models/sync_result.dart';

void main() {
  test('review status drives needsReview compatibility getter', () {
    final pending = SyncResult(
      id: 'sync-1',
      projectId: 'project-1',
      videoFileId: 'video-1',
      audioFileId: 'audio-1',
      videoDurationMs: 1200,
      timelineStartMs: 0,
      timelineEndMs: 1200,
      confidence: 0.8,
      status: SyncStatus.mediumConfidence,
      method: SyncMethod.subtitleOnly,
      reviewStatus: SyncReviewStatus.pending,
      createdAt: DateTime(2026, 5, 18),
    );
    final accepted = pending.copyWith(
      reviewStatus: SyncReviewStatus.accepted,
      reviewedAtMs: 123456,
    );

    expect(pending.needsReview, isTrue);
    expect(accepted.needsReview, isFalse);
    expect(accepted.reviewedAtMs, 123456);
  });
}
