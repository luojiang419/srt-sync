import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/constants.dart';

/// 统一管理可执行程序同级的 data 持久化目录。
class AppDataService {
  AppDataService._();

  static const String dataDirName = 'data';
  static const String configDirName = 'config';
  static const String databaseDirName = 'database';
  static const String projectsDirName = 'projects';
  static const String tempDirName = 'temp';
  static const String settingsFileName = 'asr_tools_settings.json';

  static String? _executableDirOverride;
  static String? _legacySettingsDirOverride;
  static String? _legacyDatabaseDirOverride;
  static Future<void>? _prepareFuture;

  static Future<void> preparePersistentDataLayout() {
    return _prepareFuture ??= _preparePersistentDataLayoutInternal();
  }

  static Future<Directory> executableDirectory() async {
    if (_executableDirOverride != null &&
        _executableDirOverride!.trim().isNotEmpty) {
      return Directory(_executableDirOverride!);
    }
    return File(Platform.resolvedExecutable).parent;
  }

  static Future<Directory> dataRootDirectory() async {
    final base = await executableDirectory();
    return _ensureDirectory(p.join(base.path, dataDirName));
  }

  static Future<Directory> configDirectory() async {
    final root = await dataRootDirectory();
    return _ensureDirectory(p.join(root.path, configDirName));
  }

  static Future<Directory> databaseDirectory() async {
    final root = await dataRootDirectory();
    return _ensureDirectory(p.join(root.path, databaseDirName));
  }

  static Future<Directory> projectsDirectory() async {
    final root = await dataRootDirectory();
    return _ensureDirectory(p.join(root.path, projectsDirName));
  }

  static Future<Directory> projectDirectory(String projectId) async {
    final root = await projectsDirectory();
    return _ensureDirectory(p.join(root.path, projectId));
  }

  static Future<Directory> projectThumbnailDirectory(String projectId) async {
    final projectDir = await projectDirectory(projectId);
    return _ensureDirectory(p.join(projectDir.path, 'thumbnails'));
  }

  static Future<Directory> tempDirectory() async {
    final root = await dataRootDirectory();
    return _ensureDirectory(p.join(root.path, tempDirName));
  }

  static Future<String> settingsFilePath() async {
    await preparePersistentDataLayout();
    return p.join((await configDirectory()).path, settingsFileName);
  }

  static Future<String> databaseFilePath() async {
    await preparePersistentDataLayout();
    return p.join((await databaseDirectory()).path, AppConstants.dbName);
  }

  static Future<Directory> createTempDirectory(String prefix) async {
    await preparePersistentDataLayout();
    return (await tempDirectory()).createTemp(prefix);
  }

  static Future<void> deleteProjectDirectory(String projectId) async {
    final dir = Directory(p.join((await projectsDirectory()).path, projectId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  static Future<void> _preparePersistentDataLayoutInternal() async {
    await dataRootDirectory();
    await configDirectory();
    await databaseDirectory();
    await projectsDirectory();
    await tempDirectory();
    await _migrateLegacySettingsIfNeeded();
    await _migrateLegacyDatabaseIfNeeded();
  }

  static Future<void> _migrateLegacySettingsIfNeeded() async {
    final target = File(
      p.join((await configDirectory()).path, settingsFileName),
    );
    if (await target.exists()) {
      return;
    }

    final legacy = File(await _legacySettingsFilePath());
    if (!await legacy.exists()) {
      return;
    }

    await legacy.copy(target.path);
  }

  static Future<void> _migrateLegacyDatabaseIfNeeded() async {
    final targetPath = p.join(
      (await databaseDirectory()).path,
      AppConstants.dbName,
    );
    final target = File(targetPath);
    if (await target.exists()) {
      return;
    }

    final legacyPath = await _legacyDatabaseFilePath();
    final legacy = File(legacyPath);
    if (!await legacy.exists()) {
      return;
    }

    await legacy.copy(targetPath);
    for (final suffix in ['-wal', '-shm']) {
      final legacySidecar = File('$legacyPath$suffix');
      if (await legacySidecar.exists()) {
        await legacySidecar.copy('$targetPath$suffix');
      }
    }
  }

  static Future<String> _legacySettingsFilePath() async {
    final legacyDir = _legacySettingsDirOverride ?? '';
    if (legacyDir.trim().isNotEmpty) {
      return p.join(legacyDir, settingsFileName);
    }

    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, settingsFileName);
  }

  static Future<String> _legacyDatabaseFilePath() async {
    final legacyDir = _legacyDatabaseDirOverride ?? '';
    if (legacyDir.trim().isNotEmpty) {
      return p.join(legacyDir, AppConstants.dbName);
    }

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = await getDatabasesPath();
    return p.join(dir, AppConstants.dbName);
  }

  static Future<Directory> _ensureDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static void debugOverrideDirectories({
    String? executableDir,
    String? legacySettingsDir,
    String? legacyDatabaseDir,
  }) {
    _executableDirOverride = executableDir;
    _legacySettingsDirOverride = legacySettingsDir;
    _legacyDatabaseDirOverride = legacyDatabaseDir;
    _prepareFuture = null;
  }

  static void debugResetOverrides() {
    _executableDirOverride = null;
    _legacySettingsDirOverride = null;
    _legacyDatabaseDirOverride = null;
    _prepareFuture = null;
  }
}
