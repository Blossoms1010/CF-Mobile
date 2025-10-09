# CfEditor

<div align="center">

**A Native iOS/macOS App for Codeforces Competitive Programming**

Powerful Code Editor · Problem Browsing & Practice · Real-time Submission & Testing · Personal Statistics

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-lightgrey.svg)](https://developer.apple.com)

</div>

---

## ✨ Features

### 🏆 Contests & Problemset

- **Contest Browsing**: Real-time access to Codeforces contests with countdown timers
- **Problemset Practice**: Complete problem archive with multi-dimensional filtering
- **Smart Filtering**:
  - Filter by difficulty rating (800-3500)
  - Filter by tags (DP, graphs, math, and 30+ categories)
  - Filter by status (solved, attempted, unsolved)
  - Filter contests by phase (running, upcoming, finished)
- **Favorites**: Bookmark problems for later review
- **Progress Tracking**: Real-time synchronization of your submission status
- **Problem Statement Rendering**:
  - Full HTML rendering with LaTeX math support
  - Automatic image loading
  - AI-powered translation (English to Chinese)
  - Sample test cases with one-click import

### 💻 Code Editor

- **Monaco Editor Integration**: Powered by VS Code's editing engine
  - Syntax highlighting (C++, Python, Java)
  - IntelliSense code completion
  - Code folding and indentation
  - Undo/Redo support
- **Theme Adaptation**: Automatically follows system dark/light mode
- **File Management**:
  - Create, open, and save local code files
  - Built-in file browser for project management
  - Auto-save functionality to prevent data loss
- **Code Execution**:
  - Integrated Judge0 API for online code execution
  - Batch testing with multiple test cases
  - Real-time results (output, errors, runtime, memory usage)
  - One-click import of sample test cases

### 📊 Personal Statistics

- **User Profile**:
  - Codeforces user information display
  - Rating change chart
  - Rank badges and achievements
- **Data Visualization**:
  - GitHub-style heatmap showing daily activity
  - Problem completion statistics by difficulty
  - Tag distribution pie chart for knowledge analysis
- **Submission History**:
  - Recent submissions list
  - Contest participation records
  - Rating change history
- **Account Binding**: Simple Handle input for automatic data synchronization

### 📚 OI Wiki Integration

- Built-in [OI Wiki](https://oi-wiki.org) browser
- Navigation controls (back/forward, refresh, home)
- Dark mode support
- Offline caching

---

## 🚀 Getting Started

### Requirements

- **Xcode**: 15.0+
- **iOS**: 17.0+
- **macOS**: 14.0+ (Sonoma)
- **Swift**: 5.9+

### Dependencies

This project uses Swift Package Manager:

- [Kingfisher](https://github.com/onevcat/Kingfisher) (8.5.0) - High-performance image downloading and caching

### Installation

#### For macOS Users

1. **Install Xcode**
   - Download and install [Xcode](https://apps.apple.com/us/app/xcode/id497799835) from the Mac App Store (requires macOS 14.0+)
   - Launch Xcode and agree to the license terms
   - Wait for Xcode to install additional components

2. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/CfEditor.git
   cd CfEditor
   ```

3. **Open the project**
   - Double-click `CfEditor.xcodeproj` or run:
   ```bash
   open CfEditor.xcodeproj
   ```

4. **Resolve dependencies**
   - Xcode will automatically parse `Package.resolved` and download dependencies
   - If needed, manually update: `File` → `Packages` → `Update to Latest Package Versions`

#### Install on iPhone

**Method 1: Using Simulator (No Physical Device Required)**
1. In Xcode, select a simulator from the device menu (e.g., "iPhone 15 Pro")
2. Press `Cmd + R` or click the ▶️ Run button
3. The app will launch in the iOS Simulator

**Method 2: Install on Physical iPhone**
1. **Connect your iPhone** to your Mac via USB cable
2. **Trust the computer** on your iPhone when prompted
3. **Configure signing** in Xcode:
   - Select the project in the navigator (blue icon at the top)
   - Select the **CfEditor** target
   - Go to **Signing & Capabilities** tab
   - Check **"Automatically manage signing"**
   - Select your **Team** (use your Apple ID - free developer account works fine)
4. **Select your iPhone** as the build target from the device menu in Xcode toolbar
5. **Run the app**: Press `Cmd + R` or click the ▶️ Run button
6. **Trust the developer** on iPhone:
   - Go to iPhone **Settings** → **General** → **VPN & Device Management**
   - Tap on your Apple ID under "Developer App"
   - Tap **Trust**
7. The app should now launch on your iPhone!

**Note for Free Developer Accounts:**
- Apps installed with a free Apple Developer account will expire after 7 days
- You'll need to re-run the app from Xcode to extend the validity
- For permanent installation, consider enrolling in the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year)

### First Launch

1. Launch the app and navigate to the **"Me"** tab
2. Enter your Codeforces Handle and bind your account
3. The app will automatically sync your profile data, submissions, and progress
4. Start your competitive programming journey!

---

## 📱 Project Structure

```
CfEditor/
├── api/                    # API Layer
│   ├── CFAPI.swift        # Codeforces API wrapper
│   ├── AITranslator.swift # AI translation service
│   └── APITests.swift     # API unit tests
├── contests/              # Contests & Problemset Module
│   ├── ContestsStore.swift           # Contest data management
│   ├── ProblemsetStore.swift         # Problemset data management
│   ├── ProblemParser.swift           # Problem statement parser
│   ├── ProblemStatementView.swift    # Problem rendering view
│   ├── LatexRenderedTextView.swift   # LaTeX rendering
│   ├── FavoritesManager.swift        # Favorites management
│   └── ProblemCache.swift            # Problem caching
├── editor/                # Code Editor Module
│   ├── CodeEditorView.swift          # Main editor view
│   ├── MonacoEditorView.swift        # Monaco editor wrapper
│   ├── FilesBrowserView.swift        # File browser
│   ├── RunSheetView.swift            # Code execution panel
│   └── TestCase.swift                # Test case model
├── network/               # Network Layer
│   └── Judge0Client.swift # Judge0 code evaluation client
├── profile/               # Profile Module
│   ├── ProfileView.swift             # Profile page
│   ├── ProfileViewData.swift         # Data fetching
│   ├── ProfileViewCharts.swift       # Chart components
│   ├── HeatmapView.swift             # Activity heatmap
│   └── TagPieChartView.swift         # Tag distribution chart
├── oiwiki/                # OI Wiki Module
│   └── OIWikiView.swift   # Wiki browser
└── others/                # Other Resources
    ├── CfEditorApp.swift  # App entry point
    ├── WebView.swift      # WebView wrapper
    ├── CFCookieBridge.swift # Cookie synchronization
    └── Assets.xcassets/   # App icons and assets
```

### Tech Stack

- **UI Framework**: SwiftUI + UIKit hybrid
- **Data Management**: SwiftData + UserDefaults + @AppStorage
- **Networking**: URLSession + async/await
- **Code Editor**: Monaco Editor (WebView integration)
- **Charts**: Swift Charts
- **Image Loading**: Kingfisher
- **Math Rendering**: LaTeX parsing and rendering

---

## 🔧 Configuration

### Judge0 Configuration

The code execution feature relies on Judge0 API. Default configuration uses the official free service:

```swift
// CfEditor/network/Judge0Client.swift
static var `default`: Config {
    return Config(baseURL: URL(string: "https://ce.judge0.com")!)
}
```

**Custom Configuration**:

If you have a self-hosted Judge0 instance or use RapidAPI:

```swift
// Self-hosted instance
Config(baseURL: URL(string: "https://your-judge0.example.com")!)

// RapidAPI
Config(
    baseURL: URL(string: "https://judge0-ce.p.rapidapi.com")!,
    apiKey: "YOUR_RAPIDAPI_KEY",
    extraHeaders: ["X-RapidAPI-Host": "judge0-ce.p.rapidapi.com"]
)
```

### AI Translation Configuration

Supports OpenAI-compatible API services for problem statement translation:

1. Navigate to **Settings** → **AI Translation** in the app
2. Configure the following parameters:
   - API Endpoint (e.g., `https://api.openai.com/v1/chat/completions`)
   - API Key
   - Model (e.g., `gpt-3.5-turbo`)

**Note**: The translation feature automatically protects LaTeX formulas to ensure they remain intact.

---

## 🎯 Key Features in Detail

### Problem Statement Parsing

The `ProblemParser` module can:
- Extract problem descriptions, input/output formats, and sample data from HTML
- Parse and render LaTeX mathematical formulas (inline `$...$` and block `$$...$$`)
- Handle multiple test case samples
- Automatically detect and cache problem content

### Cookie Synchronization

`CFCookieBridge` implements cookie sync between WKWebView and URLSession:
- Automatically restores Handle from browser login state on app launch
- Real-time updates of local user info when cookies change
- No need for repeated logins, maintains consistent session

### Progress Tracking

Automatically syncs through Codeforces API:
- Accepted (AC) problems marked in green
- Attempted but unsolved problems marked in yellow
- Unsolved problems remain in default state
- Real-time updates without manual refresh

### Performance Optimization

- **LaTeX Caching**: Rendered formulas are cached to avoid redundant computation
- **Problem Caching**: Local persistence of problem content reduces network requests
- **Lazy Loading**: Large lists use pagination for improved scrolling performance
- **Async Data Fetching**: Uses async/await to prevent UI blocking

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!

### Development Workflow

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Standards

- Follow Swift official code style
- Use meaningful variable and function names
- Add comments for complex logic
- Ensure UI works properly in both dark and light modes

---

## 📮 Contact

- **Author**: Zhao Boxiang
- **Email**: [2750437093@qq.com](mailto:2750437093@qq.com)
- **GitHub**: [@yourusername](https://github.com/yourusername)

For bug reports, feature requests, or any questions, feel free to reach out via email!

---

## 🙏 Acknowledgments

- [Codeforces](https://codeforces.com) - API and problem data provider
- [OI Wiki](https://oi-wiki.org) - High-quality competitive programming knowledge base
- [Judge0](https://judge0.com) - Powerful code evaluation engine
- [Monaco Editor](https://microsoft.github.io/monaco-editor/) - VS Code editor core
- [Kingfisher](https://github.com/onevcat/Kingfisher) - Image loading framework

---

## 📸 Screenshots

### Contests & Problemset
- Real-time contest list with countdowns
- Problemset filtering and search
- Problem statement rendering (with LaTeX support)

### Code Editor
- Monaco editor interface
- File management and browsing
- Code execution and testing

### Personal Statistics
- Rating change chart
- Activity heatmap
- Tag distribution statistics

---

<div align="center">

**⭐ If you find this project helpful, please star it!**

Made with ❤️ by Codeforces enthusiasts

</div>
