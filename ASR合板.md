# ASR合板 - SenseVoice ASR 影视素材自动合板工具

## 一、项目概述

### 1.1 产品定位

一款面向影视后期制作的专业 ASR 自动合板工具。核心场景：影视拍摄时多机位视频和录音笔音频分别记录，通过 SenseVoice ASR 语音识别提取双方字幕，利用字幕上下文匹配算法自动判断哪些视频和音频属于同一段录制，最后自动裁切音频适配视频长度，实现一键合板。

### 1.2 技术栈

| 技术 | 版本/说明 | 用途 |
|------|-----------|------|
| Flutter | 3.38.8 (G:\data\flutter) | 跨平台桌面应用框架 |
| Dart | 3.10.7 | 开发语言 |
| Riverpod | ^2.6.1 | 状态管理 + 依赖注入 |
| GoRouter | ^14.8.1 | 声明式路由 |
| SQLite | sqflite_common_ffi ^2.4.0 | 本地数据持久化 |
| sherpa-onnx | v1.12.38 | ASR 推理运行时 (命令行调用) |
| SenseVoice Small | int8 量化 ONNX 模型 | 多语言语音识别 (中/英/日/韩/粤) |
| FFmpeg | 8.0.1 (G:\data\app\DIT\ffmpeg) | 音视频处理 (WAV提取/时长获取/音频裁切) |

### 1.3 核心工作流

```
新建工程(卡片) → 选择视频/音频目录 → ASR识别所有文件字幕
    → 字幕上下文匹配(滑动窗口) → 匹配结果确认 → 创建时间线(音频裁切)
```

---

## 二、UI/UX 设计

### 2.1 视觉风格

采用**深色专业工具风格**（类似 DaVinci Resolve / Premiere Pro 色调）：

| 角色 | 色值 | 用途 |
|------|------|------|
| 主背景 | #1A1A2E | 页面底色 |
| 卡片底色 | #16213E | 工程卡片、面板 |
| 强调色 | #0F3460 | 按钮、选中态、进度条 |
| 高亮色 | #E94560 | 警告、错误、关键操作 |
| 成功色 | #4CAF50 | 完成状态、高置信度 |
| 主文字 | #E0E0E0 | 正文、标题 |
| 次文字 | #9E9E9E | 说明、辅助信息 |

字体：Noto Sans SC（通过 google_fonts 引入）

### 2.2 页面一：工程列表页 (HomeScreen)

```
+------------------------------------------------------------------+
|  [Logo] ASR合板工具                              [设置齿轮]       |
+------------------------------------------------------------------+
|                                                                    |
|  [+ 新建工程]                                                      |
|                                                                    |
|  +------------------+  +------------------+  +------------------+  |
|  |  工程卡片 1       |  |  工程卡片 2       |  |  工程卡片 3       |  |
|  |                  |  |                  |  |                  |  |
|  | 采访Day1         |  | 采访Day2         |  | 场景A            |  |
|  | 3视频 | 5音频    |  | 2视频 | 2音频    |  | 10视频 | 8音频   |  |
|  | ● 已完成         |  | ○ 待识别         |  | ● 已匹配         |  |
|  | 2026-04-15       |  | 2026-04-16       |  | 2026-04-16       |  |
|  +------------------+  +------------------+  +------------------+  |
|                                                                    |
+------------------------------------------------------------------+
```

**交互说明**：
- 点击卡片 → 进入该工程的操作页面
- 右键卡片 → 弹出菜单（重命名、删除）
- 点击 [+ 新建工程] → 弹出对话框输入工程名称
- 卡片状态用不同颜色标识：
  - 灰色：空工程
  - 蓝色(旋转动画)：识别中
  - 绿色：已完成
  - 红色：错误

### 2.3 页面二：工程操作页 (ProjectScreen) - 四步骤向导

