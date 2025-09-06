import SwiftUI
import WebKit

/// 支持LaTeX渲染的文本显示组件
struct LatexRenderedTextView: View {
    let text: String
    let fontSize: CGFloat
    @State private var contentHeight: CGFloat = 50
    @State private var isStable: Bool = false
    
    init(_ text: String, fontSize: CGFloat = 16) {
        self.text = text
        self.fontSize = fontSize
    }
    
    var body: some View {
        LatexWebView(text: text, fontSize: fontSize, contentHeight: $contentHeight, isStable: $isStable)
            .frame(height: contentHeight)
            .id("\(text.hashValue)-\(fontSize)") // 稳定的ID，避免不必要的WebView重创建
            .animation(.easeOut(duration: 0.2), value: contentHeight) // 平滑的高度变化动画
            .opacity(isStable ? 1.0 : 0.8) // 渲染完成前稍微透明
    }
}

/// 内部WebView组件
private struct LatexWebView: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    @Binding var contentHeight: CGFloat
    @Binding var isStable: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let userController = WKUserContentController()
        userController.add(context.coordinator, name: "heightChange")
        config.userContentController = userController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.backgroundColor = UIColor.clear
        webView.isOpaque = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // 生成内容哈希，避免重复渲染相同内容
        let contentKey = "\(text.hashValue)-\(fontSize)"
        let currentContentKey = context.coordinator.lastContentKey
        
        // 只有当内容真正变化时才重新渲染
        if contentKey != currentContentKey {
            context.coordinator.lastContentKey = contentKey
            context.coordinator.isLoading = true
            context.coordinator.parent = self  // 更新parent引用
            isStable = false  // 标记为不稳定状态
            
            // 添加延迟，确保WebView完全初始化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let html = self.generateHTML()
                webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }
    
    private func generateHTML() -> String {
        // 改进的文本处理：正确处理数学公式和换行
        var processedText = preprocessLatexText(text)
        
        // 保护LaTeX公式不被HTML转义
        var mathPlaceholders: [String: String] = [:]
        var placeholderIndex = 0
        
        // 保护块级数学公式 $$...$$
        let displayMathPattern = #"\$\$([^$]+)\$\$"#
        let displayMathRegex = try! NSRegularExpression(pattern: displayMathPattern, options: [])
        let displayMatches = displayMathRegex.matches(in: processedText, options: [], range: NSRange(location: 0, length: processedText.count))
        
        for match in displayMatches.reversed() {
            let placeholder = "DISPLAYMATH_PLACEHOLDER_\(placeholderIndex)"
            let mathContent = String(processedText[Range(match.range, in: processedText)!])
            mathPlaceholders[placeholder] = mathContent
            processedText = (processedText as NSString).replacingCharacters(in: match.range, with: placeholder)
            placeholderIndex += 1
        }
        
        // 保护内联数学公式 $...$
        let inlineMathPattern = #"\$([^$\n]+)\$"#
        let inlineMathRegex = try! NSRegularExpression(pattern: inlineMathPattern, options: [])
        let inlineMatches = inlineMathRegex.matches(in: processedText, options: [], range: NSRange(location: 0, length: processedText.count))
        
        for match in inlineMatches.reversed() {
            let placeholder = "INLINEMATH_PLACEHOLDER_\(placeholderIndex)"
            let mathContent = String(processedText[Range(match.range, in: processedText)!])
            mathPlaceholders[placeholder] = mathContent
            processedText = (processedText as NSString).replacingCharacters(in: match.range, with: placeholder)
            placeholderIndex += 1
        }
        
        // 保护 LaTeX 公式 \(...\)
        let latexInlinePattern = #"\\[\(]([^)]+)\\[\)]"#
        let latexInlineRegex = try! NSRegularExpression(pattern: latexInlinePattern, options: [])
        let latexInlineMatches = latexInlineRegex.matches(in: processedText, options: [], range: NSRange(location: 0, length: processedText.count))
        
        for match in latexInlineMatches.reversed() {
            let placeholder = "LATEXINLINE_PLACEHOLDER_\(placeholderIndex)"
            let mathContent = String(processedText[Range(match.range, in: processedText)!])
            mathPlaceholders[placeholder] = mathContent
            processedText = (processedText as NSString).replacingCharacters(in: match.range, with: placeholder)
            placeholderIndex += 1
        }
        
        // 保护 LaTeX 公式 \[...\]
        let latexDisplayPattern = #"\\[\[]([^\]]+)\\[\]]"#
        let latexDisplayRegex = try! NSRegularExpression(pattern: latexDisplayPattern, options: [])
        let latexDisplayMatches = latexDisplayRegex.matches(in: processedText, options: [], range: NSRange(location: 0, length: processedText.count))
        
        for match in latexDisplayMatches.reversed() {
            let placeholder = "LATEXDISPLAY_PLACEHOLDER_\(placeholderIndex)"
            let mathContent = String(processedText[Range(match.range, in: processedText)!])
            mathPlaceholders[placeholder] = mathContent
            processedText = (processedText as NSString).replacingCharacters(in: match.range, with: placeholder)
            placeholderIndex += 1
        }
        
        // HTML转义前进行数学表达式的智能识别和转换
        // 转换常见的数学变量下标格式（只在非数学环境中）
        
        // 保护现有的等式和数学表达式不被重复处理
        var mathExpPlaceholders: [String: String] = [:]
        var mathExpIndex = 0
        
        // 保护等式表达式 (如 s_i = 1, i = 3)
        let equationPattern = #"([a-zA-Z]_[a-zA-Z0-9]+\s*=\s*[0-9]+)"#
        let equationRegex = try! NSRegularExpression(pattern: equationPattern, options: [])
        let equationMatches = equationRegex.matches(in: processedText, options: [], range: NSRange(location: 0, length: processedText.count))
        
        for match in equationMatches.reversed() {
            let placeholder = "EQUATION_PLACEHOLDER_\(mathExpIndex)"
            let equation = String(processedText[Range(match.range, in: processedText)!])
            // 将等式包装为数学公式
            mathExpPlaceholders[placeholder] = "$\(equation)$"
            processedText = (processedText as NSString).replacingCharacters(in: match.range, with: placeholder)
            mathExpIndex += 1
        }
        
        // 转换单独的下标变量 (如 p2, p3, s_i 等)
        let subscriptPattern = #"(\b[a-zA-Z](?:_[a-zA-Z0-9]+|\d+)\b)"#
        let subscriptRegex = try! NSRegularExpression(pattern: subscriptPattern, options: [])
        let subscriptMatches = subscriptRegex.matches(in: processedText, options: [], range: NSRange(location: 0, length: processedText.count))
        
        for match in subscriptMatches.reversed() {
            let placeholder = "SUBSCRIPT_PLACEHOLDER_\(mathExpIndex)"
            var variable = String(processedText[Range(match.range, in: processedText)!])
            
            // 如果是数字下标格式 (如 p2 -> p_2)，先转换
            if let numberMatch = variable.range(of: #"^([a-zA-Z])(\d+)$"#, options: .regularExpression) {
                variable = variable.replacingOccurrences(
                    of: #"^([a-zA-Z])(\d+)$"#,
                    with: "$1_$2",
                    options: .regularExpression
                )
            }
            
            // 将变量包装为数学公式
            mathExpPlaceholders[placeholder] = "$\(variable)$"
            processedText = (processedText as NSString).replacingCharacters(in: match.range, with: placeholder)
            mathExpIndex += 1
        }
        
        // 转换区间表示法 [l, r], [l,...,r]
        let intervalPattern = #"\[([a-zA-Z0-9_]+)(?:,\.\.\.?,|,\s*)([a-zA-Z0-9_]+)\]"#
        let intervalRegex = try! NSRegularExpression(pattern: intervalPattern, options: [])
        processedText = intervalRegex.stringByReplacingMatches(
            in: processedText,
            options: [],
            range: NSRange(location: 0, length: processedText.count),
            withTemplate: "$[$1, $2$]"
        )
        
        // HTML转义
        processedText = processedText
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        
        // 处理换行：双换行变成段落，单换行变成<br/>
        let paragraphs = processedText.components(separatedBy: "\n\n")
        processedText = paragraphs.map { paragraph in
            let lines = paragraph.components(separatedBy: "\n")
            return "<p>" + lines.joined(separator: "<br/>") + "</p>"
        }.joined(separator: "\n")
        
        // 恢复数学公式
        for (placeholder, mathContent) in mathPlaceholders {
            processedText = processedText.replacingOccurrences(of: placeholder, with: mathContent)
        }
        
        // 恢复新识别的数学表达式
        for (placeholder, mathContent) in mathExpPlaceholders {
            processedText = processedText.replacingOccurrences(of: placeholder, with: mathContent)
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: \(fontSize)px;
                    line-height: 1.6;
                    margin: 0;
                    padding: 12px;
                    background: transparent;
                    color: #333;
                    text-align: left;
                    text-rendering: optimizeLegibility;
                    -webkit-font-smoothing: antialiased;
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }
                
                @media (prefers-color-scheme: dark) {
                    body {
                        color: #fff;
                    }
                    mjx-container[jax="CHTML"], .MathJax, .MathJax_Display {
                        color: #fff !important;
                    }
                }
                
                /* MathJax 样式优化 */
                mjx-container .mjx-script,
                mjx-container [class*="mjx-script"],
                .MJXc-script {
                    font-size: 0.9em !important;
                }
                
                mjx-container .mjx-math {
                    font-weight: 500;
                }
                
                mjx-container[jax="CHTML"],
                .MathJax,
                .MathJax_Display {
                    color: inherit;
                }
                
                /* 内联数学公式 */
                mjx-container[jax="CHTML"][display="false"] {
                    display: inline-block;
                    margin: 0 2px;
                    vertical-align: baseline;
                }
                
                /* 块级数学公式 */
                mjx-container[jax="CHTML"][display="true"] {
                    display: block;
                    margin: 0.8em 0;
                    text-align: left;  /* 左对齐，避免居中计算延迟 */
                    max-width: 100%;
                    overflow-x: auto;
                }
                
                /* 段落样式 */
                p {
                    margin: 0.5em 0;
                    line-height: 1.6;
                    text-align: left;
                }
                
                p:first-child {
                    margin-top: 0;
                }
                
                p:last-child {
                    margin-bottom: 0;
                }
                
                /* 强调文本 */
                strong, b {
                    font-weight: 600;
                }
                
                /* 斜体文本 */
                em, i {
                    font-style: italic;
                }
                
                /* 修复空段落 */
                p:empty {
                    display: none;
                }
                
                /* 提升渲染稳定性 */
                #content {
                    min-height: 20px;
                    contain: layout style;  /* CSS Containment 优化 */
                }
                
                /* 防止MathJax重新布局导致的闪烁 */
                mjx-container {
                    will-change: auto;
                    transform: translateZ(0);  /* 硬件加速 */
                    max-width: 100% !important;
                }
                
                /* 彻底修复圆形框架显示异常 - 超强修复 */
                mjx-container,
                mjx-container *,
                mjx-math,
                mjx-math *,
                mjx-assistive-mml,
                mjx-assistive-mml *,
                [role="presentation"],
                [role="presentation"] *,
                [data-mml-node],
                [data-mml-node] *,
                .MathJax,
                .MathJax *,
                .MathJax_Display,
                .MathJax_Display *,
                [tabindex],
                [tabindex] * {
                    border: none !important;
                    outline: none !important;
                    box-shadow: none !important;
                    background: transparent !important;
                    box-sizing: content-box !important;
                    border-radius: 0 !important;
                }
                
                /* 完全隐藏辅助元素和菜单元素 */
                mjx-assistive-mml,
                mjx-assistive-mml *,
                [aria-hidden="true"][role="presentation"],
                .MathJax_Error,
                .MathJax_Processing,
                .MathJax_MenuFrame,
                .MathJax_Menu,
                mjx-menu {
                    display: none !important;
                    visibility: hidden !important;
                    opacity: 0 !important;
                    width: 0 !important;
                    height: 0 !important;
                    position: absolute !important;
                    left: -9999px !important;
                    top: -9999px !important;
                }
                
                /* 移除所有可能的交互和焦点样式 */
                mjx-container:focus,
                mjx-container:hover,
                mjx-container:active,
                mjx-math:focus,
                mjx-math:hover, 
                mjx-math:active,
                [tabindex]:focus,
                [tabindex]:hover,
                [tabindex]:active,
                mjx-container *:focus,
                mjx-container *:hover,
                mjx-container *:active {
                    outline: none !important;
                    border: none !important;
                    box-shadow: none !important;
                    background: transparent !important;
                    border-radius: 0 !important;
                }
                
                /* 确保数学元素不可交互，避免触发辅助功能 */
                mjx-container,
                mjx-math,
                mjx-container *,
                mjx-math * {
                    pointer-events: none !important;
                    user-select: none !important;
                    -webkit-user-select: none !important;
                    -moz-user-select: none !important;
                    -ms-user-select: none !important;
                    -webkit-touch-callout: none !important;
                    -webkit-tap-highlight-color: transparent !important;
                }
                
                /* 强制移除任何动态添加的圆形边框样式 */
                *[style*="border-radius"],
                *[style*="border"],
                *[style*="outline"],
                *[style*="box-shadow"] {
                    border: none !important;
                    outline: none !important;
                    border-radius: 0 !important;
                    box-shadow: none !important;
                }
                
                /* 防止文本溢出 */
                * {
                    box-sizing: border-box;
                }
            </style>
        </head>
        <body>
            <div id="content" style="white-space: pre-wrap;">\(processedText)</div>
            
            <script>
                // 优化 MathJax 配置：更快的加载和渲染
                window.MathJax = {
                    tex: {
                        inlineMath: [
                            ['\\\\(', '\\\\)'],
                            ['$', '$']
                        ],
                        displayMath: [
                            ['\\\\[', '\\\\]'],
                            ['$$', '$$']
                        ],
                        processEscapes: true,
                        processEnvironments: true,
                        packages: {
                            '[+]': ['base', 'ams', 'color', 'boldsymbol', 'newcommand']
                        }
                    },
                    options: {
                        skipHtmlTags: ['script', 'style', 'textarea', 'pre', 'code'],
                        ignoreHtmlClass: 'tex2jax_ignore',
                        processHtmlClass: 'tex2jax_process',
                        renderActions: {
                            addMenu: [0, '', ''],          // 禁用右键菜单
                            assistiveMml: [0, '', ''],     // 禁用辅助MML
                            complexity: [0, '', ''],       // 禁用复杂度检查
                            a11y: [0, '', '']              // 禁用辅助功能
                        },
                        enableAssistiveMml: false,         // 完全禁用辅助功能
                        enableMenu: false,                 // 禁用菜单
                        enableExplorer: false,             // 禁用表达式浏览器
                        enableEnrichment: false,           // 禁用富化功能
                        enableComplexity: false,           // 禁用复杂度功能
                        menuOptions: {
                            settings: {
                                assistiveMml: false,
                                collapsible: false,
                                autocollapse: false,
                                explorer: false
                            }
                        }
                    },
                    chtml: {
                        mtextInheritFont: true,
                        displayAlign: 'left',  // 左对齐，避免居中计算延迟
                        displayIndent: '2em',
                        fontURL: 'https://polyfill.io/v3/polyfill.min.js?features=es6'  // 使用更快的CDN
                    },
                    startup: {
                        ready: function () {
                            console.log('MathJax ready, initializing...');
                            MathJax.startup.defaultReady();
                            
                            // 标记MathJax已准备就绪
                            window.mathJaxReady = true;
                            
                            // 延迟一下确保DOM完全准备好，然后触发渲染
                            setTimeout(() => {
                                console.log('MathJax startup complete, triggering typeset');
                                if (typeof typesetAndUpdateHeight === 'function') {
                                    typesetAndUpdateHeight();
                                } else {
                                    // 如果函数还没定义，等待一下
                                    setTimeout(() => {
                                        if (typeof typesetAndUpdateHeight === 'function') {
                                            typesetAndUpdateHeight();
                                        } else {
                                            updateHeight();
                                        }
                                    }, 200);
                                }
                            }, 150);
                        }
                    }
                };
                
                // 改进的MathJax加载机制 - 防止状态异常
                function loadMathJaxWithFallback() {
                    // 检查是否已经加载过MathJax
                    if (window.MathJax && window.MathJax.typesetPromise) {
                        console.log('MathJax already loaded, clearing any pending state...');
                        // 清理可能存在的渲染状态异常
                        clearMathJaxState();
                        setTimeout(() => {
                            typesetAndUpdateHeight();
                        }, 100);
                        return;
                    }
                    
                    // 检查是否正在加载MathJax
                    if (window.mathJaxLoading) {
                        console.log('MathJax is loading, waiting...');
                        const checkInterval = setInterval(() => {
                            if (window.MathJax && window.MathJax.typesetPromise) {
                                clearInterval(checkInterval);
                                clearMathJaxState();
                                setTimeout(() => {
                                    typesetAndUpdateHeight();
                                }, 100);
                            }
                        }, 200);
                        // 10秒超时
                        setTimeout(() => {
                            clearInterval(checkInterval);
                            if (!window.MathJax || !window.MathJax.typesetPromise) {
                                console.warn('MathJax loading timeout, updating height without math');
                                updateHeight();
                            }
                        }, 10000);
                        return;
                    }
                    
                    // 标记正在加载
                    window.mathJaxLoading = true;
                    
                    var script = document.createElement('script');
                    script.async = true;
                    
                    script.onload = function() {
                        console.log('MathJax script loaded successfully');
                        window.mathJaxLoading = false;
                    };
                    
                    // 主CDN加载失败的处理
                    script.onerror = function() {
                        console.log('Primary MathJax CDN failed, trying fallback...');
                        window.mathJaxLoading = false;
                        
                        var fallbackScript = document.createElement('script');
                        fallbackScript.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js';
                        fallbackScript.async = true;
                        fallbackScript.onload = function() {
                            console.log('Fallback MathJax loaded');
                        };
                        fallbackScript.onerror = function() {
                            console.error('All MathJax CDNs failed, updating height without math');
                            updateHeight();
                        };
                        document.head.appendChild(fallbackScript);
                    };
                    
                    script.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js';
                    document.head.appendChild(script);
                }
                
                // 彻底清理MathJax状态异常的函数
                function clearMathJaxState() {
                    try {
                        console.log('Performing comprehensive MathJax state cleanup...');
                        
                        // 1. 清理所有可能的数学元素和属性
                        const allMathSelectors = [
                            'mjx-container', 'mjx-math', 'mjx-assistive-mml',
                            '.MathJax', '.MathJax_Display', '.MathJax_Preview',
                            '[data-mml-node]', '[role="presentation"]', '[tabindex]',
                            '[aria-hidden]', 'mjx-menu', '.MathJax_MenuFrame',
                            '.MathJax_Menu', '[data-semantic-type]'
                        ];
                        
                        allMathSelectors.forEach(selector => {
                            try {
                                const elements = document.querySelectorAll(selector);
                                elements.forEach(element => {
                                    // 移除所有可能导致圆形框架的属性
                                    const attributesToRemove = [
                                        'data-mml-node', 'tabindex', 'role', 'aria-hidden',
                                        'aria-label', 'data-semantic-type', 'data-semantic-role',
                                        'data-semantic-id', 'data-semantic-children'
                                    ];
                                    
                                    attributesToRemove.forEach(attr => {
                                        element.removeAttribute(attr);
                                    });
                                    
                                    // 移除问题类名
                                    const classesToRemove = [
                                        'MathJax_Error', 'MathJax_Processing', 'MathJax_Preview'
                                    ];
                                    classesToRemove.forEach(cls => {
                                        element.classList.remove(cls);
                                    });
                                    
                                    // 强制清理所有可能导致圆形框架的样式
                                    const stylesToClear = {
                                        'border': 'none',
                                        'outline': 'none',
                                        'box-shadow': 'none',
                                        'border-radius': '0',
                                        'background': 'transparent',
                                        'pointer-events': 'none',
                                        'user-select': 'none'
                                    };
                                    
                                    Object.entries(stylesToClear).forEach(([prop, value]) => {
                                        element.style.setProperty(prop, value, 'important');
                                    });
                                });
                            } catch (e) {
                                console.warn(`Error processing selector ${selector}:`, e);
                            }
                        });
                        
                        // 2. 特别处理辅助元素 - 完全隐藏
                        const assistiveSelectors = [
                            'mjx-assistive-mml', '[aria-hidden="true"]',
                            '.MathJax_MenuFrame', '.MathJax_Menu', 'mjx-menu'
                        ];
                        
                        assistiveSelectors.forEach(selector => {
                            try {
                                const elements = document.querySelectorAll(selector);
                                elements.forEach(element => {
                                    const hideStyles = {
                                        'display': 'none',
                                        'visibility': 'hidden',
                                        'opacity': '0',
                                        'position': 'absolute',
                                        'left': '-9999px',
                                        'top': '-9999px',
                                        'width': '0',
                                        'height': '0'
                                    };
                                    
                                    Object.entries(hideStyles).forEach(([prop, value]) => {
                                        element.style.setProperty(prop, value, 'important');
                                    });
                                });
                            } catch (e) {
                                console.warn(`Error hiding selector ${selector}:`, e);
                            }
                        });
                        
                        // 3. 扫描并修复所有带边框的元素
                        const allElements = document.querySelectorAll('*');
                        allElements.forEach(element => {
                            const computedStyle = window.getComputedStyle(element);
                            const hasProblematicStyle = 
                                computedStyle.border !== 'none' ||
                                computedStyle.outline !== 'none' ||
                                computedStyle.boxShadow !== 'none' ||
                                computedStyle.borderRadius !== '0px';
                            
                            if (hasProblematicStyle && (
                                element.tagName.toLowerCase().startsWith('mjx') ||
                                element.classList.toString().includes('MathJax') ||
                                element.hasAttribute('data-mml-node') ||
                                element.hasAttribute('role')
                            )) {
                                element.style.setProperty('border', 'none', 'important');
                                element.style.setProperty('outline', 'none', 'important');
                                element.style.setProperty('box-shadow', 'none', 'important');
                                element.style.setProperty('border-radius', '0', 'important');
                            }
                        });
                        
                        // 4. 清理MathJax内部状态
                        if (window.MathJax && window.MathJax.startup && window.MathJax.startup.document) {
                            try {
                                console.log('Clearing MathJax document state');
                                window.MathJax.startup.document.clear();
                                if (window.MathJax.startup.document.clearCache) {
                                    window.MathJax.startup.document.clearCache();
                                }
                            } catch (e) {
                                console.warn('Error clearing MathJax document:', e);
                            }
                        }
                        
                        console.log('Comprehensive MathJax state cleanup completed');
                    } catch (error) {
                        console.error('Error in comprehensive MathJax state cleanup:', error);
                    }
                }
                
                // 开始加载MathJax
                loadMathJaxWithFallback();
                
                // 更新高度函数（优化版）
                function updateHeight() {
                    requestAnimationFrame(() => {
                        try {
                            const content = document.getElementById('content');
                            if (!content) return;
                            
                            // 确保内容已经完全渲染
                            const computedStyle = window.getComputedStyle(content);
                            const height = Math.max(
                                content.scrollHeight,
                                content.offsetHeight,
                                parseInt(computedStyle.height) || 0
                            );
                            
                            const finalHeight = Math.max(height + 20, 50);
                            console.log('Updating height to:', finalHeight);
                            
                            if (window.webkit?.messageHandlers?.heightChange) {
                                window.webkit.messageHandlers.heightChange.postMessage(finalHeight);
                            }
                        } catch (error) {
                            console.error('Height update error:', error);
                            // 回退到最小高度
                            if (window.webkit?.messageHandlers?.heightChange) {
                                window.webkit.messageHandlers.heightChange.postMessage(50);
                            }
                        }
                    });
                }
                
                // 数学公式排版并更新高度（增强版，防止状态异常）
                function typesetAndUpdateHeight() {
                    if (window.MathJax && window.MathJax.typesetPromise) {
                        console.log('Starting MathJax typeset...');
                        
                        // 先清理可能的状态异常
                        clearMathJaxState();
                        
                        // 使用Promise.race添加超时保护
                        const timeoutPromise = new Promise((_, reject) => {
                            setTimeout(() => reject(new Error('Typeset timeout')), 5000);
                        });
                        
                        Promise.race([
                            window.MathJax.typesetPromise([document.getElementById('content')]),
                            timeoutPromise
                        ]).then(() => {
                            console.log('MathJax typeset completed');
                            // 再次清理，确保没有残留的异常状态
                            setTimeout(() => {
                                clearMathJaxState();
                                updateHeight();
                            }, 50);
                        }).catch((error) => {
                            console.warn('MathJax typeset error:', error);
                            // 出错时清理状态并更新高度
                            clearMathJaxState();
                            updateHeight();
                        });
                    } else {
                        console.log('MathJax not ready, updating height without typeset');
                        updateHeight();
                    }
                }
                
                // 更智能的渲染时机：减少不必要的延迟
                let renderAttempts = 0;
                const maxAttempts = 5; // 增加重试次数
                let hasRendered = false;
                
                function smartTypeset() {
                    if (hasRendered) return; // 避免重复渲染
                    
                    renderAttempts++;
                    console.log('Smart typeset attempt:', renderAttempts);
                    
                    // 检查MathJax是否完全准备好
                    if (window.mathJaxReady && window.MathJax && window.MathJax.typesetPromise) {
                        hasRendered = true;
                        console.log('MathJax fully ready, starting typeset');
                        typesetAndUpdateHeight();
                    } else if (window.MathJax && window.MathJax.typesetPromise) {
                        hasRendered = true;
                        console.log('MathJax available but not fully ready, starting typeset anyway');
                        typesetAndUpdateHeight();
                    } else if (renderAttempts < maxAttempts) {
                        // 渐进式延迟：200ms, 500ms, 900ms, 1400ms, 2000ms
                        const delay = 200 + (renderAttempts * renderAttempts * 100);
                        console.log('MathJax not ready, retrying in', delay, 'ms');
                        setTimeout(smartTypeset, delay);
                    } else {
                        // 最终回退到基础高度更新
                        hasRendered = true;
                        console.log('Max attempts reached, updating height without math');
                        updateHeight();
                    }
                }
                
                // 监听DOM内容变化，确保在内容准备好后再渲染
                function waitForContent() {
                    const content = document.getElementById('content');
                    if (content && content.textContent.trim().length > 0) {
                        console.log('Content ready, starting smart typeset');
                        smartTypeset();
                    } else {
                        console.log('Content not ready, waiting...');
                        setTimeout(waitForContent, 50);
                    }
                }
                
                // 主动检查和清理MathJax状态异常
                function periodicStateCheck() {
                    try {
                        let needsCleanup = false;
                        
                        // 1. 检查所有可能的圆形框架元素
                        const problematicSelectors = [
                            'mjx-container[style*="border"]',
                            'mjx-container[style*="outline"]',
                            'mjx-container[style*="box-shadow"]',
                            'mjx-math[style*="border"]',
                            '[role="presentation"][style*="border"]',
                            '[tabindex][style*="outline"]',
                            'mjx-assistive-mml:not([style*="display: none"])',
                            '.MathJax_MenuFrame',
                            '.MathJax_Menu'
                        ];
                        
                        problematicSelectors.forEach(selector => {
                            const elements = document.querySelectorAll(selector);
                            if (elements.length > 0) {
                                console.log(`Found ${elements.length} problematic elements with selector: ${selector}`);
                                needsCleanup = true;
                            }
                        });
                        
                        // 2. 检查计算样式中的问题元素
                        const allMathElements = document.querySelectorAll('mjx-container, mjx-math, [data-mml-node]');
                        allMathElements.forEach(element => {
                            try {
                                const computedStyle = window.getComputedStyle(element);
                                if (computedStyle.border !== 'medium none' && computedStyle.border !== 'none' ||
                                    computedStyle.outline !== 'medium none' && computedStyle.outline !== 'none' ||
                                    computedStyle.boxShadow !== 'none' ||
                                    (computedStyle.borderRadius !== '0px' && computedStyle.borderRadius !== '0')) {
                                    console.log('Found element with problematic computed style:', element.tagName, computedStyle.border, computedStyle.outline);
                                    needsCleanup = true;
                                }
                            } catch (e) {
                                // 忽略样式检查错误
                            }
                        });
                        
                        // 3. 检查错误状态的元素
                        const errorElements = document.querySelectorAll('.MathJax_Error, .MathJax_Processing');
                        if (errorElements.length > 0) {
                            console.log(`Found ${errorElements.length} error elements`);
                            needsCleanup = true;
                        }
                        
                        // 4. 检查是否有可见的辅助元素
                        const visibleAssistive = document.querySelectorAll('mjx-assistive-mml');
                        visibleAssistive.forEach(element => {
                            const computedStyle = window.getComputedStyle(element);
                            if (computedStyle.display !== 'none' || computedStyle.visibility !== 'hidden') {
                                console.log('Found visible assistive element');
                                needsCleanup = true;
                            }
                        });
                        
                        // 5. 如果发现问题，执行清理
                        if (needsCleanup) {
                            console.log('Triggering comprehensive cleanup due to detected issues');
                            clearMathJaxState();
                            
                            // 额外的即时修复
                            setTimeout(() => {
                                const stillProblematic = document.querySelectorAll(problematicSelectors.join(', '));
                                stillProblematic.forEach(element => {
                                    element.style.setProperty('border', 'none', 'important');
                                    element.style.setProperty('outline', 'none', 'important');
                                    element.style.setProperty('box-shadow', 'none', 'important');
                                    element.style.setProperty('border-radius', '0', 'important');
                                });
                            }, 100);
                        }
                        
                    } catch (error) {
                        console.warn('Periodic state check error:', error);
                    }
                }
                
                // 每3秒检查一次状态
                setInterval(periodicStateCheck, 3000);
                
                // 立即执行一次检查
                setTimeout(periodicStateCheck, 1000);
                
                // 监听DOM变化，立即修复新出现的问题元素
                if (typeof MutationObserver !== 'undefined') {
                    const observer = new MutationObserver((mutations) => {
                        let hasNewMathElements = false;
                        
                        mutations.forEach((mutation) => {
                            if (mutation.type === 'childList') {
                                mutation.addedNodes.forEach((node) => {
                                    if (node.nodeType === 1) { // Element node
                                        const element = node;
                                        if (element.tagName && (
                                            element.tagName.toLowerCase().startsWith('mjx') ||
                                            element.classList.contains('MathJax') ||
                                            element.hasAttribute('data-mml-node')
                                        )) {
                                            hasNewMathElements = true;
                                        }
                                        
                                        // 检查子元素
                                        const mathChildren = element.querySelectorAll && 
                                            element.querySelectorAll('mjx-container, mjx-math, .MathJax, [data-mml-node]');
                                        if (mathChildren && mathChildren.length > 0) {
                                            hasNewMathElements = true;
                                        }
                                    }
                                });
                            }
                            
                            // 检查属性变化
                            if (mutation.type === 'attributes' && mutation.target.nodeType === 1) {
                                const element = mutation.target;
                                if (element.tagName.toLowerCase().startsWith('mjx') ||
                                    element.classList.contains('MathJax') ||
                                    element.hasAttribute('data-mml-node')) {
                                    hasNewMathElements = true;
                                }
                            }
                        });
                        
                        if (hasNewMathElements) {
                            console.log('New math elements detected, triggering immediate cleanup');
                            setTimeout(() => {
                                clearMathJaxState();
                                periodicStateCheck();
                            }, 50);
                        }
                    });
                    
                    observer.observe(document.body, {
                        childList: true,
                        subtree: true,
                        attributes: true,
                        attributeFilter: ['style', 'class', 'tabindex', 'role', 'data-mml-node']
                    });
                }
                
                // 等待DOM完全加载后开始
                if (document.readyState === 'loading') {
                    document.addEventListener('DOMContentLoaded', waitForContent);
                } else {
                    waitForContent();
                }
            </script>
        </body>
        </html>
        """
    }
    
    // 预处理LaTeX文本，确保正确性
    private func preprocessLatexText(_ text: String) -> String {
        var processed = text
        
        // 1. 清理可能存在的HTML标签
        processed = processed.replacingOccurrences(of: "<p>", with: "")
        processed = processed.replacingOccurrences(of: "</p>", with: "")
        processed = processed.replacingOccurrences(of: "<br/>", with: "\n")
        processed = processed.replacingOccurrences(of: "<br>", with: "\n")
        
        // 2. 统一数学公式分隔符 - 只在必要时转义
        // 检查是否已经有正确的转义
        if !processed.contains("\\\\(") && processed.contains("\\(") {
            processed = processed.replacingOccurrences(of: "\\(", with: "\\\\(")
        }
        if !processed.contains("\\\\)") && processed.contains("\\)") {
            processed = processed.replacingOccurrences(of: "\\)", with: "\\\\)")
        }
        if !processed.contains("\\\\[") && processed.contains("\\[") {
            processed = processed.replacingOccurrences(of: "\\[", with: "\\\\[")
        }
        if !processed.contains("\\\\]") && processed.contains("\\]") {
            processed = processed.replacingOccurrences(of: "\\]", with: "\\\\]")
        }
        
        // 3. 修复常见的LaTeX转义问题
        processed = processed.replacingOccurrences(of: "\\_", with: "_")
        processed = processed.replacingOccurrences(of: "\\&", with: "&")
        
        return processed
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: LatexWebView
        var lastContentKey: String = ""
        var isLoading: Bool = false
        var lastHeightUpdate: Date = Date()
        
        init(_ parent: LatexWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChange", let height = message.body as? CGFloat {
                // 防抖处理：避免频繁的高度更新
                let now = Date()
                let shouldUpdate = now.timeIntervalSince(lastHeightUpdate) > 0.1 // 100ms 防抖
                
                if shouldUpdate || !isLoading {
                    lastHeightUpdate = now
                    isLoading = false
                    
                    DispatchQueue.main.async {
                        self.parent.contentHeight = max(height, 50)
                        self.parent.isStable = true  // 标记为稳定状态
                    }
                }
            }
        }
    }
}

/// SwiftUI预览
struct LatexRenderedTextView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 测试HTML标签清理
                Group {
                    Text("HTML标签清理测试")
                        .font(.headline)
                    
                    LatexRenderedTextView("""
                    <p>两支足球队，RiOI队与KDOI队，即将展开一场足球比赛。比赛分为上下两个半场——上半场和下半场。比赛开始时，两队比分均为0分。</p>

                    <p>作为两支球队的粉丝，Aquawave深知两队实力相当，因此任何一方都不会在同一半场连续攻入三球。</p>

                    <p>比赛前夜，Aquawave做了一个梦，梦中：</p>

                    <p>上半场比分为a:b，其中a代表RiOI队得分，b代表KDOI队得分。</p>
                    """, fontSize: 16)
                }
                
                // 测试LaTeX公式
                Group {
                    Text("LaTeX公式测试")
                        .font(.headline)
                        
                    LatexRenderedTextView("""
                    在第一个测试案例中，数组 $p=[1,4,3,2]$ 是一个有效的答案，因为：

                    唯一满足 $s_i = 1$ 的位置是 $i = 3$。存在三个不同的区间 $[l, r]$ 覆盖索引 3，且这些区间的长度至少为 $k = 3$：$[1, 3]$、$[1, 4]$ 和 $[2, 4]$。

                    对于这三个区间中的每一个，$p[l,...,r]$ 中的最大元素应为 $p_2=4$，而不等于 $p_3=3$。
                    """, fontSize: 16)
                }
                
                // 测试混合内容
                Group {
                    Text("混合内容测试")
                        .font(.headline)
                        
                    LatexRenderedTextView("""
                    每个测试包含多个测试用例。第一行输入测试用例的数量 $t$ (1≤t≤1000)。接下来是各个测试用例。

                    对于每个测试用例：
                    - 第一行包含四个整数 $a$、$b$、$c$、$d$
                    - 其中 $0 ≤ a, b, c, d ≤ 100$

                    输出格式：对于每个测试用例，如果Aquawave的梦想能够实现，输出"YES"，否则输出"NO"。
                    """, fontSize: 16)
                }
            }
            .padding()
        }
        .navigationTitle("LaTeX 渲染修复测试")
    }
}
