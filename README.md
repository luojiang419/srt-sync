# ASR合板工具 / ASR Slate Sync Tool

一款面向影视后期、多机位拍摄与外录同步场景的桌面工具。  
它的目标不是“做一个通用 NLE”，而是把**素材导入、字幕反解、音频匹配、复核、时间线导出**这条链路做成一套稳定、可复核、可持续迭代的生产辅助系统。

A desktop tool for post-production teams working with multi-camera footage and dual-system sound.  
This project is not trying to become a general-purpose NLE. Its purpose is to make the pipeline of **importing sources, preparing subtitles, matching audio, reviewing results, and exporting timelines** deterministic, reviewable, and maintainable.

## 中文介绍

### 1. 这个项目要解决什么问题

在真实拍摄里，视频和录音常常来自不同设备：

- 相机视频自带一条参考音频
- 录音笔或现场录音系统保存更干净的正式声音
- 每天可能有大量零散片段，需要在后期中快速对齐

传统做法往往依赖人工听波形、看时码、拖时间线，既慢又容易出错。  
本项目的核心思路是：

1. 先把视频和音频的字幕都抽出来。
2. 用字幕上下文而不是纯波形去判断“谁和谁属于同一段内容”。
3. 把自动结果变成可以复核、可以手动修正、可以导出到剪辑软件继续工作的结构化数据。

它更像是一个“影视素材同步中间层”，而不是最终剪辑软件本身。

### 2. 软件的产品思路

这个项目从一开始就遵循下面几条原则：

#### 2.1 自动化必须可复核

我们不把匹配结果当黑盒直接吞掉，而是把它做成：

- 可查看的字幕对比
- 可跳转的锚点
- 可循环复核的结果队列
- 可手动修正的合板详情页

也就是说，自动匹配只是第一步，真正的目标是“让人工复核更快、更稳”。

#### 2.2 字幕优先，而不是波形优先

这个项目的主匹配链路基于字幕语义和上下文窗口，而不是单纯依赖波形相似度。  
原因是：

- 现场噪声、机内参考音频质量差时，波形法不稳定
- 长录音对短视频、一对多、多段错位等情况，语义上下文更容易做解释
- 字幕还能天然支持复核、搜索、关键词跳转和导出说明

#### 2.3 工程驱动，而不是单文件工具

这里的最小工作单元不是“一段文件”，而是“一个工程”：

- 一个工程里管理视频、音频、字幕、匹配结果、时间线和导出结果
- 每一步都能持久化
- 中断后可以恢复
- 允许多轮修正、重跑、复核和发布

这让它更适合真实项目，而不是一次性脚本。

#### 2.4 导出是为了继续在专业剪辑软件里工作

本项目不会替代 DaVinci Resolve、Premiere、Final Cut Pro。  
它的导出目标是：

- 让剪辑软件里能直接看到已匹配好的结构
- 保留足够多的参考信息，方便继续人工校准
- 把“粗重的同步准备工作”前移到这个工具里完成

当前已经支持：

- xmeml `.xml`
- FCPXML `.fcpxml`
- CSV 报告
- 分素材 SRT

最近导出链路也特别强调：

- 保留视频内嵌音频轨
- 保留外部录音轨
- 让后续在剪辑软件里随时可核对、可静音、可手调

### 3. 当前核心工作流

当前产品工作流大致是：

1. 新建工程
2. 导入视频、音频、视频字幕、音频字幕
3. 在素材导入阶段反解字幕并建立索引
4. 对缺失字幕的素材执行旧 ASR 补录
5. 进行一键合板
6. 在“合板详情与复核”里逐条核对
7. 生成时间线并导出 XML / FCPXML / CSV / SRT

这套流程的重点不只是“匹配成功”，而是：

- 匹配结果可解释
- 错误结果能快速复核
- 导出结果能真正进入后续剪辑流程

### 4. 关键模块

#### 4.1 素材导入与工程数据

- 负责视频、音频、字幕文件导入
- 管理工程级数据目录
- 维护项目级缩略图缓存
- 在导入内容变化后，自动使旧索引和旧匹配结果失效

#### 4.2 字幕准备与反解

- 支持总字幕反解
- 支持按素材切分本地字幕片段
- 为后续匹配建立可搜索的窗口索引

#### 4.3 字幕匹配与锚点机制

- 基于字幕文本归一化、窗口比对、锚点命中来建立视频和音频的对应关系
- 支持自动结果、异常结果、手动指定结果
- 支持在复核时围绕锚点快速跳转

#### 4.4 时间线与导出

- 把匹配结果转换成可落地的时间线数据
- 处理外录偏移、裁切区间、导出路径、参考音轨
- 输出供后续专业软件使用的 XML/FCPXML

### 5. 当前技术架构

项目目前采用 Flutter 桌面应用架构，分为几个比较清晰的层：

- `screens/`：页面级 UI
- `widgets/`：复用组件与工作台组件
- `providers/`：状态管理与流程编排
- `services/`：数据库、FFmpeg、ASR、匹配、导出等核心逻辑
- `models/`：工程、媒体、字幕、匹配、时间线等结构化数据
- `core/`：主题、路由、常量、扩展

对开发者来说，最重要的几个入口是：

- [lib/screens/project_screen.dart](lib/screens/project_screen.dart)
- [lib/providers/project_detail_provider.dart](lib/providers/project_detail_provider.dart)
- [lib/services/subtitle_match_service.dart](lib/services/subtitle_match_service.dart)
- [lib/services/export_service.dart](lib/services/export_service.dart)
- [lib/widgets/sync_review_dialog.dart](lib/widgets/sync_review_dialog.dart)

### 6. 数据与持久化思路

