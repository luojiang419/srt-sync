# 进度快照 #17 - 弃用 SenseVoice + 三模型集成

> 时间: 2026-04-18
> 版本: v0.10.0
> 状态: **SenseVoice 完全移除 + 三模型集成**
> 最新备份: backup/v0.10.0/
> 编译产物: dist/v0.9.0/
> 测试文件: G:\data\260224-元数据脚本测试\1_Video\ces\C0457.mp4

---

## 本次改动

### 弃用 SenseVoice
- 删除所有 SenseVoice 相关代码和模型引用（8个文件）
- 删除模型目录 `models/sense-voice-small/`
- 删除 `sherpa-onnx-vad-with-offline-asr.exe` 依赖（不再需要）

### 集成三种高精度 ASR 模型
| 模型 | 架构 | 特点 | RTF |
|------|------|------|-----|
| **Qwen3-ASR** | LLM (Qwen3-0.6B) | 有标点，准确率高 | 0.127 |
| **Fun-ASR-Nano** | LLM (Qwen3-0.6B) | 极快，有标点 | 0.007 |
| **FireRed-ASR** | Encoder-Decoder | 中英双语 | 0.466 |

### 新 VAD 方案
- 弃用 `sherpa-onnx-vad-with-offline-asr.exe`（依赖 SenseVoice）
- 改用 **ffmpeg silencedetect** 获取语音段时间戳
- 对每段提取 WAV → 模型识别 → 合并结果
- FunASR-Nano 自动二次分段（max_total_len=512 限制）

### 新增模型选择 UI
- 设置页面添加 ASR 模型下拉选择
- 自动检测已安装的模型
- `AppSettings` 新增 `asrModelId` 字段

## 模型文件位置
- Qwen3-ASR: `models/sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25/`
- Fun-ASR-Nano: `models/sherpa-onnx-funasr-nano-int8-2025-12-30/`
- FireRed-ASR: `models/sherpa-onnx-fire-red-asr-large-zh_en-2025-02-16/`

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `lib/services/sherpa_onnx_service.dart` | 完全重写：删除 SenseVoice，新增三模型架构 + ffmpeg silencedetect VAD |
| `lib/services/asr_batch_service.dart` | 适配新接口：`modelName` → `modelId`，移除 `modelPath` |
| `lib/providers/asr_process_provider.dart` | 传递 `settings.asrModelId` |
| `lib/providers/settings_provider.dart` | 新增 `asrModelId` 字段 |
| `lib/core/constants.dart` | `defaultAsrModel` → `'qwen3-asr'` |
| `lib/models/asr_project.dart` | 默认模型 → `'qwen3-asr'` |
| `lib/services/database_service.dart` | 建表默认值同步 |
| `lib/screens/settings_screen.dart` | 新增模型选择 UI |
| `lib/widgets/step_recognize.dart` | 更新环境指示器 |
| `lib/services/ffmpeg_service.dart` | 新增 `ffmpegPath` 公共 getter |
| `lib/l10n/app_localizations.dart` | 移除 SenseVoice 描述 |

## CLI 测试结果（C0457.mp4 第60-90秒）

**Qwen3-ASR**（推荐）:
> 没事，不用。我能看到画面，我就能看到画面。我关了。后面都是哭的。没事，就那个了。那个破屏也是爆的一样。因为光比差太大了，看看，其实还好点儿。没照。没事，我先整保人脸。你看这个位置呢，这边。

**Fun-ASR-Nano**（极快）:
> 没事不用，我能看到旁边，我这边看到旁边，甭管了。后面都是坑。

**FireRed-ASR**（无标点）:
> 没事不用我能看到画面我就能看到画面甭管了能拍后面都是铺的没事就有那个了那个也铺不进去也是爆的一样那光比差太大了没招我现在我现在只能保人脸

## 待办
- FFmpeg 编译时自动打包（用户已请求）
- FunASR-Nano 可考虑下载 max_total_len 更大的版本
