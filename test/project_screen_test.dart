import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asr_tools/l10n/app_localizations.dart';
import 'package:asr_tools/models/asr_project.dart';
import 'package:asr_tools/models/media_file.dart';
import 'package:asr_tools/models/subtitle_file.dart';
import 'package:asr_tools/providers/asr_process_provider.dart';
import 'package:asr_tools/providers/match_provider.dart';
import 'package:asr_tools/providers/project_detail_provider.dart';
import 'package:asr_tools/providers/settings_provider.dart';
import 'package:asr_tools/providers/timeline_provider.dart';
import 'package:asr_tools/screens/project_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'project screen keeps only one import status group in menu style',
    (tester) async {
      _testSettings = const AppSettings(projectNavigationStyle: 'menu');
      _testProjectDetailState = _buildProjectDetailState();

      await tester.binding.setSurfaceSize(const Size(1440, 960));
      await tester.pumpWidget(_buildProjectScreen());
      await tester.pumpAndSettle();

      expect(find.text('字幕准备'), findsNothing);
      expect(find.text('反解字幕并建立索引'), findsOneWidget);
      expect(find.text('进入下一步'), findsOneWidget);
      expect(find.text('字幕反解与补录'), findsOneWidget);
      expect(find.text('视频 1'), findsOneWidget);
      expect(find.text('音频 1'), findsOneWidget);

      final prepareX = tester.getTopLeft(find.text('反解字幕并建立索引')).dx;
      final nextX = tester.getTopLeft(find.text('进入下一步')).dx;
      expect(prepareX, lessThan(nextX));
    },
  );

  testWidgets(
    'project screen keeps dock actions on the right without duplicate top status group',
    (tester) async {
      _testSettings = const AppSettings(projectNavigationStyle: 'dock');
      _testProjectDetailState = _buildProjectDetailState();

      await tester.binding.setSurfaceSize(const Size(1440, 960));
      await tester.pumpWidget(_buildProjectScreen());
      await tester.pumpAndSettle();

      expect(find.text('字幕准备'), findsNothing);
      expect(find.text('反解字幕并建立索引'), findsOneWidget);
      expect(find.text('进入下一步'), findsOneWidget);
      expect(find.text('字幕反解与补录'), findsOneWidget);
      expect(find.text('视频 1'), findsOneWidget);
      expect(find.text('音频 1'), findsOneWidget);

      final dockX = tester.getTopLeft(find.text('时间线与导出')).dx;
      final nextX = tester.getTopLeft(find.text('进入下一步')).dx;
      expect(dockX, lessThan(nextX));
    },
  );
}

Widget _buildProjectScreen() {
  return ProviderScope(
    overrides: [
      projectDetailProvider.overrideWith(TestProjectDetailNotifier.new),
      settingsProvider.overrideWith(TestSettingsNotifier.new),
      matchProvider.overrideWith(TestMatchNotifier.new),
      timelineProvider.overrideWith(TestTimelineNotifier.new),
      asrProcessProvider.overrideWith(TestAsrProcessNotifier.new),
    ],
    child: MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProjectScreen(projectId: 'project-1'),
    ),
  );
}

ProjectDetailState _buildProjectDetailState() {
  return ProjectDetailState(
    project: AsrProject(
      id: 'project-1',
      name: '测试工程',
      status: ProjectStatus.recognized,
      createdAt: DateTime(2026, 5, 20, 10),
      updatedAt: DateTime(2026, 5, 20, 10),
    ),
    videoFiles: [
      MediaFile(
        id: 'video-1',
        projectId: 'project-1',
        filePath: r'G:\video\C0001.mp4',
        type: MediaType.video,
        durationMs: 4200,
        createdAt: DateTime(2026, 5, 20, 10),
      ),
    ],
    audioFiles: [
      MediaFile(
        id: 'audio-1',
        projectId: 'project-1',
        filePath: r'G:\audio\A0001.wav',
        type: MediaType.audio,
        durationMs: 4200,
        createdAt: DateTime(2026, 5, 20, 10),
      ),
    ],
    videoSubtitleFiles: [
      SubtitleFile(
        id: 'vs-1',
        projectId: 'project-1',
        filePath: r'G:\subs\video.srt',
        mediaType: MediaType.video,
        createdAt: DateTime(2026, 5, 20, 10),
      ),
    ],
    audioSubtitleFiles: [
      SubtitleFile(
        id: 'as-1',
        projectId: 'project-1',
        filePath: r'G:\subs\audio.srt',
        mediaType: MediaType.audio,
        createdAt: DateTime(2026, 5, 20, 10),
      ),
    ],
  );
}

late ProjectDetailState _testProjectDetailState;
late AppSettings _testSettings;

class TestProjectDetailNotifier extends ProjectDetailNotifier {
  @override
  ProjectDetailState build() => _testProjectDetailState;

  @override
  Future<void> loadProject(String projectId) async {}
}

class TestSettingsNotifier extends SettingsNotifier {
  @override
  AppSettings build() => _testSettings;

  @override
  Future<void> toggleProjectNavigationStyle() async {}

  @override
  Future<void> toggleThemeMode() async {}
}

class TestMatchNotifier extends MatchNotifier {
  @override
  MatchState build() => const MatchState();
}

class TestTimelineNotifier extends TimelineNotifier {
  @override
  TimelineState build() => const TimelineState();
}

class TestAsrProcessNotifier extends AsrProcessNotifier {
  @override
  AsrProcessState build() => const AsrProcessState();
}
