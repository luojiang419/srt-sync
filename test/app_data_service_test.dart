import 'dart:convert';
import 'dart:io';

import 'package:asr_tools/core/constants.dart';
import 'package:asr_tools/models/asr_project.dart';
import 'package:asr_tools/services/app_data_service.dart';
import 'package:asr_tools/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory sandboxRoot;
  late Directory executableDir;
  late Directory legacySettingsDir;
  late Directory legacyDatabaseDir;

  setUp(() async {
    sandboxRoot = await Directory.systemTemp.createTemp(
      'asr_tools_app_data_test_',
    );
    executableDir = Directory(p.join(sandboxRoot.path, 'release'))
      ..createSync(recursive: true);
    legacySettingsDir = Directory(p.join(sandboxRoot.path, 'legacy_settings'))
      ..createSync(recursive: true);
    legacyDatabaseDir = Directory(p.join(sandboxRoot.path, 'legacy_database'))
      ..createSync(recursive: true);

    AppDataService.debugOverrideDirectories(
      executableDir: executableDir.path,
      legacySettingsDir: legacySettingsDir.path,
      legacyDatabaseDir: legacyDatabaseDir.path,
    );
  });

  tearDown(() async {
    await DatabaseService.close();
    AppDataService.debugResetOverrides();
    if (sandboxRoot.existsSync()) {
      await sandboxRoot.delete(recursive: true);
    }
  });

  test('migrates legacy settings into executable sibling data tree', () async {
    final legacySettingsFile = File(
      p.join(legacySettingsDir.path, AppDataService.settingsFileName),
    );
    await legacySettingsFile.writeAsString(
      jsonEncode({'proxy_address': '127.0.0.1:9000', 'theme_mode': 'light'}),
    );

    final settingsPath = await AppDataService.settingsFilePath();
    final settingsFile = File(settingsPath);

    expect(
      p.normalize(settingsPath),
      p.normalize(
        p.join(
          executableDir.path,
          AppDataService.dataDirName,
          AppDataService.configDirName,
          AppDataService.settingsFileName,
        ),
      ),
    );
    expect(await settingsFile.exists(), isTrue);

    final migrated =
        jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>;
    expect(migrated['proxy_address'], '127.0.0.1:9000');
    expect(migrated['theme_mode'], 'light');

    expect(
      Directory(
        p.join(
          executableDir.path,
          AppDataService.dataDirName,
          AppDataService.projectsDirName,
        ),
      ).existsSync(),
      isTrue,
    );
    expect(
      Directory(
        p.join(
          executableDir.path,
          AppDataService.dataDirName,
          AppDataService.tempDirName,
        ),
      ).existsSync(),
      isTrue,
    );

    final tempDir = await AppDataService.createTempDirectory('asr_temp_');
    expect(
      p.isWithin(
        p.join(
          executableDir.path,
          AppDataService.dataDirName,
          AppDataService.tempDirName,
        ),
        tempDir.path,
      ),
      isTrue,
    );
  });

  test('migrates legacy database into executable sibling data tree', () async {
    final legacyDbPath = p.join(legacyDatabaseDir.path, AppConstants.dbName);

    await DatabaseService.init(overridePath: legacyDbPath);
    final project = AsrProject(
      id: 'legacy-project',
      name: '旧工程',
      createdAt: DateTime(2026, 5, 19, 10),
      updatedAt: DateTime(2026, 5, 19, 10),
    );
    await DatabaseService.insertProject(project);
    await DatabaseService.close();

    await DatabaseService.init();
    final loaded = await DatabaseService.getProject(project.id);

    expect(loaded?.name, '旧工程');
    expect(
      File(
        p.join(
          executableDir.path,
          AppDataService.dataDirName,
          AppDataService.databaseDirName,
          AppConstants.dbName,
        ),
      ).existsSync(),
      isTrue,
    );
  });
}
