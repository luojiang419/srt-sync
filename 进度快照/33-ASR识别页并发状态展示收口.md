# 进度快照 33 - ASR 识别页并发状态展示收口

## 版本信息
- 版本号: v1.0.7
- 备份: backup/v0.15.0
- 编译: 尚未开始，本阶段完成后统一编译新版本

## 已完成内容

### 1. 扩展并发运行状态模型
- `AsrProcessState` 已新增:
  - `usedConcurrency`
  - `queuedCount`
  - `runningCount`
- 当前批次启动时，会先计算实际并发数并写入状态。
- 初始待识别文件在批处理中会先标记为 `queued`，不再全部显示为普通待识别。

### 2. 识别结束后的状态收口
- 批次结束后，会将仍处于:
  - `queued`
  - `extracting`
  - `recognizing`
  - `saving`
  的残留状态统一收口为 `pending`
- 这样取消后可继续续跑，不会留下假“处理中”状态。

### 3. 识别页 UI 完成并发态展示
- 总进度卡片已新增:
  - 实际并发数
  - 运行中数量
  - 排队中数量
  - 已完成数量
  - 失败数量
- 结果摘要会显示本次实际并发数。
- 单文件状态卡片已支持显示 `排队中`。

### 4. 基础检查
- 已完成代码格式化。
- `flutter analyze` 针对并发相关服务/Provider/UI 文件结果为 `No issues found`

## 当前修改模块
- `lib/services/asr_batch_service.dart`
- `lib/providers/asr_process_provider.dart`
- `lib/widgets/asr_progress_panel.dart`
- `lib/widgets/step_recognize.dart`

## 待办清单
- [ ] 做全项目静态检查
- [ ] 跑验证脚本或样例流程，确认并发改动不影响匹配与时间线
- [ ] 生成最终快照
- [ ] 编译新版本到 `dist`

## 下一步
- 进入第四步:
  - 全项目分析检查
  - 运行样例流程验证识别/匹配/时间线/XML
  - 若通过则编译 `dist` 新版本
