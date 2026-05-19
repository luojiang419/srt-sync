import 'package:flutter_test/flutter_test.dart';

import 'package:asr_tools/services/export_service.dart';

void main() {
  test(
    'sanitize export base name trims and replaces Windows invalid chars',
    () {
      final sanitized = ExportService.sanitizeExportBaseName(
        '  工程:测试?版本*1  ',
        fallbackName: '备用名称',
      );

      expect(sanitized, '工程_测试_版本_1');
    },
  );

  test('sanitize export base name falls back when input becomes empty', () {
    final sanitized = ExportService.sanitizeExportBaseName(
      '   ',
      fallbackName: '默认工程名',
    );

    expect(sanitized, '默认工程名');
  });

  test(
    'sanitize export base name falls back to ASR Timeline as last resort',
    () {
      final sanitized = ExportService.sanitizeExportBaseName(
        '///',
        fallbackName: ':::',
      );

      expect(sanitized, 'ASR Timeline');
    },
  );
}
