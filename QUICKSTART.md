# Quick Start Guide | 快速开始指南

<div align="center">

**Get started with CfEditor in 5 minutes**

[English](#english) • [中文](#中文)

</div>

---

## English

### 🚀 Installation (2 minutes)

1. Open `CfEditor.xcodeproj` in Xcode
2. Select your device/simulator
3. Press `⌘R` to build and run
4. ✅ Done! The app is now running

### ⚙️ Basic Setup (3 minutes)

#### 1. Bind Your Codeforces Account
- Open app → **"Me"** tab
- Enter your Codeforces handle
- Tap **"Bind Account"**
- ✅ You'll now see your profile, rating, and statistics

#### 2. Configure Code Execution (Choose one)

**Option A: Use Free Public API (Recommended for beginners)**
- No setup needed! Public API is enabled by default
- URL: `https://ce.judge0.com`

**Option B: Use RapidAPI (For premium features)**
1. Get API key from [RapidAPI](https://rapidapi.com/judge0-official/api/judge0-ce)
2. In app: **"Me"** → **"Settings"** → **"Judge0 Configuration"**
3. Select **"RapidAPI"**
4. Paste your **X-RapidAPI-Key**
5. ✅ Done!

**Option C: Use Your Own Server**
1. Deploy Judge0 ([guide](https://github.com/judge0/judge0))
2. In app: **"Me"** → **"Settings"** → **"Judge0 Configuration"**
3. Select **"Custom"**
4. Enter your server URL (e.g., `https://judge0.yourdomain.com`)
5. Add API key if required
6. ✅ Done!

#### 3. Enable AI Translation (Optional)

1. **"Me"** → **"Settings"** → **"Translation AI Models"**
2. Tap **"Add Model"**
3. Fill in:
   - **Name**: "GPT-4o Mini" (or your choice)
   - **Model**: `gpt-4o-mini`
   - **Endpoint**: `https://api.openai.com/v1/chat/completions`
   - **API Key**: Your OpenAI key
4. Tap **"Test API"** to verify
5. ✅ Done!

**Supported APIs:**
- OpenAI (GPT-3.5, GPT-4, GPT-4o)
- Deepseek
- Local Ollama (`http://localhost:11434/v1/chat/completions`)
- Any OpenAI-compatible proxy

### 🎯 Your First Problem

1. Go to **"Contests"** or **"Problemset"** tab
2. Tap any problem
3. Read the statement (tap **"Translate"** for Chinese)
4. Tap **"Import to Editor"** to load sample tests
5. Write your code in the **"Editor"** tab
6. Tap **"Run"** to test
7. ✅ Submit when all tests pass!

### 💡 Pro Tips

- **Favorites**: Tap ⭐ on any problem to bookmark it
- **Filters**: Use the filter button to find problems by difficulty/tags
- **Templates**: Customize your default code in Settings → Code Templates
- **Dark Mode**: Toggle in Settings → Theme
- **Offline**: Problems and translations are cached for offline access

---

## 中文

### 🚀 安装（2 分钟）

1. 在 Xcode 中打开 `CfEditor.xcodeproj`
2. 选择您的设备/模拟器
3. 按 `⌘R` 构建并运行
4. ✅ 完成！应用现在正在运行

### ⚙️ 基础设置（3 分钟）

#### 1. 绑定您的 Codeforces 账户
- 打开应用 → **"我的"** 标签
- 输入您的 Codeforces handle
- 点击 **"绑定账号"**
- ✅ 您现在可以看到个人资料、评分和统计数据

#### 2. 配置代码执行（选择一项）

**选项 A: 使用免费公共 API（推荐新手）**
- 无需设置！公共 API 默认启用
- URL: `https://ce.judge0.com`

**选项 B: 使用 RapidAPI（高级功能）**
1. 从 [RapidAPI](https://rapidapi.com/judge0-official/api/judge0-ce) 获取 API 密钥
2. 在应用中: **"我的"** → **"设置"** → **"Judge0 配置"**
3. 选择 **"RapidAPI"**
4. 粘贴您的 **X-RapidAPI-Key**
5. ✅ 完成！

**选项 C: 使用您自己的服务器**
1. 部署 Judge0（[指南](https://github.com/judge0/judge0)）
2. 在应用中: **"我的"** → **"设置"** → **"Judge0 配置"**
3. 选择 **"自定义"**
4. 输入您的服务器 URL（例如 `https://judge0.yourdomain.com`）
5. 如需要，添加 API 密钥
6. ✅ 完成！

#### 3. 启用 AI 翻译（可选）

1. **"我的"** → **"设置"** → **"翻译 AI 模型"**
2. 点击 **"添加模型"**
3. 填写:
   - **名称**: "GPT-4o Mini"（或您的选择）
   - **模型**: `gpt-4o-mini`
   - **端点**: `https://api.openai.com/v1/chat/completions`
   - **API 密钥**: 您的 OpenAI 密钥
4. 点击 **"测试 API"** 验证
5. ✅ 完成！

**支持的 API:**
- OpenAI (GPT-3.5, GPT-4, GPT-4o)
- Deepseek
- 本地 Ollama (`http://localhost:11434/v1/chat/completions`)
- 任何 OpenAI 兼容代理

### 🎯 您的第一道题

1. 前往 **"比赛"** 或 **"题库"** 标签
2. 点击任意题目
3. 阅读题面（点击 **"翻译"** 获取中文翻译）
4. 点击 **"导入到编辑器"** 加载样例测试
5. 在 **"编辑器"** 标签中编写代码
6. 点击 **"运行"** 测试
7. ✅ 所有测试通过后提交！

### 💡 专业技巧

- **收藏**: 点击任意题目的 ⭐ 将其加入书签
- **筛选**: 使用筛选按钮按难度/标签查找题目
- **模板**: 在 设置 → 代码模板 中自定义默认代码
- **深色模式**: 在 设置 → 主题 中切换
- **离线**: 题目和翻译会缓存以供离线访问

---

## 🆘 Need Help?

- **English**: Read the [Full Documentation](README.md)
- **中文**: 阅读[完整文档](README_CN.md)
- **Issues**: [Report bugs or request features](https://github.com/Blossoms1010/CfEditor/issues)
- **Email**: 2750437093@qq.com

---

<div align="center">

**Happy Coding! 编程愉快！**

⭐ Star this repo if you find it helpful!

</div>

