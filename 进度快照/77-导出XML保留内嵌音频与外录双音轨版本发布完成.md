# 进度快照 77 - 导出XML保留内嵌音频与外录双音轨版本发布完成

## 版本信息
- 新版本号: `v1.1.15`
- `pubspec.yaml`: `1.1.15+33`
- 阶段备份: `backup/v0.40.0`
- 发布目录: `dist/v1.1.15`

## 已完成内容

### 1. XML/FCPXML 已同时保留双音轨
- 导出的两种格式现在都会同时保留：
  - 视频内嵌音频轨
  - 外部录音音轨
- 两条轨道彼此独立，导入剪辑软件后可直接静音、核对和手动校准
- 外录继续沿用现有匹配偏移与裁切窗口

### 2. xmeml 已改为显式双音轨
- `.xml` 中的 `audio` 轨道现在会按实际素材情况生成：
  - 内嵌音频轨
  - 外录音轨
- 内嵌音频轨引用视频源资产
- 外录音轨引用外部录音文件资产
- 若某段素材没有内嵌音频或外录，则只导出存在的那一类

### 3. FCPXML 已改为显式双参考轨
- `.fcpxml` 中视频仍保留在 `spine`
- 额外显式导出了两类 `audio` 元素：
  - `lane="-1"` 内嵌音频参考轨
  - `lane="-2"` 外录音频参考轨
- 这样导入支持 FCPXML 的软件后，也能直接看到两条独立可核对音轨

### 4. 测试、构建与启动冒烟已完成
- `flutter test --no-pub test/export_service_test.dart test/audio_align_service_test.dart`
  - 通过
- `flutter test --no-pub`
  - 通过
- `flutter analyze lib test`
  - 无新增 error / warning
  - 仍存在仓库既有 info 级提示
- `flutter build windows --release`
  - 通过
- 已生成：
  - `build/windows/x64/runner/Release/asr_tools.exe`
  - `dist/v1.1.15`
- 已完成启动冒烟：
  - `dist/v1.1.15/asr_tools.exe`
  - 正常拉起并完成自动关闭验证
- 已确认存在：
  - `dist/v1.1.15/data/config/asr_tools_settings.json`
  - `dist/v1.1.15/data/database/asr_tools.db`
  - `dist/v1.1.15/data/projects`
  - `dist/v1.1.15/data/temp`

## 当前修改到哪个模块
- 时间线模型内嵌音频标记
- 时间线构建导出字段回填
- xmeml 双音轨导出
- FCPXML 双参考轨导出
- 导出结构测试与时间线字段测试
- 版本构建与发布

## 待办清单
- [ ] 如需要，可继续在导出预设里增加“仅外录 / 双音轨 / 参考轨静音”可选项
- [ ] 如需要，可继续补一份真实样例导出文件用于人工导入验证
- [ ] 如需要，可继续把导出双音轨逻辑同步体现在操作手册说明里

## 下一步
- 可以直接使用 `dist/v1.1.15` 验证：
  - 导出的 `.xml` 是否出现两条并行音轨
  - 导出的 `.fcpxml` 是否同时保留内嵌音频与外录参考轨
  - 导入剪辑软件后是否能随时核对并手动校准
