# CfEditor

<div align="center">

**您的全功能 iOS Codeforces 编程助手**

一款原生 iOS/macOS 应用，将完整的 Codeforces 体验带到您的移动设备上，拥有强大的代码编辑器、智能题目浏览和精美的数据可视化。

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0%2B%20%7C%20macOS%2014.0%2B-lightgrey.svg)](https://developer.apple.com)

[功能特性](#-功能特性) • [安装说明](#-安装说明) • [截图展示](#-截图展示) • [配置指南](#-配置指南)

</div>

> **🆕 最新版本新功能:**
> - 🔧 **灵活的 Judge0 配置**: 在公共 API、RapidAPI 和自定义实例之间切换
> - 🔑 **独立 API 密钥管理**: RapidAPI 和自定义实例凭据分别存储
> - ⚙️ **便捷设置界面**: 直接在应用内配置代码执行服务

---

## ✨ 功能特性

### 🏆 比赛与题库浏览器

**智能题目发现**
- 📋 **实时比赛动态**: 浏览进行中、即将开始和已结束的比赛，带有实时倒计时
- 🔍 **高级筛选**: 按以下条件筛选题目：
  - 难度评分（800-3500+）
  - 标签（40+ 类别：动态规划、图论、数学、贪心等）
  - 解题状态（AC ✅、尝试过 🟡、未解决 ⚪）
  - 比赛阶段（进行中、即将开始、已结束）
- ⭐ **收藏系统**: 收藏题目以便后续练习，持久化存储
- 📊 **进度追踪**: 实时同步您的提交状态，带视觉指示器

**精美的题目查看器**
- 📝 **富文本渲染**: 完整的 HTML 题面，优雅的排版
- 🧮 **LaTeX 数学支持**: 行内 `$...$` 和块级 `$$...$$` 公式渲染
- 🖼️ **自动图片加载**: 题目配图和插图无缝加载
- 🌐 **AI 翻译**: 逐段流式翻译（英文 → 中文）
  - 保护 LaTeX 公式和代码片段
  - 支持 OpenAI 兼容 API（ChatGPT、Claude、本地 Ollama 等）
  - 每段完成即时显示
- 📋 **一键导入**: 直接将样例测试用例导入编辑器

**智能缓存**
- 💾 **题目缓存**: 下载的题目本地缓存（7天过期）
- 🌍 **翻译缓存**: 翻译结果跨会话持久化，带模型版本追踪
- ⚡ **即时加载**: 之前浏览过的题目瞬间加载

### 💻 强大的代码编辑器

**VS Code 驱动的编辑体验**
- ⌨️ **Monaco 编辑器**: 与 Visual Studio Code 相同的引擎
  - 语法高亮（C++、Python、Java）
  - IntelliSense 智能补全
  - 代码折叠和括号匹配
  - 多光标支持
  - 完整历史记录的撤销/重做
- 🎨 **主题同步**: 编辑器主题跟随系统浅色/深色模式
- 📁 **文件管理**:
  - 浏览、创建和管理本地文件
  - 文件夹层级支持
  - 最近文件快速访问
  - 自动保存防止数据丢失

**集成测试环境**
- 🧪 **Judge0 集成**: 在强大的云端运行器上执行代码
  - 支持 C++17、Python 3、Java 11+
  - 实时执行，带超时保护
  - 内存使用和运行时统计
  - **灵活的 API 配置**: 在 RapidAPI、自定义实例或公共服务器之间切换
  - **独立 API 密钥**: RapidAPI 和自定义实例的独立密钥管理
- 📊 **批量测试**: 并行运行多个测试用例
- ✅ **评测系统**: 清晰的 AC/WA/TLE/RE 指示器
- 📋 **测试用例管理**: 
  - 添加/编辑/删除测试用例
  - 从题目样例导入
  - 按题目保存测试套件

**代码模板**
- 📄 **自定义模板**: 为每种语言定义您的启动代码
- ⚡ **快速开始**: 一键使用您的模板创建新文件
- 🔄 **跨设备同步**: 模板通过 iCloud 持久化和同步

### 📊 个人统计仪表盘

**用户资料**
- 👤 **Codeforces 集成**: 通过绑定 handle 自动数据同步
- 🎖️ **段位徽章**: 可视化显示您的评分等级，带颜色编码
  - 新手（灰色）→ 传奇特级大师（红色）
- 📈 **评分图表**: 精美的折线图展示您的历史评分变化

**可视化分析**
- 🔥 **活动热力图**: GitHub 风格的贡献日历
  - 基于提交和 AC 数量的颜色强度
  - 交互式：点击任意日期查看详情
- 📊 **难度分布**: 按评分展示已解决题目的柱状图
- 🥧 **标签分析**: 饼图可视化您的强项
  - 查看您练习最多的主题
  - 识别知识薄弱点

**提交历史**
- 📜 **最近活动**: 查看您的最新提交及评测结果
- 🏆 **比赛参与**: 追踪比赛表现
- 📅 **时间线视图**: 按时间顺序的提交历史

**智能设置**
- 🎨 **主题选择**: 浅色、深色或跟随系统
- 📝 **代码模板编辑器**: 自定义 C++、Python、Java 的模板
- 🤖 **AI 模型管理**: 
  - 添加多个翻译模型
  - 使用前测试 API 连接
  - 轻松切换模型
- ⚙️ **Judge0 配置**:
  - 在公共 API、RapidAPI 或自定义实例之间选择
  - 不同提供商的独立 API 密钥存储
  - 实时 API 状态和健康检查

### 📚 集成 OI Wiki

- 🌐 **完整 Wiki 浏览器**: 在应用内访问 [OI-Wiki.org](https://oi-wiki.org)
- 🔍 **导航控件**: 后退/前进、刷新、主页
- 🌙 **深色模式支持**: 与应用主题同步
- 💾 **离线缓存**: 之前浏览过的页面可离线访问

---

## 🚀 安装说明

### 系统要求

- **macOS**: 14.0+ (Sonoma 或更高版本)
- **Xcode**: 15.0+
- **iOS 设备/模拟器**: iOS 17.0+
- **Swift**: 5.9+

### 快速开始

#### macOS 用户

1. **安装 Xcode**
   ```bash
   # 从 Mac App Store 安装或从以下地址下载:
   # https://developer.apple.com/xcode/
   ```

2. **克隆仓库**
   ```bash
   git clone https://github.com/yourusername/CfEditor.git
   cd CfEditor
   ```

3. **打开项目**
   ```bash
   open CfEditor.xcodeproj
   ```

4. **解析依赖**
   - Xcode 会通过 Swift Package Manager 自动下载依赖
   - 如需手动: `文件` → `Packages` → `Update to Latest Package Versions`

#### 安装到真机 iPhone

1. **连接 iPhone**: 通过 USB 线将 iPhone 连接到 Mac
2. **信任电脑**: 在 iPhone 上点击"信任"
3. **配置代码签名**:
   - 在 Xcode 导航栏中选择项目（蓝色图标）
   - 选择 **CfEditor** target
   - 前往 **Signing & Capabilities** 标签
   - 启用 **"Automatically manage signing"**
   - 选择您的 **Team**（免费 Apple ID 即可）
4. **选择设备**: 从 Xcode 工具栏的设备下拉菜单中选择您的 iPhone
5. **构建并运行**: 按 `⌘R` 或点击 ▶️ 按钮
6. **信任开发者**（首次需要）:
   - 在 iPhone 上: `设置` → `通用` → `VPN 与设备管理`
   - 点击您的 Apple ID → **信任**

**免费开发者账户说明:**
- 应用会在 7 天后过期，需要重新安装
- 最多同时安装 3 个应用
- 如需永久安装，可加入 [Apple Developer Program](https://developer.apple.com/programs/) ($99/年)

#### 使用 iOS 模拟器（无需 iPhone）

1. 从 Xcode 的设备菜单中选择任意 iOS 模拟器（例如 "iPhone 15 Pro"）
2. 按 `⌘R` 构建并运行
3. 应用会在模拟器中自动启动

### 首次启动设置

1. **启动应用** → 导航到 **"我的"** 标签
2. **绑定账号**（可选但推荐）:
   - 输入您的 Codeforces handle
   - 或点击"浏览器登录"进行认证
3. **配置 AI 翻译**（可选）:
   - 点击 **"设置"** → **"翻译 AI 模型"**
   - 添加您的 OpenAI 兼容 API 端点
   - 测试连接
4. **开始编程!** 🎉

---

## 📱 项目架构

```
CfEditor/
├── api/                           # 网络与外部 API
│   ├── CFAPI.swift               # Codeforces API 封装
│   ├── AITranslator.swift        # AI 翻译引擎（流式）
│   └── api.swift                 # 共享 API 工具
│
├── contests/                      # 比赛与题目模块
│   ├── ContestsStore.swift       # 比赛数据管理与状态
│   ├── ProblemsetStore.swift     # 题库数据与筛选逻辑
│   ├── ProblemParser*.swift      # HTML 解析与 LaTeX 提取（6 个文件）
│   ├── ProblemStatementView.swift # 题目查看器 UI
│   ├── ProblemCache.swift        # 本地题目缓存（7天）
│   ├── TranslationCache.swift    # 翻译持久化
│   ├── LatexRenderedTextView.swift # 数学公式渲染
│   ├── FavoritesManager.swift    # 收藏的题目
│   └── ContestFilterView.swift   # 筛选 UI 组件
│
├── editor/                        # 代码编辑器模块
│   ├── CodeEditorView.swift      # 主编辑器界面
│   ├── MonacoEditorView.swift    # Monaco 编辑器 WebView 桥接
│   ├── FilesBrowserView.swift    # 文件系统浏览器
│   ├── RunSheetView.swift        # 测试执行面板
│   ├── TestCase.swift            # 测试用例数据模型
│   ├── DocumentPicker.swift      # 系统文件选择器集成
│   └── SettingsSheetView.swift   # 编辑器设置 UI
│
├── profile/                       # 用户资料模块
│   ├── ProfileView.swift         # 主资料页面
│   ├── ProfileSettingsView.swift # 应用设置（主题、模板、AI）
│   ├── ProfileViewData.swift     # 数据获取与 API 调用
│   ├── ProfileViewCharts.swift   # 评分与统计图表
│   ├── HeatmapView.swift         # GitHub 风格活动热力图
│   ├── TagPieChartView.swift     # 标签分布可视化
│   └── BindCFAccountView.swift   # Handle 绑定界面
│
├── models/                        # 数据模型
│   ├── AppTheme.swift            # 主题系统（浅色/深色/跟随系统）
│   └── CodeTemplate.swift        # 代码模板管理
│
├── network/                       # 网络服务
│   ├── Judge0Client.swift        # 代码执行 API 客户端
│   └── Judge0Config.swift        # Judge0 配置管理
│
├── oiwiki/                        # OI Wiki 集成
│   └── OIWikiView.swift          # Wiki 浏览器视图
│
├── debug/                         # 开发工具
│   └── DebugPerformanceView.swift # 性能分析
│
└── others/                        # 核心与共享
    ├── CfEditorApp.swift         # 应用入口与生命周期
    ├── WebView.swift             # 可复用 WebView 包装器
    ├── CFCookieBridge.swift      # Cookie 同步（WebView ↔ URLSession）
    ├── SafariView.swift          # 应用内 Safari 浏览器
    └── Assets.xcassets/          # 应用图标与图像资源
```

### 技术栈

| 组件 | 技术 |
|------|------|
| **UI 框架** | SwiftUI + UIKit 互操作 |
| **数据持久化** | SwiftData + UserDefaults + FileManager |
| **网络** | URLSession with async/await |
| **代码编辑器** | Monaco Editor（WebView 桥接）|
| **图表** | Swift Charts 框架 |
| **图片加载** | Kingfisher（懒加载 + 缓存）|
| **数学渲染** | 自定义 LaTeX 解析器 + AttributedString |
| **Cookie 管理** | WKWebView + HTTPCookieStorage 同步 |
| **代码执行** | Judge0 REST API |
| **AI 翻译** | OpenAI 兼容流式 API |

---

## 🔧 配置指南

### 1. Judge0 代码执行

应用支持三种 Judge0 配置模式，可通过应用内设置轻松切换：

#### **应用内配置**（推荐）:

1. 打开应用 → **"我的"** 标签 → **"设置"** → **"Judge0 配置"**
2. 选择您偏好的 API 类型：
   - **🌐 公共 API**: `ce.judge0.com` 的免费服务（无需 API 密钥）
   - **⚡ RapidAPI**: 具有更高速率限制的高级服务
   - **🔧 自定义实例**: 自托管或第三方 Judge0 服务器

#### **配置选项**:

**选项 1: 公共 API（默认）**
- 无需配置
- 免费服务，合理的速率限制
- 适合学习和练习
- URL: `https://ce.judge0.com`

**选项 2: RapidAPI**
1. 从 [RapidAPI Judge0 CE](https://rapidapi.com/judge0-official/api/judge0-ce) 获取您的 API 密钥
2. 在设置中选择 **"RapidAPI"**
3. 输入您的 **X-RapidAPI-Key**
4. 应用会自动使用: `https://judge0-ce.p.rapidapi.com`

**选项 3: 自定义实例**
1. 部署您自己的 Judge0 服务器（参见 [Judge0 文档](https://github.com/judge0/judge0)）
2. 在设置中选择 **"自定义"**
3. 输入您的 **API URL**（例如 `https://your-server.com`）
4. 如果需要认证，可选添加 **API 密钥**

#### **主要特性**:
- ✅ **独立 API 密钥**: RapidAPI 密钥和自定义实例密钥分别存储
- ✅ **轻松切换**: 更换提供商而不丢失配置
- ✅ **持久化存储**: 设置通过 UserDefaults 自动保存
- ✅ **实时显示**: 设置中显示当前活动的 API

### 2. AI 翻译设置

**应用内配置**（推荐）:
1. 打开应用 → **"我的"** 标签 → **"设置"**
2. 滚动到 **"翻译 AI 模型"**
3. 点击 **"添加"** 并配置:
   - **模型名称**: 显示名称（例如 "GPT-4o Mini"）
   - **模型**: 模型 ID（例如 `gpt-4o-mini`, `claude-3-sonnet`, `qwen2.5:14b`）
   - **API 端点**: `/v1/chat/completions` 的完整 URL
   - **API 密钥**: 您的 API 密钥（某些代理可选）

**支持的 API**:
- ✅ OpenAI (GPT-3.5, GPT-4, GPT-4o)
- ✅ Anthropic Claude（通过代理）
- ✅ 本地 Ollama (`http://localhost:11434/v1/chat/completions`)
- ✅ OpenRouter、Together AI 或任何 OpenAI 兼容代理

**示例端点**:
```
OpenAI:       https://api.openai.com/v1/chat/completions
Ollama:       http://localhost:11434/v1/chat/completions
OpenRouter:   https://openrouter.ai/api/v1/chat/completions
自定义代理:    https://your-proxy.com/v1/chat/completions
```

**测试**: 使用内置的 **"测试 API"** 按钮在使用前验证连接。

### 3. 主题自定义

提供三种主题模式:
- **浅色**: 强制浅色模式
- **深色**: 强制深色模式  
- **跟随系统**: 根据 iOS 设置自动切换

在以下位置更改: **"我的"** → **"设置"** → **"主题"**

### 4. 代码模板

自定义每种语言的默认代码:

1. **"我的"** → **"设置"** → **"代码模板"**
2. 选择一种语言（C++、Python、Java）
3. 编辑模板
4. 保存（通过 UserDefaults 同步）

**默认 C++ 模板**:
```cpp
#include <bits/stdc++.h>
using namespace std;

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(nullptr);
    
    // Your code here
    
    return 0;
}
```

---

## 🎯 核心功能深度解析

### 高级题目解析

**HTML 到结构化数据**:
```swift
// 从 Codeforces HTML 提取:
struct ProblemStatement {
    let name: String
    let timeLimit: String
    let memoryLimit: String
    let statement: [ContentElement]      // 混合文本 + LaTeX
    let inputSpec: [ContentElement]
    let outputSpec: [ContentElement]
    let sampleTests: [SampleTest]
    let note: [ContentElement]?
}
```

**LaTeX 渲染**:
- 行内: `$O(n \log n)$` → O(n log n)
- 块级: `$$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$`
- 保留数学符号、下标、分数、希腊字母
- AI 翻译期间保护 LaTeX

### 智能 Cookie 同步

**无缝登录**:
```swift
// 在以下之间自动同步 Codeforces cookies:
// 1. WKWebView（用于 OI Wiki 和题目查看器）
// 2. URLSession（用于 API 调用）
// 3. UserDefaults（持久化 handle 存储）

// 这实现了:
// - 在 web 视图中登录一次 → API 调用即被认证
// - 无需重复登录提示
// - 应用重启后保持会话一致
```

### 智能进度追踪

**实时状态同步**:
- 通过 Codeforces API 获取您的提交
- 标记题目: ✅ AC（绿色）、🟡 尝试过（黄色）、⚪ 未解决
- 切换比赛或刷新时更新
- 本地缓存以便即时显示

### 流式 AI 翻译

**逐段翻译**:
```swift
// 而不是等待整个翻译:
// 1. 将题目拆分为段落
// 2. 独立翻译每段
// 3. 结果到达时显示（流式 UI 更新）
// 4. 出错时继续（部分翻译优于无翻译）
```

**优势**:
- ⚡ 更快的感知速度（立即看到结果）
- 🛡️ 容错性（一段失败不会破坏全部）
- 🧮 LaTeX 安全（公式用占位符保护）

### 性能优化

| 功能 | 优化 |
|------|------|
| **LaTeX 渲染** | 渲染的公式在内存中缓存 |
| **题目加载** | 7 天磁盘缓存（JSON）|
| **API 调用** | 防抖动，带并发请求限制 |
| **翻译** | 带模型版本追踪的永久缓存 |
| **图片** | Kingfisher 磁盘+内存缓存，懒加载 |
| **大列表** | LazyVStack 带分页 |
| **数据同步** | async/await 防止 UI 阻塞 |

---

## 🐛 故障排除

### 构建问题

**"依赖解析失败"**:
```bash
# 在 Xcode 中: 文件 → Packages → Reset Package Caches
# 然后: 文件 → Packages → Update to Latest Package Versions
```

**"代码签名错误"**:
- 确保您在 Signing & Capabilities 中选择了 Team
- 免费 Apple ID 即可使用（无需付费开发者账户）

### 运行时问题

**"翻译不工作"**:
- 验证 API 端点 URL 包含完整路径: `/v1/chat/completions`
- 检查 API 密钥是否正确（使用内置测试按钮测试）
- 确保模型名称与您的提供商的模型 ID 匹配

**"题目加载失败"**:
- 检查网络连接
- 在 比赛/题库 标签上下拉刷新
- 清除缓存: 设置 → 题目缓存设置 → 清除全部

**"代码执行失败"**:
- **检查配置**: 前往 设置 → Judge0 配置
  - 验证选择了正确的 API 类型
  - RapidAPI: 确保 API 密钥输入正确
  - 自定义: 验证 URL 可访问且包含协议（https://）
- **测试连接**: 
  - 公共 API: 在浏览器中访问 https://ce.judge0.com
  - RapidAPI: 在 RapidAPI 仪表板上检查配额
  - 自定义: Ping 您的服务器或检查健康端点
- **代码问题**:
  - 检查代码是否有语法错误
  - 确保测试输入格式与预期格式匹配
  - 验证语言 ID 与您的代码匹配（C++17、Python3 等）
- **速率限制**: 如果使用免费服务，高峰期可能会遇到速率限制

---

## 🤝 贡献

欢迎贡献！以下是您可以帮助的方式:

### 贡献方式

- 🐛 **报告 Bug**: 打开 issue 并附上复现步骤
- ✨ **建议功能**: 在 issue 中描述您的想法
- 💻 **提交代码**: Fork → 创建分支 → Pull request
- 📖 **改进文档**: 修复错别字、添加示例、澄清说明
- 🌐 **翻译**: 添加对更多语言的支持

### 开发流程

1. **Fork** 仓库
2. **创建** 功能分支:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **提交** 您的更改:
   ```bash
   git commit -m "添加惊人的功能"
   ```
4. **推送** 到您的 fork:
   ```bash
   git push origin feature/amazing-feature
   ```
5. **打开** Pull Request 并附上:
   - 清晰的更改描述
   - 截图（如果是 UI 更改）
   - 测试用例（如适用）

### 代码风格

- 遵循 [Swift API 设计指南](https://swift.org/documentation/api-design-guidelines/)
- 使用 `// MARK: -` 组织代码段
- 为复杂逻辑添加注释
- 在浅色和深色模式下测试
- 确保 iPad 和 iPhone 兼容性

---

## 🙏 致谢

这个项目离不开这些出色的资源:

- [**Codeforces**](https://codeforces.com) - API 访问和题库
- [**OI Wiki**](https://oi-wiki.org) - 全面的竞赛编程知识
- [**Judge0**](https://judge0.com) - 代码执行基础设施
- [**Monaco Editor**](https://microsoft.github.io/monaco-editor/) - VS Code 的编辑器引擎
- [**Kingfisher**](https://github.com/onevcat/Kingfisher) - 高效的图片加载
- [**OpenAI**](https://openai.com) & [**Anthropic**](https://anthropic.com) - AI 翻译能力

特别感谢竞赛编程社区的灵感和反馈。

---

## 📮 联系方式

**作者**: 赵勃翔 (Boxiang Zhao)

- 📧 **邮箱**: [2750437093@qq.com](mailto:2750437093@qq.com)
- 💬 **Issues**: [GitHub Issues](https://github.com/yourusername/CfEditor/issues)

有关 bug 报告、功能请求或一般问题，请随时打开 issue 或发送电子邮件。

---

## 📸 截图展示

<div align="center">

### 比赛与题目浏览
*实时比赛列表 • 高级筛选 • 带 LaTeX 的题目描述*

### 代码编辑器
*Monaco 编辑器 • 文件管理 • 测试执行面板*

### 个人统计
*评分图表 • 活动热力图 • 标签分布*

### 设置与自定义
*主题选择 • 代码模板 • AI 模型配置*

</div>

---

<div align="center">

**⭐ 如果您觉得这个项目有帮助，请给个 Star！**

**用 ❤️ 为竞赛编程社区打造**

[报告 Bug](https://github.com/yourusername/CfEditor/issues) • [请求功能](https://github.com/yourusername/CfEditor/issues) • [文档](https://github.com/yourusername/CfEditor/wiki)

</div>

