# 进度快照 31 - 新增 ASR 并发识别设置入口

## 版本信息
- 版本号: v1.0.7
- 备份: backup/v0.15.0
- 编译: 尚未开始，本阶段完成后统一编译新版本

## 已完成内容

### 1. 新增并发识别设置字段
- `AppSettings` 已新增:
  - `asrConcurrencyMode`
  - `asrMaxConcurrency`
- 设置已接入本地持久化读写。
- 对历史配置做了兼容:
  - 未配置时默认回落到自动模式
  - 并发数会限制在 `1-4`

### 2. 新增并发识别设置 UI
- 设置页新增“并发识别”卡片。
- 支持两种模式:
  - 自动
  - 手动
- 手动模式下可选择并发数 `1-4`。
- 已补充中英文文案键。

### 3. 基础检查
- 已完成代码格式化。
- 静态检查通过本次新增逻辑。
- 当前剩余的 `use_build_context_synchronously` 为设置页原有 info 级提示，未由本次功能新增。

## 当前修改模块
- `lib/core/constants.dart`
- `lib/providers/settings_provider.dart`
- `lib/l10n/app_localizations.dart`
- `lib/screens/settings_screen.dart`

## 待办清单
- [ ] 将批量识别从串行改为限流并发调度
- [ ] 处理并发下 WAV 临时文件目录隔离
- [ ] 扩展 ASR 运行态统计字段
- [ ] 更新识别页并发状态展示
- [ ] 回归验证识别/匹配/时间线/XML 链路
- [ ] 编译新版本到 `dist`

## 下一步
- 进入第二步:
  - 重构 `AsrBatchService.batchRecognize()`
  - 接入自动/手动并发策略
  - 处理取消、失败统计和临时文件唯一性
