# 进度快照 28 - 修复 ASR/匹配/时间线主链路并完成单条样例验证

## 版本信息
- 版本号: v1.0.5
- 备份: backup/v0.12.0
- 编译: dist/v1.0.5

## 已完成内容

### 1. 工程基础修复
- 增加 `path_provider` 直接依赖，消除主工程依赖缺失
- `analysis_options.yaml` 排除 `backup/build/dist/windows/flutter` 分析噪音
- SQLite 初始化时显式开启 `PRAGMA foreign_keys = ON`
- 默认模板测试已替换为有效的基础单测，`flutter test` 可通过

### 2. ASR 主链路修复
- ASR 从“仅识别音频”改为“视频和音频双端识别”
- 新增取消态，修复“点击停止后仍被当作成功完成”的状态错误
- 修复批量重新开始与断点续传的语义分离
  - 开始/重启: 全量重跑
  - 继续: 跳过已有字幕，仅处理未完成文件
- 识别页已支持查看视频自身字幕，不再依赖“同名音频字幕挂到视频卡片”
- 环境指示器会校验当前所选模型是否真实可用

### 3. 字幕匹配主链路修复
- 自动匹配从“文件名+时长猜测”改为“视频字幕窗口 vs 音频字幕窗口”真实比对
- 匹配时会产出字幕对齐偏移 `offsetMs`
- 重新匹配会先清空旧匹配结果，避免旧数据残留
- 手动匹配会清除冲突占用，避免同一视频/音频被重复占用
- 匹配状态与项目状态同步，确认/取消确认/删除后会回写工程状态
- 字幕对比弹窗改为双栏，视频字幕和音频字幕同时展示

### 4. 时间线与导出修复
- `TimelineData` 统一承载
  - 原始音频时长
  - 实际裁切区间
  - 序列偏移
  - 裁切后音频路径
- 时间线构建不再用“首条字幕差值”覆盖匹配阶段得到的偏移
- 批量裁切后会把裁切结果回写到时间线状态
- XML/FCPXML 导出改为使用
  - 对齐后的序列偏移
  - 正确的音频源 `in/out`
  - 裁切音频路径（如果已生成）
- 时间线总时长统计改为按视频时长累计

### 5. 导入与拖拽修复
- 拖拽导入路径支持递归展开文件夹
- 导入页和数据层统一复用同一套递归展开逻辑
- 文件去重按 Windows 路径大小写不敏感处理
- 目录导入扫描改为递归

### 6. 单条样例验证
- 仅对 1 组样例执行全流程验证，避免全量素材浪费时间
- 验证样例:
  - 视频: `G:\data\260224-元数据脚本测试\1_Video\220822shipin\C0459.mp4`
  - 音频: `G:\data\260224-元数据脚本测试\2_Audio\220822yinpin\ZOOM0041_LR.mp3`
- 验证结果:
  - 双端 ASR 成功
  - 匹配成功
  - 时间线成功生成
  - XML 导出成功
- 导出文件:
  - `测试合板\单条样例流程修复验证.xml`
  - `测试合板\单条样例流程修复验证.fcpxml`

## 关键修改文件
- `pubspec.yaml`
- `analysis_options.yaml`
- `lib/services/database_service.dart`
- `lib/services/asr_batch_service.dart`
- `lib/services/sherpa_onnx_service.dart`
- `lib/providers/asr_process_provider.dart`
- `lib/services/subtitle_match_service.dart`
- `lib/providers/match_provider.dart`
- `lib/widgets/step_recognize.dart`
- `lib/widgets/subtitle_compare.dart`
- `lib/models/timeline_data.dart`
- `lib/services/audio_align_service.dart`
- `lib/providers/timeline_provider.dart`
- `lib/services/export_service.dart`
- `lib/providers/project_detail_provider.dart`
- `lib/services/media_scan_service.dart`
- `lib/widgets/step_import.dart`
- `test/widget_test.dart`
- `tool/run_sample_workflow.dart`

## 待办清单
- [ ] 若需要，再做多条样例或全量样例回归验证
- [ ] 处理剩余 lint/info 级静态提示（不影响当前功能链路）

## 下一步
- 等待你决定是否继续做多条样例或全量样例验证
- 若继续开发新功能，优先从本快照继续，不需要再回看历史快照