```
+------------------------------------------------------------------+
|  [<- 返回]  工程名称: 采访Day1              Step 2/4: ASR识别     |
+------------------------------------------------------------------+
|                                                                    |
|  [1.导入素材]  --(2.ASR识别)--  [3.匹配确认]  -- [4.时间线]       |
|     灰色         蓝色高亮           灰色           灰色            |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |                                                                | |
|  |  当前步骤的内容区域（根据步骤动态切换）                         | |
|  |                                                                | |
|  +--------------------------------------------------------------+ |
|                                                                    |
|  +--------------------------------------------------------------+ |
|  |  底部操作栏: [上一步]            [开始识别] / [下一步 ->]      | |
|  +--------------------------------------------------------------+ |
+------------------------------------------------------------------+
```

#### Step 1: 素材导入

```
+--------------------------------------------------------------+
|                                                                |
|  +----------------------------+  +----------------------------+ |
|  |  视频目录                    |  |  音频目录                  | |
|  |  [选择目录] C:\Videos\Day1  |  |  [选择目录] C:\Audio\Day1  | |
|  |                              |  |                            | |
|  |  已发现 5 个视频文件:        |  |  已发现 8 个音频文件:      | |
|  |  - C0457.mp4  (17:23)       |  |  - T01.wav  (18:01)       | |
|  |  - C0458.mp4  (12:45)       |  |  - T02.wav  (13:12)       | |
|  |  - C0459.mp4  (08:32)       |  |  - T03.wav  (08:55)       | |
|  |  - C0460.mp4  (22:10)       |  |  - T04.wav  (22:08)       | |
|  |  - C0461.mp4  (05:18)       |  |  - ...                    | |
|  +----------------------------+  +----------------------------+ |
|                                                                |
|  ASR设置:  语言 [中文 ▼]  模型 [SenseVoice Small ▼]           |
+--------------------------------------------------------------+
```

#### Step 2: ASR 识别

```
+--------------------------------------------------------------+
|                                                                |
|  [开始识别]  [取消]            整体进度: ████████░░ 65%        |
|                                                                |
|  +----------------------------------------------------------+ |
|  |  视频文件:                                                 | |
|  |  C0457.mp4  ██████████████ 完成  (135条字幕)              | |
|  |  C0458.mp4  ████████░░░░░░ 识别中  (预计剩余 1m20s)       | |
|  |  C0459.mp4  ░░░░░░░░░░░░░░ 等待                          | |
|  |                                                            | |
|  |  音频文件:                                                 | |
|  |  T01.wav    ██████████████ 完成  (142条字幕)              | |
|  |  T02.wav    ░░░░░░░░░░░░░░ 等待                          | |
|  +----------------------------------------------------------+ |
|                                                                |
+--------------------------------------------------------------+
```

#### Step 3: 匹配确认

```
+--------------------------------------------------------------+
|                                                                |
|  匹配结果: 5/5 个视频已匹配                                   |
|                                                                |
|  +----------------------------------------------------------+ |
|  |  ✓ C0457.mp4  ↔  T01.wav                                 | |
|  |    置信度: 高 (92%)  偏移: +2300ms    [查看字幕对比]       | |
|  +----------------------------------------------------------+ |
|  |  ✓ C0458.mp4  ↔  T02.wav                                 | |
|  |    置信度: 中 (78%)  偏移: -1200ms    [查看字幕对比]       | |
|  +----------------------------------------------------------+ |
|  |  ? C0460.mp4  ↔  T04.wav                                  | |
|  |    置信度: 低 (62%)         [手动匹配] [取消匹配]          | |
|  +----------------------------------------------------------+ |
|  |                                                            | |
|  |  未匹配音频:                                               | |
|  |  T07.wav (无匹配视频)  [手动指定视频]                      | |
|  +----------------------------------------------------------+ |
|                                                                |
+--------------------------------------------------------------+
```

#### Step 4: 时间线预览与创建

```
+--------------------------------------------------------------+
|                                                                |
|  [创建时间线]  [导出 XML]                                     |
|                                                                |
|  +----------------------------------------------------------+ |
|  |  V | C0457.mp4 |  C0458.mp4  | C0459.mp4 |  C0460.mp4   | |
|  |  A |  [T01.wav 裁切]  | [T02.wav] | [T03.wav] | [T04]    | |
|  |  S | 字幕... | 字幕... | 字幕... | 字幕... | 字幕...     | |
|  +----------------------------------------------------------+ |
|                                                                |
|  时间线信息:                                                   |
|  总时长: 01:05:08 | 5 个视频片段 | 5 个音频片段               |
|                                                                |
+--------------------------------------------------------------+
```

