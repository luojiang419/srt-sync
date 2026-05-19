import 'anchor_pair.dart';
import 'media_file.dart';
import 'subtitle_clip.dart';
import 'subtitle_file.dart';
import 'sync_result.dart';

class SyncReviewDetail {
  final SyncResult syncResult;
  final MediaFile videoFile;
  final MediaFile? audioFile;
  final List<MediaFile> audioCandidates;
  final List<SubtitleClip> videoSubtitles;
  final List<SubtitleClip> audioSubtitles;
  final SubtitleFile? aggregateAudioSubtitleFile;
  final List<SubtitleClip> aggregateAudioSubtitles;
  final List<AnchorPair> anchorPairs;

  const SyncReviewDetail({
    required this.syncResult,
    required this.videoFile,
    required this.audioFile,
    required this.audioCandidates,
    required this.videoSubtitles,
    required this.audioSubtitles,
    required this.aggregateAudioSubtitleFile,
    required this.aggregateAudioSubtitles,
    required this.anchorPairs,
  });
}
