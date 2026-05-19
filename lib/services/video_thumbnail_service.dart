import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/media_file.dart';
import 'app_data_service.dart';
import 'ffmpeg_service.dart';

class VideoThumbnailService {
  VideoThumbnailService._();

  static const int _defaultCaptureMs = 1000;
  static const int _targetWidth = 240;

  static Future<String> thumbnailPathFor(MediaFile file) async {
    final dir = await AppDataService.projectThumbnailDirectory(file.projectId);
    return p.join(dir.path, '${file.id}.jpg');
  }

  static Future<String?> ensureThumbnail(MediaFile file) async {
    if (file.type != MediaType.video) {
      return null;
    }

    final declaredPath = file.thumbnailPath?.trim();
    if (declaredPath != null &&
        declaredPath.isNotEmpty &&
        File(declaredPath).existsSync()) {
      return declaredPath;
    }

    final canonicalPath = await thumbnailPathFor(file);
    if (File(canonicalPath).existsSync()) {
      return canonicalPath;
    }

    if (!File(file.filePath).existsSync() || !FfmpegService.isConfigured) {
      return null;
    }

    final outputFile = File(canonicalPath);
    await outputFile.parent.create(recursive: true);

    final durationMs = file.durationMs ?? 0;
    final captureMs = durationMs > _defaultCaptureMs ? _defaultCaptureMs : 0;

    try {
      await FfmpegService.extractVideoThumbnail(
        inputPath: file.filePath,
        outputPath: outputFile.path,
        positionMs: captureMs,
        targetWidth: _targetWidth,
      );
      if (await outputFile.exists()) {
        return outputFile.path;
      }
    } catch (_) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
    }

    return null;
  }

  static Future<void> deleteProjectCache(String projectId) async {
    await AppDataService.deleteProjectDirectory(projectId);
  }
}
