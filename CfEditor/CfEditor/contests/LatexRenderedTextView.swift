import SwiftUI
import WebKit

/// 支持LaTeX渲染的文本显示组件
struct LatexRenderedTextView: View {
    let text: String
    let fontSize: CGFloat
    @State private var contentHeight: CGFloat = 50
    
    init(_ text: String, fontSize: CGFloat = 16) {
        self.text = text
        self.fontSize = fontSize
    }
    
    var body: some View {
        LatexWebView(text: text, fontSize: fontSize, contentHeight: $contentHeight)
            .frame(height: contentHeight)
    }
}

/// 内部WebView组件
private struct LatexWebView: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    @Binding var contentHeight: CGFloat
    
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
        let html = generateHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func generateHTML() -> String {
        // 更安全的HTML转义，保留LaTeX语法
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br/>")
        
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
                }
                
                /* 块级数学公式 */
                mjx-container[jax="CHTML"][display="true"] {
                    display: block;
                    margin: 1em 0;
                    text-align: center;
                }
                
                /* 段落间距 */
                p {
                    margin: 0.8em 0;
                }
                
                /* 强调文本 */
                strong, b {
                    font-weight: 600;
                }
                
                /* 斜体文本 */
                em, i {
                    font-style: italic;
                }
            </style>
        </head>
        <body>
            <div id="content">\(escapedText)</div>
            
            <script>
                // 配置 MathJax
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
                            '[+]': ['base', 'ams', 'color', 'boldsymbol']
                        }
                    },
                    options: {
                        skipHtmlTags: ['script', 'style', 'textarea', 'pre', 'code'],
                        ignoreHtmlClass: 'tex2jax_ignore',
                        processHtmlClass: 'tex2jax_process'
                    },
                    chtml: {
                        mtextInheritFont: true,
                        displayAlign: 'center',
                        displayIndent: '0'
                    },
                    startup: {
                        ready: function () {
                            MathJax.startup.defaultReady();
                            // 渲染完成后调整高度
                            setTimeout(() => {
                                updateHeight();
                            }, 200);
                        }
                    }
                };
                
                // 加载 MathJax
                (function() {
                    var script = document.createElement('script');
                    script.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js';
                    script.async = true;
                    document.head.appendChild(script);
                })();
                
                // 更新高度函数
                function updateHeight() {
                    setTimeout(() => {
                        const content = document.getElementById('content');
                        const height = Math.max(
                            document.body.scrollHeight,
                            document.body.offsetHeight,
                            content.scrollHeight,
                            content.offsetHeight
                        );
                        window.webkit?.messageHandlers?.heightChange?.postMessage(height + 20);
                    }, 50);
                }
                
                // 监听内容变化，重新渲染数学公式
                function retypeset() {
                    if (window.MathJax && window.MathJax.typesetPromise) {
                        window.MathJax.typesetPromise([document.body]).then(() => {
                            updateHeight();
                        }).catch(() => {
                            updateHeight();
                        });
                    } else {
                        updateHeight();
                    }
                }
                
                // 多次尝试渲染和高度调整
                setTimeout(retypeset, 300);
                setTimeout(retypeset, 800);
                setTimeout(() => {
                    updateHeight();
                }, 1200);
            </script>
        </body>
        </html>
        """
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: LatexWebView
        
        init(_ parent: LatexWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChange", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.contentHeight = max(height, 50)
                }
            }
        }
    }
}

/// SwiftUI预览
struct LatexRenderedTextView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LatexRenderedTextView("""
            这是一个包含数学公式的示例文本。

            内联公式：给定 $n$ 个整数 $a_1, a_2, \\ldots, a_n$

            块级公式：
            $$\\sum_{i=1}^{n} a_i = a_1 + a_2 + \\cdots + a_n$$

            更复杂的公式：
            $$f(x) = \\frac{1}{\\sqrt{2\\pi\\sigma^2}} e^{-\\frac{(x-\\mu)^2}{2\\sigma^2}}$$
            """, fontSize: 16)
            .frame(height: 300)
            .border(Color.gray, width: 1)
        }
        .padding()
    }
}
