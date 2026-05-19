import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/asr_project.dart';
import '../services/database_service.dart';
import '../services/video_thumbnail_service.dart';

/// 工程列表状态
class ProjectListState {
  final List<AsrProject> projects;
  final bool isLoading;
  final String? error;

  const ProjectListState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectListState copyWith({
    List<AsrProject>? projects,
    bool? isLoading,
    String? error,
  }) {
    return ProjectListState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 工程列表 Notifier
class ProjectListNotifier extends AsyncNotifier<ProjectListState> {
  @override
  ProjectListState build() {
    // 初始化时自动加载
    Future.microtask(() => loadProjects());
    return const ProjectListState(isLoading: true);
  }

  /// 加载所有工程
  Future<void> loadProjects() async {
    state = AsyncData(
      state.valueOrNull?.copyWith(isLoading: true) ??
          const ProjectListState(isLoading: true),
    );
    try {
      final projects = await DatabaseService.getAllProjects();
      state = AsyncData(ProjectListState(projects: projects));
    } catch (e) {
      state = AsyncData(ProjectListState(error: e.toString()));
    }
  }

  /// 新建工程
  Future<AsrProject> createProject(String name) async {
    final now = DateTime.now();
    final project = AsrProject(
      id: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    await DatabaseService.insertProject(project);
    await loadProjects();
    return project;
  }

  /// 重命名工程
  Future<void> renameProject(String id, String newName) async {
    final project = await DatabaseService.getProject(id);
    if (project == null) return;
    final updated = project.copyWith(name: newName, updatedAt: DateTime.now());
    await DatabaseService.updateProject(updated);
    await loadProjects();
  }

  /// 删除工程
  Future<void> deleteProject(String id) async {
    await DatabaseService.deleteProject(id);
    await VideoThumbnailService.deleteProjectCache(id);
    await loadProjects();
  }

  /// 更新工程状态
  Future<void> updateStatus(String id, ProjectStatus status) async {
    final project = await DatabaseService.getProject(id);
    if (project == null) return;
    final updated = project.copyWith(status: status, updatedAt: DateTime.now());
    await DatabaseService.updateProject(updated);
    await loadProjects();
  }
}

/// 工程列表 Provider
final projectListProvider =
    AsyncNotifierProvider<ProjectListNotifier, ProjectListState>(
      ProjectListNotifier.new,
    );
