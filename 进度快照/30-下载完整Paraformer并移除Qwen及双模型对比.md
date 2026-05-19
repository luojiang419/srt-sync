# 进度快照 30 - 下载完整 Paraformer 并移除 Qwen 及双模型对比

## 版本信息
- 版本号: v1.0.7
- 备份: backup/v0.14.0
- 编译: dist/v1.0.7

## 已完成内容

### 1. 下载并接入完整 Paraformer-zh 大模型
- 已下载并解压官方完整模型:
  - `G:\data\app\DIT\sherpa-onnx\models\sherpa-onnx-paraformer-zh-2024-03-09`
- 当前模型目录中同时存在:
  - `sherpa-onnx-fire-red-asr-large-zh_en-2025-02-16`
  - `sherpa-onnx-paraformer-zh-2024-03-09`
  - `sherpa-onnx-paraformer-zh-small-2024-03-09`
- 代码中的 Paraformer 检测优先命中完整大模型，再退回 small

### 2. 完整移除 Qwen-ASR 相关代码
- 从 `sherpa_onnx_service.dart` 中移除:
  - `Qwen3AsrConfig`
  - `findQwen3AsrModel()`
  - `Qwen3-ASR` 枚举分支
  - `_recognizeWithQwen3Asr()`
  - `SherpaOnnxEnv.qwen3AsrConfig`
  - `hasQwen3Asr`
- 从 UI 与设置中移除:
  - 设置页 Qwen 选项
  - ASR 页 Qwen 环境标签
  - 速度对比脚本中的 Qwen 分支
- 已删除本地 Qwen 模型目录:
  - `G:\data\app\DIT\sherpa-onnx\models\sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25`

### 3. 模型配置与默认值整理
- 当前仅保留两模型:
  - `fire-red-asr`
  - `paraformer-zh`
- 默认模型仍为 `fire-red-asr`
- 对旧配置的兼容处理:
  - 旧 `qwen3-asr` 设置会在读取时自动回落到 `fire-red-asr`
  - 旧工程里的 `asr_model=qwen3-asr` 也会回落为 `fire-red-asr`

### 4. FireRed vs 完整 Paraformer 同样例对比
- 样例:
  - `G:\data\260224-元数据脚本测试\2_Audio\220822yinpin\ZOOM0041_LR.mp3`
- 时长:
  - `313095 ms`
- 推理环境:
  - `CUDA`

#### 对比结果
- FireRed-ASR
  - `elapsed_ms=141681`
  - `rtf=0.453`
  - `segments=37`
  - 主观准确率: 当前更好，文本语义更连贯
- Paraformer-zh（完整大模型）
  - `elapsed_ms=100768`
  - `rtf=0.322`
  - `segments=27`
  - 主观准确率: 比 FireRed 略差，但比此前 small 版更稳

#### 当前结论
- 速度:
  - Paraformer 更快
- 准确率:
  - FireRed 仍更好
- 默认模型保持 FireRed 是合理的

## 修改的文件
- `lib/services/sherpa_onnx_service.dart`
- `lib/providers/settings_provider.dart`
- `lib/models/asr_project.dart`
- `lib/screens/settings_screen.dart`
- `lib/widgets/step_recognize.dart`
- `tool/_compare_asr_models.dart`

## 当前可用模型
- FireRed-ASR
- Paraformer-zh

## 待办清单
- [ ] 如果需要，可继续做“同样例下 FireRed / Paraformer 的多条音频对比”
- [ ] 若要进一步提速，可增加“默认优先使用 Paraformer，手动切 FireRed”的工作流提示
- [ ] 处理剩余 lint/info 级静态提示

## 下一步
- 如果继续优化模型体验，建议做:
  - 多条样例对比
  - ASR 页增加“默认推荐模型”提示
  - 显示每个模型偏向“准确率/速度”的标签
