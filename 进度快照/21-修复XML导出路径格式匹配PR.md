# 进度快照 #21 - 修复 XML 导出路径格式（匹配 PR 正确格式）

> 时间: 2026-04-22
> 版本: v1.0.0 (路径修复)
> 状态: **pathurl 已改为 file://localhost/ + percent-encoding，匹配 PR 导出格式**
> 编译产物: build\windows\x64\runner\Debug\asr_tools.exe

---

## 本次修改内容

### 问题
导入 PR/DaVinci 时媒体显示离线，但手动搜索后可以匹配上。

### 根因
对比 PR 导出的正确 XML (`测试合板/PR导出测试.xml`) 和我们导出的 (`测试合板/asr_timeline.xml`)，发现 `pathurl` 格式不一致：

| 项目 | 我们之前 | PR 正确格式 |
|------|----------|-------------|
| 前缀 | `file:///` | `file://localhost/` |
| 中文 | 原始 UTF-8 | percent-encoded (`%e5%85%83...`) |
| 冒号 | `G:` | `G%3a` |

### 修复
重写 `_toFileUri()` 方法：
- 前缀改为 `file://localhost/`
- 对路径做 percent-encoding（保留 `/`、字母、数字、`-`、`.`、`_`、`~`）
- 使用小写十六进制（匹配 PR 输出 `%e5` 而非 `%E5`）

### 修复前输出:
```
file:///G:/data/260224-元数据脚本测试/1_Video/220822shipin/C0459.mp4
```

### 修复后输出:
```
file://localhost/G%3a/data/260224-%e5%85%83%e6%95%b0%e6%8d%ae%e8%84%9a%e6%9c%ac%e6%b5%8b%e8%af%95/1_Video/220822shipin/C0459.mp4
```

### 修改的文件：
- `lib/services/export_service.dart` — 新增 `_percentEncodePath()` 方法，重写 `_toFileUri()`，添加 `dart:convert` 导入

---

## 待办
- [ ] 用实际项目测试 PR 导入是否不再显示离线
- [ ] 测试 DaVinci Resolve 导入是否正常
- [ ] 检查 xmeml 格式是否还有其他结构性差异需修复（如 version="4" vs "5"）
