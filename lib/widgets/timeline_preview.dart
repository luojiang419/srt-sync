import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/timeline_data.dart';

class TimelinePreview extends StatelessWidget {
  final List<TimelineData> timelineList;

  const TimelinePreview({super.key, required this.timelineList});

  @override
  Widget build(BuildContext context) {
    if (timelineList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline, size: 48, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('暂无时间线数据', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'V1 / A1 合板预览',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: timelineList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _TimelineRow(index: index, timeline: timelineList[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final int index;
  final TimelineData timeline;

  const _TimelineRow({required this.index, required this.timeline});

  @override
  Widget build(BuildContext context) {
    final statusColor = timeline.needsReview
        ? AppTheme.warning
        : AppTheme.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1}'.padLeft(2, '0'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  timeline.videoFileName,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Pill(label: timeline.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          _TrackBar(
            title: 'V1',
            color: AppTheme.accent,
            label:
                '${_formatMs(timeline.timelineStartMs)} - ${_formatMs(timeline.timelineEndMs)}',
          ),
          const SizedBox(height: 6),
          _TrackBar(
            title: 'A1',
            color: AppTheme.highlight,
            label: timeline.audioFileId == null
                ? '未匹配音频'
                : '${timeline.audioFileName} | ${_formatMs(timeline.audioTrimStartMs)} - ${_formatMs(timeline.audioTrimEndMs)}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Meta(
                label: '置信度',
                value: '${(timeline.confidence * 100).toStringAsFixed(0)}%',
              ),
              _Meta(label: '锚点', value: '${timeline.anchorCount}'),
              _Meta(label: '视频字幕', value: '${timeline.videoSubtitles.length}'),
              _Meta(label: '音频字幕', value: '${timeline.audioSubtitles.length}'),
              if (timeline.sourceClamped) _Meta(label: '越界', value: '已修正'),
              if (timeline.audioTooShort) _Meta(label: '音频', value: '过短'),
            ],
          ),
          if (timeline.markerText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              timeline.markerText,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMs(int ms) {
    final h = (ms ~/ 3600000).toString().padLeft(2, '0');
    final m = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _TrackBar extends StatelessWidget {
  final String title;
  final Color color;
  final String label;

  const _TrackBar({
    required this.title,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            title,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 16,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final String label;
  final String value;

  const _Meta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