---

## 三、数据模型设计

### 3.1 AsrProject（工程模型）

```dart
enum ProjectStatus {
  empty,        // 空工程
  ready,        // 已添加素材
  recognizing,  // ASR 识别中
  recognized,   // 识别完成
  matched,      // 匹配完成
  completed,    // 时间线已创建
  error,        // 错误
}

class AsrProject {
  final String id;                    // UUID
  String name;                        // 工程名称
  String? videoDirectory;             // 视频目录路径
  String? audioDirectory;             // 音频目录路径
  ProjectStatus status;               // 工程状态
  String asrLanguage;                 // 'zh' | 'en' | 'auto'
  String asrModel;                    // 'sense-voice-small'
  DateTime createdAt;                 // 创建时间
  DateTime updatedAt;                 // 更新时间
}
```

### 3.2 MediaFile（媒体文件模型）

```dart
enum MediaType { video, audio }
enum SubtitleStatus { pending, extracting, recognizing, done, error, skipped }

class MediaFile {
  final String id;                    // UUID
  final String projectId;            // 所属工程ID
  final String filePath;             // 绝对路径
  final MediaType type;              // video / audio
  final String fileName;             // 文件名
  int durationMs;                     // 时长(毫秒), ffprobe获取
  int fileSizeBytes;                  // 文件大小(字节)
  SubtitleStatus subtitleStatus;     // 字幕识别状态
}
```

### 3.3 SubtitleClip（字幕片段模型）

```dart
class SubtitleClip {
  final int? dbId;                    // 数据库自增ID
  final String mediaFileId;          // 所属媒体文件ID
  final int startMs;                 // 起始时间(毫秒)
  final int endMs;                   // 结束时间(毫秒)
  final String text;                 // 字幕文本
  final int sortOrder;              // 排序序号

  String get normalizedText;         // 归一化文本(去标点空格)
}
```

### 3.4 MatchPair（匹配结果模型）

```dart
class MatchPair {
  final String id;                   // UUID
  final String projectId;           // 所属工程ID
  final String videoFileId;         // 视频文件ID
  final String audioFileId;         // 音频文件ID
  final double confidence;          // 置信度 0.0~1.0
  final int offsetMs;               // 偏移量(毫秒): 视频时间 - 音频时间
  final int matchedWindowCount;     // 匹配窗口数
  final int totalWindowCount;       // 总窗口数
  final bool isConsistent;          // 偏移量是否一致
  bool isUserConfirmed;             // 用户已确认
  bool isManualMatch;               // 手动匹配
}
```

### 3.5 TimelineData（时间线数据模型）

```dart
enum TrackType { video, audio, subtitle }

class TimelineData {
  final String projectId;
  final List<TimelineTrack> tracks;
  final int totalDurationMs;
}

class TimelineTrack {
  final TrackType type;
  final String label;
  final List<TimelineClip> clips;
}

class TimelineClip {
  final String id;
  final String filePath;
  final String fileName;
  final int timelineStartMs;        // 时间线上的起始位置
  final int durationMs;             // 持续时长
  final int sourceStartMs;          // 源文件中的起始偏移(用于裁切)
  final String? text;               // 字幕文本(仅字幕轨)
}
```

---

## 四、数据库设计 (SQLite)

### 4.1 表结构

