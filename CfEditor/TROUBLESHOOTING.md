# 题面渲染系统 - 故障排查指南

## 问题：提示"加载失败"

### 可能原因 1：题目缺少 Contest ID ⭐️ 最常见

**症状**：
- 错误提示："该题目缺少比赛 ID，无法加载原生题面"
- 建议："切换到网页模式查看"

**原因**：
某些题目（特别是从 Problemset 页面进入的）的 `contestId` 字段为 `nil`，无法构造题目 URL。

**解决方案**：
1. **立即解决**：点击右上角切换到"网页模式"
2. **查看详情**：打开 Xcode 控制台，查看日志：
   ```
   ❌ [ProblemViewer] contestId 为 nil，题目: XXX
   ```

**为什么会这样？**
- Codeforces API 在某些情况下不返回 `contestId`
- 这是 API 的设计，不是 bug
- 网页模式可以正常工作

---

### 可能原因 2：网络错误

**症状**：
- 错误提示："网络请求失败"
- 或："请求超时"

**原因**：
- 网络连接不稳定
- Codeforces 服务器响应慢
- 防火墙/代理拦截

**解决方案**：
1. 检查网络连接
2. 点击"重试"按钮
3. 如果多次失败，切换到网页模式

**查看日志**：
```
🔍 [ProblemParser] 开始下载题目: https://...
❌ [ProblemParser] HTTP 错误: 404
```

---

### 可能原因 3：Cloudflare 拦截（已修复误判问题）

**症状**：
- 错误提示："Codeforces 启用了 Cloudflare 验证"
- 建议："请使用网页模式查看"

**原因**：
- Codeforces 检测到自动化请求
- 触发了 Cloudflare 人机验证

**⚠️ 注意**：
早期版本存在误判问题（将正常页面误判为 Cloudflare 拦截）。
如果你看到这个错误，请确保使用最新版本（2025-10-09 之后）。

**解决方案**：
1. **如果是真的被拦截**：
   - 必须切换到网页模式
   - 在网页模式中完成人机验证
   - 等待几分钟后再试原生模式

2. **如果怀疑是误判**：
   - 更新到最新版本
   - 查看控制台日志，确认是否真的被拦截

**查看日志**：
```
🚫 [ProblemParser] 检测到 Cloudflare 拦截
```

**真正的 Cloudflare 拦截页面特征**：
- 包含 "Checking your browser"
- 包含 "Just a moment"
- 包含 "Enable JavaScript and cookies to continue"

---

### 可能原因 4：HTML 解析失败

**症状**：
- 错误提示："题目解析失败"
- 或："无法提取题目内容"

**原因**：
- Codeforces 网页结构变化
- 题目格式特殊（罕见）

**解决方案**：
1. 切换到网页模式
2. 报告问题给开发者

**查看日志**：
```
✅ [ProblemParser] HTML 下载成功，长度: 12345 字符
🔄 [ProblemParser] 开始解析 HTML...
❌ [ProblemParser] 解析失败: ...
```

---

## 调试步骤

### 步骤 1：查看控制台日志

在 Xcode 中运行项目，打开控制台（Cmd+Shift+Y），查找以下日志：

```
📦 [ProblemCache] 请求题目: 2042-A, 强制刷新: false
💾 [ProblemCache] 找到缓存，年龄: 2小时，过期: false
✅ [ProblemCache] 使用缓存
```

或者：

```
🌐 [ProblemCache] 从网络下载...
🔍 [ProblemParser] 开始下载题目: https://...
📡 [ProblemParser] HTTP 状态码: 200
✅ [ProblemParser] HTML 下载成功，长度: 45678 字符
🔄 [ProblemParser] 开始解析 HTML...
✅ [ProblemParser] 解析成功: Greedy Monocarp
   - 样例数量: 3
   - 题面长度: 5 个元素
```

### 步骤 2：使用调试视图

1. 在项目中找到 `ProblemDebugView.swift`
2. 在 SwiftUI Preview 中运行，或者添加到主界面
3. 输入 Contest ID 和 Problem Index
4. 点击"测试解析"
5. 查看详细的解析结果

