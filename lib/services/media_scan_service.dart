import 'dart:io';

import '../core/constants.dart';
import '../core/extensions.dart';
import '../models/media_file.dart';

/// 扫描结果
class ScannedFile {
  final String path;
  final String name;
  final String extension;

  const ScannedFile({
    required this.path,
    required this.name,
    required this.extension,
  });
}

/// 媒体文件目录扫描服务
class MediaScanService {
  MediaScanService._();

  /// 扫描目录，返回匹配扩展名的文件列表
  static Future<List<ScannedFile>> scanDirectory(
    String directoryPath,
    MediaType type,
  ) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw Exception('目录不存在: $directoryPath');
    }

    final extensions = type == MediaType.video
        ? AppConstants.videoExtensions
        : AppConstants.audioExtensions;

    final results = <ScannedFile>[];

    await for (final entity in dir.list(recursive: true, followLinks: true)) {
      if (entity is File) {
        final ext = entity.path.fileExtension;
        if (extensions.contains(ext)) {
          results.add(
            ScannedFile(
              path: entity.path,
              name: entity.path.fileName,
              extension: ext,
            ),
          );
        }
      }
    }

    // 按文件名排序
    results.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return results;
  }
}