```sql
-- 工程表
CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  video_directory TEXT,
  audio_directory TEXT,
  status TEXT NOT NULL DEFAULT 'empty',
  asr_language TEXT DEFAULT 'zh',
  asr_model TEXT DEFAULT 'sense-voice-small',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- 媒体文件表
CREATE TABLE media_files (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_type TEXT NOT NULL,           -- 'video' | 'audio'
  file_name TEXT NOT NULL,
  duration_ms INTEGER DEFAULT 0,
  file_size INTEGER DEFAULT 0,
  subtitle_status TEXT DEFAULT 'pending',
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 字幕表
CREATE TABLE subtitle_clips (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  media_file_id TEXT NOT NULL,
  start_ms INTEGER NOT NULL,
  end_ms INTEGER NOT NULL,
  text TEXT NOT NULL,
  sort_order INTEGER NOT NULL,
  FOREIGN KEY (media_file_id) REFERENCES media_files(id) ON DELETE CASCADE
);

-- 匹配结果表
CREATE TABLE match_pairs (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  video_file_id TEXT NOT NULL,
  audio_file_id TEXT NOT NULL,
  confidence REAL NOT NULL,
  offset_ms INTEGER NOT NULL,
  matched_window_count INTEGER DEFAULT 0,
  total_window_count INTEGER DEFAULT 0,
  is_consistent INTEGER DEFAULT 1,
  is_user_confirmed INTEGER DEFAULT 0,
  is_manual_match INTEGER DEFAULT 0,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);
```

### 4.2 状态流转

```
empty → ready → recognizing → recognized → matched → completed
  ↑                                                    ↓
  +-------------------- error ←------------------------+
```

- `empty`: 新建空工程
- `ready`: 已添加视频/音频目录
- `recognizing`: ASR 识别进行中（可取消回退到 ready）
- `recognized`: 所有文件识别完成
- `matched`: 匹配算法完成
- `completed`: 时间线已创建
- `error`: 任何阶段出错

---

## 五、核心算法设计

### 5.1 ASR 识别流程

```
输入: 媒体文件 (视频或音频)
输出: List<SubtitleClip> 字幕列表

Step 1: FFmpeg 提取 16kHz WAV
  ffmpeg.exe -i <input> -ar 16000 -ac 1 -c:a pcm_s16le -y <output.wav>

Step 2: sherpa-onnx VAD + ASR 识别
  sherpa-onnx-vad-with-offline-asr.exe \
    --silero-vad-model=<path>/silero_vad.onnx \
    --sense-voice-model=<path>/model.int8.onnx \
    --tokens=<path>/tokens.txt \
    --sense-voice-language=zh \
    --sense-voice-use-itn=true \
    --num-threads=8 \
    <input.wav>

Step 3: 解析输出
  输出格式: "0.518 -- 1.452: 快点。"
  → SubtitleClip(startMs=518, endMs=1452, text="快点。")

Step 4: 幻觉过滤
  检测连续重复/交替重复模式，过滤 ASR 幻觉输出

Step 5: 缓存
  缓存键 = MD5(文件路径 + 文件大小 + 修改时间)
  缓存格式: .srt 文件存储在工程目录 .asr_cache/ 下
```

### 5.2 字幕上下文匹配算法

```
算法: SubtitleMatchService.match()
参数: windowSize=3, similarityThreshold=0.85, minMatchCount=3, offsetConsistencyMs=3000

输入: videoSubtitles: Map<fileId, List<SubtitleClip>>
      audioSubtitles: Map<fileId, List<SubtitleClip>>
输出: List<MatchPair>

Step 1: 构建指纹集合
  对每个文件的字幕列表，用滑动窗口(window=3)取连续3条字幕:
    fingerprint[i] = normalize(sub[i].text + sub[i+1].text + sub[i+2].text)
  每个指纹关联: (startIndex, firstTimestampMs)

Step 2: 交叉匹配
  for each (videoFile, audioFile) 配对:
    for each videoFingerprint:
      a) 精确匹配: audioFingerprints.contains(videoFp) ?
         → 记录 offset = videoStartMs - audioStartMs
      b) 模糊匹配: levenshteinSimilarity(videoFp, audioFp) >= 0.85 ?
         → 记录 offset

Step 3: 计算置信度
  confidence = matchedWindowCount / totalVideoWindows
  medianOffset = median(allMatchedOffsets)
  isConsistent = stddev(offsets) < 3000ms
  if !isConsistent: confidence *= 0.5  (不一致惩罚)

Step 4: 贪心分配
  所有候选匹配按置信度降序排列
  每个视频取最高置信度的音频匹配
  同一个音频可匹配多个视频（多机位场景）

Step 5: 返回 MatchPair 列表
```

**文本归一化规则**：去除中英文标点、空格、换行，只保留文字内容。

