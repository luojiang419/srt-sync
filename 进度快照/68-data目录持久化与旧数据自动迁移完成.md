# 进度快照 68 - data目录持久化与旧数据自动迁移完成

## 版本信息
- 当前源码版本: `1.1.11+29`
- 阶段备份: `backup/v0.36.0`
- 发布状态: 待编译发布

## 已完成内容

### 1. 可执行程序同级 `data/` 目录体系已建立
- 已新增统一数据目录服务
- 现在会在可执行程序同级维护以下目录：
  - `data/config`
  - `data/database`
  - `data/projects`
  - `data/temp`
- 后续内部持久化文件统一从这里取路径，不再直接散落到系统应用目录

### 2. 设置文件已迁移到 `data/config`
- `asr_tools_settings.json` 已改为存放在：
  - `data/config/asr_tools_settings.json`
- 包括以下配置都会持久化到这里：
  - FFmpeg / Sherpa-ONNX 路径
  - 代理地址
  - 语言
  - 主题
  - 导航样式
  - ASR 并发 / 模型 / VAD / 识别语言
  - 窗口位置与大小

### 3. 工程与项目数据已迁移到 `data/database`
- SQLite 数据库已改为存放在：
  - `data/database/asr_tools.db`
- 当前工程、素材、字幕、匹配、时间线、复核等项目数据都会跟随数据库一起落在该目录
- 已预留 `data/projects` 目录，便于后续继续拆分独立项目文件

### 4. 旧设置与旧数据库已支持自动迁移
- 如果旧位置存在：
  - 系统应用目录下的 `asr_tools_settings.json`
  - 系统数据库目录下的 `asr_tools.db`
- 且新的 `data/` 目录里还没有对应文件
- 首次启动时会自动复制迁移到新的 `data/` 目录
- 已兼容数据库 `-wal / -shm` 辅助文件复制

### 5. 运行时临时目录也已收口到 `data/temp`
- ASR 提取 WAV 的临时目录已改到 `data/temp`
- sherpa-onnx 分段识别的临时目录已改到 `data/temp`
- 软件内部中间产物将尽量跟随发布目录，便于定位和清理

### 6. 自动化验证已完成
- `flutter analyze lib/services/app_data_service.dart lib/services/database_service.dart lib/providers/settings_provider.dart lib/main.dart lib/services/asr_batch_service.dart lib/services/sherpa_onnx_service.dart test/app_data_service_test.dart`
  - 无新增 error
  - 仍有仓库既有 info 级提示
- `flutter test --no-pub test/app_data_service_test.dart`
  - 通过
- `flutter test --no-pub`
  - 通过
- `flutter analyze lib test`
  - 无新增 error
  - 仍存在仓库既有 info 级提示

## 当前修改到哪个模块
- `AppDataService` 统一数据目录服务
- `main.dart` 启动期数据目录准备与窗口几何落盘
- `SettingsNotifier` 设置文件存储路径
- `DatabaseService` 数据库初始化路径
- `AsrBatchService / SherpaOnnxService` 临时目录路径
- 旧配置 / 旧数据库自动迁移测试

## 待办清单
- [ ] 执行 Windows release 编译
- [ ] 复制发布产物到 `dist/v1.1.11`
- [ ] 启动发布版，验证 `data/` 目录自动生成
- [ ] 生成版本发布快照
- [ ] 提交并推送本次功能修改

## 下一步
- 继续执行 `flutter build windows --release`，生成 `dist/v1.1.11`，并验证发布版同级 `data/` 目录及其中配置/数据库目录自动创建。
