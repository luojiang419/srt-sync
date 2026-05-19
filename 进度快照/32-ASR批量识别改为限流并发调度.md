# 进度快照 32 - ASR 批量识别改为限流并发调度

## 版本信息
- 版本号: v1.0.7
- 备份: backup/v0.15.0
- 编译: 尚未开始，本阶段完成后统一编译新版本

## 已完成内容

### 1. 批量识别由串行改为限流并发
- `AsrBatchService.batchRecognize()` 已从单个 `for-await` 串行处理改为 worker 池模式。
- 支持按并发数同时处理多个媒体文件。
- 不再一次性全量启动所有文件，而是按限流并发逐个从队列取任务。

### 2. 自动/手动并发策略接入识别主链路
- `AsrProcessProvider` 已将设置页中的:
  - `asrConcurrencyMode`
  - `asrMaxConcurrency`
  传入 `AsrBatchService`
- 自动模式逻辑:
  - GPU/CUDA 可用时默认 `1`
  - CPU 模式默认 `2`
- 手动模式逻辑:
  - 使用用户设置值
  - 最终仍限制在 `1-4` 且不超过待识别文件数

### 3. 并发安全处理
- WAV 临时文件已改为按 `mediaFileId` 隔离目录，避免同名文件并发冲突。
- 字幕写库已增加串行化保护，降低并发写入互相抢占的风险。
- 批次结果已新增 `usedConcurrency` 字段，用于后续 UI 展示和验证。

### 4. 基础检查
- 已完成代码格式化。
- `flutter analyze` 针对:
  - `lib/services/asr_batch_service.dart`
  - `lib/providers/asr_process_provider.dart`
  结果为 `No issues found`

## 当前修改模块
- `lib/services/asr_batch_service.dart`
- `lib/providers/asr_process_provider.dart`

## 待办清单
- [ ] 扩展识别页并发运行状态展示
- [ ] 显示运行中/待识别/失败/完成统计
- [ ] 回归验证取消、续跑、单文件重试
- [ ] 跑通完整合板流程
- [ ] 生成最终快照并编译新版本

## 下一步
- 进入第三步:
  - 扩展 `AsrProcessState`
  - 更新 `step_recognize.dart`
  - 让识别页明确显示并发运行数量与实际并发数