项目现在采用“可执行程序同级 `data/` 目录”的持久化方式：

- `data/config`：设置
- `data/database`：SQLite 数据库
- `data/projects`：工程级缓存与缩略图
- `data/temp`：临时文件

这样做的原因是：

- 发布版可独立运行
- 数据路径可控
- 备份和迁移都更直观
- 更适合桌面工具分发

同时，项目已经补了“清洁发布”流程，避免把开发者本机旧工程数据误带入发布包。

### 7. 当前平台状态

当前项目是 **Windows 优先** 的桌面工具：

- 已落地 `windows/` 平台工程
- 默认路径、打包流程、外部依赖路径目前都更偏 Windows
- 业务层大量逻辑本身是跨平台可迁移的，但 `macOS` 还没有完整预设

这意味着：

- 如果你是后来接手的开发者，优先把它理解成“Windows 生产工具”
- 如果要做 macOS 版，需要额外补平台工程、路径策略和依赖适配

### 8. 你应该先读什么

如果你是新开发者，建议按下面顺序阅读：

1. 本 README：理解产品定位和整体思路
2. [ASR合板.md](ASR合板.md)：更完整的产品说明和交互背景
3. [文档/逻辑设计文档.md](文档/逻辑设计文档.md)：架构、数据流、目录结构
4. [进度快照](进度快照/)：了解项目最近的真实迭代轨迹

### 9. 适合后续继续演进的方向

这个项目后续非常适合继续沿这些方向演进：

- 更稳的字幕匹配与异常识别
- 更强的复核工作台
- 更清晰的导出预设
- 更好的跨平台支持
- 更干净的一键发布流程

简而言之，这不是一个“从零开始的 Flutter demo”，而是一套已经围绕真实后期生产流程持续演进的桌面工具。

---

## English Overview

### 1. What this project is for

This project is designed for real-world post-production workflows where:

- camera footage contains scratch / embedded audio
- field recorders capture cleaner production sound
- editors need to sync many short clips against longer audio recordings

Instead of manually aligning everything by waveform and timeline dragging, this tool uses **speech recognition + subtitle context matching** to automate the first 80% of the process and then hands the result to a review-friendly UI and export pipeline.

### 2. Product philosophy

This repository is built around a few key ideas:

#### 2.1 Automation must remain reviewable

We do not treat sync results as a black box.  
Every important step should remain visible and correctable:

- subtitle comparison
- anchor-based navigation
- result review queues
- manual override paths

#### 2.2 Subtitle-first matching

The main matching pipeline is driven by subtitle normalization, context windows, and anchors rather than raw waveform similarity alone.

Why this matters:

- production scratch audio is often noisy
- long external recordings vs short camera clips are easier to reason about with language context
- subtitle-based workflows are naturally easier to review, search, and export

#### 2.3 Project-oriented workflow

The core unit is a **project**, not a single file.

Projects persist:

- imported media
- subtitles
- prepared indexes
- match results
- review state
- timeline data
- export artifacts

This makes the tool much closer to a practical production assistant than a one-off script.

#### 2.4 Export exists to continue work in pro NLEs

This app is not trying to replace DaVinci Resolve, Premiere Pro, or Final Cut Pro.  
Its job is to prepare clean, reviewable, and structurally useful data so that editorial work can continue in professional software.

Current export targets include:

- xmeml `.xml`
- FCPXML `.fcpxml`
- CSV reports
- per-clip SRT

Recent export work also focuses on preserving:

- embedded camera audio
- external recorder audio

so editors can keep both tracks for verification and manual correction.

### 3. Current workflow

The current product flow is roughly:

1. Create a project
2. Import video, audio, video subtitles, and audio subtitles
3. Reverse-split subtitles and build indexes during the import stage
4. Run fallback ASR on missing material when needed
5. Perform automatic sync matching
6. Review and correct results in the review workspace
7. Build a timeline and export XML / FCPXML / CSV / SRT

### 4. Technical structure

The codebase is organized into clear layers:

- `screens/` for page-level UI
- `widgets/` for reusable workbench components
- `providers/` for state orchestration
- `services/` for database, FFmpeg, ASR, matching, and export logic
- `models/` for structured domain data
- `core/` for theme, routing, constants, and utilities

Important entry points for new developers:

- `lib/screens/project_screen.dart`
- `lib/providers/project_detail_provider.dart`
- `lib/services/subtitle_match_service.dart`
- `lib/services/export_service.dart`
- `lib/widgets/sync_review_dialog.dart`

### 5. Persistence and release philosophy

The app stores runtime data beside the executable in a `data/` tree:

- `data/config`
- `data/database`
- `data/projects`
- `data/temp`

This is intentional:

- release builds stay self-contained
- project data is easy to inspect and back up
- desktop deployment becomes more predictable

The repository also includes a clean-release step so that developer-local data does not leak into shipped builds.

### 6. Current platform status

This is currently a **Windows-first desktop project**.

- a Windows platform project is present
- default paths and release flows are still Windows-oriented
- a lot of business logic is portable, but macOS is not fully prepared yet

So if you are joining later, treat the current state as:

- production-ready on Windows
- potentially portable, but not yet fully productized for macOS

### 7. Suggested onboarding path

If you are a future developer, read these in order:

1. this README
2. `ASR合板.md`
3. `文档/逻辑设计文档.md`
4. `进度快照/`

That sequence gives you:

- product intent
- real workflow assumptions
- architecture
- actual iteration history

### 8. In one sentence

This repository is a production-oriented sync preparation tool for film/video workflows:  
it uses ASR and subtitle context to reduce manual sync work, while preserving human review, manual correction, and downstream NLE compatibility.
