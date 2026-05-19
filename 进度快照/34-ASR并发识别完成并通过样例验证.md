# 进度快照 34 - ASR 并发识别完成并通过样例验证

## 版本信息
- 版本号: v1.0.8
- 备份: backup/v0.15.0
- 编译: dist/v1.0.8

## 已完成内容

### 1. ASR 并发识别功能已完成
- 已新增并发设置:
  - 自动模式
  - 手动模式
  - 手动并发数 `1-4`
- 批量识别已改为限流并发 worker 池。
- 自动模式策略:
  - GPU 默认 `1`
  - CPU 默认 `2`
- 并发下已处理:
  - WAV 临时目录隔离
  - 字幕写库串行保护
  - 取消后的残留状态收口
  - 识别页并发状态展示

### 2. 识别页与状态管理已同步完成
- 识别页可显示:
  - 实际并发数
  - 运行中数量
  - 排队中数量
  - 已完成数量
  - 失败数量
- 单文件卡片已支持 `排队中` 状态。

### 3. 验证结果
- `flutter test`:
  - 通过
- 并发相关文件静态检查:
  - 通过
- 全项目 `flutter analyze --no-fatal-infos`:
  - 无 error / warning
  - 仍有 37 个历史 info 级提示，主要集中在:
    - `settings_screen.dart` 的 async context
    - `sherpa_onnx_service.dart` 的 `print`
    - 若干旧文件的样式级提示

### 4. 样例全流程验证已通过
- 使用脚本:
  - `tool/sample_workflow.dart`
- 验证参数:
  - `--video-limit=2`
  - `--audio-limit=2`
  - `--concurrency-mode=manual`
  - `--concurrency=2`
- 实际结果:
  - `usedConcurrency=2`
  - `completed=4`
  - `failed=0`
  - 匹配成功 `2` 条
  - 时间线生成成功
  - XML / FCPXML 导出成功
- 导出文件:
  - `测试合板/sample_workflow_v2_a2_c2.xml`
  - `测试合板/sample_workflow_v2_a2_c2.fcpxml`

### 5. 发布产物
- 已完成 Windows 发布版编译。
- 新版本目录:
  - `dist/v1.0.8`

## 修改的文件
- `lib/core/constants.dart`
- `lib/providers/settings_provider.dart`
- `lib/l10n/app_localizations.dart`
- `lib/screens/settings_screen.dart`
- `lib/services/asr_batch_service.dart`
- `lib/providers/asr_process_provider.dart`
- `lib/widgets/asr_progress_panel.dart`
- `lib/widgets/step_recognize.dart`
- `tool/sample_workflow.dart`

## 当前状态
- 本轮目标已完成，可继续进入下一项任务。

## 下一步
- 如需继续优化，可选方向:
  - 根据 GPU 显存和任务时长做自适应并发
  - 增加“仅音频 / 仅视频 / 指定文件”并发识别入口
  - 清理全项目剩余 info 级静态提示
