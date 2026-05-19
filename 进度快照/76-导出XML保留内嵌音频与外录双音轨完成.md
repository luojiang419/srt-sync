# 进度快照 76 - 导出XML保留内嵌音频与外录双音轨完成

## 已完成内容

### 1. 时间线数据已补齐内嵌音频可见性
- `TimelineData` 已新增：
  - `videoHasEmbeddedAudio`
- `AudioAlignService.buildTimeline()` 在构建时间线时，已把视频素材的 `hasEmbeddedAudio` 带入时间线数据
- 未新增数据库字段，继续复用现有 `media_files.has_embedded_audio`

### 2. xmeml 导出已升级为双音轨结构
- `.xml` 导出现在会按两条并行音轨导出：
  - `A1` 视频内嵌音频轨
  - `A2` 外部录音音轨
- 有内嵌音频的视频素材会显式生成独立音频 `clipitem`
- 外录音频继续沿用现有偏移、裁切窗口和源入点导出
- 无内嵌音频或无外录时，会自动跳过对应轨道片段，不补空白占位

### 3. FCPXML 导出也已升级为显式双参考轨
- `.fcpxml` 导出现在会显式写出两类 `audio` 元素：
  - 内嵌音频参考轨 `lane="-1"`
  - 外录音频参考轨 `lane="-2"`
- 视频仍保留在 `spine`
- 内嵌音频与外录不再只靠视频资产隐式带出，而是都能在支持 FCPXML 的软件里作为可核对轨道存在

### 4. 导出入口与其他功能保持兼容
- `导出精简版 XML`
- `导出审片版 XML`
  两个按钮行为都已直接升级为双音轨保留
- `review` 预设仍只影响 marker
- CSV、SRT、试听音频裁切逻辑未改

## 当前修改到哪个模块
- `TimelineData.videoHasEmbeddedAudio`
- `AudioAlignService.buildTimeline()`
- `ExportService.exportXmeml()`
- `ExportService.exportFcpxml()`
- 导出结构测试
- 时间线字段测试

## 验证结果
- `flutter test --no-pub test/export_service_test.dart test/audio_align_service_test.dart`
  - 通过
- `flutter test --no-pub`
  - 通过
- `flutter analyze lib test`
  - 无新增 error / warning
  - 仍存在仓库既有 info 级提示

## 待办清单
- [ ] 递增版本号并构建新的 Windows release
- [ ] 复制发布产物到新的 `dist` 目录
- [ ] 做启动冒烟并补发布快照

## 下一步
- 进入版本发布流程，生成新版本目录供你直接验证导出的 `.xml/.fcpxml` 是否同时保留内嵌音频与外录双音轨。