### 步骤 3：检查缓存

进入 **设置 → 题面渲染设置**：
- 查看缓存统计
- 尝试"清空缓存"
- 重新加载题目

---

## 常见问题 FAQ

### Q1: 为什么有些题目能加载，有些不能？

**A**: 主要原因是 `contestId` 字段。从 Contests 页面进入的题目通常有 `contestId`，而从 Problemset 页面进入的某些题目可能没有。

### Q2: 网页模式和原生模式有什么区别？

**A**: 
- **原生模式**：下载 HTML，本地解析，移动端优化，支持缓存
- **网页模式**：直接加载 Codeforces 网页，功能完整，但体验较差

### Q3: 缓存会占用多少空间？

**A**: 每个题目约 30-50 KB，100 个题目约 3-5 MB。缓存会自动过期（7天）。

### Q4: 可以离线查看题目吗？

**A**: 可以！查看过的题目会自动缓存，离线时可以查看（仅原生模式）。

### Q5: LaTeX 公式显示不正常？

**A**: 
1. 确保有网络连接（首次加载 MathJax）
2. 等待几秒让 MathJax 加载完成
3. 尝试调整字体大小

### Q6: 如何报告 bug？

**A**: 
1. 截图错误信息
2. 复制控制台日志
3. 记录题目 ID（Contest ID + Problem Index）
4. 联系开发者

---

## 日志说明

### 正常流程日志

```
📦 [ProblemCache] 请求题目: 2042-A, 强制刷新: false
🌐 [ProblemCache] 从网络下载...
🔍 [ProblemParser] 开始下载题目: https://codeforces.com/contest/2042/problem/A
📡 [ProblemParser] HTTP 状态码: 200
✅ [ProblemParser] HTML 下载成功，长度: 45678 字符
🔄 [ProblemParser] 开始解析 HTML...
✅ [ProblemParser] 解析成功: Greedy Monocarp
   - 样例数量: 3
   - 题面长度: 5 个元素
💾 [ProblemCache] 已保存到缓存
✅ [ProblemViewer] 加载成功
```

### 使用缓存日志

```
📦 [ProblemCache] 请求题目: 2042-A, 强制刷新: false
💾 [ProblemCache] 找到缓存，年龄: 2小时，过期: false
✅ [ProblemCache] 使用缓存
✅ [ProblemViewer] 加载成功
```

### 错误日志示例

#### Contest ID 为 nil
```
🔄 [ProblemViewer] 开始加载题目: 2042-A
❌ [ProblemViewer] contestId 为 nil，题目: Some Problem
```

#### 网络错误
```
🔍 [ProblemParser] 开始下载题目: https://...
📡 [ProblemParser] HTTP 状态码: 404
❌ [ProblemParser] HTTP 错误: 404
❌ [ProblemViewer] 加载失败: networkError
```

#### Cloudflare 拦截
```
🔍 [ProblemParser] 开始下载题目: https://...
📡 [ProblemParser] HTTP 状态码: 200
✅ [ProblemParser] HTML 下载成功，长度: 12345 字符
🚫 [ProblemParser] 检测到 Cloudflare 拦截
❌ [ProblemViewer] 加载失败: cloudflareBlocked
```

---

## 快速解决方案总结

| 错误信息 | 解决方案 |
|---------|---------|
| "该题目缺少比赛 ID" | ✅ 切换到网页模式 |
| "网络请求失败" | 🔄 点击重试，或检查网络 |
| "Cloudflare 验证" | 🌐 必须使用网页模式 |
| "题目解析失败" | 🌐 切换到网页模式，报告问题 |
| 加载很慢 | ⏳ 等待，或切换到网页模式 |
| LaTeX 不显示 | 🔄 刷新，或调整字体大小 |

---

## 联系支持

如果以上方法都无法解决问题：

1. **收集信息**：
   - 错误截图
   - 控制台日志（完整）
   - 题目 ID（Contest ID + Problem Index）
   - iOS 版本和设备型号

2. **提供反馈**：
   - 通过 GitHub Issues
   - 或联系开发者

---

**最后更新**: 2025-10-09  
**版本**: 1.0.0

