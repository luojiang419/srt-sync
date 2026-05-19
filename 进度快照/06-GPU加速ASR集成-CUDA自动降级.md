# 进度快照 #06 - GPU加速ASR集成 + CUDA自动降级

> 时间: 2026-04-16
> 版本: v0.4.1
> 状态: 阶段4完成（含GPU加速），下次从阶段5开始
> 最新备份: backup/v0.4.1/
> 编译产物: dist/v0.4.1/

---

## 本次完成内容：GPU 加速 ASR 引擎集成

### 背景
参考 DIT 项目 (v3.6.0) 的 GPU 加速实现，将 CUDA 自动检测和降级机制集成到 ASR-tools 中。

### 修改文件

#### 1. `lib/core/constants.dart`
- 模型名称从 `SenseVoiceSmall` 改为 `sense-voice-small`（匹配 DIT 项目目录结构）

#### 2. `lib/providers/settings_provider.dart`
- `sherpaOnnxPath` 默认值从空字符串改为 `G:\data\app\DIT\sherpa-onnx`
- 解决"ASR未配置路径"问题

#### 3. `lib/services/sherpa_onnx_service.dart` — 完整重写
新增功能：
- **GPU 4级自动检测**：
  1. NVIDIA GPU 硬件检测 (nvidia-smi)
  2. CUDA DLL 检查 (cudart64_12.dll, onnxruntime_providers_cuda.dll)
  3. cuDNN DLL 检查 (cudnn64_9.dll, cudnn_ops64_9.dll)
  4. cuFFT DLL 检查 (cufft64_11.dll)
- **Provider 自动选择**：`auto` → CUDA 可用则用，否则 CPU
- **CUDA→CPU 自动降级**：CUDA 推理失败时自动切换 CPU 重试
- **VAD+ASR 双模式**：
  - 优先使用 `sherpa-onnx-vad-with-offline-asr.exe`（VAD 预处理 + ASR 识别一步到位）
  - 后备使用 `sherpa-onnx-offline.exe`（传统模式）
- **多格式输出解析**：
  - VAD 输出: `start -- end: text`
  - JSON 输出: `{"text": "...", "timestamps": [...], "tokens": [...]}`
  - Token 聚合（按标点/42字符分段）
  - 长文本按标点拆分 + 时间等比分配
- `SherpaOnnxEnv` 扩展：新增 `modelFile`, `tokensFile`, `vadWithAsrExePath`
- `GpuStatus` 枚举：`gpuAvailable`, `cpuOnly`, `notConfigured`, `unknown`

#### 4. `lib/services/asr_batch_service.dart`
- `_recognizeSingleFile` 适配新的 `SherpaOnnxService.recognize` 签名
- 传递 `baseDir` 用于 GPU 检测

#### 5. `lib/widgets/step_recognize.dart`
- 环境指示器改为异步 `FutureBuilder<GpuStatus>` 显示
- GPU 加速时显示绿色 "GPU 加速" + 蓝色 "VAD+ASR"
- CPU 模式时显示橙色 "CPU 模式" + 蓝色 "VAD+ASR"
- 环境异常时显示黄色警告

### sherpa-onnx 路径结构（复用 DIT 项目）
```
G:\data\app\DIT\sherpa-onnx\
├── bin\
│   ├── sherpa-onnx-offline.exe          ← 传统模式
│   ├── sherpa-onnx-vad-with-offline-asr.exe  ← VAD+ASR 组合模式（优先）
│   ├── cudart64_12.dll                  ← CUDA Runtime
│   ├── onnxruntime_providers_cuda.dll   ← CUDA EP
│   ├── cudnn64_9.dll                    ← cuDNN
│   └── ...其他 CUDA DLL
└── models\
    ├── sense-voice-small\
    │   ├── model.int8.onnx              ← SenseVoice 模型
    │   └── tokens.txt
    └── silero_vad.onnx                  ← Silero VAD 模型
```

---

## 待办清单（未完成）

### 阶段 5: 字幕匹配 [ ] 0/7
- [ ] 5.1 实现 lib/services/subtitle_match_service.dart
- [ ] 5.2 实现 lib/providers/match_provider.dart
- [ ] 5.3 实现 lib/widgets/step_match.dart
- [ ] 5.4 实现 lib/widgets/match_result_tile.dart
- [ ] 5.5 实现 lib/widgets/subtitle_compare.dart
- [ ] 5.6 实现手动匹配功能
- [ ] 5.7 验收

### 阶段 6: 时间线生成 [ ] 0/6
- [ ] 6.1 ~ 6.6

### 阶段 7: 打磨优化 [ ] 0/6
- [ ] 7.1 ~ 7.6

## 技术备忘

- **Flutter**: G:\data\flutter (3.38.8 / Dart 3.10.7)
- **FFmpeg**: G:\data\app\DIT\ffmpeg
- **sherpa-onnx**: G:\data\app\DIT\sherpa-onnx
- **模型**: sense-voice-small (model.int8.onnx)
- **代理**: 192.168.0.211:7890
- **编译命令**: `"G:/data/flutter/bin/flutter.bat" build windows --debug`
- **备份位置**: backup/v0.4.1/
- **编译产物**: dist/v0.4.1/

## 下次续写从这里开始

1. **阶段5: 字幕匹配** - 下一个要开发的阶段
2. 首先创建 `subtitle_match_service.dart`（滑动窗口 + Levenshtein + 贪心分配）
3. 然后创建 `match_provider.dart`
4. 再创建 UI 组件
