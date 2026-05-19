import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:asr_tools/core/constants.dart';
import 'package:asr_tools/models/media_file.dart';
import 'package:asr_tools/services/app_data_service.dart';
import 'package:asr_tools/services/database_service.dart';
import 'package:asr_tools/services/video_thumbnail_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandboxRoot;
  late Directory executableDir;
  late String databasePath;

  setUp(() async {
    sandboxRoot = await Directory.systemTemp.createTemp(
      'asr_tools_video_thumb_',
    );
    executableDir = Directory(p.join(sandboxRoot.path, 'release'))
      ..createSync(recursive: true);
    databasePath = p.join(sandboxRoot.path, 'thumb-test.db');
    AppDataService.debugOverrideDirectories(executableDir: executableDir.path);
  });

  tearDown(() async {
    await DatabaseService.close();
    AppDataService.debugResetOverrides();
    if (sandboxRoot.existsSync()) {
      await sandboxRoot.delete(recursive: true);
    }
  });

  test(
    'thumbnail cache path is stable under project thumbnails directory',
    () async {
      final file = MediaFile(
        id: 'video-1',
        projectId: 'project-1',
        filePath: r'G:\video\C0001.mp4',
        type: MediaType.video,
        createdAt: DateTime(2026, 5, 20),
      );

      final path = await VideoThumbnailService.thumbnailPathFor(file);

      expect(
        p.normalize(path),
        p.normalize(
          p.join(
            executableDir.path,
            AppDataService.dataDirName,
            AppDataService.projectsDirName,
            'project-1',
            'thumbnails',
            'video-1.jpg',
          ),
        ),
      );
    },
  );

  test('existing cached thumbnail is reused without regeneration', () async {
    final file = MediaFile(
      id: 'video-2',
      projectId: 'project-1',
      filePath: r'G:\video\C0002.mp4',
      type: MediaType.video,
      createdAt: DateTime(2026, 5, 20),
    );
    final path = await VideoThumbnailService.thumbnailPathFor(file);
    final cached = File(path);
    await cached.parent.create(recursive: true);
    await cached.writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xD9]);

    final resolved = await VideoThumbnailService.ensureThumbnail(file);

    expect(resolved, path);
  });

  test('missing source video returns null thumbnail path', () async {
    final file = MediaFile(
      id: 'video-3',
      projectId: 'project-1',
      filePath: p.join(sandboxRoot.path, 'missing.mp4'),
      type: MediaType.video,
      createdAt: DateTime(2026, 5, 20),
    );

    final resolved = await VideoThumbnailService.ensureThumbnail(file);

    expect(resolved, isNull);
  });

  test('delete project cache removes project thumbnail directory', () async {
    final file = MediaFile(
      id: 'video-4',
      projectId: 'project-cleanup',
      filePath: r'G:\video\C0004.mp4',
      type: MediaType.video,
      createdAt: DateTime(2026, 5, 20),
    );
    final path = await VideoThumbnailService.thumbnailPathFor(file);
    final cached = File(path);
    await cached.parent.create(recursive: true);
    await cached.writeAsString('cached');

    await VideoThumbnailService.deleteProjectCache(file.projectId);

    expect(Directory(p.dirname(path)).existsSync(), isFalse);
  });

  test(
    'database init adds thumbnail_path column for existing media_files table',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await openDatabase(
        databasePath,
        version: AppConstants.dbVersion,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            video_directory TEXT,
            audio_directory TEXT,
            status TEXT NOT NULL DEFAULT 'created',
            asr_language TEXT NOT NULL DEFAULT 'auto',
            asr_model TEXT NOT NULL DEFAULT 'fire-red-asr',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          await db.execute('''
          CREATE TABLE media_files (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            type TEXT NOT NULL,
            duration_ms INTEGER,
            sort_index INTEGER NOT NULL DEFAULT 0,
            layout_start_ms INTEGER NOT NULL DEFAULT 0,
            layout_end_ms INTEGER NOT NULL DEFAULT 0,
            frame_rate REAL,
            sample_rate INTEGER,
            channels INTEGER,
            width INTEGER,
            height INTEGER,
            has_embedded_audio INTEGER NOT NULL DEFAULT 0,
            file_size INTEGER,
            modified_at_ms INTEGER,
            subtitle_status TEXT NOT NULL DEFAULT 'pending',
            created_at INTEGER NOT NULL,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
          )
        ''');
          await db.execute('''
          CREATE TABLE sync_results (
            id TEXT PRIMARY KEY,
            needs_review INTEGER NOT NULL DEFAULT 0
          )
        ''');
        },
      );
      await db.close();

      await DatabaseService.init(overridePath: databasePath);
      final columns = await DatabaseService.database.rawQuery(
        'PRAGMA table_info(media_files)',
      );

      expect(columns.any((row) => row['name'] == 'thumbnail_path'), isTrue);
    },
  );
}
