import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/constants.dart';
import '../models/anchor_pair.dart';
import '../models/asr_project.dart';
import '../models/match_candidate.dart';
import '../models/match_pair.dart';
import '../models/media_file.dart';
import '../models/source_layout_item.dart';
import '../models/subtitle_clip.dart';
import '../models/subtitle_file.dart';
import '../models/subtitle_window.dart';
import '../models/sync_review_detail.dart';
import '../models/sync_result.dart';
import 'app_data_service.dart';

/// SQLite 数据库服务：建表、迁移、CRUD
class DatabaseService {
  static Database? _db;

  static Database get database {
    if (_db == null) {
      throw StateError('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  /// 初始化数据库
  static Future<void> init({String? overridePath}) async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    final path = overridePath ?? await AppDataService.databaseFilePath();
    await Directory(p.dirname(path)).create(recursive: true);

    _db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    await _ensureCurrentSchema(_db!);
  }

  static Future<void> close() async {
    if (_db == null) return;
    await _db!.close();
    _db = null;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createProjectsTable(db);
    await _createMediaFilesTable(db);
    await _createSubtitleFilesTable(db);
    await _createSubtitleClipsTable(db);
    await _createMatchPairsTable(db);
    await _createSourceLayoutsTable(db);
    await _createSubtitleWindowsTable(db);
    await _createMatchCandidatesTable(db);
    await _createSyncResultsTable(db);
    await _createAnchorPairsTable(db);
    await _createTimelineItemsTable(db);
    await _createIndexes(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _migrateToV2(db);
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    if (oldVersion < 4) {
      await _migrateToV4(db);
    }
  }

  static Future<void> _createProjectsTable(Database db) async {
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
  }

  static Future<void> _createMediaFilesTable(Database db) async {
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
        thumbnail_path TEXT,
        subtitle_status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createSubtitleFilesTable(Database db) async {
    await db.execute('''
      CREATE TABLE subtitle_files (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        media_type TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'aggregate',
        status TEXT NOT NULL DEFAULT 'pending',
        cue_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createSubtitleClipsTable(Database db) async {
    await db.execute('''
      CREATE TABLE subtitle_clips (
        id TEXT PRIMARY KEY,
        subtitle_file_id TEXT,
        media_file_id TEXT,
        source_kind TEXT NOT NULL DEFAULT 'local',
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        global_start_ms INTEGER,
        global_end_ms INTEGER,
        local_start_ms INTEGER,
        local_end_ms INTEGER,
        text TEXT NOT NULL,
        normalized_text TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL,
        FOREIGN KEY (subtitle_file_id) REFERENCES subtitle_files(id) ON DELETE CASCADE,
        FOREIGN KEY (media_file_id) REFERENCES media_files(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createMatchPairsTable(Database db) async {
    await db.execute('''
      CREATE TABLE match_pairs (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        video_file_id TEXT NOT NULL,
        audio_file_id TEXT NOT NULL,
        confidence REAL NOT NULL,
        offset_ms INTEGER NOT NULL DEFAULT 0,
        confirmed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (video_file_id) REFERENCES media_files(id) ON DELETE CASCADE,
        FOREIGN KEY (audio_file_id) REFERENCES media_files(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createSourceLayoutsTable(Database db) async {
    await db.execute('''
      CREATE TABLE source_layouts (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        media_id TEXT NOT NULL,
        media_type TEXT NOT NULL,
        sort_index INTEGER NOT NULL,
        layout_start_ms INTEGER NOT NULL,
        layout_end_ms INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (media_id) REFERENCES media_files(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createSubtitleWindowsTable(Database db) async {
    await db.execute('''
      CREATE TABLE subtitle_windows (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        media_file_id TEXT NOT NULL,
        media_type TEXT NOT NULL,
        window_size INTEGER NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER NOT NULL,
        text TEXT NOT NULL,
        normalized_text TEXT NOT NULL,
        cue_ids TEXT NOT NULL,
        uniqueness_weight REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (media_file_id) REFERENCES media_files(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createMatchCandidatesTable(Database db) async {
    await db.execute('''
      CREATE TABLE match_candidates (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        video_file_id TEXT NOT NULL,
        audio_file_id TEXT NOT NULL,
        video_window_id TEXT NOT NULL,
        audio_window_id TEXT NOT NULL,
        text_score REAL NOT NULL,
        context_score REAL NOT NULL,
        anchor_score REAL NOT NULL,
        uniqueness_score REAL NOT NULL,
        metadata_score REAL NOT NULL,
        neighbor_score REAL NOT NULL,
        total_score REAL NOT NULL,
        fallback_offset_ms INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createSyncResultsTable(Database db) async {
    await db.execute('''
      CREATE TABLE sync_results (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        video_file_id TEXT NOT NULL,
        audio_file_id TEXT,
        video_duration_ms INTEGER NOT NULL,
        timeline_start_ms INTEGER NOT NULL,
        timeline_end_ms INTEGER NOT NULL,
        audio_source_in_ms INTEGER,
        audio_source_out_ms INTEGER,
        handle_before_ms INTEGER NOT NULL DEFAULT 0,
        handle_after_ms INTEGER NOT NULL DEFAULT 0,
        confidence REAL NOT NULL,
        status TEXT NOT NULL,
        method TEXT NOT NULL,
        anchor_count INTEGER NOT NULL DEFAULT 0,
        source_clamped INTEGER NOT NULL DEFAULT 0,
        audio_too_short INTEGER NOT NULL DEFAULT 0,
        needs_review INTEGER NOT NULL DEFAULT 0,
        review_status TEXT NOT NULL DEFAULT 'pending',
        reviewed_at_ms INTEGER,
        review_note TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
        FOREIGN KEY (video_file_id) REFERENCES media_files(id) ON DELETE CASCADE,
        FOREIGN KEY (audio_file_id) REFERENCES media_files(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createAnchorPairsTable(Database db) async {
    await db.execute('''
      CREATE TABLE anchor_pairs (
        id TEXT PRIMARY KEY,
        sync_result_id TEXT NOT NULL,
        video_clip_id TEXT NOT NULL,
        audio_clip_id TEXT NOT NULL,
        video_time_ms INTEGER NOT NULL,
        audio_time_ms INTEGER NOT NULL,
        offset_ms INTEGER NOT NULL,
        similarity REAL NOT NULL,
        FOREIGN KEY (sync_result_id) REFERENCES sync_results(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createTimelineItemsTable(Database db) async {
    await db.execute('''
      CREATE TABLE timeline_items (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        track_id TEXT NOT NULL,
        item_type TEXT NOT NULL,
        media_file_id TEXT,
        sync_result_id TEXT,
        source_in_ms INTEGER,
        source_out_ms INTEGER,
        timeline_start_ms INTEGER NOT NULL,
        timeline_end_ms INTEGER NOT NULL,
        label TEXT NOT NULL,
        metadata_json TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_media_project ON media_files(project_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_media_sort ON media_files(project_id, type, sort_index)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subtitle_file_project ON subtitle_files(project_id, media_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subtitle_media ON subtitle_clips(media_file_id, sort_order)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_subtitle_file ON subtitle_clips(subtitle_file_id, sort_order)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_match_project ON match_pairs(project_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_layout_project ON source_layouts(project_id, media_type, sort_index)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_window_project ON subtitle_windows(project_id, media_type, media_file_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_candidate_project ON match_candidates(project_id, video_file_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_project ON sync_results(project_id, timeline_start_ms)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_anchor_sync ON anchor_pairs(sync_result_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_timeline_project ON timeline_items(project_id, track_id, timeline_start_ms)',
    );
  }

  static Future<void> _migrateToV2(Database db) async {
    await _safeAddColumn(
      db,
      'media_files',
      'sort_index INTEGER NOT NULL DEFAULT 0',
    );
    await _safeAddColumn(
      db,
      'media_files',
      'layout_start_ms INTEGER NOT NULL DEFAULT 0',
    );
    await _safeAddColumn(
      db,
      'media_files',
      'layout_end_ms INTEGER NOT NULL DEFAULT 0',
    );
    await _safeAddColumn(db, 'media_files', 'frame_rate REAL');
    await _safeAddColumn(db, 'media_files', 'sample_rate INTEGER');
    await _safeAddColumn(db, 'media_files', 'channels INTEGER');
    await _safeAddColumn(db, 'media_files', 'width INTEGER');
    await _safeAddColumn(db, 'media_files', 'height INTEGER');
    await _safeAddColumn(
      db,
      'media_files',
      'has_embedded_audio INTEGER NOT NULL DEFAULT 0',
    );
    await _safeAddColumn(db, 'media_files', 'file_size INTEGER');
    await _safeAddColumn(db, 'media_files', 'modified_at_ms INTEGER');

    await _createSubtitleFilesTable(db);
    await _migrateSubtitleClipsTable(db);
    await _createSourceLayoutsTable(db);
    await _createSubtitleWindowsTable(db);
    await _createMatchCandidatesTable(db);
    await _createSyncResultsTable(db);
    await _createAnchorPairsTable(db);
    await _createTimelineItemsTable(db);
    await _createIndexes(db);
  }

  static Future<void> _migrateToV3(Database db) async {
    await _safeAddColumn(
      db,
      'sync_results',
      "review_status TEXT NOT NULL DEFAULT 'pending'",
    );
    await _safeAddColumn(db, 'sync_results', 'reviewed_at_ms INTEGER');
    await _safeAddColumn(db, 'sync_results', 'review_note TEXT');
    await db.execute('''
      UPDATE sync_results
      SET review_status = CASE
        WHEN needs_review = 1 THEN 'pending'
        ELSE 'notRequired'
      END
      WHERE review_status IS NULL
         OR review_status = ''
         OR review_status = 'pending'
    ''');
  }

  static Future<void> _migrateToV4(Database db) async {
    await _safeAddColumn(db, 'media_files', 'thumbnail_path TEXT');
  }

  static Future<void> _migrateSubtitleClipsTable(Database db) async {
    await db.execute('ALTER TABLE subtitle_clips RENAME TO subtitle_clips_old');
    await _createSubtitleClipsTable(db);
    await db.execute('''
      INSERT INTO subtitle_clips (
        id, subtitle_file_id, media_file_id, source_kind,
        start_ms, end_ms, global_start_ms, global_end_ms,
        local_start_ms, local_end_ms, text, normalized_text, sort_order
      )
      SELECT
        id,
        NULL,
        media_file_id,
        'local',
        start_ms,
        end_ms,
        start_ms,
        end_ms,
        start_ms,
        end_ms,
        text,
        '',
        sort_order
      FROM subtitle_clips_old
    ''');
    await db.execute('DROP TABLE subtitle_clips_old');
  }

  static Future<void> _safeAddColumn(
    Database db,
    String table,
    String definition,
  ) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $definition');
    } catch (_) {
      // ignore
    }
  }

  static Future<void> _ensureCurrentSchema(Database db) async {
    final mediaFileColumns = await db.rawQuery(
      'PRAGMA table_info(media_files)',
    );
    final mediaColumnNames = mediaFileColumns
        .map((row) => row['name'] as String? ?? '')
        .toSet();
    if (!mediaColumnNames.contains('thumbnail_path')) {
      await _safeAddColumn(db, 'media_files', 'thumbnail_path TEXT');
    }

    final syncResultColumns = await db.rawQuery(
      'PRAGMA table_info(sync_results)',
    );
    final columnNames = syncResultColumns
        .map((row) => row['name'] as String? ?? '')
        .toSet();

    if (!columnNames.contains('review_status')) {
      await _safeAddColumn(
        db,
        'sync_results',
        "review_status TEXT NOT NULL DEFAULT 'pending'",
      );
    }
    if (!columnNames.contains('reviewed_at_ms')) {
      await _safeAddColumn(db, 'sync_results', 'reviewed_at_ms INTEGER');
    }
    if (!columnNames.contains('review_note')) {
      await _safeAddColumn(db, 'sync_results', 'review_note TEXT');
    }

    await db.execute('''
      UPDATE sync_results
      SET review_status = CASE
        WHEN needs_review = 1 THEN 'pending'
        ELSE 'notRequired'
      END
      WHERE review_status IS NULL
         OR review_status = ''
    ''');
  }

  // ========== Project CRUD ==========

  static Future<List<AsrProject>> getAllProjects() async {
    final maps = await database.query('projects', orderBy: 'updated_at DESC');
    return maps.map((m) => AsrProject.fromMap(m)).toList();
  }

  static Future<AsrProject?> getProject(String id) async {
    final maps = await database.query(
      'projects',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return AsrProject.fromMap(maps.first);
  }

  static Future<void> insertProject(AsrProject project) async {
    await database.insert('projects', project.toMap());
  }

  static Future<void> updateProject(AsrProject project) async {
    await database.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  static Future<void> deleteProject(String id) async {
    await database.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // ========== MediaFile CRUD ==========

  static Future<List<MediaFile>> getMediaFiles(
    String projectId, {
    MediaType? type,
  }) async {
    var where = 'project_id = ?';
    final args = <Object?>[projectId];
    if (type != null) {
      where += ' AND type = ?';
      args.add(type.name);
    }
    final maps = await database.query(
      'media_files',
      where: where,
      whereArgs: args,
      orderBy: 'sort_index ASC, file_path COLLATE NOCASE ASC',
    );
    return maps.map((m) => MediaFile.fromMap(m)).toList();
  }

  static Future<void> insertMediaFile(MediaFile file) async {
    await database.insert('media_files', file.toMap());
  }

  static Future<void> insertMediaFiles(List<MediaFile> files) async {
    final batch = database.batch();
    for (final file in files) {
      batch.insert('media_files', file.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<void> updateMediaFile(MediaFile file) async {
    await database.update(
      'media_files',
      file.toMap(),
      where: 'id = ?',
      whereArgs: [file.id],
    );
  }

  static Future<void> updateMediaFiles(List<MediaFile> files) async {
    final batch = database.batch();
    for (final file in files) {
      batch.update(
        'media_files',
        file.toMap(),
        where: 'id = ?',
        whereArgs: [file.id],
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<void> deleteMediaFiles(
    String projectId, {
    MediaType? type,
  }) async {
    var where = 'project_id = ?';
    final args = <Object?>[projectId];
    if (type != null) {
      where += ' AND type = ?';
      args.add(type.name);
    }
    await database.delete('media_files', where: where, whereArgs: args);
  }

  static Future<void> deleteMediaFilesByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await database.delete(
      'match_pairs',
      where:
          'video_file_id IN ($placeholders) OR audio_file_id IN ($placeholders)',
      whereArgs: [...ids, ...ids],
    );
    await database.delete(
      'sync_results',
      where:
          'video_file_id IN ($placeholders) OR audio_file_id IN ($placeholders)',
      whereArgs: [...ids, ...ids],
    );
    await database.delete(
      'media_files',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  static Future<MediaFile?> getMediaFileById(String id) async {
    final maps = await database.query(
      'media_files',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return MediaFile.fromMap(maps.first);
  }

  // ========== SubtitleFile CRUD ==========

  static Future<List<SubtitleFile>> getSubtitleFiles(
    String projectId, {
    MediaType? mediaType,
  }) async {
    var where = 'project_id = ?';
    final args = <Object?>[projectId];
    if (mediaType != null) {
      where += ' AND media_type = ?';
      args.add(mediaType.name);
    }
    final maps = await database.query(
      'subtitle_files',
      where: where,
      whereArgs: args,
      orderBy: 'created_at ASC, file_path COLLATE NOCASE ASC',
    );
    return maps.map((m) => SubtitleFile.fromMap(m)).toList();
  }

  static Future<SubtitleFile?> getPreferredAggregateAudioSubtitleFile(
    String projectId,
  ) async {
    final maps = await database.query(
      'subtitle_files',
      where:
          'project_id = ? AND media_type = ? AND source_type = ? AND status != ?',
      whereArgs: [
        projectId,
        MediaType.audio.name,
        SubtitleSourceType.aggregate.name,
        SubtitleFileStatus.failed.name,
      ],
      orderBy: 'created_at ASC, file_path COLLATE NOCASE ASC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SubtitleFile.fromMap(maps.first);
  }

  static Future<void> insertSubtitleFile(SubtitleFile file) async {
    await database.insert('subtitle_files', file.toMap());
  }

  static Future<void> updateSubtitleFile(SubtitleFile file) async {
    await database.update(
      'subtitle_files',
      file.toMap(),
      where: 'id = ?',
      whereArgs: [file.id],
    );
  }

  static Future<void> deleteSubtitleFiles(
    String projectId, {
    MediaType? mediaType,
  }) async {
    var where = 'project_id = ?';
    final args = <Object?>[projectId];
    if (mediaType != null) {
      where += ' AND media_type = ?';
      args.add(mediaType.name);
    }
    await database.delete('subtitle_files', where: where, whereArgs: args);
  }

  static Future<void> deleteSubtitleFileById(String subtitleFileId) async {
    await database.delete(
      'subtitle_files',
      where: 'id = ?',
      whereArgs: [subtitleFileId],
    );
  }

  // ========== SourceLayout CRUD ==========

  static Future<List<SourceLayoutItem>> getSourceLayouts(
    String projectId, {
    MediaType? mediaType,
  }) async {
    var where = 'project_id = ?';
    final args = <Object?>[projectId];
    if (mediaType != null) {
      where += ' AND media_type = ?';
      args.add(mediaType.name);
    }
    final maps = await database.query(
      'source_layouts',
      where: where,
      whereArgs: args,
      orderBy: 'sort_index ASC',
    );
    return maps.map((m) => SourceLayoutItem.fromMap(m)).toList();
  }

  static Future<void> replaceSourceLayouts(
    String projectId,
    MediaType mediaType,
    List<SourceLayoutItem> items,
  ) async {
    await database.delete(
      'source_layouts',
      where: 'project_id = ? AND media_type = ?',
      whereArgs: [projectId, mediaType.name],
    );
    final batch = database.batch();
    for (final item in items) {
      batch.insert('source_layouts', item.toMap());
    }
    await batch.commit(noResult: true);
  }

  // ========== SubtitleClip CRUD ==========

  static Future<List<SubtitleClip>> getSubtitleClips(String mediaFileId) async {
    final maps = await database.query(
      'subtitle_clips',
      where: 'media_file_id = ?',
      whereArgs: [mediaFileId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => SubtitleClip.fromMap(m)).toList();
  }

  static Future<SubtitleClip?> getSubtitleClipById(String clipId) async {
    final maps = await database.query(
      'subtitle_clips',
      where: 'id = ?',
      whereArgs: [clipId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SubtitleClip.fromMap(maps.first);
  }

  static Future<List<SubtitleClip>> getSubtitleClipsByProject(
    String projectId, {
    MediaType? mediaType,
  }) async {
    var where = 'mf.project_id = ?';
    final args = <Object?>[projectId];
    if (mediaType != null) {
      where += ' AND mf.type = ?';
      args.add(mediaType.name);
    }
    final maps = await database.rawQuery('''
      SELECT sc.*
      FROM subtitle_clips sc
      LEFT JOIN media_files mf ON mf.id = sc.media_file_id
      WHERE $where
      ORDER BY mf.sort_index ASC, sc.sort_order ASC
    ''', args);
    return maps.map((m) => SubtitleClip.fromMap(m)).toList();
  }

  static Future<List<SubtitleClip>> getGlobalSubtitleClips(
    String subtitleFileId,
  ) async {
    final maps = await database.query(
      'subtitle_clips',
      where: 'subtitle_file_id = ? AND media_file_id IS NULL',
      whereArgs: [subtitleFileId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => SubtitleClip.fromMap(m)).toList();
  }

  static Future<void> insertSubtitleClips(List<SubtitleClip> clips) async {
    final batch = database.batch();
    for (final clip in clips) {
      batch.insert('subtitle_clips', clip.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<void> deleteSubtitleClips(String mediaFileId) async {
    await database.delete(
      'subtitle_clips',
      where: 'media_file_id = ?',
      whereArgs: [mediaFileId],
    );
  }

  static Future<void> deleteSubtitleClipsBySubtitleFile(
    String subtitleFileId,
  ) async {
    await database.delete(
      'subtitle_clips',
      where: 'subtitle_file_id = ?',
      whereArgs: [subtitleFileId],
    );
  }

  // ========== SubtitleWindow CRUD ==========

  static Future<void> replaceSubtitleWindows(
    String projectId,
    MediaType mediaType,
    List<SubtitleWindow> windows,
  ) async {
    await database.delete(
      'subtitle_windows',
      where: 'project_id = ? AND media_type = ?',
      whereArgs: [projectId, mediaType.name],
    );
    final batch = database.batch();
    for (final window in windows) {
      batch.insert('subtitle_windows', window.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<List<SubtitleWindow>> getSubtitleWindows(
    String projectId, {
    required MediaType mediaType,
  }) async {
    final maps = await database.query(
      'subtitle_windows',
      where: 'project_id = ? AND media_type = ?',
      whereArgs: [projectId, mediaType.name],
      orderBy: 'media_file_id ASC, start_ms ASC',
    );
    return maps.map((m) => SubtitleWindow.fromMap(m)).toList();
  }

  // ========== MatchCandidate CRUD ==========

  static Future<void> replaceMatchCandidates(
    String projectId,
    List<MatchCandidate> candidates,
  ) async {
    await database.delete(
      'match_candidates',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    final batch = database.batch();
    for (final candidate in candidates) {
      batch.insert('match_candidates', candidate.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<List<MatchCandidate>> getMatchCandidates(
    String projectId,
  ) async {
    final maps = await database.query(
      'match_candidates',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'total_score DESC',
    );
    return maps.map((m) => MatchCandidate.fromMap(m)).toList();
  }

  // ========== SyncResult CRUD ==========

  static Future<void> replaceSyncResults(
    String projectId,
    List<SyncResult> results,
  ) async {
    await deleteSyncResults(projectId);
    final batch = database.batch();
    for (final result in results) {
      batch.insert('sync_results', result.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<List<SyncResult>> getSyncResults(String projectId) async {
    final maps = await database.query(
      'sync_results',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'timeline_start_ms ASC, created_at ASC',
    );
    return maps.map((m) => SyncResult.fromMap(m)).toList();
  }

  static Future<SyncResult?> getSyncResultById(String syncResultId) async {
    final maps = await database.query(
      'sync_results',
      where: 'id = ?',
      whereArgs: [syncResultId],
    );
    if (maps.isEmpty) return null;
    return SyncResult.fromMap(maps.first);
  }

  static Future<void> updateSyncResult(SyncResult result) async {
    await database.update(
      'sync_results',
      result.toMap(),
      where: 'id = ?',
      whereArgs: [result.id],
    );
  }

  static Future<void> deleteAnchorPairs(String syncResultId) async {
    await database.delete(
      'anchor_pairs',
      where: 'sync_result_id = ?',
      whereArgs: [syncResultId],
    );
  }

  static Future<void> deleteSyncResults(String projectId) async {
    final syncIds = await database.query(
      'sync_results',
      columns: ['id'],
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    final ids = syncIds.map((row) => row['id'] as String).toList();
    if (ids.isNotEmpty) {
      final placeholders = List.filled(ids.length, '?').join(',');
      await database.delete(
        'anchor_pairs',
        where: 'sync_result_id IN ($placeholders)',
        whereArgs: ids,
      );
    }
    await database.delete(
      'sync_results',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
  }

  // ========== AnchorPair CRUD ==========

  static Future<void> insertAnchorPairs(List<AnchorPair> anchors) async {
    final batch = database.batch();
    for (final anchor in anchors) {
      batch.insert('anchor_pairs', anchor.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<List<AnchorPair>> getAnchorPairs(String syncResultId) async {
    final maps = await database.query(
      'anchor_pairs',
      where: 'sync_result_id = ?',
      whereArgs: [syncResultId],
      orderBy: 'offset_ms ASC',
    );
    return maps.map((m) => AnchorPair.fromMap(m)).toList();
  }

  static Future<SyncReviewDetail?> getSyncReviewDetail(
    String syncResultId,
  ) async {
    final syncResult = await getSyncResultById(syncResultId);
    if (syncResult == null) return null;
    final videoFile = await getMediaFileById(syncResult.videoFileId);
    if (videoFile == null) return null;
    final audioFile = syncResult.audioFileId == null
        ? null
        : await getMediaFileById(syncResult.audioFileId!);
    final audioCandidates = await getMediaFiles(
      syncResult.projectId,
      type: MediaType.audio,
    );
    final aggregateAudioSubtitleFile =
        await getPreferredAggregateAudioSubtitleFile(syncResult.projectId);
    final videoSubtitles = await getSubtitleClips(videoFile.id);
    final audioSubtitles = audioFile == null
        ? const <SubtitleClip>[]
        : await getSubtitleClips(audioFile.id);
    final aggregateAudioSubtitles = aggregateAudioSubtitleFile == null
        ? const <SubtitleClip>[]
        : await getGlobalSubtitleClips(aggregateAudioSubtitleFile.id);
    final anchorPairs = await getAnchorPairs(syncResultId);

    return SyncReviewDetail(
      syncResult: syncResult,
      videoFile: videoFile,
      audioFile: audioFile,
      audioCandidates: audioCandidates,
      videoSubtitles: videoSubtitles,
      audioSubtitles: audioSubtitles,
      aggregateAudioSubtitleFile: aggregateAudioSubtitleFile,
      aggregateAudioSubtitles: aggregateAudioSubtitles,
      anchorPairs: anchorPairs,
    );
  }

  // ========== MatchPair CRUD（保留旧流程兼容） ==========

  static Future<List<MatchPair>> getMatchPairs(String projectId) async {
    final maps = await database.query(
      'match_pairs',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'confidence DESC',
    );
    return maps.map((m) => MatchPair.fromMap(m)).toList();
  }

  static Future<void> insertMatchPairs(List<MatchPair> pairs) async {
    final batch = database.batch();
    for (final pair in pairs) {
      batch.insert('match_pairs', pair.toMap());
    }
    await batch.commit(noResult: true);
  }

  static Future<void> updateMatchPair(MatchPair pair) async {
    await database.update(
      'match_pairs',
      pair.toMap(),
      where: 'id = ?',
      whereArgs: [pair.id],
    );
  }

  static Future<void> deleteMatchPairs(String projectId) async {
    await database.delete(
      'match_pairs',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
  }

  // ========== Cleanup ==========

  static Future<void> clearPreparedData(String projectId) async {
    await deleteSyncResults(projectId);
    await database.delete(
      'match_candidates',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    await database.delete(
      'subtitle_windows',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
    await database.delete(
      'source_layouts',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );

    final subtitleFiles = await getSubtitleFiles(projectId);
    for (final file in subtitleFiles) {
      await deleteSubtitleClipsBySubtitleFile(file.id);
      await updateSubtitleFile(
        file.copyWith(cueCount: 0, status: SubtitleFileStatus.pending),
      );
    }
  }
}
