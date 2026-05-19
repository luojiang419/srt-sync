# 进度快照 #25 - ASR步骤分栏显示 + 批量删除

> 时间: 2026-04-22
> 版本: v1.0.2
> 状态: **ASR识别步骤改为视频/音频分栏布局，支持多选批量删除**
> 编译产物: dist\v1.0.2\asr_tools.exe

---

## 新增/修改功能

### 1. ASR识别步骤改为分栏布局
- 左栏：视频素材列表（文件名 + 时长）
- 右栏：音频素材列表（ASR进度卡片）
- 每栏顶部：类型图标 + 文件数量 + 全选复选框

### 2. 批量删除功能
- 每个素材行左侧有复选框，支持单选和全选
- 选中后顶部出现"删除选中 (N)"红色按钮
- 删除前弹出确认对话框
- 删除后自动刷新素材列表和ASR进度

### 3. 数据库新增方法
- `DatabaseService.deleteMediaFilesByIds(ids)` — 按 ID 批量删除
- 同时清理关联的 match_pairs 和 subtitle_clips（CASCADE）

### 4. ASR进度管理新增方法
- `AsrProcessNotifier.removeFileProgresses(ids)` — 删除文件后清理进度

### 修改的文件
| 文件 | 操作 |
|------|------|
| `lib/widgets/step_recognize.dart` | **重构** — ConsumerStatefulWidget + 分栏 + 多选删除 |
| `lib/widgets/asr_progress_panel.dart` | **修改** — 增加 isSelected/onSelect 复选框 |
| `lib/services/database_service.dart` | **修改** — 新增 deleteMediaFilesByIds |
| `lib/providers/asr_process_provider.dart` | **修改** — 新增 removeFileProgresses |

### 新增文件
- `lib/widgets/subtitle_detail_dialog.dart` — 字幕查看弹窗（#24功能）

---

## 待办
- 用户测试分栏布局和批量删除功能
