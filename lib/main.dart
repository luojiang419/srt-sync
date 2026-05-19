import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/settings_provider.dart';
import 'services/app_data_service.dart';
import 'services/database_service.dart';

void main() {
  var bootstrapCompleted = false;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('Flutter Error: ${details.exceptionAsString()}');
    }
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppDataService.preparePersistentDataLayout();

      // 预加载设置（用于恢复窗口位置）
      final settings = await _loadSettings();
      final hasUsableStoredGeometry = _hasUsableStoredGeometry(settings);

      await windowManager.ensureInitialized();

      final windowOptions = WindowOptions(
        size: _targetWindowSize(settings),
        center: !hasUsableStoredGeometry,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'ASR合板工具',
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await _showConfiguredWindow(settings);
      });

      await DatabaseService.init();

      runApp(const ProviderScope(child: AsrToolsApp()));
      unawaited(_ensureWindowVisible(settings));
      bootstrapCompleted = true;
    },
    (error, stack) {
      if (!bootstrapCompleted) {
        runApp(StartupErrorApp(error: error, stack: stack));
        bootstrapCompleted = true;
      }
      if (kDebugMode) {
        debugPrint('Unhandled error: $error\n$stack');
      }
    },
  );
}

/// 预加载设置（不依赖 Riverpod）
Future<AppSettings> _loadSettings() async {
  try {
    final file = File(await AppDataService.settingsFilePath());
    if (await file.exists()) {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return AppSettings.fromMap(json);
    }
  } catch (_) {}
  return const AppSettings();
}

const _defaultWindowSize = Size(1280, 800);
const _fallbackWindowOffset = Offset(120, 80);

bool _hasUsableStoredGeometry(AppSettings settings) {
  if (!settings.hasWindowGeometry) return false;

  return settings.windowX!.isFinite &&
      settings.windowY!.isFinite &&
      settings.windowWidth!.isFinite &&
      settings.windowHeight!.isFinite &&
      settings.windowWidth! >= 640 &&
      settings.windowHeight! >= 480 &&
      settings.windowWidth! <= 10000 &&
      settings.windowHeight! <= 10000 &&
      settings.windowX! > -30000 &&
      settings.windowY! > -30000;
}

Size _targetWindowSize(AppSettings settings) {
  if (_hasUsableStoredGeometry(settings)) {
    return Size(settings.windowWidth!, settings.windowHeight!);
  }
  return _defaultWindowSize;
}

Offset _targetWindowOffset(AppSettings settings) {
  if (_hasUsableStoredGeometry(settings)) {
    return Offset(settings.windowX!, settings.windowY!);
  }
  return _fallbackWindowOffset;
}

bool _looksWindowHidden(Offset position, Size size) {
  return position.dx <= -30000 ||
      position.dy <= -30000 ||
      size.width < 200 ||
      size.height < 120;
}

Future<void> _showConfiguredWindow(
  AppSettings settings, {
  bool forceFallbackPosition = false,
}) async {
  final targetSize = _targetWindowSize(settings);
  final targetOffset = forceFallbackPosition
      ? _fallbackWindowOffset
      : _targetWindowOffset(settings);

  try {
    await windowManager.setSize(targetSize);
    await windowManager.setPosition(targetOffset);
    await windowManager.show();
    await windowManager.focus();
  } catch (_) {}
}

Future<void> _ensureWindowVisible(AppSettings settings) async {
  const probeDelays = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 1200),
    Duration(milliseconds: 3000),
  ];

  for (final delay in probeDelays) {
    await Future.delayed(delay);
    try {
      final position = await windowManager.getPosition();
      final size = await windowManager.getSize();
      if (_looksWindowHidden(position, size)) {
        await _showConfiguredWindow(settings, forceFallbackPosition: true);
        await _persistWindowGeometrySnapshot();
        continue;
      }

      await windowManager.show();
      await windowManager.focus();
      await _persistWindowGeometrySnapshot();
      return;
    } catch (_) {}
  }
}

Future<void> _persistWindowGeometrySnapshot() async {
  try {
    final pos = await windowManager.getPosition();
    final size = await windowManager.getSize();
    final file = File(await AppDataService.settingsFilePath());
    await file.parent.create(recursive: true);

    Map<String, dynamic> json = {};
    if (await file.exists()) {
      json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    }

    json['window_x'] = pos.dx;
    json['window_y'] = pos.dy;
    json['window_width'] = size.width;
    json['window_height'] = size.height;
    await file.writeAsString(jsonEncode(json));
  } catch (_) {}
}

/// 窗口位置/大小自动保存监听器
class WindowGeometryListener with WindowListener {
  static WindowGeometryListener? _instance;
  Timer? _debounce;

  WindowGeometryListener._();

  static void attach() {
    _instance ??= WindowGeometryListener._();
    windowManager.addListener(_instance!);
  }

  static void detach() {
    if (_instance != null) {
      windowManager.removeListener(_instance!);
    }
  }

  @override
  void onWindowMoved() => _saveGeometry();

  @override
  void onWindowResized() => _saveGeometry();

  void _saveGeometry() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 500),
      _persistWindowGeometrySnapshot,
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace? stack;

  const StartupErrorApp({super.key, required this.error, this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                color: const Color(0xFF1F2937),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Color(0xFFF59E0B),
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'ASR合板工具启动失败',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '程序在初始化阶段发生错误，因此未能正常进入主界面。请把下面的错误信息发给我，我会继续处理。',
                        style: TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SelectableText(
                        '$error',
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      if (stack != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF374151)),
                          ),
                          child: SelectableText(
                            '$stack',
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
