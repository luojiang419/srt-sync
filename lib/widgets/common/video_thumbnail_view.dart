import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class VideoThumbnailView extends StatelessWidget {
  final String? thumbnailPath;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const VideoThumbnailView({
    super.key,
    required this.thumbnailPath,
    this.width = 92,
    this.height = 52,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  Widget build(BuildContext context) {
    final path = thumbnailPath?.trim();
    final thumbnailFile = path == null || path.isEmpty ? null : File(path);
    late final Widget child;
    if (thumbnailFile != null && thumbnailFile.existsSync()) {
      child = Image.file(
        thumbnailFile,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) =>
            _ThumbnailPlaceholder(width: width, height: height),
      );
    } else {
      child = _ThumbnailPlaceholder(width: width, height: height);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.accent,
          borderRadius: borderRadius,
          border: Border.all(color: AppTheme.border),
        ),
        child: child,
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  final double width;
  final double height;

  const _ThumbnailPlaceholder({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: height * 0.45,
          color: AppTheme.textSecondary.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
