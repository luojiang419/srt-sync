# 进度快照 #15 - Bug修复：新建工程无反应 + ASR模型配置

> 时间: 2026-04-18
> 版本: v0.9.0
> 状态: **Bug修复完成**
> 最新备份: backup/v0.9.0/
> 编译产物: dist/v0.9.0/

---

## 本次修复内容

### Bug 1: 新建工程弹窗上下文失效
- **文件**: `lib/screens/home_screen.dart`
- **问题**: `_doCreate` 在 `Navigator.pop(dialogContext)` 后使用已失效的 `dialogContext` 调用 `SnackbarUtil.success`，导致静默报错
- **修复**: 分离 `parentContext`（首页）和 `dialogContext`（弹窗），Snackbar 使用 parentContext；增加 try-catch 错误处理

### Bug 2: 模型名称不一致
- **文件**: `lib/models/asr_project.dart`, `lib/services/database_service.dart`
- **问题**: `AsrProject.asrModel` 默认值为 `'SenseVoiceSmall'`，但 `AppConstants.defaultAsrModel` 为 `'sense-voice-small'`，导致 `findModelDir` 查找目录名不匹配
- **修复**: 统一为 `'sense-voice-small'`（与 sherpa-onnx 实际目录名一致）

### Bug 3: modelPath 设置未生效
- **文件**: `lib/services/sherpa_onnx_service.dart`, `lib/services/asr_batch_service.dart`, `lib/providers/asr_process_provider.dart`, `lib/widgets/step_recognize.dart`
- **问题**: 设置页可配置 `modelPath`，但从未传递到 sherpa 服务链路
- **修复**: `checkEnv` 增加 `customModelPath` 参数，整个调用链（batch → provider → UI）全部传递 `modelPath`

---

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `lib/screens/home_screen.dart` | 修复 `_doCreate` 上下文，增加错误处理 |
| `lib/models/asr_project.dart` | `asrModel` 默认值 `'SenseVoiceSmall'` → `'sense-voice-small'` |
| `lib/services/database_service.dart` | 建表默认值同步修改 |
| `lib/services/sherpa_onnx_service.dart` | `checkEnv` 增加 `customModelPath` 参数 |
| `lib/services/asr_batch_service.dart` | `batchRecognize`/`reRecognizeFile` 增加 `modelPath` 参数 |
| `lib/providers/asr_process_provider.dart` | 三处调用传递 `settings.modelPath` |
| `lib/widgets/step_recognize.dart` | 环境指示器传递 `modelPath` |

## 版本信息
- 版本号：v0.9.0
- 编译通过：dist/v0.9.0/asr_tools.exe

## 待办清单（未完成）
- 无

## 下一步
- 等待新任务指令
