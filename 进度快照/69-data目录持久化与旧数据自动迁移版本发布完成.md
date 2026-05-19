# 进度快照 69 - data目录持久化与旧数据自动迁移版本发布完成

## 版本信息
- 新版本号: `v1.1.11`
- `pubspec.yaml`: `1.1.11+29`
- 阶段备份: `backup/v0.36.0`
- 发布目录: `dist/v1.1.11`

## 已完成内容

### 1. 已统一为可执行程序同级 `data/` 目录持久化
- 应用已改为使用可执行程序同级的 `data/` 目录体系
- 当前内部已统一使用以下子目录：
  - `data/config`
  - `data/database`
  - `data/projects`
  - `data/temp`

### 2. 设置文件已改为文件持久化到 `data/config`
- `asr_tools_settings.json` 已写入：
  - `data/config/asr_tools_settings.json`
- 窗口位置与大小、主题、语言、代理、ASR 路径与并发配置等，都跟随这个文件持久化

### 3. 工程与项目数据库已改为落在 `data/database`
- SQLite 数据库已写入：
  - `data/database/asr_tools.db`
- 当前工程、素材、字幕、匹配、复核、时间线等项目数据都会跟随数据库保存在这里
- `data/projects` 目录已预留，便于后续扩展独立项目文件

### 4. 旧数据自动迁移已接入
- 若旧系统位置已有：
  - `asr_tools_settings.json`
  - `asr_tools.db`
- 且新 `data/` 目录里尚无对应文件
- 首次启动时会自动迁移复制到新位置
- 数据库辅助文件 `-wal / -shm` 也已兼容复制

### 5. 运行时临时目录已收口到 `data/temp`
- ASR 提取 WAV 的临时工作目录已改到 `data/temp`
- sherpa-onnx 分段识别的临时目录已改到 `data/temp`

### 6. Flutter 发布包内的 `data/` 目录已被复用
- Flutter Windows 发布包本身会自带同级 `data/` 目录用于资源文件
- 本次没有再额外创建并列重名目录
- 而是在这个现有 `data/` 目录下继续创建应用自己的：
  - `config`
  - `database`
  - `projects`
  - `temp`
- 这样既满足“同级 `data/` 目录体系”的要求，也避免与 Flutter 运行时结构冲突

### 7. 构建与启动冒烟已完成
- `flutter build windows --release`
  - 通过
- 已生成：
  - `build/windows/x64/runner/Release/asr_tools.exe`
  - `dist/v1.1.11`
- 已完成启动冒烟：
  - `dist/v1.1.11/asr_tools.exe`
  - 正常启动并退出，验证通过
- 启动后已确认生成：
  - `dist/v1.1.11/data/config/asr_tools_settings.json`
  - `dist/v1.1.11/data/database/asr_tools.db`
  - `dist/v1.1.11/data/projects`
  - `dist/v1.1.11/data/temp`

## 验证结果

### 1. 静态检查
- `flutter analyze lib/services/app_data_service.dart lib/services/database_service.dart lib/providers/settings_provider.dart lib/main.dart lib/services/asr_batch_service.dart lib/services/sherpa_onnx_service.dart test/app_data_service_test.dart`
  - 无新增 error
  - 仍存在仓库既有 info 级提示
- `flutter analyze lib test`
  - 无新增 error
  - 仍存在仓库既有 info 级提示

### 2. 测试
- `flutter test --no-pub test/app_data_service_test.dart`
  - 通过
- `flutter test --no-pub`
  - 通过

### 3. Windows 构建
- `flutter build windows --release`
  - 通过

## 当前修改到哪个模块
- `AppDataService` 统一数据目录服务
- 设置文件与窗口几何持久化
- 数据库路径与旧数据迁移
- ASR 运行时临时目录路径
- 启动期数据目录准备流程
- 迁移测试、版本构建与发布

## 待办清单
- [ ] 可继续补一个设置页“当前数据目录位置”展示入口，方便用户直接打开
- [ ] 如需要，可继续把更多可再生中间文件进一步细分到 `data/temp` 或 `data/projects`
- [ ] 如需要，可继续增加“导出/迁移当前 data 目录”的手动工具入口

## 下一步
- 可以直接使用 `dist/v1.1.11` 验证新版存储结构；后续软件配置、工程数据与内部临时目录都会优先收口到同级 `data/` 目录体系。
