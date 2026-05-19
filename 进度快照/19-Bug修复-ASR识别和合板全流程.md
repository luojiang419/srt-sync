# 进度快照 #19 - Bug 修复 + 脚本验证全流程

> 时间: 2026-04-22
> 版本: v0.11.0
> 状态: **脚本全流程验证通过，Flutter 代码已更新**
> 最新备份: backup/v0.11.0/
> 编译产物: build\windows\x64\runner\Debug\asr_tools.exe
> FCPXML 输出: 测试合板\asr_timeline.xml

---

## 脚本验证结果

### 测试数据
- 视频: G:\data\260224-元数据脚本测试\1_Video\220822shipin (11个 mp4)
- 音频: G:\data\260224-元数据脚本测试\2_Audio\220822yinpin (21个 mp3)

### ASR 识别结果
- 21个音频文件全部识别成功
- 共产出 145 条中文字幕，识别内容准确
- silencedetect 修复后正确检测语音段（不再包含静默区间）

### 匹配结果（11对，基于时长相似度）
| 视频 | 音频 | 时长相似度 |
|------|------|-----------|
| C0459.mp4 | ZOOM0041_LR.mp3 | 99% |
| C0455.mp4 | ZOOM0027_LR.mp3 | 99% |
| C0458.mp4 | ZOOM0026_LR.mp3 | 99% |
| C0457.mp4 | ZOOM0035_LR.mp3 | 97% |
| C0449.mp4 | ZOOM0021_LR.mp3 | 94% |
| C0454.mp4 | ZOOM0029_LR.mp3 | 93% |
| C0450.mp4 | ZOOM0039_LR.mp3 | 89% |
| C0453.mp4 | ZOOM0040_LR.mp3 | 85% |
| C0452.mp4 | ZOOM0038_LR.mp3 | 66% |
| C0451.mp4 | ZOOM0032_LR.mp3 | 55% |
| C0456.mp4 | ZOOM0023_LR.mp3 | 38% |

### FCPXML 导出
- 已导出到 测试合板\asr_timeline.xml
- 包含正确的 `<asset>` + `file:///` URI 引用
- Premiere Pro / DaVinci Resolve 可直接导入

---

## Flutter 代码修复清单

### Bug#1: silencedetect 语音段解析算法完全重写
- 遍历 `silenceStarts` 而非 `silenceEnds`，正确提取两次静默之间的语音段
- 处理音频开头是静默的情况

### Bug#2: FCPXML 导出重写
- 添加 `<asset>` + `<media-rep>` + `file:///` URI
- TimelineData 新增 videoFilePath/audioFilePath 字段

### Bug#3: reimport 方法只删除对应类型
- deleteMediaFiles 增加 type 参数

### Bug#4: reRecognizeFile 使用 getMediaFileById
- 新增按主键查询方法

### Bug#5: 路径分隔符改为 p.join()

### Bug#6: 匹配算法动态权重

### 关键改进: WAV 分段提取改用 ffmpeg -ss/-to
- 替代旧的字节偏移量方式，更可靠且避免大文件内存问题

## 待办
- 在 Flutter 应用中实际运行完整流程测试
