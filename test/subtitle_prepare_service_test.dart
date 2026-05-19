import 'package:flutter_test/flutter_test.dart';

import 'package:asr_tools/services/subtitle_prepare_service.dart';

void main() {
  test('low-value short phrase gets strong penalty', () {
    final normalized = SubtitlePrepareService.normalizeTextForMatching('嗯');
    final multiplier = SubtitlePrepareService.lowValuePhraseMultiplier(
      normalized,
    );

    expect(normalized, '嗯');
    expect(multiplier, 0.25);
  });

  test('low-value short sentence gets moderate penalty', () {
    final normalized = SubtitlePrepareService.normalizeTextForMatching('好 啊');
    final multiplier = SubtitlePrepareService.lowValuePhraseMultiplier(
      normalized,
    );

    expect(multiplier, 0.4);
  });

  test('normal sentence keeps default weight', () {
    final normalized = SubtitlePrepareService.normalizeTextForMatching(
      '我们今天从船尾进去',
    );
    final multiplier = SubtitlePrepareService.lowValuePhraseMultiplier(
      normalized,
    );

    expect(multiplier, 1.0);
  });
}
