/// 通用扩展方法
extension StringExtension on String {
  /// 文件名（不含扩展名）
  String get fileNameWithoutExtension {
    final lastSlash = lastIndexOf(RegExp(r'[/\\]'));
    final name = lastSlash >= 0 ? substring(lastSlash + 1) : this;
    final lastDot = name.lastIndexOf('.');
    return lastDot >= 0 ? name.substring(0, lastDot) : name;
  }

  /// 文件扩展名（小写，含点）
  String get fileExtension {
    final lastDot = lastIndexOf('.');
    if (lastDot < 0) return '';
    return substring(lastDot).toLowerCase();
  }

  /// 仅文件名（含扩展名）
  String get fileName {
    final lastSlash = lastIndexOf(RegExp(r'[/\\]'));
    return lastSlash >= 0 ? substring(lastSlash + 1) : this;
  }
}

extension IntExtension on int {
  /// 毫秒转可读时长 (mm:ss 或 hh:mm:ss)
  String get toReadableDuration {
    final totalSeconds = this ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

extension DoubleExtension on double {
  /// 秒转毫秒
  int get secToMs => (this * 1000).round();

  /// 保留指定小数位百分比显示
  String toPercent([int fractionDigits = 1]) =>
      '${(this * 100).toStringAsFixed(fractionDigits)}%';
}
