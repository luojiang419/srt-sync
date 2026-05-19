import 'package:flutter_test/flutter_test.dart';

import 'package:asr_tools/core/constants.dart';
import 'package:asr_tools/services/subtitle_match_service.dart';

void main() {
  test('cheap prefilter rejects very different lengths', () {
    final passed = SubtitleMatchService.passesCheapPrefilter('我们今天从船尾进去', '好');

    expect(passed, isFalse);
  });

  test('cheap prefilter rejects strings without shared bigrams', () {
    final passed = SubtitleMatchService.passesCheapPrefilter(
      '今天上船拍摄',
      '完全不同内容',
    );

    expect(passed, isFalse);
  });

  test('limited candidate bucket drops low scores when over budget', () {
    final bucket = LimitedCandidateBucket<int>(
      perWindowLimit: 2,
      totalLimit: 3,
    );

    bucket.add(windowKey: 'w1', value: 10, score: 0.20);
    bucket.add(windowKey: 'w1', value: 11, score: 0.50);
    bucket.add(windowKey: 'w1', value: 12, score: 0.40);
    bucket.add(windowKey: 'w2', value: 20, score: 0.30);
    bucket.add(windowKey: 'w2', value: 21, score: 0.80);

    final scores = bucket.entriesSortedByScoreDesc
        .map((entry) => entry.score)
        .toList();

    expect(bucket.countForWindow('w1'), lessThanOrEqualTo(2));
    expect(bucket.totalCount, lessThanOrEqualTo(3));
    expect(scores, containsAll([0.80, 0.50, 0.40]));
    expect(scores, isNot(contains(0.20)));
  });

  test('anchor local search prefers candidates near fallback offset', () {
    final candidates = SubtitleMatchService.selectAnchorCandidateLocalStarts(
      videoLocalStartMs: 10000,
      audioLocalStartMs: [12000, 55000, 130000],
      fallbackOffsetMs: 2000,
      radiusMs: AppConstants.anchorSearchRadiusMs,
    );

    expect(candidates, [12000, 55000]);
  });

  test(
    'anchor local search falls back to full list when local hit is absent',
    () {
      final candidates = SubtitleMatchService.selectAnchorCandidateLocalStarts(
        videoLocalStartMs: 10000,
        audioLocalStartMs: [180000, 240000],
        fallbackOffsetMs: 2000,
        radiusMs: 1000,
      );

      expect(candidates, [180000, 240000]);
    },
  );
}
