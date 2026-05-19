# 进度快照 #18 - 移除 FunASR-Nano

> 时间: 2026-04-21
> 版本: v0.10.1
> 状态: **FunASR-Nano 完全移除**
> 最新备份: backup/v0.10.0/
> 编译产物: build\windows\x64\runner\Release\asr_tools.exe
> 测试文件: G:\data\260224-元数据脚本测试\1_Video\ces\C0457.mp4

---

## 本次改动

### 移除 FunASR-Nano
- 删除 `FunAsrNanoConfig` 类、`findFunAsrNanoModel()`、`_recognizeWithFunAsrNano()` 方法
- 从 `AsrModelType` 枚举移除 `funAsrNano`
- 从 `SherpaOnnxEnv` 移除 `funAsrNanoConfig` 字段和 `hasFunAsrNano` getter
- 移除 FunASR-Nano 专用 8 秒分段逻辑（`maxSegSec`），统一使用 60 秒分段
- 从设置页面移除 FunASR-Nano 下拉选项
- 从环境指示器移除 FunASR-Nano 芯片
- 删除模型目录 `sherpa-onnx-funasr-nano-int8-2025-12-30/`

### 原因
FunASR-Nano 受限于 `max_total_len=512`（约 8 秒音频），长段音频需要强制分段导致上下文断裂，识别质量不如 Qwen3-ASR。

### 当前保留模型
| 模型 | 架构 | 特点 | RTF |
|------|------|------|-----|
| **Qwen3-ASR** | LLM (Qwen3-0.6B) | 有标点，准确率高（推荐） | 0.127 |
| **FireRed-ASR** | Encoder-Decoder | 中英双语，无标点 | 0.466 |

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `lib/services/sherpa_onnx_service.dart` | 移除 FunASR-Nano 全部代码：Config 类、查找、识别、枚举、分段逻辑 |
| `lib/screens/settings_screen.dart` | 移除 FunASR-Nano 下拉选项 |
| `lib/widgets/step_recognize.dart` | 移除 FunASR-Nano 环境指示芯片 |
| `lib/providers/settings_provider.dart` | 更新 `asrModelId` 注释 |

## 待办
- FFmpeg 编译时自动打包