**Levenshtein 相似度公式**：
```
similarity(a, b) = 1 - levenshtein_distance(a, b) / max(a.length, b.length)
```
使用滚动数组优化，空间复杂度 O(min(m,n))。

### 5.3 音频裁切对齐算法

```
算法: AudioAlignService.buildTimeline()
输入: List<MediaFile> videoFiles, audioFiles + List<MatchPair>
输出: TimelineData

Step 1: 建立视频轨道（顺序平铺）
  currentTimeMs = 0
  for each video (按文件名排序):
    clip = TimelineClip(
      timelineStartMs = currentTimeMs,
      durationMs = video.durationMs,
      sourceStartMs = 0,
    )
    currentTimeMs += video.durationMs

Step 2: 为每个视频匹配的音频创建音频轨道
  for each (video, matchPair):
    offsetMs = matchPair.offsetMs

    if offsetMs >= 0:
      // 音频比视频晚开始，从源音频 offset 位置裁切
      sourceStartMs = offsetMs
      availableMs = audio.durationMs - offsetMs
    else:
      // 音频比视频早开始
      sourceStartMs = 0
      availableMs = min(audio.durationMs, video.durationMs + offsetMs)

    // 裁切后不超过视频时长
    clipDurationMs = min(availableMs, video.durationMs)

Step 3: 创建字幕轨道
  for each video's subtitles:
    subtitleClip.timelineStartMs = video.timelineStartMs + subtitle.startMs

Step 4: FFmpeg 执行裁切
  for each audioClip:
    ffmpeg -i <source> -ss <startSec> -t <durationSec> -c:a pcm_s16le <output.wav>
```

---

## 六、服务层设计

### 6.1 服务类清单

| 服务类 | 职责 | 预估行数 |
|--------|------|----------|
| `DatabaseService` | SQLite 初始化、建表、迁移、通用 CRUD | ~300 |
| `FfmpegService` | FFmpeg/ffprobe 路径管理、WAV 提取、时长获取、音频裁切 | ~250 |
| `SherpaOnnxService` | sherpa-onnx 路径管理、模型检测、命令行调用、输出解析 | ~350 |
| `MediaScanService` | 目录扫描（按扩展名过滤）、ffprobe 元数据获取 | ~150 |
| `AsrBatchService` | 批量 ASR 识别编排（队列、并发控制、进度回调、缓存） | ~250 |
| `SubtitleMatchService` | 滑动窗口指纹构建、Levenshtein 匹配、贪心分配 | ~280 |
| `AudioAlignService` | 时间线生成、音频裁切对齐、FFmpeg 裁切执行 | ~200 |
| `ExportService` | 导出 Premiere XML / EDL | ~200 |

### 6.2 模块调用关系

```
UI Layer (Screens + Widgets)
    ↓
Provider Layer (Riverpod Notifiers)
    ↓
    +--→ DatabaseService        (持久化)
    |
    +--→ AsrBatchService        (ASR编排)
    |       +--→ FfmpegService      (音频提取)
    |       +--→ SherpaOnnxService  (语音识别)
    |
    +--→ SubtitleMatchService   (匹配算法，纯计算)
    |
    +--→ AudioAlignService      (时间线生成)
    |       +--→ FfmpegService      (音频裁切)
    |
    +--→ MediaScanService       (文件扫描)
            +--→ FfmpegService      (元数据获取)
```

---

## 七、项目文件清单

### 7.1 目录结构

