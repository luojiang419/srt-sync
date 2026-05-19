# 进度快照 #24 - 新增功能: ASR识别卡片点击查看字幕弹窗

> 时间: 2026-04-22
> 版本: v1.0.2
> 状态: **ASR识别完成卡片可点击查看字幕弹窗，已编译输出到 dist/v1.0.2**
> 编译产物: dist\v1.0.2\asr_tools.exe

---

## 新增功能

ASR 识别完成后，点击已完成的素材卡片弹出字幕查看弹窗。

### 新增文件
- `lib/widgets/subtitle_detail_dialog.dart` — 字幕查看弹窗组件
  - Dialog 弹窗，宽680×高520
  - 顶部：标题 + 文件名 + 关闭按钮
  - 统计信息：总段数 + 总时长
  - 列表：序号 + 时间码 + 字幕文本（复用 SubtitleCompareDialog 样式）
  - 使用 `subtitleClipsProvider` 从数据库加载字幕

### 修改文件
- `lib/widgets/asr_progress_panel.dart`
  - 新增 `onTap` 回调参数
  - 已完成/已跳过的卡片用 `InkWell` 包裹，支持点击涟漪效果
  - 右侧增加箭头图标提示可点击

- `lib/widgets/step_recognize.dart`
  - 给已完成/已跳过的卡片传入 `onTap` 回调
  - 点击后 `showDialog` 打开 `SubtitleDetailDialog`

---

## 待办
- 用户测试验证弹窗功能
