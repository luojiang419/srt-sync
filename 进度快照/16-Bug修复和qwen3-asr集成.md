# 进度快照 #16 - Bug修复 + qwen3-asr 高精度识别集成

> 时间: 2026-04-18
> 版本: v0.9.0
> 状态: **修复完成 + qwen3-asr 集成**
> 最新备份: backup/v0.9.0/
> 编译产物: dist/v0.9.0/
> 测试文件: G:\data\260224-元数据脚本测试\1_Video\ces\C0457.mp4

---

## 本次修复内容

### Bug 1: 新建工程弹窗上下文失效
- **文件**: `lib/screens/home_screen.dart`
- **修复**: 分离 parentContext/dialogContext，Snackbar 使用 parentContext；增加 try-catch

### Bug 2: 模型名称不一致
- **文件**: `lib/models/asr_project.dart`, `lib/services/database_service.dart`
- **修复**: 统一为 `'sense-voice-small'`

### Bug 3: modelPath 设置未生效
- **文件**: `lib/services/sherpa_onnx_service.dart` 等多文件
- **修复**: `checkEnv` 增加 `customModelPath` 参数，全链路传递

### Bug 4: FfmpegService 路径未注入
- **文件**: `lib/services/ffmpeg_service.dart`, `lib/app.dart`
- **问题**: `setFfmpegDir()` 从未被调用，FFmpeg 不在系统 PATH
- **修复**: app.dart 中注入路径；`setFfmpegDir` 自动检测 bin 子目录

### 新功能: qwen3-asr 高精度识别
- **文件**: `lib/services/sherpa_onnx_service.dart`, `lib/widgets/step_recognize.dart`
- **实现**: 两阶段识别
  1. VAD+SenseVoice 获取精确时间戳
  2. 对每段用 qwen3-asr 重新识别，获取更准确文本
- **模型位置**: `G:\data\app\DIT\sherpa-onnx\models\sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25\`
- **自动检测**: 如果模型存在则自动启用，否则使用 SenseVoice

## 测试结果
- 测试文件: C0457.mp4 (17分钟, 1080p, AAC)
- SenseVoice: 多处误识别，如 "手机能看外面吗"
- qwen3-asr: 准确识别，如 "你手机能看画面吗？连上了吗？没连，现在连吧。"
- qwen3-asr 准确率显著优于 SenseVoice

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `lib/screens/home_screen.dart` | 修复 _doCreate 上下文 |
| `lib/models/asr_project.dart` | 模型名称统一 |
| `lib/services/database_service.dart` | 建表默认值同步 |
| `lib/services/sherpa_onnx_service.dart` | checkEnv 支持 modelPath + qwen3-asr 两阶段识别 |
| `lib/services/ffmpeg_service.dart` | bin 子目录检测 |
| `lib/services/asr_batch_service.dart` | 传递 modelPath |
| `lib/providers/asr_process_provider.dart` | 传递 settings.modelPath |
| `lib/providers/settings_provider.dart` | 无变化 |
| `lib/widgets/step_recognize.dart` | 传递 modelPath + 显示 Qwen3-ASR 状态 |
| `lib/app.dart` | 注入 FFmpeg 路径 |

## 待办
- 用户要求 FFmpeg 编译时自动打包（每个 exe 约 200MB）
- 长时间音频处理性能优化

## 下一步
- 等待用户确认 FFmpeg 打包方案
