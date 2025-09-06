//
//  WebView.swift
//  CfEditor
//
//  Created by 赵勃翔 on 2025/8/16.
//

import SwiftUI
import WebKit
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// 可观察的 WebView 模型：管控加载、前进后退、进度等
final class WebViewModel: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0.0
    // 是否启用题面阅读模式（仅对 Codeforces 题目页注入提取脚本）
    @Published var enableProblemReader: Bool = true

    internal weak var webView: WKWebView?
    // 标记是否已进行过一次初始加载，防止视图返回时重复刷新
    private(set) var hasLoadedOnce: Bool = false

    // 页面完成加载时的回调（用于特定场景注入脚本，如一键提交自动填充）
    var onDidFinishLoad: ((WKWebView) -> Void)?

    init(enableProblemReader: Bool = true) {
        self.enableProblemReader = enableProblemReader
    }

    func load(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        hasLoadedOnce = true
        webView?.load(URLRequest(url: url))
    }
    // 带 Referer 的加载，修复某些页面（如 Codeforces 提交页）在无来源时的跳转异常
    func load(urlString: String, referer: String?) {
        guard let url = URL(string: urlString) else { return }
        hasLoadedOnce = true
        if let ref = referer, !ref.isEmpty, let _ = URL(string: ref) {
            var req = URLRequest(url: url)
            req.setValue(ref, forHTTPHeaderField: "Referer")
            webView?.load(req)
        } else {
            webView?.load(URLRequest(url: url))
        }
    }
    func goBack()    { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload()    { webView?.reload() }

    // 强制忽略缓存刷新（可用于打破 Cloudflare 验证卡顿）
    func reloadIgnoringCache() {
        guard let web = webView else { return }
        if let url = web.url {
            let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            web.load(req)
        } else {
            web.reloadFromOrigin()
        }
    }

    func reloadFromOrigin() {
        webView?.reloadFromOrigin()
    }

    // 切换为移动端 Safari UA
    func setUserAgentMobile() {
        UserDefaults.standard.set("mobile", forKey: "web.uaMode")
        webView?.customUserAgent = WebView.mobileSafariUserAgent()
        reloadFromOrigin()
    }

    // 切换为桌面端 Safari UA
    func setUserAgentDesktop() {
        UserDefaults.standard.set("desktop", forKey: "web.uaMode")
        webView?.customUserAgent = WebView.desktopSafariUserAgent()
        reloadFromOrigin()
    }

    // 切回系统默认 UA（最兼容 Cloudflare 验证）
    func setUserAgentSystem() {
        UserDefaults.standard.set("system", forKey: "web.uaMode")
        webView?.customUserAgent = nil
        reloadFromOrigin()
    }

    // 仅清理 Codeforces 域的站点数据（缓存、IndexedDB、Cookie 等）
    func clearCodeforcesSiteData(completion: (() -> Void)? = nil) {
        let store = WebDataStoreProvider.shared.currentStore()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            let targets = records.filter { rec in
                let name = rec.displayName.lowercased()
                return name.contains("codeforces.com") || name.contains("polygon.codeforces.com")
            }
            store.removeData(ofTypes: types, for: targets) {
                // 额外清除 URLSession 的 Cookie 中与 codeforces 相关的条目
                let storage = HTTPCookieStorage.shared
                (storage.cookies ?? []).forEach { c in
                    if c.domain.contains("codeforces.com") { storage.deleteCookie(c) }
                }
                completion?()
            }
        }
    }

    // 收集题面可翻译文本段（排除样例/代码块），返回顺序与 DOM 顺序一致
    func collectTranslatableSegments(completion: @escaping ([String]) -> Void) {
        guard let web = webView else { completion([]); return }
        let js = #"""
        (function(){
          try{
            const root = document.getElementById('cf-reader-container') || document.querySelector('.problem-statement');
            if(!root) return JSON.stringify([]);
            const nodes = [];
            const candidates = root.querySelectorAll('h1,h2,h3,h4,h5,h6,p,li,div.legend p,div.header p');
            let idx = 0;
            for (const el of candidates){
              if (el.closest('.sample-tests') || el.closest('pre') || el.closest('code')) continue;
              // 跳过包含真实图片/图标的元素（避免替换后丢失图片），MathJax SVG 允许替换
              const hasNonMathImage = !!el.querySelector('img');
              const svgs = Array.from(el.querySelectorAll('svg'));
              const hasNonMathSvg = svgs.some(svg => !svg.closest('mjx-container'));
              if (hasNonMathImage || hasNonMathSvg) continue;
              const t = (el.innerText||'').trim();
              if (!t) continue;
              el.setAttribute('data-cf-tr-idx', String(idx));
              nodes.push(t);
              idx++;
            }
            return JSON.stringify(nodes);
          }catch(e){ return JSON.stringify([]); }
        })();
        """#
        web.evaluateJavaScript(js) { result, _ in
            var arr: [String] = []
            if let s = result as? String, let data = s.data(using: .utf8) {
                if let list = try? JSONSerialization.jsonObject(with: data) as? [String] {
                    arr = list
                }
            }
            DispatchQueue.main.async { completion(arr) }
        }
    }

    // 收集题面文本段，按部分组织（Input、Output、Note等）
    func collectSectionBasedSegments(completion: @escaping ([String: [String]]) -> Void) {
        guard let web = webView else { completion([:]); return }
        let js = #"""
        (function(){
          try{
            const root = document.getElementById('cf-reader-container') || document.querySelector('.problem-statement');
            if(!root) return JSON.stringify({});
            
            const sections = {};
            let currentSection = 'Legend'; // 默认部分
            
            // 查找所有可能的文本元素
            const candidates = root.querySelectorAll('h1,h2,h3,h4,h5,h6,p,li,div.legend p,div.header p,div.input-specification p,div.output-specification p,div.note p,div.notes p,div.interaction p,div.hack p');
            
            for (const el of candidates){
              // 跳过样例和代码块
              if (el.closest('.sample-tests') || el.closest('pre') || el.closest('code')) continue;
              
              // 跳过包含真实图片/图标的元素
              const hasNonMathImage = !!el.querySelector('img');
              const svgs = Array.from(el.querySelectorAll('svg'));
              const hasNonMathSvg = svgs.some(svg => !svg.closest('mjx-container'));
              if (hasNonMathImage || hasNonMathSvg) continue;
              
              const text = (el.innerText||'').trim();
              if (!text) continue;
              
              // 检查是否是新的部分标题
              const lowerText = text.toLowerCase();
              if (lowerText === 'input' || lowerText.includes('input specification')) {
                currentSection = 'Input';
                continue;
              } else if (lowerText === 'output' || lowerText.includes('output specification')) {
                currentSection = 'Output';
                continue;
              } else if (lowerText === 'note' || lowerText.includes('note')) {
                currentSection = 'Note';
                continue;
              } else if (lowerText === 'interaction' || lowerText.includes('interaction')) {
                currentSection = 'Interaction';
                continue;
              } else if (lowerText === 'hack' || lowerText.includes('hack')) {
                currentSection = 'Hack';
                continue;
              } else if (lowerText === 'tutorial' || lowerText.includes('tutorial')) {
                currentSection = 'Tutorial';
                continue;
              }
              
              // 检查元素的父容器类来确定部分
              if (el.closest('.input-specification')) {
                currentSection = 'Input';
              } else if (el.closest('.output-specification')) {
                currentSection = 'Output';
              } else if (el.closest('.note') || el.closest('.notes')) {
                currentSection = 'Note';
              } else if (el.closest('.interaction')) {
                currentSection = 'Interaction';
              } else if (el.closest('.hack')) {
                currentSection = 'Hack';
              }
              
              // 将文本添加到对应部分
              if (!sections[currentSection]) {
                sections[currentSection] = [];
              }
              sections[currentSection].push(text);
            }
            
            return JSON.stringify(sections);
          }catch(e){ return JSON.stringify({}); }
        })();
        """#
        web.evaluateJavaScript(js) { result, _ in
            var sectionsDict: [String: [String]] = [:]
            if let s = result as? String, let data = s.data(using: .utf8) {
                if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] {
                    sectionsDict = dict
                }
            }
            DispatchQueue.main.async { completion(sectionsDict) }
        }
    }

    // 将翻译结果写回对应节点（按照 data-cf-tr-idx 对应顺序）
    func applyTranslations(_ translations: [String], completion: (() -> Void)? = nil) {
        guard let web = webView,
              let data = try? JSONSerialization.data(withJSONObject: translations),
              let json = String(data: data, encoding: .utf8) else { completion?(); return }
        let js = #"""
        (function(){
          try{
            const arr = JSON.parse('%@');
            const root = document.getElementById('cf-reader-container') || document.querySelector('.problem-statement');
            if(!root) return;
            for (let i=0;i<arr.length;i++){
              const el = root.querySelector('[data-cf-tr-idx="'+i+'"]');
              if (!el) continue;
              // 允许覆盖 MathJax（稍后会重新 typeset），但保护真实图片/图标与代码块
              if (el.closest('pre') || el.closest('code')) continue;
              const hasNonMathImage = !!el.querySelector('img');
              const svgs = Array.from(el.querySelectorAll('svg'));
              const hasNonMathSvg = svgs.some(svg => !svg.closest('mjx-container'));
              if (hasNonMathImage || hasNonMathSvg) continue;
              el.textContent = arr[i];
            }
            // 应用后触发 MathJax 重新排版，修复翻译后公式失效问题（兼容 v2/v3）
            try{
              if (window.MathJax) {
                if (window.MathJax.typesetPromise) {
                  window.MathJax.typesetPromise([root]).catch(function(){});
                } else if (window.MathJax.Hub && window.MathJax.Hub.Queue) {
                  window.MathJax.Hub.Queue(["Typeset", window.MathJax.Hub, root]);
                }
              }
            }catch(e){}
          }catch(e){}
        })();
        """#
        let script = String(
            format: js,
            json.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\"", with: "\\\"")
        )
        web.evaluateJavaScript(script) { _, _ in
            DispatchQueue.main.async { completion?() }
        }
    }

    // 使用临时（非持久）会话：不持久化缓存/存储，常用于规避异常风控状态
    func useEphemeralSession() {
        UserDefaults.standard.set(true, forKey: "web.useEphemeral")
        NotificationCenter.default.post(name: .appReloadRequested, object: nil)
    }

    // 使用持久会话
    func usePersistentSession() {
        UserDefaults.standard.set(false, forKey: "web.useEphemeral")
        NotificationCenter.default.post(name: .appReloadRequested, object: nil)
    }

    // 提取 Codeforces 题面中的样例输入输出对（基于 DOM 解析）
    func extractCodeforcesSamples(completion: @escaping ([(input: String, output: String)]) -> Void) {
        guard let web = webView else {
            completion([])
            return
        }
        let js = #"""
        (() => {
          const preToText = (pre) => {
            let text = '';
            const serialize = (node) => {
              if (!node) return;
              if (node.nodeType === Node.TEXT_NODE) { text += node.textContent; return; }
              if (node.nodeType === Node.ELEMENT_NODE) {
                const tag = node.tagName;
                // 跳过注入的复制按钮及提示元素
                if (node.classList && (node.classList.contains('cf-copy-wrap') || node.classList.contains('cf-copied-tip'))) { return; }
                if (tag === 'BUTTON' && node.classList && node.classList.contains('cf-copy-btn')) { return; }
                if (tag === 'BR') { text += '\n'; return; }
                const blockLike = (tag === 'DIV' || tag === 'P');
                const children = node.childNodes ? Array.from(node.childNodes) : [];
                if (children.length === 0) { text += node.textContent; return; }
                for (const c of children) serialize(c);
                if (blockLike) { text += '\n'; }
              }
            };
            const children = Array.from(pre.childNodes || []);
            for (const c of children) serialize(c);
            return text.replace(/\r/g, '').replace(/\s+$/, '');
          };
          const root = document.querySelector('.sample-tests') || document;
          const inputs = Array.from(root.querySelectorAll('.input pre'));
          const outputs = Array.from(root.querySelectorAll('.output pre'));
          const n = Math.min(inputs.length, outputs.length);
          const pairs = [];
          for (let i = 0; i < n; i++) {
            pairs.push({ input: preToText(inputs[i]), output: preToText(outputs[i]) });
          }
          return JSON.stringify(pairs);
        })();
        """#
        web.evaluateJavaScript(js) { result, _ in
            var pairs: [(String, String)] = []
            if let s = result as? String, let data = s.data(using: .utf8) {
                if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                    for dict in arr {
                        if let inp = dict["input"], let out = dict["output"] {
                            pairs.append((inp, out))
                        }
                    }
                }
            }
            DispatchQueue.main.async { completion(pairs) }
        }
    }

    // 从 Codeforces 页面 DOM 中推断当前登录用户的 handle
    // 方案：尝试读取导航栏中的 profile 链接 /profile/<handle>
    func extractCodeforcesHandle(completion: @escaping (String?) -> Void) {
        guard let web = webView else {
            completion(nil)
            return
        }
        let js = #"""
        (() => {
          // 优先从 cookie 中读取 X-User（最可靠）
          try {
            const cookie = document.cookie || '';
            const m = cookie.match(/(?:^|; )X-User=([^;]+)/);
            if (m) {
              const v = decodeURIComponent(m[1]);
              if (/^[A-Za-z0-9_-]{1,24}$/.test(v)) return v;
            }
          } catch (e) {}
          // 退路：仅从页面头部导航栏读取，避免误取博客作者等正文链接
          try {
            const header = document.querySelector('#header');
            if (header) {
              const anchors = Array.from(header.querySelectorAll('a[href^="/profile/"]'));
              for (const a of anchors) {
                const href = a.getAttribute('href') || '';
                const mm = href.match(/^\/profile\/([A-Za-z0-9_-]{1,24})$/);
                if (mm) return mm[1];
              }
            }
          } catch (e) {}
          return null;
        })();
        """#
        web.evaluateJavaScript(js) { result, _ in
            let s = result as? String
            DispatchQueue.main.async { completion(s) }
        }
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var model: WebViewModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // 明确开启 JS，使用系统默认 UA 与移动内容模式（WKWebView 最稳定的组合）
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            config.defaultWebpagePreferences.preferredContentMode = .mobile
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        // 根据偏好使用持久或临时数据存储
        // 统一数据存储来源，避免出现多个“非持久”实例彼此不共享 Cookie 的问题
        config.websiteDataStore = WebDataStoreProvider.shared.currentStore()

        // 在 Codeforces 题面页「文档开始」阶段即注入遮罩，直到我们完成题面提取再移除
        // 这样可避免在提取完成前短暂露出官方原始页面
        if model.enableProblemReader {
            let overlayJS = #"""
            (function(){try{
              var host=(location.hostname||'').toLowerCase();
              var path=(location.pathname||'').toLowerCase();
              if(host.indexOf('codeforces.com')===-1) return;
              if(!(path.indexOf('/problem/')!==-1 || path.indexOf('/problemset/problem/')!==-1)) return;
              if (document.getElementById('cf-reader-loading')) return;
              var o=document.createElement('div');
              o.id='cf-reader-loading';
              o.setAttribute('role','status');
              // 不设置背景/文字颜色在内联样式，改由 CSS 变量 + 媒体查询控制
              o.style.cssText='position:fixed;inset:0;z-index:2147483647;display:flex;align-items:center;justify-content:center;font-size:15px;';
              o.innerHTML='\
                <div style="text-align:center;line-height:1.7">\
                  <div class="ring" style="margin:0 auto 10px"></div>\
                  <div>正在提取题面…</div>\
                </div>\
                <style>\
                  :root{ --cf-ovl-bg:#ffffff; --cf-ovl-text:#333; --cf-ovl-ring:#d0d0d4; --cf-ovl-accent:#409eff; }\
                  @media (prefers-color-scheme: dark){ :root{ --cf-ovl-bg:#0b0b0c; --cf-ovl-text:#eaeaea; --cf-ovl-ring:#2c2d30; --cf-ovl-accent:#5aa3ff; } }\
                  #cf-reader-loading{ background: var(--cf-ovl-bg); color: var(--cf-ovl-text); }\
                  #cf-reader-loading .ring{ width:28px; height:28px; border:3px solid var(--cf-ovl-ring); border-top-color: var(--cf-ovl-accent); border-radius:50%; animation:cfspin 1s linear infinite }\
                  @keyframes cfspin{to{transform:rotate(360deg)}}\
                </style>';
              (document.documentElement||document.body).appendChild(o);
              // 兜底超时移除遮罩（5秒后）
              setTimeout(function(){
                try{var l=document.getElementById('cf-reader-loading'); if(l&&l.parentNode){l.parentNode.removeChild(l);} }catch(e){}
              }, 5000);
            }catch(e){}})();
            """#
            let overlayScript = WKUserScript(source: overlayJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            config.userContentController.addUserScript(overlayScript)
        }

        // 后面做 CodeMirror 或注入脚本也在这里加
        let web = WKWebView(frame: .zero, configuration: config)
        // 根据偏好设置 UA（默认使用系统 UA，更兼容 Cloudflare 验证）
        Self.applyPreferredUserAgent(to: web)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        // KVO 监听
        web.addObserver(context.coordinator, forKeyPath: "estimatedProgress", options: .new, context: nil)
        web.addObserver(context.coordinator, forKeyPath: "canGoBack", options: .new, context: nil)
        web.addObserver(context.coordinator, forKeyPath: "canGoForward", options: .new, context: nil)

        model.webView = web
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.removeObserver(coordinator, forKeyPath: "estimatedProgress")
        uiView.removeObserver(coordinator, forKeyPath: "canGoBack")
        uiView.removeObserver(coordinator, forKeyPath: "canGoForward")
        coordinator.teardown()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let model: WebViewModel
        init(model: WebViewModel) { self.model = model }
        
        // 检测进度卡住并在主体内容可用时强制完成
        private var stallTimer: Timer?
        private var lastProgressValue: Double = 0.0
        private var lastProgressUpdateAt: Date = .distantPast
        private var forcedProgress: Double = 0.0
        
        fileprivate func teardown() {
            invalidateStallTimer()
        }
        
        private func startStallTimer(for webView: WKWebView) {
            invalidateStallTimer()
            lastProgressValue = 0.0
            lastProgressUpdateAt = Date()
            forcedProgress = 0.0
            stallTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self, weak webView] _ in
                guard let self = self, let web = webView else { return }
                self.checkForStall(on: web)
            }
        }
        
        private func invalidateStallTimer() {
            stallTimer?.invalidate()
            stallTimer = nil
        }
        
        private func checkForStall(on webView: WKWebView) {
            guard model.isLoading else { return }
            let progress = webView.estimatedProgress
            let since = Date().timeIntervalSince(lastProgressUpdateAt)
            if progress >= 0.55, since > 2.5 {
                tryMarkContentReady(on: webView)
            }
        }
        
        private func tryMarkContentReady(on webView: WKWebView) {
            let js = #"""
            (function(){
              const ready = document.readyState === 'interactive' || document.readyState === 'complete';
              const el = document.querySelector('.problem-statement') || document.querySelector('#pageContent') || document.querySelector('#content') || document.querySelector('#main-container');
              const textLen = el ? (el.textContent||'').trim().length : 0;
              return !!(ready && textLen > 80);
            })();
            """#
            webView.evaluateJavaScript(js) { [weak self] result, _ in
                guard let self = self else { return }
                if let ok = result as? Bool, ok {
                    self.forcedProgress = 1.0
                    self.model.progress = 1.0
                    self.model.isLoading = false
                    self.invalidateStallTimer()
                }
            }
        }

        // 进度 & 前进后退 KVO
        override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                   change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            guard let web = object as? WKWebView else { return }
            switch keyPath {
            case "estimatedProgress":
                let p = max(web.estimatedProgress, forcedProgress)
                model.progress = p
                if p > lastProgressValue + 0.01 {
                    lastProgressValue = p
                    lastProgressUpdateAt = Date()
                }
            case "canGoBack":
                model.canGoBack = web.canGoBack
            case "canGoForward":
                model.canGoForward = web.canGoForward
            default: break
            }
        }

        // 导航回调
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            model.isLoading = true
            forcedProgress = 0.0
            model.progress = 0.0
            startStallTimer(for: webView)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            model.isLoading = false
            forcedProgress = 1.0
            model.progress = 1.0
            invalidateStallTimer()
            // 对 Codeforces 题面页做「阅读模式」处理：仅保留题面，避免页面存在多个可滚动区域
            if model.enableProblemReader,
               let url = webView.url, let host = url.host?.lowercased(), host.contains("codeforces.com") {
                let path = url.path.lowercased()
                if path.contains("/problem/") || path.contains("/problemset/problem/") {
                    injectCodeforcesProblemReader(on: webView)
                }
            }
            // 供外部完成后的自定义处理（如提交页自动填充表单）
            model.onDidFinishLoad?(webView)
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false
            forcedProgress = 1.0
            invalidateStallTimer()
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.isLoading = false
            forcedProgress = 1.0
            invalidateStallTimer()
        }

        // 在同一 WebView 打开新窗口（阻止跳到外部 Safari）
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                // 检查是否为允许的域名
                if let url = navigationAction.request.url,
                   let host = url.host?.lowercased() {
                    let allowedHosts = [
                        "codeforces.com",
                        "www.codeforces.com",
                        "codeforces.ml",
                        "www.codeforces.ml"
                    ]
                    
                    if allowedHosts.contains(host) {
                        webView.load(navigationAction.request)
                    } else {
                        // 禁止加载外部链接
                        print("阻止在新窗口打开外部链接: \(url)")
                    }
                }
            }
            return nil
        }

        // 所有页面使用移动端界面
        @available(iOS 13.0, *)
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     preferences: WKWebpagePreferences,
                     decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            // 避免每次导航都强制写入 viewport 配置，减少 WebPage_SetViewportConfigurationViewLayoutSize 消息量
            WebView.applyPreferredUserAgent(to: webView)
            
            // 检查是否为外部链接并禁止跳转
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel, preferences)
                return
            }
            
            // 允许的域名（只允许 Codeforces 相关域名）
            let allowedHosts = [
                "codeforces.com",
                "www.codeforces.com",
                "codeforces.ml",
                "www.codeforces.ml"
            ]
            
            if let host = url.host?.lowercased() {
                if allowedHosts.contains(host) {
                    decisionHandler(.allow, preferences)
                } else {
                    // 禁止跳转到外部网站
                    decisionHandler(.cancel, preferences)
                    DispatchQueue.main.async {
                        print("阻止跳转到外部链接: \(url)")
                    }
                }
            } else {
                // 无法确定域名，为安全起见禁止跳转
                decisionHandler(.cancel, preferences)
            }
        }

        // 旧版回退：无法改内容模式，但仍切换 UA 为移动端
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            WebView.applyPreferredUserAgent(to: webView)
            
            // 检查是否为外部链接并禁止跳转
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            
            // 允许的域名（只允许 Codeforces 相关域名）
            let allowedHosts = [
                "codeforces.com",
                "www.codeforces.com",
                "codeforces.ml",
                "www.codeforces.ml"
            ]
            
            if let host = url.host?.lowercased() {
                if allowedHosts.contains(host) {
                    decisionHandler(.allow)
                } else {
                    // 禁止跳转到外部网站
                    decisionHandler(.cancel)
                    DispatchQueue.main.async {
                        print("阻止跳转到外部链接: \(url)")
                    }
                }
            } else {
                // 无法确定域名，为安全起见禁止跳转
                decisionHandler(.cancel)
            }
        }

        // 获取用户阅读设置
        private func getUserReadingSettings() -> (fontSize: Int, lineHeight: Double) {
            let fontSize = UserDefaults.standard.object(forKey: "problemReaderFontSize") as? Int ?? 17
            let lineHeight = UserDefaults.standard.object(forKey: "problemReaderLineHeight") as? Double ?? 1.5
            return (fontSize, lineHeight)
        }
        
        // 仅保留题面，隐藏其他模块，减少多滚动区域
        private func injectCodeforcesProblemReader(on webView: WKWebView) {
            let settings = getUserReadingSettings()
            let js = String(format: #"""
            (function(){
              try {
                var removeOverlay=function(){try{var l=document.getElementById('cf-reader-loading'); if(l&&l.parentNode){l.parentNode.removeChild(l);} }catch(e){}};
                // 若已注入，则不再重复处理，避免滚动位置被重置
                if (document.getElementById('cf-reader-container')) {
                  removeOverlay();
                  return;
                }
                // 尝试多种选择器找到题面内容
                let problem = document.querySelector('.problem-statement') || 
                             document.querySelector('[class*="problem"]') ||
                             document.querySelector('.problemindexholder') ||
                             document.querySelector('#pageContent .ttypography');
                if (!problem) { 
                  console.log('未找到题面元素，可用的类：', Array.from(document.querySelectorAll('[class*="problem"]')).map(el => el.className));
                  removeOverlay(); 
                  return; 
                }

                // 记录当前滚动位置，注入后恢复
                const se = document.scrollingElement || document.documentElement || document.body;
                const savedTop = se.scrollTop || 0;
                const savedLeft = se.scrollLeft || 0;

                // 新容器 - 优化阅读体验
                const container = document.createElement('div');
                container.id = 'cf-reader-container';
                container.style.margin = '0';
                container.style.padding = '16px 20px';
                container.style.fontSize = 'var(--cf-font-size, 17px)';
                container.style.lineHeight = 'var(--cf-line-height, 1.7)';
                container.style.color = 'var(--cf-text, #111)';
                container.style.maxWidth = '800px';
                container.style.marginLeft = 'auto';
                container.style.marginRight = 'auto';

                // 移动原始题面节点（不克隆），避免图片/公式等懒加载资源丢失
                container.appendChild(problem);

                // 清空 body，仅保留题面容器
                document.documentElement.style.margin = '0';
                document.documentElement.style.padding = '0';
                document.documentElement.style.overflow = 'auto';
                document.body.innerHTML = '';
                document.body.style.margin = '0';
                document.body.style.padding = '0';
                document.body.style.overflow = 'auto';
                document.body.style.background = 'var(--cf-bg, #ffffff)';
                document.body.appendChild(container);

                // 优化的阅读体验样式
                const style = document.createElement('style');
                style.textContent = `
                  :root{ 
                    --cf-bg: #ffffff; 
                    --cf-text: #2c2c2e; 
                    --cf-text-secondary: #666; 
                    --cf-border: rgba(0,0,0,0.12); 
                    --cf-sample-bg: #f8f9fa; 
                    --cf-sample-border: #e9ecef;
                    --cf-header-bg: #f5f5f7;
                    --cf-font-size: %dpx;
                    --cf-line-height: %.2f;
                    --cf-heading-color: #1d1d1f;
                  }
                  @media (prefers-color-scheme: dark){ 
                    :root{ 
                      --cf-bg: #000000; 
                      --cf-text: #e8e8ea; 
                      --cf-text-secondary: #a1a1a6; 
                      --cf-border: rgba(255,255,255,0.15); 
                      --cf-sample-bg: #1c1c1e; 
                      --cf-sample-border: #2c2c2e;
                      --cf-header-bg: #1c1c1e;
                      --cf-heading-color: #f2f2f7;
                    } 
                  }
                  
                  /* 基础布局优化 */
                  html, body { height: 100%; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; }
                  html, body, #cf-reader-container { background: var(--cf-bg); color: var(--cf-text); filter: none !important; }
                  body { padding: env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left); }
                  
                  /* 题面容器优化 */
                  .problem-statement { 
                    width: 100% !important; 
                    max-width: none !important; 
                    font-size: var(--cf-font-size);
                    line-height: var(--cf-line-height);
                  }
                  
                  /* 标题层次优化 */
                  .problem-statement .header { 
                    margin-bottom: 20px; 
                    padding: 16px 0;
                    border-bottom: 1px solid var(--cf-border);
                  }
                  .problem-statement .title { 
                    font-size: 1.5em; 
                    font-weight: 700; 
                    color: var(--cf-heading-color);
                    margin-bottom: 8px;
                    line-height: 1.3;
                  }
                  .problem-statement .header .input-output-frame { 
                    font-size: 0.9em; 
                    color: var(--cf-text-secondary); 
                    margin-top: 12px;
                  }
                  
                  /* 内容段落优化 */
                  .problem-statement p { 
                    margin: 16px 0; 
                    text-align: justify;
                  }
                  .problem-statement .section-title { 
                    font-size: 1.2em; 
                    font-weight: 600; 
                    color: var(--cf-heading-color);
                    margin: 24px 0 12px 0;
                    border-left: 4px solid var(--cf-border);
                    padding-left: 12px;
                  }
                  
                  /* 样例测试优化 */
                  .sample-tests { 
                    margin: 24px 0; 
                    background: var(--cf-sample-bg);
                    border: 1px solid var(--cf-sample-border);
                    border-radius: 12px;
                    padding: 16px;
                  }
                  .sample-tests .title { 
                    font-weight: 600; 
                    color: var(--cf-heading-color);
                    margin-bottom: 8px;
                    font-size: 1.1em;
                  }
                  .sample-tests pre { 
                    white-space: pre-wrap !important; 
                    word-wrap: break-word !important; 
                    color: var(--cf-text);
                    background: var(--cf-bg) !important;
                    border: 1px solid var(--cf-border);
                    border-radius: 8px;
                    padding: 12px;
                    margin: 8px 0;
                    font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;
                    font-size: 0.9em;
                    line-height: 1.5;
                    overflow-x: auto;
                    -webkit-overflow-scrolling: touch;
                  }
                  
                  /* 代码和公式优化 */
                  pre, code { color: var(--cf-text); }
                  code { 
                    background: var(--cf-sample-bg); 
                    padding: 2px 6px; 
                    border-radius: 4px; 
                    font-size: 0.9em;
                  }
                  
                  /* 图片和媒体优化 */
                  img { 
                    max-width: 100% !important; 
                    height: auto !important; 
                    background: transparent !important;
                    border-radius: 8px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                    margin: 12px 0;
                  }
                  #cf-reader-container img, #cf-reader-container svg, mjx-container svg { 
                    filter: none !important; 
                    mix-blend-mode: normal !important; 
                  }
                  
                  /* 表格优化 */
                  table { 
                    width: 100% !important; 
                    border-collapse: collapse;
                    margin: 16px 0;
                    border-radius: 8px;
                    overflow: hidden;
                    border: 1px solid var(--cf-border);
                  }
                  table th, table td { 
                    padding: 12px; 
                    border: 1px solid var(--cf-border);
                    text-align: left;
                  }
                  table th { 
                    background: var(--cf-header-bg); 
                    font-weight: 600;
                  }
                  
                  /* 响应式优化 */
                  @media (max-width: 480px) {
                    #cf-reader-container { 
                      padding: 12px 16px; 
                      font-size: 16px;
                    }
                    .problem-statement .title { font-size: 1.3em; }
                    .sample-tests { padding: 12px; }
                  }
                  
                  /* 颜色方案声明 */
                  :root { color-scheme: light dark; }
                  
                  /* 使 input/output 标题与 Copy 同行并右对齐 */
                  .sample-tests .input > .title,
                  .sample-tests .output > .title {
                    display: flex; align-items: center; justify-content: space-between;
                    font-weight: 700; font-size: 20px; text-transform: lowercase;
                    padding: 8px 10px; background: var(--cf-bg);
                    border: 1px solid var(--cf-border); border-bottom: 0;
                  }
                  .sample-tests .input > pre,
                  .sample-tests .output > pre {
                    margin: 0; padding: 10px; background: var(--cf-sample-bg);
                    border: 1px solid var(--cf-border); border-top: 0;
                  }
                  .cf-copy-title-btn {
                    appearance: none; -webkit-appearance: none;
                    border: 1px solid var(--cf-border); border-radius: 4px;
                    background: var(--cf-sample-bg); color: var(--cf-text); padding: 4px 10px;
                    font-size: 14px; line-height: 1; cursor: pointer;
                  }
                  .cf-copy-title-btn:hover { background: var(--cf-bg); }
                  .cf-copy-title-btn:active { transform: translateY(1px); }
                  .cf-mini-tip { margin-left: 8px; font-size: 12px; color: #4caf50; opacity: 0; transition: opacity .18s ease; }
                  .cf-mini-tip.show { opacity: 1; }
                  /* MathJax：让上/下标更明显一些（兼容 v2/v3） */
                  mjx-container .mjx-script,
                  mjx-container [class*="mjx-script"],
                  .MJXc-script { font-size: 0.9em !important; }
                  mjx-container .mjx-math { font-weight: 500; }
                  mjx-container[jax="CHTML"], .MathJax, .MathJax_Display { color: var(--cf-text); }
                  /* 在暗色下改善 MathJax inline/block 背景，避免被站点遗留样式影响 */
                  @media (prefers-color-scheme: dark){
                    .MathJax_Display, mjx-container[jax="CHTML"][display="true"] { background: transparent; }
                  }
                `;
                document.head.appendChild(style);

                // 声明 color-scheme 元信息，改善 iOS 暗色滚动条/控件表现
                try {
                  var meta = document.head.querySelector('meta[name="color-scheme"]');
                  if (!meta) {
                    meta = document.createElement('meta');
                    meta.setAttribute('name','color-scheme');
                    meta.setAttribute('content','light dark');
                    document.head.appendChild(meta);
                  }
                } catch(e) {}

                // 规范化/恢复懒加载图片，避免图片在阅读模式中丢失
                const absolutize = (u) => { try { return new URL(u, location.href).href } catch(_) { return u } };
                const normalizeImages = (root) => {
                  const imgs = Array.from(root.querySelectorAll('img'));
                  imgs.forEach(img => {
                    const ds = img.getAttribute('data-src');
                    const dss = img.getAttribute('data-srcset');
                    if (ds) { img.setAttribute('src', absolutize(ds)); }
                    if (dss) {
                      const parts = dss.split(',').map(s => s.trim()).filter(Boolean).map(entry => {
                        const segs = entry.split(' ');
                        const url = segs.shift() || '';
                        return [absolutize(url), ...segs].join(' ');
                      });
                      img.setAttribute('srcset', parts.join(', '));
                    }
                    const src = img.getAttribute('src');
                    if (src && !/^https?:|^data:|^\//.test(src)) { img.setAttribute('src', absolutize(src)); }
                    img.setAttribute('loading','eager');
                    img.setAttribute('decoding','sync');
                    img.style.background = 'transparent';
                  });
                  const sources = Array.from(root.querySelectorAll('source'));
                  sources.forEach(s => {
                    const dss = s.getAttribute('data-srcset');
                    if (dss) s.setAttribute('srcset', dss);
                  });
                };
                normalizeImages(container);

                // 注入完成，移除遮罩
                removeOverlay();

                // 为 input/output 标题行添加单一的 Copy 按钮（与标题同行，右对齐）
                const sampleRoot = container.querySelector('.sample-tests, .sample-test');
                const preToText = (pre) => (pre?.innerText || '').replace(/\u00A0/g, ' ');
                if (sampleRoot) {
                  // 1) 处理“表格布局”的样例：若存在右侧 copy 列，将其移除，并把该列的按钮移动到标题行右侧
                  try {
                    const isCopyHeader = (el) => ((el?.textContent)||'').trim().toLowerCase() === 'copy';
                    const tables = Array.from(sampleRoot.querySelectorAll('table'));
                    tables.forEach(tbl => {
                      const thead = tbl.querySelector('thead');
                      const headCells = thead ? Array.from(thead.querySelectorAll('th,td')) : [];
                      let copyIdx = -1;
                      headCells.forEach((th, idx) => { if (isCopyHeader(th)) copyIdx = idx; });
                      if (copyIdx === -1) return; // 无 copy 列

                      // 移除表头的 copy 单元格
                      if (headCells[copyIdx] && headCells[copyIdx].parentNode) {
                        headCells[copyIdx].parentNode.removeChild(headCells[copyIdx]);
                      }

                      // 逐行迁移该列中的按钮，并删除该列
                      const bodyRows = Array.from(tbl.querySelectorAll('tbody tr'));
                      bodyRows.forEach(tr => {
                        const cells = Array.from(tr.children);
                        if (copyIdx >= cells.length) return;
                        const copyCell = cells[copyIdx];
                        const leftCell = cells[Math.max(0, copyIdx - 1)];
                        // 找到 copyCell 内的按钮（尽可能通用）
                        const btn = copyCell ? (copyCell.querySelector('button, a, [role="button"]')) : null;
                        if (btn && leftCell) {
                          // 放到左侧单元格的标题行右侧
                          let title = leftCell.querySelector('.title');
                          if (!title) {
                            title = document.createElement('div');
                            title.className = 'title';
                            // 尝试推断 label
                            const isInput = ((leftCell.textContent||'').toLowerCase().includes('input'));
                            const isOutput = ((leftCell.textContent||'').toLowerCase().includes('output'));
                            title.textContent = isInput ? 'input' : (isOutput ? 'output' : 'example');
                            leftCell.insertBefore(title, leftCell.firstChild);
                          }
                          // 包一层并右对齐
                          const right = document.createElement('span');
                          right.style.display = 'inline-flex';
                          right.style.alignItems = 'center';
                          right.style.marginLeft = '8px';
                          // 复制按钮风格以统一
                          btn.classList.add('cf-copy-title-btn');
                          right.appendChild(btn);
                          // 轻量“已复制”提示
                          const tip = document.createElement('span');
                          tip.className = 'cf-mini-tip';
                          tip.textContent = 'Copied';
                          right.appendChild(tip);
                          title.appendChild(right);
                          // 绑定按钮点击后的提示
                          btn.addEventListener('click', () => {
                            tip.classList.add('show'); setTimeout(() => tip.classList.remove('show'), 900);
                          });
                        }
                        // 删除该列
                        if (copyCell && copyCell.parentNode) copyCell.parentNode.removeChild(copyCell);
                      });
                    });
                  } catch (e) {}

                  // 1.1) 处理“非 table 布局”的标题：删除仅包含 "copy" 的标题单元
                  try {
                    const copyLabels = Array.from(sampleRoot.querySelectorAll('th,td,div,span,p')).filter(el => {
                      const t = ((el.textContent)||'').trim().toLowerCase();
                      if (t !== 'copy') return false;
                      if (el.closest('.cf-copy-title-btn')) return false;
                      if (el.closest('button,a,[role="button"]')) return false;
                      if (el.closest('pre')) return false;
                      return !!el.closest('.input, .output');
                    });
                    copyLabels.forEach(el => el.remove());
                  } catch (e) {}

                  // 隐藏原站可能自带的“浮动/行内” Copy 按钮，避免与标题行重复
                  const nativeCopyBtns = sampleRoot.querySelectorAll('a.copy, button.copy, .copy[role="button"]');
                  nativeCopyBtns.forEach(el => {
                    // 如果该按钮已经被迁移到标题行，则保留；否则隐藏
                    const inTitle = el.closest('.title');
                    if (!inTitle) el.style.display = 'none';
                  });
                  const sections = Array.from(sampleRoot.querySelectorAll('.input, .output'));
                  sections.forEach(sec => {
                    let title = sec.querySelector('.title');
                    if (!title) {
                      title = document.createElement('div');
                      title.className = 'title';
                      title.textContent = sec.classList.contains('input') ? 'input' : 'output';
                      sec.insertBefore(title, sec.firstChild);
                    }
                    // 添加标题样式并插入 Copy 控件
                    title.classList.add('cf-sample-title');
                    if (!title.querySelector('.cf-copy-title-btn')) {
                      const right = document.createElement('span');
                      right.style.display = 'inline-flex';
                      right.style.alignItems = 'center';
                      const btn = document.createElement('button');
                      btn.type = 'button';
                      btn.className = 'cf-copy-title-btn';
                      btn.textContent = 'Copy';
                      const tip = document.createElement('span');
                      tip.className = 'cf-mini-tip';
                      tip.textContent = 'Copied';
                      right.appendChild(btn);
                      right.appendChild(tip);
                      title.appendChild(right);
                      btn.addEventListener('click', () => {
                        const pre = sec.querySelector('pre');
                        const text = preToText(pre);
                        const done = () => { tip.classList.add('show'); setTimeout(() => tip.classList.remove('show'), 900); };
                        if (navigator.clipboard && navigator.clipboard.writeText) {
                          navigator.clipboard.writeText(text).then(done).catch(() => {
                            const ta = document.createElement('textarea');
                            ta.value = text; document.body.appendChild(ta); ta.select();
                            try { document.execCommand('copy'); } catch (e) {}
                            document.body.removeChild(ta); done();
                          });
                        } else {
                          const ta = document.createElement('textarea');
                          ta.value = text; document.body.appendChild(ta); ta.select();
                          try { document.execCommand('copy'); } catch (e) {}
                          document.body.removeChild(ta); done();
                        }
                      });
                    }
                    const pre = sec.querySelector('pre');
                    if (pre) { pre.style.margin = '0'; }
                  });
                }

                // 触发或注入 MathJax（优先使用已存在实例；否则加载 v3 并渲染）
                (function ensureMathJax(){
                  if (window.MathJax) {
                    try {
                      if (window.MathJax.typesetPromise) {
                        window.MathJax.typesetPromise([container]).catch(function(){});
                      } else if (window.MathJax.Hub && window.MathJax.Hub.Queue) {
                        window.MathJax.Hub.Queue(["Typeset", window.MathJax.Hub, container]);
                      }
                    } catch (e) {}
                    return;
                  }
                  window.MathJax = {
                    tex: { inlineMath: [["\\(","\\)"],["$","$"]], displayMath: [["\\[","\\]"],["$$","$$"]] },
                    options: { skipHtmlTags: ['script','style','textarea','pre','code'] },
                    chtml: { mtextInheritFont: true }
                  };
                  var s = document.createElement('script');
                  s.src = 'https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js';
                  s.async = true;
                  s.onload = function(){ try { window.MathJax.typesetPromise && window.MathJax.typesetPromise([container]); } catch(e){} };
                  document.head.appendChild(s);
                })();

                // 恢复滚动位置（防止注入后页面跳动）
                se.scrollTop = savedTop;
                se.scrollLeft = savedLeft;

                // 延迟一次仅做排版刷新（不再替换 DOM），避免首屏后加载导致公式漏排版
                setTimeout(function(){
                  if (window.MathJax && window.MathJax.typesetPromise) {
                    try { window.MathJax.typesetPromise([container]); } catch(e){}
                  }
                }, 800);

                // 已移除"我的提交记录"页面内区块，相关功能已集成到原生判题状态面板
              } catch (e) { 
                // 如果出现任何错误，确保移除遮罩
                try { var l=document.getElementById('cf-reader-loading'); if(l&&l.parentNode){l.parentNode.removeChild(l);} } catch(ee){}
                console.error('题面阅读模式注入失败:', e);
              }
            })();
            """#, settings.fontSize, settings.lineHeight)
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        // 收集可翻译文本段：仅针对已注入的阅读模式容器，排除样例/代码块
        fileprivate func collectTranslatableSegments(on webView: WKWebView, completion: @escaping ([String]) -> Void) {
            let js = #"""
            (function(){
              try{
                const root = document.getElementById('cf-reader-container') || document.querySelector('.problem-statement');
                if(!root) return JSON.stringify([]);
                const nodes = [];
                // 按DOM顺序收集可翻译文本，确保包含Note部分
                const candidates = root.querySelectorAll('h1,h2,h3,h4,h5,h6,p,li,div.legend p,div.header p,div.note p,div.notes p,.section-title');
                let idx = 0;
                for (const el of candidates){
                  // 排除样例测试和代码块，但包含Note部分
                  if (el.closest('.sample-tests') || el.closest('pre') || el.closest('code')) continue;
                  const t = (el.innerText||'').trim();
                  if (!t) continue;
                  el.setAttribute('data-cf-tr-idx', String(idx));
                  nodes.push(t);
                  idx++;
                }
                return JSON.stringify(nodes);
              }catch(e){ return JSON.stringify([]); }
            })();
            """#
            webView.evaluateJavaScript(js) { result, _ in
                var arr: [String] = []
                if let s = result as? String, let data = s.data(using: .utf8) {
                    if let list = try? JSONSerialization.jsonObject(with: data) as? [String] {
                        arr = list
                    }
                }
                DispatchQueue.main.async { completion(arr) }
            }
        }

        // 将翻译结果写回对应节点（按照 data-cf-tr-idx 对应顺序）
        fileprivate func applyTranslations(on webView: WKWebView, translations: [String], completion: (() -> Void)? = nil) {
            guard let data = try? JSONSerialization.data(withJSONObject: translations), let json = String(data: data, encoding: .utf8) else {
                completion?(); return
            }
            let js = #"""
            (function(){
              try{
                const arr = JSON.parse('%@');
                const root = document.getElementById('cf-reader-container') || document.querySelector('.problem-statement');
                if(!root) return;
                for (let i=0;i<arr.length;i++){
                  const el = root.querySelector('[data-cf-tr-idx="'+i+'"]');
                  if (el) { el.innerText = arr[i]; }
                }
              }catch(e){}
            })();
            """#
            let script = String(format: js, json.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\"", with: "\\\""))
            webView.evaluateJavaScript(script) { _, _ in
                DispatchQueue.main.async { completion?() }
            }
        }

    }

    // MARK: - UA Helper
    private static func currentUAMode() -> String {
        UserDefaults.standard.string(forKey: "web.uaMode") ?? "system"
    }

    private static func applyPreferredUserAgent(to web: WKWebView) {
        // 仅在需要时变更 UA，避免重复写入触发底层重配置
        let desired: String?
        switch currentUAMode() {
        case "mobile":
            desired = mobileSafariUserAgent()
        case "desktop":
            desired = desktopSafariUserAgent()
        default:
            desired = nil
        }
        if web.customUserAgent == desired { return }
        web.customUserAgent = desired
    }
    static func mobileSafariUserAgent() -> String {
        // 构造一个常见的 iPhone Safari UA；无需完全精确到补丁版本
        #if canImport(UIKit)
        let iosVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "Mozilla/5.0 (iPad; CPU OS \(iosVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        } else {
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        }
        #else
        // macOS 的移动 Safari UA 模拟
        return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        #endif
    }

    static func desktopSafariUserAgent() -> String {
        // 使用 macOS Safari UA（常用于绕过对移动 WebKit 的特殊风控）
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    }
}