```
g:\data\app\ASR-tools\
├── pubspec.yaml
├── analysis_options.yaml
├── windows/                         # Flutter Windows 壳工程
├── lib/
│   ├── main.dart                    # 入口 (30行)
│   ├── app.dart                     # MaterialApp + 主题 + 路由 (60行)
│   │
│   ├── core/
│   │   ├── constants.dart           # 全局常量 (40行)
│   │   ├── app_theme.dart           # 暗色主题 (80行)
│   │   ├── app_router.dart          # GoRouter 路由 (50行)
│   │   └── extensions.dart          # 扩展方法 (40行)
│   │
│   ├── models/
│   │   ├── asr_project.dart         # 工程模型 (100行)
│   │   ├── media_file.dart          # 媒体文件模型 (80行)
│   │   ├── subtitle_clip.dart       # 字幕片段模型 (60行)
│   │   ├── match_pair.dart          # 匹配结果模型 (70行)
│   │   └── timeline_data.dart       # 时间线数据模型 (80行)
│   │
│   ├── providers/
│   │   ├── project_list_provider.dart   # 工程列表状态 (120行)
│   │   ├── project_detail_provider.dart # 单工程详情状态 (200行)
│   │   ├── asr_process_provider.dart    # ASR 识别过程 (150行)
│   │   ├── match_provider.dart          # 匹配过程状态 (100行)
│   │   └── settings_provider.dart       # 全局设置 (80行)
│   │
│   ├── services/
│   │   ├── database_service.dart        # SQLite (300行)
│   │   ├── ffmpeg_service.dart          # FFmpeg 封装 (250行)
│   │   ├── sherpa_onnx_service.dart     # sherpa-onnx 封装 (350行)
│   │   ├── media_scan_service.dart      # 文件扫描 (150行)
│   │   ├── asr_batch_service.dart       # ASR 批量编排 (250行)
│   │   ├── subtitle_match_service.dart  # 字幕匹配算法 (280行)
│   │   ├── audio_align_service.dart     # 音频裁切对齐 (200行)
│   │   └── export_service.dart          # XML 导出 (200行)
│   │
│   ├── screens/
│   │   ├── home_screen.dart             # 工程列表页 (200行)
│   │   ├── project_screen.dart          # 4步骤向导操作页 (250行)
│   │   └── settings_screen.dart         # 设置页 (150行)
│   │
│   └── widgets/
│       ├── project_card.dart            # 工程卡片 (120行)
│       ├── step_import.dart             # Step1 素材导入 (200行)
│       ├── step_recognize.dart          # Step2 ASR识别 (180行)
│       ├── step_match.dart              # Step3 匹配确认 (200行)
│       ├── step_timeline.dart           # Step4 时间线 (220行)
│       ├── asr_progress_panel.dart      # 识别进度面板 (140行)
│       ├── match_result_tile.dart       # 匹配结果条目 (130行)
│       ├── subtitle_compare.dart        # 字幕对比弹窗 (180行)
│       ├── timeline_preview.dart        # 时间线可视化 (250行)
│       └── common/
│           ├── loading_overlay.dart     # 加载遮罩 (40行)
│           ├── empty_state.dart         # 空状态占位 (50行)
│           └── directory_picker.dart    # 目录选择器 (60行)
│
├── dist/                            # 编译输出 (版本递增)
├── backup/                          # 源码备份 (版本递增)
├── 进度快照/                        # 开发进度记录
├── ASR合板.md                       # 本文档
├── 大型项目规划.md                  # 工作规则
└── 需求.md                          # 原始需求
```

### 7.2 文件统计

- Dart 源文件: 39 个
- 预估总代码量: ~5,340 行

---

## 八、实施步骤

### 阶段 1: 项目骨架与数据层

**目标**: 创建 Flutter 项目，配置依赖，实现数据模型和数据库

