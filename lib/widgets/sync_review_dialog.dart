import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_theme.dart';
import '../models/subtitle_clip.dart';
import '../models/sync_review_detail.dart';
import '../models/sync_result.dart';
import '../providers/match_provider.dart';
import '../services/subtitle_match_service.dart';
import '../services/subtitle_prepare_service.dart';

enum _SubtitlePanelMode { fullTranscript, keywordList }

enum SyncReviewDialogSequenceMode { pending, all, accepted, rejected }

class SyncReviewDialog extends ConsumerStatefulWidget {
  final String projectId;
  final String syncResultId;
  final List<String> reviewSequenceIds;
  final int initialIndex;
  final SyncReviewDialogSequenceMode sequenceMode;
  final Future<ManualAnchorMatchPreview> Function({
    required String projectId,
    required String videoClipId,
    required String aggregateAudioClipId,
  })?
  previewResolver;

  const SyncReviewDialog({
    super.key,
    required this.projectId,
    required this.syncResultId,
    required this.reviewSequenceIds,
    required this.initialIndex,
    required this.sequenceMode,
    this.previewResolver,
  });

  @override
  ConsumerState<SyncReviewDialog> createState() => _SyncReviewDialogState();
}

class _SyncReviewDialogState extends ConsumerState<SyncReviewDialog> {
  final ScrollController _videoController = ScrollController();
  final ScrollController _audioController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _dialogFocusNode = FocusNode(debugLabel: 'syncReviewDialog');
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'syncReviewSearch');
  final Map<String, GlobalKey> _videoItemKeys = {};
  final Map<String, GlobalKey> _audioItemKeys = {};

  late List<String> _reviewSequenceIds;
  late String _currentSyncResultId;
  late int _currentSequenceIndex;

  List<ReviewAnchorJumpTarget> _resolvedReviewAnchors = const [];
  List<SubtitleClip> _latestVideoClips = const [];
  List<SubtitleClip> _latestAggregateAudioClips = const [];
  String _searchQuery = '';
  String? _selectedVideoClipId;
  String? _selectedAggregateAudioClipId;
  _SubtitlePanelMode _videoPanelMode = _SubtitlePanelMode.fullTranscript;
  _SubtitlePanelMode _audioPanelMode = _SubtitlePanelMode.fullTranscript;
  int? _currentAnchorCycleIndex;
  ManualAnchorMatchPreview? _manualPreview;
  bool _isPreviewLoading = false;
  bool _isHandlingAction = false;
  int _previewRequestId = 0;

  @override
  void initState() {
    super.initState();
    final normalizedIds = widget.reviewSequenceIds
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: true);
    if (!normalizedIds.contains(widget.syncResultId)) {
      normalizedIds.add(widget.syncResultId);
    }
    if (normalizedIds.isEmpty) {
      normalizedIds.add(widget.syncResultId);
    }

    _reviewSequenceIds = List.unmodifiable(normalizedIds);
    final currentIndex = _reviewSequenceIds.indexOf(widget.syncResultId);
    final fallbackIndex = widget.initialIndex.clamp(
      0,
      _reviewSequenceIds.length - 1,
    );
    _currentSequenceIndex = currentIndex == -1 ? fallbackIndex : currentIndex;
    _currentSyncResultId = _reviewSequenceIds[_currentSequenceIndex];
  }

  @override
  void dispose() {
    _videoController.dispose();
    _audioController.dispose();
    _searchController.dispose();
    _dialogFocusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      syncReviewDetailProvider(_currentSyncResultId),
    );

    return Focus(
      autofocus: true,
      focusNode: _dialogFocusNode,
      onKeyEvent: _handleDialogKeyEvent,
      child: Dialog(
        insetPadding: const EdgeInsets.all(28),
        child: Container(
          width: 1240,
          height: 820,
          padding: const EdgeInsets.all(20),
          child: detailAsync.when(
            data: (detail) {
              if (detail == null) {
                return Center(
                  child: Text(
                    '当前结果不存在或已被移除。',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                );
              }
              return _buildContent(context, detail);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleDialogKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isHandlingAction) {
        return KeyEventResult.handled;
      }
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    if (_searchFocusNode.hasFocus || _isHandlingAction) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_canGoPrevious) {
        _goToPreviousResult();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_canGoNext) {
        _goToNextResult();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  Widget _buildContent(BuildContext context, SyncReviewDetail detail) {
    _latestVideoClips = detail.videoSubtitles;
    _latestAggregateAudioClips = detail.aggregateAudioSubtitles;
    final videoMatchedClips = _matchedClips(detail.videoSubtitles);
    final audioMatchedClips = _matchedClips(detail.aggregateAudioSubtitles);
    final resolvedReviewAnchors = SubtitleMatchService.resolveReviewAnchors(
      detail,
    );
    _resolvedReviewAnchors = resolvedReviewAnchors;
    if (resolvedReviewAnchors.isEmpty) {
      _currentAnchorCycleIndex = null;
    } else if (_currentAnchorCycleIndex != null &&
        _currentAnchorCycleIndex! >= resolvedReviewAnchors.length) {
      _currentAnchorCycleIndex = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, detail, resolvedReviewAnchors),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _chip(
              '置信度',
              '${(detail.syncResult.confidence * 100).toStringAsFixed(0)}%',
              AppTheme.highlight,
            ),
            _chip(
              '复核状态',
              detail.syncResult.reviewStatus.label,
              _reviewColor(detail.syncResult.reviewStatus),
            ),
            _chip(
              '结果状态',
              detail.syncResult.status.label,
              _statusColor(detail.syncResult.status),
            ),
            _chip('方法', detail.syncResult.method.label, AppTheme.accent),
            _chip('锚点', '${detail.syncResult.anchorCount}', AppTheme.success),
            _chip(
              'Source In',
              detail.syncResult.audioSourceInMs == null
                  ? '--'
                  : _formatTime(detail.syncResult.audioSourceInMs!),
              AppTheme.textSecondary,
            ),
            _chip(
              'Source Out',
              detail.syncResult.audioSourceOutMs == null
                  ? '--'
                  : _formatTime(detail.syncResult.audioSourceOutMs!),
              AppTheme.textSecondary,
            ),
          ],
        ),
        if ((detail.syncResult.notes ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            detail.syncResult.notes!,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildSubtitlePanel(
                  title: '视频字幕',
                  subtitleName: p.basename(detail.videoFile.filePath),
                  allClips: detail.videoSubtitles,
                  matchedClips: videoMatchedClips,
                  controller: _videoController,
                  itemKeys: _videoItemKeys,
                  mode: _videoPanelMode,
                  selectedClipId: _selectedVideoClipId,
                  emptyText: '当前视频没有可用字幕',
                  keywordEmptyText: '未找到包含该关键词的视频字幕',
                  useGlobalTime: false,
                  onSelect: (clip) => _selectVideoClip(clip.id),
                  onKeywordSelect: (clip) =>
                      _openVideoKeywordResult(detail.videoSubtitles, clip.id),
                  onReturnToKeywordList:
                      _hasActiveSearch &&
                          videoMatchedClips.isNotEmpty &&
                          _videoPanelMode == _SubtitlePanelMode.fullTranscript
                      ? _showVideoKeywordList
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSubtitlePanel(
                  title: '音频总字幕',
                  subtitleName: detail.aggregateAudioSubtitleFile == null
                      ? '未检测到音频总字幕文件'
                      : p.basename(detail.aggregateAudioSubtitleFile!.filePath),
                  allClips: detail.aggregateAudioSubtitles,
                  matchedClips: audioMatchedClips,
                  controller: _audioController,
                  itemKeys: _audioItemKeys,
                  mode: _audioPanelMode,
                  selectedClipId: _selectedAggregateAudioClipId,
                  emptyText: detail.aggregateAudioSubtitleFile == null
                      ? '当前工程没有可用的音频总字幕文件'
                      : '音频总字幕文件里没有可显示的条目',
                  keywordEmptyText: '未找到包含该关键词的音频字幕',
                  useGlobalTime: true,
                  onSelect: (clip) => _selectAggregateAudioClip(clip.id),
                  onKeywordSelect: (clip) => _openAudioKeywordResult(
                    detail.aggregateAudioSubtitles,
                    clip.id,
                  ),
                  onReturnToKeywordList:
                      _hasActiveSearch &&
                          audioMatchedClips.isNotEmpty &&
                          _audioPanelMode == _SubtitlePanelMode.fullTranscript
                      ? _showAudioKeywordList
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSearchBar(videoMatchedClips.length, audioMatchedClips.length),
        const SizedBox(height: 16),
        _buildPreviewPanel(detail),
        const SizedBox(height: 16),
        _buildActionBar(context, detail),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SyncReviewDetail detail,
    List<ReviewAnchorJumpTarget> resolvedReviewAnchors,
  ) {
    final videoName = p.basename(detail.videoFile.filePath);
    final audioName = detail.audioFile == null
        ? '未匹配音频'
        : p.basename(detail.audioFile!.filePath);
    final aggregateName = detail.aggregateAudioSubtitleFile == null
        ? '未检测到音频总字幕'
        : p.basename(detail.aggregateAudioSubtitleFile!.filePath);
    final canJumpToAnchor =
        !_isHandlingAction && resolvedReviewAnchors.isNotEmpty;
    final anchorLabel = resolvedReviewAnchors.isEmpty
        ? '合板锚点'
        : '合板锚点 ${_anchorDisplayIndex(resolvedReviewAnchors.length)}/${resolvedReviewAnchors.length}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '合板详情与复核',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$videoName  <->  $audioName',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '总字幕: $aggregateName',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '素材 $_sequenceDisplayIndex/$_sequenceDisplayTotal',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _canGoPrevious ? _goToPreviousResult : null,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('上一条'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _canGoNext ? _goToNextResult : null,
          icon: const Icon(Icons.arrow_forward, size: 16),
          label: const Text('下一条'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: canJumpToAnchor ? _jumpToNextResolvedAnchor : null,
          icon: const Icon(Icons.my_location, size: 16),
          label: Text(anchorLabel),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _isHandlingAction
              ? null
              : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }

  Widget _buildSubtitlePanel({
    required String title,
    required String subtitleName,
    required List<SubtitleClip> allClips,
    required List<SubtitleClip> matchedClips,
    required ScrollController controller,
    required Map<String, GlobalKey> itemKeys,
    required _SubtitlePanelMode mode,
    required String? selectedClipId,
    required String emptyText,
    required String keywordEmptyText,
    required bool useGlobalTime,
    required ValueChanged<SubtitleClip> onSelect,
    required ValueChanged<SubtitleClip> onKeywordSelect,
    required VoidCallback? onReturnToKeywordList,
  }) {
    final displayClips = mode == _SubtitlePanelMode.keywordList
        ? matchedClips
        : allClips;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              subtitleName,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_hasActiveSearch &&
              (mode == _SubtitlePanelMode.keywordList ||
                  matchedClips.isNotEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: mode == _SubtitlePanelMode.keywordList
                  ? Text(
                      '关键词结果 ${matchedClips.length} 条',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onReturnToKeywordList,
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('返回关键词列表'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
            ),
          Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: displayClips.isEmpty
                ? Center(
                    child: Text(
                      mode == _SubtitlePanelMode.keywordList
                          ? keywordEmptyText
                          : emptyText,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: displayClips.length,
                    itemBuilder: (context, index) {
                      final clip = displayClips[index];
                      final key = mode == _SubtitlePanelMode.fullTranscript
                          ? itemKeys.putIfAbsent(clip.id, GlobalKey.new)
                          : GlobalKey();
                      final isSelected = selectedClipId == clip.id;
                      final startMs = useGlobalTime
                          ? (clip.globalStartMs ?? clip.startMs)
                          : (clip.localStartMs ?? clip.startMs);
                      final endMs = useGlobalTime
                          ? (clip.globalEndMs ?? clip.endMs)
                          : (clip.localEndMs ?? clip.endMs);

                      Color background = AppTheme.surface;
                      Color border = AppTheme.border;
                      if (isSelected) {
                        background = AppTheme.highlight.withValues(alpha: 0.18);
                        border = AppTheme.highlight;
                      }

                      return Padding(
                        key: key,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => mode == _SubtitlePanelMode.keywordList
                                ? onKeywordSelect(clip)
                                : onSelect(clip),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 104,
                                    child: Text(
                                      '${_formatTime(startMs)}\n${_formatTime(endMs)}',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      clip.text,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 12,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(int videoHitCount, int audioHitCount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _searchFocusNode,
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入关键词后，左右分栏会显示命中的字幕条列表',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _videoPanelMode = _SubtitlePanelMode.fullTranscript;
                            _audioPanelMode = _SubtitlePanelMode.fullTranscript;
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: '清空搜索',
                      ),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  final hasActiveSearch = value.trim().isNotEmpty;
                  _videoPanelMode = hasActiveSearch
                      ? _SubtitlePanelMode.keywordList
                      : _SubtitlePanelMode.fullTranscript;
                  _audioPanelMode = hasActiveSearch
                      ? _SubtitlePanelMode.keywordList
                      : _SubtitlePanelMode.fullTranscript;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _searchQuery.trim().isEmpty
                ? '输入关键词后，可先看结果列表再点击回原文核对上下文'
                : '视频命中 $videoHitCount / 音频命中 $audioHitCount',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(SyncReviewDetail detail) {
    final selectedVideoClip = detail.videoSubtitles
        .cast<SubtitleClip?>()
        .firstWhere(
          (clip) => clip?.id == _selectedVideoClipId,
          orElse: () => null,
        );
    final selectedAudioClip = detail.aggregateAudioSubtitles
        .cast<SubtitleClip?>()
        .firstWhere(
          (clip) => clip?.id == _selectedAggregateAudioClipId,
          orElse: () => null,
        );

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '匹配预览',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _previewCard(
                      title: '已选视频字幕',
                      clip: selectedVideoClip,
                      useGlobalTime: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _previewCard(
                      title: '已选音频总字幕',
                      clip: selectedAudioClip,
                      useGlobalTime: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _previewResultCard(detail)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard({
    required String title,
    required SubtitleClip? clip,
    required bool useGlobalTime,
  }) {
    final startMs = clip == null
        ? null
        : useGlobalTime
        ? (clip.globalStartMs ?? clip.startMs)
        : (clip.localStartMs ?? clip.startMs);
    final endMs = clip == null
        ? null
        : useGlobalTime
        ? (clip.globalEndMs ?? clip.endMs)
        : (clip.localEndMs ?? clip.endMs);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (clip == null)
            Expanded(
              child: Center(
                child: Text(
                  '尚未选择字幕条',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            )
          else ...[
            Text(
              '${_formatTime(startMs!)} - ${_formatTime(endMs!)}',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  clip.text,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewResultCard(SyncReviewDetail detail) {
    if (detail.aggregateAudioSubtitleFile == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Center(
          child: Text(
            '当前工程没有可用的音频总字幕文件，无法执行手动匹配。',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: _isPreviewLoading
          ? const Center(child: CircularProgressIndicator())
          : _manualPreview == null
          ? Center(
              child: Text(
                '左右各选择 1 条字幕后，会在这里预览目标音频和裁切区间。',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '匹配结果',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _resultLine(
                    '目标音频',
                    _manualPreview!.targetAudioFile == null
                        ? '--'
                        : p.basename(_manualPreview!.targetAudioFile!.filePath),
                  ),
                  _resultLine(
                    'Source In',
                    _manualPreview!.audioSourceInMs == null
                        ? '--'
                        : _formatTime(_manualPreview!.audioSourceInMs!),
                  ),
                  _resultLine(
                    'Source Out',
                    _manualPreview!.audioSourceOutMs == null
                        ? '--'
                        : _formatTime(_manualPreview!.audioSourceOutMs!),
                  ),
                  _resultLine(
                    '状态',
                    _manualPreview!.status?.label ?? '无法生成匹配结果',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _manualPreview!.error ?? _manualPreview!.notes,
                    style: TextStyle(
                      color: _manualPreview!.error == null
                          ? AppTheme.textSecondary
                          : AppTheme.error,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                  if (_manualPreview!.sourceClamped ||
                      _manualPreview!.audioTooShort) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_manualPreview!.sourceClamped)
                          _chip('提示', '起点越界已钳制', AppTheme.warning),
                        if (_manualPreview!.audioTooShort)
                          _chip('提示', '尾部不足已截断', AppTheme.warning),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _resultLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, SyncReviewDetail detail) {
    final syncResult = detail.syncResult;
    final showAccept =
        syncResult.audioFileId != null &&
        syncResult.reviewStatus == SyncReviewStatus.pending;
    final showReject = syncResult.reviewStatus != SyncReviewStatus.rejected;
    final showRestore = syncResult.reviewStatus == SyncReviewStatus.rejected;
    final canMatch =
        detail.aggregateAudioSubtitleFile != null &&
        _manualPreview?.canMatch == true &&
        !_isPreviewLoading;

    return Row(
      children: [
        TextButton(
          onPressed: _isHandlingAction
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        const Spacer(),
        if (showRestore)
          OutlinedButton.icon(
            onPressed: _isHandlingAction
                ? null
                : () => _handleAction(
                    () => ref
                        .read(matchProvider.notifier)
                        .restoreReview(_currentSyncResultId, widget.projectId),
                  ),
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('恢复'),
          ),
        if (showAccept) ...[
          OutlinedButton.icon(
            onPressed: _isHandlingAction
                ? null
                : () => _handleAction(
                    () => ref
                        .read(matchProvider.notifier)
                        .acceptReview(_currentSyncResultId, widget.projectId),
                  ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('接受'),
          ),
          const SizedBox(width: 10),
        ],
        OutlinedButton.icon(
          onPressed: _isHandlingAction || !canMatch ? null : _handleManualMatch,
          icon: const Icon(Icons.add_link, size: 16),
          label: const Text('匹配'),
        ),
        if (showReject) ...[
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: _isHandlingAction
                ? null
                : () => _handleAction(
                    () => ref
                        .read(matchProvider.notifier)
                        .rejectReview(_currentSyncResultId, widget.projectId),
                  ),
            icon: const Icon(Icons.remove_circle_outline, size: 16),
            label: const Text('移除'),
          ),
        ],
      ],
    );
  }

  Future<void> _handleAction(Future<void> Function() action) async {
    final previousSyncResultId = _currentSyncResultId;
    final previousIndex = _currentSequenceIndex;

    setState(() => _isHandlingAction = true);
    try {
      await action();
      if (!mounted) return;
      _syncSequenceAfterMutation(
        previousSyncResultId: previousSyncResultId,
        previousIndex: previousIndex,
      );
    } finally {
      if (mounted) {
        setState(() => _isHandlingAction = false);
      }
    }
  }

  Future<void> _handleManualMatch() async {
    final videoClipId = _selectedVideoClipId;
    final aggregateAudioClipId = _selectedAggregateAudioClipId;
    if (videoClipId == null || aggregateAudioClipId == null) {
      return;
    }
    await _handleAction(
      () => ref
          .read(matchProvider.notifier)
          .manualAnchorMatch(
            syncResultId: _currentSyncResultId,
            projectId: widget.projectId,
            videoClipId: videoClipId,
            aggregateAudioClipId: aggregateAudioClipId,
          ),
    );
  }

  void _selectVideoClip(String clipId) {
    setState(() {
      _selectedVideoClipId = clipId;
    });
    _refreshManualPreview();
  }

  void _selectAggregateAudioClip(String clipId) {
    setState(() {
      _selectedAggregateAudioClipId = clipId;
    });
    _refreshManualPreview();
  }

  void _jumpToNextResolvedAnchor() {
    final anchors = _resolvedReviewAnchors;
    if (anchors.isEmpty) return;
    final currentIndex = _currentAnchorCycleIndex;
    final nextIndex = currentIndex == null
        ? 0
        : (currentIndex + 1) % anchors.length;
    final nextAnchor = anchors[nextIndex];

    setState(() {
      _currentAnchorCycleIndex = nextIndex;
      _videoPanelMode = _SubtitlePanelMode.fullTranscript;
      _audioPanelMode = _SubtitlePanelMode.fullTranscript;
      _selectedVideoClipId = nextAnchor.videoClipId;
      _selectedAggregateAudioClipId = nextAnchor.aggregateAudioClipId;
    });

    _focusClip(
      controller: _videoController,
      itemKeys: _videoItemKeys,
      allClips: _latestVideoClips,
      clipId: nextAnchor.videoClipId,
    );
    _focusClip(
      controller: _audioController,
      itemKeys: _audioItemKeys,
      allClips: _latestAggregateAudioClips,
      clipId: nextAnchor.aggregateAudioClipId,
    );
    _refreshManualPreview();
  }

  Future<void> _refreshManualPreview() async {
    final videoClipId = _selectedVideoClipId;
    final aggregateAudioClipId = _selectedAggregateAudioClipId;
    if (videoClipId == null || aggregateAudioClipId == null) {
      if (mounted) {
        setState(() {
          _manualPreview = null;
          _isPreviewLoading = false;
        });
      }
      return;
    }

    final requestId = ++_previewRequestId;
    setState(() {
      _isPreviewLoading = true;
      _manualPreview = null;
    });

    final preview =
        await (widget.previewResolver ??
            SubtitleMatchService.previewManualAnchorMatch)(
          projectId: widget.projectId,
          videoClipId: videoClipId,
          aggregateAudioClipId: aggregateAudioClipId,
        );
    if (!mounted || requestId != _previewRequestId) return;

    setState(() {
      _manualPreview = preview;
      _isPreviewLoading = false;
    });
  }

  bool _clipMatchesSearch(SubtitleClip clip) {
    final query = _searchQuery.trim();
    if (query.isEmpty) return false;
    final normalizedQuery = SubtitlePrepareService.normalizeTextForMatching(
      query,
    );
    final rawMatch = clip.text.toLowerCase().contains(query.toLowerCase());
    final normalizedMatch =
        normalizedQuery.isNotEmpty &&
        clip.normalizedText.toLowerCase().contains(normalizedQuery);
    return rawMatch || normalizedMatch;
  }

  List<SubtitleClip> _matchedClips(List<SubtitleClip> clips) {
    if (!_hasActiveSearch) {
      return const [];
    }
    return clips.where(_clipMatchesSearch).toList();
  }

  bool get _hasActiveSearch => _searchQuery.trim().isNotEmpty;

  bool get _canGoPrevious =>
      _reviewSequenceIds.isNotEmpty && _currentSequenceIndex > 0;

  bool get _canGoNext =>
      _reviewSequenceIds.isNotEmpty &&
      _currentSequenceIndex >= 0 &&
      _currentSequenceIndex < _reviewSequenceIds.length - 1;

  int get _sequenceDisplayIndex {
    if (_reviewSequenceIds.isEmpty) return 1;
    final safeIndex = _currentSequenceIndex.clamp(
      0,
      _reviewSequenceIds.length - 1,
    );
    return safeIndex + 1;
  }

  int get _sequenceDisplayTotal =>
      _reviewSequenceIds.isEmpty ? 1 : _reviewSequenceIds.length;

  void _showVideoKeywordList() {
    setState(() {
      _videoPanelMode = _SubtitlePanelMode.keywordList;
    });
  }

  void _showAudioKeywordList() {
    setState(() {
      _audioPanelMode = _SubtitlePanelMode.keywordList;
    });
  }

  void _openVideoKeywordResult(List<SubtitleClip> allClips, String clipId) {
    setState(() {
      _selectedVideoClipId = clipId;
      _videoPanelMode = _SubtitlePanelMode.fullTranscript;
    });
    _focusClip(
      controller: _videoController,
      itemKeys: _videoItemKeys,
      allClips: allClips,
      clipId: clipId,
    );
    _refreshManualPreview();
  }

  void _openAudioKeywordResult(List<SubtitleClip> allClips, String clipId) {
    setState(() {
      _selectedAggregateAudioClipId = clipId;
      _audioPanelMode = _SubtitlePanelMode.fullTranscript;
    });
    _focusClip(
      controller: _audioController,
      itemKeys: _audioItemKeys,
      allClips: allClips,
      clipId: clipId,
    );
    _refreshManualPreview();
  }

  void _goToPreviousResult() {
    _switchToSequenceIndex(_currentSequenceIndex - 1);
  }

  void _goToNextResult() {
    _switchToSequenceIndex(_currentSequenceIndex + 1);
  }

  void _switchToSequenceIndex(int nextIndex) {
    if (nextIndex < 0 || nextIndex >= _reviewSequenceIds.length) {
      return;
    }

    final nextSyncResultId = _reviewSequenceIds[nextIndex];
    if (nextSyncResultId == _currentSyncResultId &&
        nextIndex == _currentSequenceIndex) {
      return;
    }

    setState(() {
      _currentSequenceIndex = nextIndex;
      _currentSyncResultId = nextSyncResultId;
      _resetCurrentResultViewState();
    });
    _jumpToTopAfterNavigation();
  }

  void _syncSequenceAfterMutation({
    required String previousSyncResultId,
    required int previousIndex,
  }) {
    final updatedSequenceIds = _resolveSequenceIdsFromState(
      ref.read(matchProvider).valueOrNull,
    );

    if (updatedSequenceIds.isEmpty) {
      ref.invalidate(syncReviewDetailProvider(previousSyncResultId));
      setState(() {
        _reviewSequenceIds = const [];
        _currentSequenceIndex = -1;
        _currentSyncResultId = previousSyncResultId;
        _manualPreview = null;
        _isPreviewLoading = false;
        _previewRequestId++;
      });
      return;
    }

    final retainedIndex = updatedSequenceIds.indexOf(previousSyncResultId);
    if (retainedIndex != -1) {
      ref.invalidate(syncReviewDetailProvider(previousSyncResultId));
      setState(() {
        _reviewSequenceIds = List.unmodifiable(updatedSequenceIds);
        _currentSequenceIndex = retainedIndex;
        _currentSyncResultId = previousSyncResultId;
        _manualPreview = null;
        _isPreviewLoading = false;
        _previewRequestId++;
      });
      if (_selectedVideoClipId != null &&
          _selectedAggregateAudioClipId != null) {
        _refreshManualPreview();
      }
      return;
    }

    final targetIndex = previousIndex.clamp(0, updatedSequenceIds.length - 1);
    setState(() {
      _reviewSequenceIds = List.unmodifiable(updatedSequenceIds);
      _currentSequenceIndex = targetIndex;
      _currentSyncResultId = updatedSequenceIds[targetIndex];
      _resetCurrentResultViewState();
    });
    _jumpToTopAfterNavigation();
  }

  List<String> _resolveSequenceIdsFromState(MatchState? matchState) {
    final syncResults = matchState?.syncResults;
    if (syncResults == null || syncResults.isEmpty) {
      return const [];
    }

    final filteredResults = switch (widget.sequenceMode) {
      SyncReviewDialogSequenceMode.pending =>
        syncResults
            .where((item) => item.reviewStatus == SyncReviewStatus.pending)
            .toList(),
      SyncReviewDialogSequenceMode.all => syncResults,
      SyncReviewDialogSequenceMode.accepted =>
        syncResults
            .where((item) => item.reviewStatus == SyncReviewStatus.accepted)
            .toList(),
      SyncReviewDialogSequenceMode.rejected =>
        syncResults
            .where((item) => item.reviewStatus == SyncReviewStatus.rejected)
            .toList(),
    };

    return filteredResults.map((item) => item.id).toList(growable: false);
  }

  void _resetCurrentResultViewState() {
    _selectedVideoClipId = null;
    _selectedAggregateAudioClipId = null;
    _videoItemKeys.clear();
    _audioItemKeys.clear();
    _currentAnchorCycleIndex = null;
    _manualPreview = null;
    _isPreviewLoading = false;
    _previewRequestId++;
    _videoPanelMode = _hasActiveSearch
        ? _SubtitlePanelMode.keywordList
        : _SubtitlePanelMode.fullTranscript;
    _audioPanelMode = _hasActiveSearch
        ? _SubtitlePanelMode.keywordList
        : _SubtitlePanelMode.fullTranscript;
  }

  void _jumpToTopAfterNavigation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_videoController.hasClients) {
        _videoController.jumpTo(0);
      }
      if (_audioController.hasClients) {
        _audioController.jumpTo(0);
      }
    });
  }

  void _focusClip({
    required ScrollController controller,
    required Map<String, GlobalKey> itemKeys,
    required List<SubtitleClip> allClips,
    required String clipId,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureVisibleForClip(itemKeys, clipId);
      final context = itemKeys[clipId]?.currentContext;
      if (context != null) {
        return;
      }
      final targetIndex = allClips.indexWhere((clip) => clip.id == clipId);
      if (targetIndex < 0 || !controller.hasClients) {
        return;
      }

      final estimatedOffset = (targetIndex * 96.0).clamp(
        0.0,
        controller.position.maxScrollExtent,
      );
      controller.jumpTo(estimatedOffset);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ensureVisibleForClip(itemKeys, clipId);
      });
    });
  }

  void _ensureVisibleForClip(Map<String, GlobalKey> itemKeys, String clipId) {
    final context = itemKeys[clipId]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  int _anchorDisplayIndex(int total) {
    if (total <= 0) return 0;
    final currentIndex = _currentAnchorCycleIndex;
    if (currentIndex == null || currentIndex < 0) {
      return 1;
    }
    return (currentIndex % total) + 1;
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _reviewColor(SyncReviewStatus status) {
    switch (status) {
      case SyncReviewStatus.notRequired:
        return AppTheme.success;
      case SyncReviewStatus.pending:
        return AppTheme.warning;
      case SyncReviewStatus.accepted:
        return AppTheme.highlight;
      case SyncReviewStatus.rejected:
        return AppTheme.error;
    }
  }

  Color _statusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.autoAccepted:
        return AppTheme.success;
      case SyncStatus.mediumConfidence:
        return AppTheme.warning;
      case SyncStatus.lowConfidence:
      case SyncStatus.noSubtitle:
      case SyncStatus.noMatch:
      case SyncStatus.audioTooShort:
      case SyncStatus.sourceClamped:
      case SyncStatus.needsReview:
        return AppTheme.error;
    }
  }

  String _formatTime(int ms) {
    final h = (ms ~/ 3600000).toString().padLeft(2, '0');
    final m = ((ms % 3600000) ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
