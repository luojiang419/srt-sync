# 进度快照 #23 - Bug修复: ASR识别进度显示优化

> 时间: 2026-04-22
> 版本: v1.0.1
> 状态: **ASR识别进度显示已优化 + 进程超时保护，编译输出到 dist/v1.0.1**
> 编译产物: dist\v1.0.1\asr_tools.exe

---

## 问题

ASR 识别时进度条跳到中间就不再动，等几分钟后突然跳到完成。

## 根因

1. **进度显示粗糙** — 每个文件只有 4 个固定进度点（0.1 → 0.4 → 0.9 → 1.0），识别阶段的分段循环没有子进度
2. **总体进度跳跃** — 总进度只统计已完成的文件数，不反映当前正在识别的文件进度
3. **进程无超时** — sherpa-onnx/ffmpeg 子进程可能卡住无超时保护

## 修复内容

### 1. 分段级别进度回调
- `SherpaOnnxService.recognize()` 增加 `onSegmentProgress` 回调
- `_recognizeImpl` 预计算总子段数，每完成一段按比例报告进度
- 段进度 0.0~1.0 映射到文件进度 0.15~0.85

### 2. 平滑总体进度
- 总体进度改为每文件实际进度的平均值（而非只数完成数）

### 3. 进程超时保护
- 所有 `Process.run` 改为 `_runProcessWithTimeout`（`Process.start` + kill）
- silencedetect 3分钟、ffmpeg截取 2分钟、模型推理 10分钟

### 进度映射（单文件）
```
0.05 → 提取音频
0.15 → 开始识别
0.15~0.85 → 逐段识别（按子段数比例实时更新）
0.90 → 保存结果
1.00 → 完成
```

### 修改的文件：
- `lib/services/sherpa_onnx_service.dart` — 段进度回调 + 超时保护
- `lib/services/asr_batch_service.dart` — 将段进度映射到文件进度
- `lib/providers/asr_process_provider.dart` — 总体进度改为平均值算法

---

## 待办
- 用户测试验证进度显示是否平滑