| 步骤 | 内容 | 文件 |
|------|------|------|
| 1.1 | `flutter create` 创建项目 | pubspec.yaml |
| 1.2 | 配置依赖并 `flutter pub get` | pubspec.yaml |
| 1.3 | 配置窗口标题和默认大小(1280x800) | windows/runner/main.cpp |
| 1.4 | 实现暗色主题 | app_theme.dart |
| 1.5 | 配置路由 (/ → /project/:id → /settings) | app_router.dart |
| 1.6 | 实现全部 5 个数据模型 | models/*.dart |
| 1.7 | 实现 DatabaseService | database_service.dart |
| 1.8 | 实现全局常量 | constants.dart |

**验收**: `flutter run -d windows` 启动正常，暗色主题生效，数据库文件创建成功

### 阶段 2: 工程管理 UI

**目标**: 实现工程卡片的增删改查

| 步骤 | 内容 | 文件 |
|------|------|------|
| 2.1 | 工程列表 Provider | project_list_provider.dart |
| 2.2 | 设置 Provider | settings_provider.dart |
| 2.3 | 工程列表页 + 网格布局 | home_screen.dart |
| 2.4 | 工程卡片组件 | project_card.dart |
| 2.5 | 新建工程弹窗 | home_screen.dart 内 |
| 2.6 | 设置页（路径配置） | settings_screen.dart |

**验收**: 能新建/删除/重命名工程，卡片列表正常显示

### 阶段 3: 素材导入

**目标**: 实现目录选择和文件扫描

| 步骤 | 内容 | 文件 |
|------|------|------|
| 3.1 | 工程详情 Provider | project_detail_provider.dart |
| 3.2 | 目录扫描服务 | media_scan_service.dart |
| 3.3 | FFmpeg 服务 | ffmpeg_service.dart |
| 3.4 | 向导容器页面 | project_screen.dart |
| 3.5 | Step1 素材导入组件 | step_import.dart |
| 3.6 | 目录选择器组件 | directory_picker.dart |

**验收**: 选择视频/音频目录后显示文件列表和时长

### 阶段 4: ASR 引擎集成

**目标**: 集成 sherpa-onnx + SenseVoice，实现批量识别

| 步骤 | 内容 | 文件 |
|------|------|------|
| 4.1 | sherpa-onnx 服务 | sherpa_onnx_service.dart |
| 4.2 | ASR 批量编排服务 | asr_batch_service.dart |
| 4.3 | ASR 过程 Provider | asr_process_provider.dart |
| 4.4 | Step2 ASR 识别 UI | step_recognize.dart |
| 4.5 | ASR 进度面板组件 | asr_progress_panel.dart |
| 4.6 | ASR 缓存机制 | asr_batch_service.dart 内 |

**验收**: 点击开始识别后进度正常，识别完成后字幕写入数据库

### 阶段 5: 字幕匹配

**目标**: 实现字幕上下文匹配算法和匹配确认 UI

| 步骤 | 内容 | 文件 |
|------|------|------|
| 5.1 | 字幕匹配算法服务 | subtitle_match_service.dart |
| 5.2 | 匹配 Provider | match_provider.dart |
| 5.3 | Step3 匹配确认 UI | step_match.dart |
| 5.4 | 匹配结果条目组件 | match_result_tile.dart |
| 5.5 | 字幕对比弹窗 | subtitle_compare.dart |
| 5.6 | 手动匹配功能 | step_match.dart 内 |

**验收**: 匹配结果正确，置信度和字幕对比显示正常

### 阶段 6: 时间线生成

**目标**: 实现音频裁切对齐和时间线可视化

| 步骤 | 内容 | 文件 |
|------|------|------|
| 6.1 | 音频裁切对齐服务 | audio_align_service.dart |
| 6.2 | Step4 时间线 UI | step_timeline.dart |
| 6.3 | 时间线 Canvas 可视化 | timeline_preview.dart |
| 6.4 | FFmpeg 批量裁切执行 | audio_align_service.dart 内 |
| 6.5 | XML 导出服务 | export_service.dart |

**验收**: 音频裁切对齐成功，XML 导出可用

### 阶段 7: 打磨优化

**目标**: 完善体验，编译发布

| 步骤 | 内容 |
|------|------|
| 7.1 | 错误处理完善（文件不存在、ASR失败、FFmpeg失败的友好提示） |
| 7.2 | 断点续传（应用重启后恢复进度） |
| 7.3 | UI 动画和过渡效果 |
| 7.4 | 窗口位置/大小记忆 |
| 7.5 | 编译 release 版本到 dist/ |

**验收**: `flutter build windows --release` 编译成功

---

## 九、扩展功能规划（非核心，后续迭代）

| 功能 | 说明 |
|------|------|
| 时间码辅助验证 | 有源时间码时直接精确计算偏移，提升置信度 |
| 波形指纹匹配 | 处理静音/纯音乐场景的字幕缺失情况 |
| 一对多匹配增强 | 一个长录音笔音频匹配多个短视频 |
| AAF/EDL 导出 | 兼容更多后期软件 |
| 批量工程管理 | 一次创建多个工程，批量识别 |
| 工程模板 | 保存常用配置为模板 |
| 音量归一化 | 裁切后自动调整音频音量 |
