# CfEditor

<div align="center">

**Your All-in-One Codeforces Companion for iOS**

A native iOS/macOS app that brings the complete Codeforces experience to your mobile device with powerful code editing, intelligent problem browsing, and beautiful data visualization.

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0%2B%20%7C%20macOS%2014.0%2B-lightgrey.svg)](https://developer.apple.com)

[Features](#-features) • [Installation](#-installation) • [Configuration](#-configuration)

</div>

## ✨ Features

### 🏆 Contest & Problemset Explorer

**Smart Problem Discovery**
- 📋 **Live Contest Feed**: Browse ongoing, upcoming, and past contests with real-time countdown timers
- 🔍 **Advanced Filtering**: Filter problems by:
  - Difficulty rating (800-3500+)
  - Tags (40+ categories: DP, Graphs, Math, Greedy, etc.)
  - Solve status (AC ✅, Attempted 🟡, Unsolved ⚪)
  - Contest phase (Running, Upcoming, Finished)
- ⭐ **Favorites System**: Bookmark problems for later practice with persistent storage
- 📊 **Progress Tracking**: Real-time sync of your submission status with visual indicators

**Beautiful Problem Viewer**
- 📝 **Rich Rendering**: Full HTML problem statements with beautiful typography
- 🧮 **LaTeX Math Support**: Inline `$...$` and block `$$...$$` formula rendering
- 🖼️ **Automatic Image Loading**: Problem diagrams and illustrations load seamlessly
- 🌐 **AI Translation**: Paragraph-by-paragraph streaming translation (English → Chinese)
  - Preserves LaTeX formulas and code snippets
  - Uses OpenAI-compatible APIs (ChatGPT, Claude, local Ollama, etc.)
  - Real-time display as each paragraph completes
- 📋 **One-Click Import**: Import sample test cases directly to the editor

**Smart Caching**
- 💾 **Problem Cache**: Downloaded problems cached locally (7-day expiration)
- 🌍 **Translation Cache**: Translations persist across sessions with model tracking
- ⚡ **Instant Load**: Previously viewed problems load instantly

### 💻 Powerful Code Editor

**VS Code-Powered Editing**
- ⌨️ **Monaco Editor**: The same engine that powers Visual Studio Code
  - Syntax highlighting (C++, Python, Java)
  - IntelliSense auto-completion
  - Code folding and bracket matching
  - Multi-cursor support
  - Undo/Redo with full history
- 🎨 **Theme Sync**: Editor theme follows system Light/Dark mode
- 📁 **File Management**:
  - Browse, create, and organize local files
  - Folder hierarchy support
  - Recent files quick access
  - Auto-save to prevent data loss

**Integrated Testing Environment**
- 🧪 **Judge0 Integration**: Execute code on powerful cloud runners
  - Support for C++17, Python 3, Java 11+
  - Real-time execution with timeout protection
  - Memory usage and runtime statistics
  - **Flexible API Configuration**: Switch between RapidAPI, custom instances, or public servers
  - **Separate API Keys**: Independent key management for RapidAPI and custom instances
- 📊 **Batch Testing**: Run multiple test cases in parallel
- ✅ **Verdict System**: Clear AC/WA/TLE/RE indicators
- 📋 **Test Case Management**: 
  - Add/edit/delete test cases
  - Import from problem samples
  - Save test suites per problem

**Code Templates**
- 📄 **Custom Templates**: Define your starter code for each language
- ⚡ **Quick Start**: One-tap new file creation with your template
- 🔄 **Sync Across**: Templates persist and sync via iCloud

### 📊 Personal Statistics Dashboard

**User Profile**
- 👤 **Codeforces Integration**: Automatic data sync via handle binding
- 🎖️ **Rank Badges**: Visual display of your rating tier with color coding
  - Newbie (Gray) → Legendary Grandmaster (Red)
- 📈 **Rating Chart**: Beautiful line chart showing your rating history over time

**Visual Analytics**
- 🔥 **Activity Heatmap**: GitHub-style contribution calendar
  - Color intensity based on submissions and AC count
  - Interactive: tap any day to view details
- 📊 **Difficulty Distribution**: Bar chart showing solved problems by rating
- 🥧 **Tag Analysis**: Pie chart visualizing your strengths
  - See which topics you've practiced most
  - Identify knowledge gaps

**Submission History**
- 📜 **Recent Activity**: View your latest submissions with verdicts
- 🏆 **Contest Participation**: Track contest performance
- 📅 **Timeline View**: Chronological submission history

**Smart Settings**
- 🎨 **Theme Selection**: Light, Dark, or System Auto
- 📝 **Code Template Editor**: Customize templates for C++, Python, Java
- 🤖 **AI Model Management**: 
  - Add multiple translation models
  - Test API connectivity before use
  - Switch between models easily
- ⚙️ **Judge0 Configuration**:
  - Choose between Public API, RapidAPI, or Custom Instance
  - Separate API key storage for different providers
  - Real-time API status and health checks

### 📚 Integrated OI Wiki

- 🌐 **Full Wiki Browser**: Access [OI-Wiki.org](https://oi-wiki.org) without leaving the app
- 🔍 **Navigation Controls**: Back/Forward, Refresh, Home
- 🌙 **Dark Mode Support**: Synchronized with app theme
- 💾 **Offline Cache**: Previously viewed pages available offline

---

## 🚀 Installation

### Prerequisites

- **macOS**: 14.0+ (Sonoma or later)
- **Xcode**: 15.0+
- **iOS Device/Simulator**: iOS 17.0+
- **Swift**: 5.9+

### Quick Start

#### For macOS Users

1. **Install Xcode**
   ```bash
   # Install from Mac App Store or download from:
   # https://developer.apple.com/xcode/
   ```

2. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/CfEditor.git
   cd CfEditor
   ```

3. **Open the Project**
   ```bash
   open CfEditor.xcodeproj
   ```

4. **Resolve Dependencies**
   - Xcode will automatically download dependencies via Swift Package Manager
   - If needed: `File` → `Packages` → `Update to Latest Package Versions`

#### Install on Physical iPhone

1. **Connect iPhone**: Plug your iPhone into your Mac via USB
2. **Trust Computer**: Tap "Trust" on your iPhone when prompted
3. **Configure Code Signing**:
   - Select the project (blue icon) in Xcode's navigator
   - Select the **CfEditor** target
   - Go to **Signing & Capabilities** tab
   - Enable **"Automatically manage signing"**
   - Select your **Team** (Apple ID works for free developer accounts)
4. **Select Device**: Choose your iPhone from the device dropdown in Xcode's toolbar
5. **Build & Run**: Press `⌘R` or click the ▶️ button
6. **Trust Developer** (First time only):
   - On iPhone: `Settings` → `General` → `VPN & Device Management`
   - Tap your Apple ID → **Trust**

**Free Developer Account Notes:**
- Apps expire after 7 days and need to be re-installed
- Limited to 3 apps installed simultaneously
- For permanent installation, join [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)

#### Using iOS Simulator (No iPhone Required)

1. Select any iOS Simulator from Xcode's device menu (e.g., "iPhone 15 Pro")
2. Press `⌘R` to build and run
3. The app launches in the simulator automatically

### First Launch Setup

1. **Launch the App** → Navigate to the **"Me"** tab
2. **Bind Account** (Optional but recommended):
   - Enter your Codeforces handle
   - Or tap "Login with Browser" to authenticate
3. **Configure Judge0** (Optional):
   - Tap **"Settings"** → **"Judge0 Configuration"**
   - Choose your preferred API type (Public/RapidAPI/Custom)
   - Add API key if using RapidAPI or authenticated custom instance
4. **Configure AI Translation** (Optional):
   - Tap **"Settings"** → **"Translation AI Models"**
   - Add your OpenAI-compatible API endpoint
   - Test the connection
5. **Start Coding!** 🎉

---

## 📱 Project Architecture

```
CfEditor/
├── api/                           # Networking & External APIs
│   ├── CFAPI.swift               # Codeforces API wrapper
│   ├── AITranslator.swift        # AI translation engine (streaming)
│   └── api.swift                 # Shared API utilities
│
├── contests/                      # Contest & Problem Module
│   ├── ContestsStore.swift       # Contest data management & state
│   ├── ProblemsetStore.swift     # Problemset data & filtering logic
│   ├── ProblemParser*.swift      # HTML parsing & LaTeX extraction (6 files)
│   ├── ProblemStatementView.swift # Problem viewer UI
│   ├── ProblemCache.swift        # Local problem caching (7-day)
│   ├── TranslationCache.swift    # Translation persistence
│   ├── LatexRenderedTextView.swift # Math formula rendering
│   ├── FavoritesManager.swift    # Bookmarked problems
│   └── ContestFilterView.swift   # Filter UI components
│
├── editor/                        # Code Editor Module
│   ├── CodeEditorView.swift      # Main editor interface
│   ├── MonacoEditorView.swift    # Monaco editor WebView bridge
│   ├── FilesBrowserView.swift    # File system browser
│   ├── RunSheetView.swift        # Test execution panel
│   ├── TestCase.swift            # Test case data model
│   ├── DocumentPicker.swift      # System file picker integration
│   └── SettingsSheetView.swift   # Editor settings UI
│
├── profile/                       # User Profile Module
│   ├── ProfileView.swift         # Main profile page
│   ├── ProfileSettingsView.swift # App settings (theme, templates, AI)
│   ├── ProfileViewData.swift     # Data fetching & API calls
│   ├── ProfileViewCharts.swift   # Rating & statistics charts
│   ├── HeatmapView.swift         # GitHub-style activity heatmap
│   ├── TagPieChartView.swift     # Tag distribution visualization
│   └── BindCFAccountView.swift   # Handle binding interface
│
├── models/                        # Data Models
│   ├── AppTheme.swift            # Theme system (Light/Dark/System)
│   └── CodeTemplate.swift        # Code template management
│
├── network/                       # Network Services
│   ├── Judge0Client.swift        # Code execution API client
│   └── Judge0Config.swift        # Judge0 configuration management
│
├── oiwiki/                        # OI Wiki Integration
│   └── OIWikiView.swift          # Wiki browser view
│
├── debug/                         # Development Tools
│   └── DebugPerformanceView.swift # Performance profiling
│
└── others/                        # Core & Shared
    ├── CfEditorApp.swift         # App entry point & lifecycle
    ├── WebView.swift             # Reusable WebView wrapper
    ├── CFCookieBridge.swift      # Cookie sync (WebView ↔ URLSession)
    ├── SafariView.swift          # In-app Safari browser
    └── Assets.xcassets/          # App icon & image assets
```

### Tech Stack

| Component | Technology |
|-----------|-----------|
| **UI Framework** | SwiftUI + UIKit Interop |
| **Data Persistence** | SwiftData + UserDefaults + FileManager |
| **Networking** | URLSession with async/await |
| **Code Editor** | Monaco Editor (WebView bridge) |
| **Charts & Graphs** | Swift Charts Framework |
| **Image Loading** | Kingfisher (lazy loading + cache) |
| **Math Rendering** | Custom LaTeX parser + AttributedString |
| **Cookie Management** | WKWebView + HTTPCookieStorage sync |
| **Code Execution** | Judge0 REST API |
| **AI Translation** | OpenAI-compatible streaming API |

---

## 🔧 Configuration

### 1. Judge0 Code Execution

The app supports three Judge0 configuration modes, easily switchable via in-app settings:

#### **In-App Configuration** (Recommended):

1. Open app → **"Me"** tab → **"Settings"** → **"Judge0 Configuration"**
2. Select your preferred API type:
   - **🌐 Public API**: Free tier at `ce.judge0.com` (no API key required)
   - **⚡ RapidAPI**: Premium service with higher rate limits
   - **🔧 Custom Instance**: Self-hosted or third-party Judge0 server

#### **Configuration Options**:

**Option 1: Public API (Default)**
- No configuration needed
- Free tier with reasonable rate limits
- Perfect for learning and practice
- URL: `https://ce.judge0.com`

**Option 2: RapidAPI**
1. Get your API key from [RapidAPI Judge0 CE](https://rapidapi.com/judge0-official/api/judge0-ce)
2. In settings, select **"RapidAPI"**
3. Enter your **X-RapidAPI-Key**
4. The app automatically uses: `https://judge0-ce.p.rapidapi.com`

**Option 3: Custom Instance**
1. Deploy your own Judge0 server (see [Judge0 Docs](https://github.com/judge0/judge0))
2. In settings, select **"Custom"**
3. Enter your **API URL** (e.g., `https://your-server.com`)
4. Optionally add an **API Key** if authentication is required

#### **Key Features**:
- ✅ **Independent API Keys**: RapidAPI key and Custom instance key are stored separately
- ✅ **Easy Switching**: Change providers without losing configuration
- ✅ **Persistent Storage**: Settings saved automatically via UserDefaults
- ✅ **Real-time Display**: Current active API shown in settings

### 2. AI Translation Setup

**In-App Configuration** (Recommended):
1. Open app → **"Me"** tab → **"Settings"**
2. Scroll to **"Translation AI Models"**
3. Tap **"Add"** and configure:
   - **Model Name**: Display name (e.g., "GPT-4o Mini")
   - **Model**: Model ID (e.g., `gpt-4o-mini`, `claude-3-sonnet`, `qwen2.5:14b`)
   - **API Endpoint**: Full URL to `/v1/chat/completions`
   - **API Key**: Your API key (optional for some proxies)

**Supported APIs**:
- ✅ OpenAI (GPT-3.5, GPT-4, GPT-4o)
- ✅ Anthropic Claude (via proxy)
- ✅ Local Ollama (`http://localhost:11434/v1/chat/completions`)
- ✅ OpenRouter, Together AI, or any OpenAI-compatible proxy

**Example Endpoints**:
```
OpenAI:       https://api.openai.com/v1/chat/completions
Ollama:       http://localhost:11434/v1/chat/completions
OpenRouter:   https://openrouter.ai/api/v1/chat/completions
Custom Proxy: https://your-proxy.com/v1/chat/completions
```

**Testing**: Use the built-in **"Test API"** button to verify connectivity before use.

### 3. Theme Customization

Three theme modes available:
- **浅色 (Light)**: Force light mode
- **深色 (Dark)**: Force dark mode  
- **跟随系统 (System)**: Auto-switch based on iOS settings

Change in: **"Me"** → **"Settings"** → **"主题"**

### 4. Code Templates

Customize your default code for each language:

1. **"Me"** → **"Settings"** → **"Code Templates"**
2. Select a language (C++, Python, Java)
3. Edit the template
4. Save (syncs via UserDefaults)

**Default C++ Template**:
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

## 🎯 Key Features Deep Dive

### Advanced Problem Parsing

**HTML to Structured Data**:
```swift
// Extracts from Codeforces HTML:
struct ProblemStatement {
    let name: String
    let timeLimit: String
    let memoryLimit: String
    let statement: [ContentElement]      // Mixed text + LaTeX
    let inputSpec: [ContentElement]
    let outputSpec: [ContentElement]
    let sampleTests: [SampleTest]
    let note: [ContentElement]?
}
```

**LaTeX Rendering**:
- Inline: `$O(n \log n)$` → O(n log n)
- Block: `$$\sum_{i=1}^{n} i = \frac{n(n+1)}{2}$$`
- Preserves math symbols, subscripts, fractions, Greek letters
- Protects LaTeX during AI translation

### Smart Cookie Synchronization

**Seamless Login**:
```swift
// Automatically syncs Codeforces cookies between:
// 1. WKWebView (used in OI Wiki and problem viewer)
// 2. URLSession (used for API calls)
// 3. UserDefaults (persistent handle storage)

// This enables:
// - Login once in web view → API calls authenticated
// - No repeated login prompts
// - Consistent session across app restarts
```

### Intelligent Progress Tracking

**Real-Time Status Sync**:
- Fetches your submissions via Codeforces API
- Marks problems: ✅ AC (green), 🟡 Attempted (yellow), ⚪ Unsolved
- Updates when you switch contests or refresh
- Cached locally for instant display

### Streaming AI Translation

**Paragraph-by-Paragraph**:
```swift
// Instead of waiting for entire translation:
// 1. Split problem into paragraphs
// 2. Translate each paragraph independently
// 3. Display results as they arrive (streaming UI update)
// 4. Continue on error (partial translation better than nothing)
```

**Benefits**:
- ⚡ Faster perceived speed (see results immediately)
- 🛡️ Error resilient (one failed paragraph doesn't break all)
- 🧮 LaTeX-safe (formulas protected with placeholders)

### Performance Optimizations

| Feature | Optimization |
|---------|--------------|
| **LaTeX Rendering** | Rendered formulas cached in memory |
| **Problem Loading** | 7-day disk cache (JSON) |
| **API Calls** | Debounced, with concurrent request limits |
| **Translations** | Permanent cache with model version tracking |
| **Images** | Kingfisher disk+memory cache, lazy loading |
| **Large Lists** | LazyVStack with pagination |
| **Data Sync** | async/await prevents UI blocking |

---

## 🐛 Troubleshooting

### Build Issues

**"Failed to resolve dependencies"**:
```bash
# In Xcode: File → Packages → Reset Package Caches
# Then: File → Packages → Update to Latest Package Versions
```

**"Code signing error"**:
- Ensure you've selected a Team in Signing & Capabilities
- Free Apple IDs work fine (no paid developer account needed)

### Runtime Issues

**"Translation not working"**:
- Verify API endpoint URL includes full path: `/v1/chat/completions`
- Check API key is correct (test with built-in Test button)
- Ensure model name matches your provider's model ID

**"Problems not loading"**:
- Check internet connection
- Pull to refresh on Contests/Problemset tab
- Clear cache: Settings → Problem Cache Settings → Clear All

**"Code execution failed"**:
- **Check Configuration**: Go to Settings → Judge0 Configuration
  - Verify correct API type is selected
  - For RapidAPI: Ensure your API key is entered correctly
  - For Custom: Verify URL is accessible and includes protocol (https://)
- **Test Connectivity**: 
  - Public API: Visit https://ce.judge0.com in browser
  - RapidAPI: Check your quota on RapidAPI dashboard
  - Custom: Ping your server or check health endpoint
- **Code Issues**:
  - Check if code has syntax errors
  - Ensure test input format matches expected format
  - Verify language ID matches your code (C++17, Python3, etc.)
- **Rate Limits**: If using free tier, you may hit rate limits during peak hours

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

### Ways to Contribute

- 🐛 **Report Bugs**: Open an issue with reproduction steps
- ✨ **Suggest Features**: Describe your idea in an issue
- 💻 **Submit Code**: Fork → Create branch → Pull request
- 📖 **Improve Docs**: Fix typos, add examples, clarify instructions
- 🌐 **Translations**: Add support for more languages

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Commit** your changes:
   ```bash
   git commit -m "Add amazing feature"
   ```
4. **Push** to your fork:
   ```bash
   git push origin feature/amazing-feature
   ```
5. **Open** a Pull Request with:
   - Clear description of changes
   - Screenshots (if UI changes)
   - Test cases (if applicable)

### Code Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use `// MARK: -` for section organization
- Add comments for complex logic
- Test in both Light and Dark modes
- Ensure iPad and iPhone compatibility

---

## 🙏 Acknowledgments

This project wouldn't be possible without these amazing resources:

- [**Codeforces**](https://codeforces.com) - API access and problem database
- [**OI Wiki**](https://oi-wiki.org) - Comprehensive competitive programming knowledge
- [**Judge0**](https://judge0.com) - Code execution infrastructure
- [**Monaco Editor**](https://microsoft.github.io/monaco-editor/) - VS Code's editor engine
- [**Kingfisher**](https://github.com/onevcat/Kingfisher) - Efficient image loading
- [**OpenAI**](https://openai.com) & [**Anthropic**](https://anthropic.com) - AI translation capabilities

Special thanks to the competitive programming community for inspiration and feedback.

---

## 📮 Contact

**Author**: Boxiang Zhao (赵勃翔)

- 📧 **Email**: [2750437093@qq.com](mailto:2750437093@qq.com)
- 💬 **Issues**: [GitHub Issues](https://github.com/yourusername/CfEditor/issues)

For bug reports, feature requests, or general questions, feel free to open an issue or send an email.

---


<div align="center">

**⭐ Star this repo if you find it helpful!**

**Built with ❤️ for the Competitive Programming Community**

[Report Bug](https://github.com/yourusername/CfEditor/issues) • [Request Feature](https://github.com/yourusername/CfEditor/issues) • [Documentation](https://github.com/yourusername/CfEditor/wiki)

</div>
