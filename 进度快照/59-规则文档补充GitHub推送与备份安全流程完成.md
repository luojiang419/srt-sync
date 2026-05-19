# 进度快照 59 - 规则文档补充GitHub推送与备份安全流程完成

## 版本信息
- 当前应用版本: `v1.1.6`
- `pubspec.yaml`: `1.1.6+24`
- 阶段备份: `backup/v0.33.0`
- Git 分支: `main`
- GitHub 远端: `origin -> https://github.com/luojiang419/srt-sync.git`

## 已完成内容

### 1. 规则文档已补充 GitHub 推送方法与仓库地址
- 已在 `大型项目规划.md` 明确记录远端仓库地址
- 已写明当前环境优先使用 Windows 侧 Git 凭据链路
- 已补充手动推送命令：`cmd.exe /c git push origin main`

### 2. 已补充“修改前推送”与“备份前推送”规则
- 修改前推送继续统一使用：
  - `bash tool/pre_change_push.sh "chore: pre-change checkpoint - 本次修改说明"`
- 新增备份前推送规则：
  - `bash tool/pre_backup_push.sh "chore: pre-backup checkpoint - 阶段说明"`
- 已明确：只有 GitHub 推送成功后，才允许继续修改或继续执行阶段备份

### 3. 已新增备份前推送脚本
- 新增 `tool/pre_backup_push.sh`
- 用于在创建新阶段 `backup` 前先推送 GitHub 检查点
- 复用 `tool/pre_change_push.sh` 的 Win 侧 Git 凭据链路

### 4. 已明确 GitHub 与本地 backup 的职责边界
- `backup/` 目录继续作为本地离线兜底备份
- 不要求将 `backup/` 目录本身提交到 GitHub
- 但每次执行“备份动作”前必须先推送 GitHub 检查点
- 备份完成后如果又新增规则、脚本、快照等流程文件，也要再次推送 GitHub

## 当前修改到哪个模块
- 项目规则文档中的 GitHub 推送与回滚规则
- 备份前推送脚本
- GitHub 与本地 backup 的安全流程约定

## 待办清单
- [ ] 后续每次进入新修改任务前，先执行 `bash tool/pre_change_push.sh "chore: pre-change checkpoint - 本次修改说明"`
- [ ] 后续每次创建新阶段备份前，先执行 `bash tool/pre_backup_push.sh "chore: pre-backup checkpoint - 阶段说明"`
- [ ] 如后续需要，可补 `.gitattributes` 统一换行符策略，减少 CRLF/LF 提示

## 下一步
- 后续开发统一按文档中的 GitHub 安全流程执行：先推送，再修改；先推送，再备份；完成后再推送。
