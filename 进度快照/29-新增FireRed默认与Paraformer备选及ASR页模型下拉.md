# 进度快照 29 - 新增 FireRed 默认与 Paraformer 备选及 ASR 页模型下拉

## 版本信息
- 版本号: v1.0.6
- 备份: backup/v0.13.0
- 编译: dist/v1.0.6

## 已完成内容

### 1. 默认模型切换
- 默认 ASR 模型从 `qwen3-asr` 调整为 `fire-red-asr`
- 同步修改位置:
  - `AppConstants.defaultAsrModel`
  - `AppSettings` 默认值与反序列化默认值
  - `AsrProject` 默认值
  - 新建数据库表结构中的 `projects.asr_model` 默认值

### 2. 新增 Paraformer-zh 集成
- 在 `sherpa_onnx_service.dart` 中新增 `paraformer-zh` 模型类型
- 新增 `ParaformerZhConfig`
- 新增本地模型发现逻辑:
  - `sherpa-onnx-paraformer-zh-2024-03-09`
  - `sherpa-onnx-paraformer-zh-2023-09-14`
  - `sherpa-onnx-paraformer-zh-small-2024-03-09`
  - `paraformer-zh`
  - 以上目录的 `models/` 变体
- 新增 `--paraformer=... --tokens=... --model-type=paraformer` 调用逻辑
- `SherpaOnnxEnv` 现支持同时检测:
  - `FireRed-ASR`
  - `Paraformer-zh`
  - `Qwen3-ASR`

### 3. 本地模型已落地
- 已下载并解压官方 Paraformer 中文模型族中的轻量版本:
  - `G:\data\app\DIT\sherpa-onnx\models\sherpa-onnx-paraformer-zh-small-2024-03-09`
- 当前环境检测结果:
  - FireRed: 可用
  - Paraformer: 可用
  - Qwen: 可用

### 4. ASR 识别页面新增模型下拉
- 在 `lib/widgets/step_recognize.dart` 顶部新增模型下拉选择
- 下拉来源于当前本机真实可用模型，不显示不存在的模型
- 切换后会直接写回 `settingsProvider`
- 识别运行中禁用切换，避免中途改模型

### 5. 设置页模型选项更新
- `settings_screen.dart` 的模型下拉已扩展为三模型
- 顺序调整为:
  - `FireRed-ASR`
  - `Paraformer-zh`
  - `Qwen3-ASR`

### 6. 运行验证
- `flutter test` 通过
- `flutter build windows --release` 通过
- Paraformer 进行了最小推理验证:
  - 使用 `sherpa-onnx-paraformer-zh-small-2024-03-09/test_wavs/0.wav`
  - 成功输出中文识别结果

## 修改的文件
- `lib/core/constants.dart`
- `lib/providers/settings_provider.dart`
- `lib/models/asr_project.dart`
- `lib/services/database_service.dart`
- `lib/services/sherpa_onnx_service.dart`
- `lib/screens/settings_screen.dart`
- `lib/widgets/step_recognize.dart`

## 新增/落地的模型资源
- `G:\data\app\DIT\sherpa-onnx\models\sherpa-onnx-paraformer-zh-small-2024-03-09`

## 待办清单
- [ ] 如需更高 Paraformer 准确率，可再下载并替换为完整 `sherpa-onnx-paraformer-zh-2024-03-09`
- [ ] 如需进一步比较三模型速度/准确率，可做同一条样例的对比测试
- [ ] 处理剩余 lint/info 级静态提示

## 下一步
- 如果你要继续，我建议直接做“三模型同样例对比测试”
- 输出每个模型的:
  - 推理耗时
  - 识别文本
  - 主观准确率对比
