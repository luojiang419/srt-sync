# 进度快照 #22 - XML 导出路径修复验证通过

> 时间: 2026-04-22
> 版本: v1.0.0
> 状态: **XML 导出路径修复已验证通过，PR 导入不再显示离线**
> 编译产物: build\windows\x64\runner\Debug\asr_tools.exe

---

## 本次修改内容

### 问题
XML 导出导入 PR/DaVinci 时媒体显示离线，需手动搜索才能链接。

### 根因
`_toFileUri()` 输出的 `pathurl` 格式与 PR 期望不一致：
- 旧格式: `file:///G:/data/260224-元数据脚本测试/...`（中文未编码、缺少 localhost）
- PR 格式: `file://localhost/G%3a/data/260224-%e5%85%83%e6%95%b0%e6%8d%ae...`

### 修复
1. 重写 `_toFileUri()` — 使用 `file://localhost/` 前缀
2. 新增 `_percentEncodePath()` — 对非 ASCII 和特殊字符做小写 percent-encoding
3. 同步更新测试脚本 `test_export_xml.dart`
4. 生成测试文件 `测试合板/asr_timeline_v2.xml` 验证通过

### 修改的文件：
- `lib/services/export_service.dart` — 路径格式修复
- `测试合板/test_export_xml.dart` — 测试脚本同步修复

### 验证结果
PR 导入 `asr_timeline_v2.xml` 媒体正常识别，不再离线。

---

## 下一步
- 可继续其他功能开发或优化
