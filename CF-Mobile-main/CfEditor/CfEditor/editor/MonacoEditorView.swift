import SwiftUI
import WebKit

/// SwiftUI 包装的 Monaco Editor（通过 WKWebView + CDN 加载）
struct MonacoEditorView: UIViewRepresentable {
    @Binding var text: String

    var language: String = "plaintext"   // 例："cpp", "python", "swift", "javascript"
    var theme: String = "vs-dark"         // "vs" | "vs-dark" | "hc-black"
    var readOnly: Bool = false
    var fontSize: Int = 14
    var lineNumbers: String = "on"        // "on" | "off"
    var minimap: Bool = false
    var onContentChange: ((String) -> Void)?
    var undoRequestToken: Int = 0
    var redoRequestToken: Int = 0
    var onUndoStateChange: ((Bool, Bool) -> Void)?
    var onReady: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "monacoHandler")
        config.userContentController = userContent

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.scrollView.keyboardDismissMode = .interactive

        let html = Self.htmlTemplate(
            language: language,
            theme: theme,
            readOnly: readOnly,
            fontSize: fontSize,
            lineNumbers: lineNumbers,
            minimap: minimap
        )
        // baseURL 设为 CDN 域，便于相对路径/跨域资源策略更宽松
        webView.loadHTMLString(html, baseURL: URL(string: "https://cdn.jsdelivr.net"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 同步文本
        let escaped = Self.escapeForTemplateLiteral(text)
        let setTextJS = "window.swiftSetValue && window.swiftSetValue(`\(escaped)`);"
        webView.evaluateJavaScript(setTextJS, completionHandler: nil)

        // 同步语言/主题/只读
        webView.evaluateJavaScript("window.swiftSetLanguage && window.swiftSetLanguage('\(language)');", completionHandler: nil)
        webView.evaluateJavaScript("window.swiftSetTheme && window.swiftSetTheme('\(theme)');", completionHandler: nil)
        webView.evaluateJavaScript("window.swiftSetReadOnly && window.swiftSetReadOnly(\(readOnly ? "true" : "false"));", completionHandler: nil)
        webView.evaluateJavaScript("window.swiftSetOptions && window.swiftSetOptions({ fontSize: \(fontSize), lineNumbers: '\(lineNumbers)', minimap: { enabled: \(minimap ? "true" : "false") } });", completionHandler: nil)

        // 请求一次撤销/重做可用性
        webView.evaluateJavaScript("window.swiftRequestUndoState && window.swiftRequestUndoState();", completionHandler: nil)

        // Handle undo/redo triggers when tokens change
        if context.coordinator.lastUndoToken != undoRequestToken {
            context.coordinator.lastUndoToken = undoRequestToken
            webView.evaluateJavaScript("window.swiftUndo && window.swiftUndo();", completionHandler: nil)
        }
        if context.coordinator.lastRedoToken != redoRequestToken {
            context.coordinator.lastRedoToken = redoRequestToken
            webView.evaluateJavaScript("window.swiftRedo && window.swiftRedo();", completionHandler: nil)
        }
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let parent: MonacoEditorView
        init(_ parent: MonacoEditorView) { self.parent = parent }
        var lastUndoToken: Int = 0
        var lastRedoToken: Int = 0

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "monacoHandler" else { return }
            if let body = message.body as? [String: Any] {
                if let event = body["event"] as? String {
                    if event == "change", let value = body["value"] as? String {
                        DispatchQueue.main.async {
                            self.parent.text = value
                            self.parent.onContentChange?(value)
                        }
                    } else if event == "ready" {
                        DispatchQueue.main.async {
                            self.parent.onReady?()
                        }
                    } else if event == "undoState" {
                        let canUndo = (body["canUndo"] as? Bool) ?? false
                        let canRedo = (body["canRedo"] as? Bool) ?? false
                        DispatchQueue.main.async {
                            self.parent.onUndoStateChange?(canUndo, canRedo)
                        }
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 页面加载完成后设置初始文本并初始化编辑器
            let escaped = MonacoEditorView.escapeForTemplateLiteral(parent.text)
            let setInitial = "window._swiftInitialValue = `\(escaped)`;"
            webView.evaluateJavaScript(setInitial, completionHandler: nil)
            webView.evaluateJavaScript("window.swiftInit && window.swiftInit();", completionHandler: nil)
            // 初始化后请求一次撤销/重做可用性
            webView.evaluateJavaScript("window.swiftRequestUndoState && window.swiftRequestUndoState();", completionHandler: nil)
        }
    }

    // MARK: - HTML 模板
    private static func htmlTemplate(language: String, theme: String, readOnly: Bool, fontSize: Int, lineNumbers: String, minimap: Bool) -> String {
        // 版本可按需更新
        let version = "0.43.0"
        let cdnBase = "https://cdn.jsdelivr.net/npm/monaco-editor@\(version)/min"
        let ro = readOnly ? "true" : "false"
        let mm = minimap ? "true" : "false"
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset=\"utf-8\" />
          <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\" />
          <style>
            html, body, #container { height: 100%; margin: 0; padding: 0; }
            #container { display: flex; }
            html, body, #container { -webkit-writing-mode: horizontal-tb; writing-mode: horizontal-tb; text-orientation: mixed; }
            @media (prefers-color-scheme: dark) {
              html, body, #container { background: #1e1e1e; }
            }
            @media (prefers-color-scheme: light) {
              html, body, #container { background: #ffffff; }
            }
          </style>
          <script>
            // 通过 Blob worker 方式解决 WKWebView 中跨源 worker 的限制
            window.MonacoEnvironment = {
              getWorkerUrl: function(moduleId, label) {
                const proxy = `self.MonacoEnvironment = { baseUrl: '${cdnBase}/' };\nimportScripts('${cdnBase}/vs/base/worker/workerMain.js');`;
                return URL.createObjectURL(new Blob([proxy], { type: 'text/javascript' }));
              }
            };
          </script>
          <script src=\"\(cdnBase)/vs/loader.min.js\"></script>
          <script>
            const CDN_BASE = "\(cdnBase)";
            require.config({ paths: { 'vs': CDN_BASE + '/vs' } });

            let editor;

            window.swiftInit = function() {
              require(['vs/editor/editor.main'], function() {
                const value = window._swiftInitialValue || '';
                editor = monaco.editor.create(document.getElementById('container'), {
                  value: value,
                  language: '\(language)',
                  theme: '\(theme)',
                  readOnly: \(ro),
                  fontSize: \(fontSize),
                  automaticLayout: true,
                  minimap: { enabled: \(mm) },
                  lineNumbers: '\(lineNumbers)',
                  scrollBeyondLastLine: false,
                  wordWrap: 'on',
                });

                editor.onDidChangeModelContent(function() {
                  const text = editor.getValue();
                  try { window.webkit.messageHandlers.monacoHandler.postMessage({ event: 'change', value: text }); } catch (e) {}
                  reportUndoRedo();
                });
                setTimeout(reportUndoRedo, 0);

                // 通知 Swift：编辑器已就绪
                try { window.webkit.messageHandlers.monacoHandler.postMessage({ event: 'ready' }); } catch (e) {}
              });
            }

            // Swift -> JS 同步接口
            window.swiftSetValue = function(v) {
              if (!editor) return;
              if (v === editor.getValue()) return;
              const fullRange = editor.getModel().getFullModelRange();
              editor.pushUndoStop();
              editor.executeEdits('swift', [{ range: fullRange, text: v }]);
              editor.pushUndoStop();
            }
            window.swiftGetValue = function() { return editor ? editor.getValue() : ''; }
            window.swiftSetLanguage = function(lang) { if (editor) monaco.editor.setModelLanguage(editor.getModel(), lang); }
            window.swiftSetTheme = function(theme) { try { monaco.editor.setTheme(theme); } catch (e) {} }
            window.swiftSetReadOnly = function(flag) { if (editor) editor.updateOptions({ readOnly: !!flag }); }
            window.swiftSetOptions = function(opts) { if (editor) editor.updateOptions(opts || {}); }
            window.swiftUndo = function() {
              if (!editor) return;
              const hadFocus = (typeof editor.hasTextFocus === 'function') ? editor.hasTextFocus() : false;
              editor.trigger('swift', 'undo', null);
              setTimeout(function() {
                if (!hadFocus) {
                  try { const node = editor.getDomNode && editor.getDomNode(); node && node.blur && node.blur(); } catch (e) {}
                  try { document.activeElement && document.activeElement.blur && document.activeElement.blur(); } catch (e) {}
                }
                reportUndoRedo();
              }, 0);
            }
            window.swiftRedo = function() {
              if (!editor) return;
              const hadFocus = (typeof editor.hasTextFocus === 'function') ? editor.hasTextFocus() : false;
              editor.trigger('swift', 'redo', null);
              setTimeout(function() {
                if (!hadFocus) {
                  try { const node = editor.getDomNode && editor.getDomNode(); node && node.blur && node.blur(); } catch (e) {}
                  try { document.activeElement && document.activeElement.blur && document.activeElement.blur(); } catch (e) {}
                }
                reportUndoRedo();
              }, 0);
            }

            function reportUndoRedo() {
              if (!editor) return;
              let canUndo = false, canRedo = false;
              try {
                const model = editor.getModel();
                if (model && typeof model.canUndo === 'function' && typeof model.canRedo === 'function') {
                  canUndo = !!model.canUndo();
                  canRedo = !!model.canRedo();
                } else {
                  const undoAction = editor.getAction && editor.getAction('undo');
                  const redoAction = editor.getAction && editor.getAction('redo');
                  const undoSupported = undoAction && typeof undoAction.isSupported === 'function' ? undoAction.isSupported() : true;
                  const redoSupported = redoAction && typeof redoAction.isSupported === 'function' ? redoAction.isSupported() : true;
                  canUndo = !!undoSupported;
                  canRedo = !!redoSupported;
                }
              } catch (e) {}
              try { window.webkit.messageHandlers.monacoHandler.postMessage({ event: 'undoState', canUndo, canRedo }); } catch (e) {}
            }

            window.swiftRequestUndoState = function() { setTimeout(reportUndoRedo, 0); }
          </script>
        </head>
        <body>
          <div id=\"container\"></div>
        </body>
        </html>
        """
    }

    private static func escapeForTemplateLiteral(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "\\", with: "\\\\")
        t = t.replacingOccurrences(of: "`", with: "\\`")
        t = t.replacingOccurrences(of: "$", with: "\\$")
        t = t.replacingOccurrences(of: "\r", with: "")
        t = t.replacingOccurrences(of: "\n", with: "\\n")
        return t
    }
}

#if DEBUG
struct MonacoEditorView_Previews: PreviewProvider {
    @State static var code: String = """
#include <bits/stdc++.h>
#define cy {cout << "YES" << endl; return;}
#define cn {cout << "NO" << endl; return;}
#define inf 0x3f3f3f3f
#define llinf 0x3f3f3f3f3f3f3f3f
// #define int long long
#define db(a) cout << #a << " = " << a << endl

using namespace std;

typedef pair<int, int> PII;
typedef tuple<int, int, int, int> St;
typedef long long ll;

int T = 1;
const int N = 2e5 + 10, MOD = 998244353;
int dx[] = {1, -1, 0, 0}, dy[] = {0, 0, 1, -1};

void solve() {
    
}

signed main() {
    ios::sync_with_stdio(false);
    cin.tie(nullptr);

    cin >> T;
    while (T -- ) {
        solve();
    }
    return 0;
}
"""
    static var previews: some View {
        MonacoEditorView(text: $code, language: "cpp", theme: "vs-dark", readOnly: false, fontSize: 14, lineNumbers: "on", minimap: false, onContentChange: nil)
            .ignoresSafeArea()
    }
}
#endif


