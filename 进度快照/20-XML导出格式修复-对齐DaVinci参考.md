# 进度快照 #20 - XML 导出格式修复（对齐 DaVinci 参考格式）

> 时间: 2026-04-22
> 版本: v1.0.0
> 状态: **xmeml 格式已对齐 DaVinci 导出格式，PR 导入仍有问题待解决**
> 编译产物: build\windows\x64\runner\Release\asr_tools.exe
> 测试输出: 测试合板\asr_timeline.xml

---

## 本次修改内容

### 对比参考文件 `测试.xml`（DaVinci Resolve 导出的正确 xmeml），修复了以下格式差异：

| 修改项 | 修改前 | 修改后 |
|--------|--------|--------|
| xmeml version | `"5.1"` | `"5"` |
| clipitem id | 无 | 有 (如 `"C0459_mp4 0"`) |
| file id | 无 | 有 (如 `"C0459_mp4 1"`) |
| audio track 结构 | 每个音频一个 track | 所有音频在同一个 track |
| sequence 子元素 | 无 `<in>`, `<out>`, `<timecode>` | 有 |
| duration 位置 | `</media>` 之后 | `<name>` 之后 |
| link 引用 | 无 | 有（关联 video/audio clip） |
| compositemode | 无 | `normal` |
| track enabled/locked | 无 | 有 |
| video format | 简化版 | 含 `<pixelaspectratio>square</pixelaspectratio>` |

### 修改的文件：
- `lib/services/export_service.dart` — xmeml 导出重写，匹配 DaVinci 格式
- `测试合板/test_export_xml.dart` — 测试脚本同步更新

---

## 当前测试结果

### DaVinci Resolve：
- ✅ 音频可以导入
- ❌ 视频显示离线，无法自动/手动链接
- ❌ 音频轨道超出对应视频长度，跑到后一条视频区域内

### Premiere Pro：
- ❌ 导入时报错（用户截图显示错误信息）

### 可能的原因分析：
1. **视频离线**：`pathurl` 格式问题（`file:///G:/data/...` vs DaVinci 用 `file://localhost/` + URL编码），或视频缺少正确的编解码器信息
2. **音频超出视频长度**：音频 clip 的 `<end>` 帧超出了对应视频 clip 的 `<end>` 帧（因为音频时长可能比视频长）
3. **PR 报错**：xmeml version 或结构不兼容

---

## 待办
- [ ] 修复视频离线问题（可能需要调整 pathurl 格式或 file 内 media 信息）
- [ ] 修复音频超出视频长度的问题（需要限制音频 clip 不超过对应视频的 end）
- [ ] 解决 PR 导入报错
