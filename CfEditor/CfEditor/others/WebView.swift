//
//  WebView.swift
//  CfEditor
//
//  Created by 赵勃翔 on 2025/8/16.
//

import SwiftUI
import WebKit
import Combine
import UIKit

// 可观察的 WebView 模型：管控加载、前进后退、进度等
final class WebViewModel: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0.0

    internal weak var webView: WKWebView?
    // 标记是否已进行过一次初始加载，防止视图返回时重复刷新
    private(set) var hasLoadedOnce: Bool = false

    // 页面完成加载时的回调（用于特定场景注入脚本，如一键提交自动填充）
    var onDidFinishLoad: ((WKWebView) -> Void)?

    func load(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        hasLoadedOnce = true
        webView?.load(URLRequest(url: url))
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
        let store = WKWebsiteDataStore.default()
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
        let useEphemeral = UserDefaults.standard.bool(forKey: "web.useEphemeral")
        config.websiteDataStore = useEphemeral ? .nonPersistent() : .default()

        // 在 Codeforces 题面页「文档开始」阶段即注入遮罩，直到我们完成题面提取再移除
        // 这样可避免在提取完成前短暂露出官方原始页面
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
          o.style.cssText='position:fixed;inset:0;z-index:2147483647;display:flex;align-items:center;justify-content:center;background:#fff;color:#333;font-size:15px;';
          o.innerHTML='<div style="text-align:center;line-height:1.7"><div style="width:28px;height:28px;border:3px solid #ddd;border-top-color:#409eff;border-radius:50%;margin:0 auto 10px;animation:cfspin 1s linear infinite"></div><div>正在提取题面…</div></div><style>@keyframes cfspin{to{transform:rotate(360deg)}}</style>';
          (document.documentElement||document.body).appendChild(o);
        }catch(e){}})();
        """#
        let overlayScript = WKUserScript(source: overlayJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(overlayScript)

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
            if let url = webView.url, let host = url.host?.lowercased(), host.contains("codeforces.com") {
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
                webView.load(navigationAction.request)
            }
            return nil
        }

        // 所有页面使用移动端界面
        @available(iOS 13.0, *)
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     preferences: WKWebpagePreferences,
                     decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            preferences.preferredContentMode = .mobile
            WebView.applyPreferredUserAgent(to: webView)
            decisionHandler(.allow, preferences)
        }

        // 旧版回退：无法改内容模式，但仍切换 UA 为移动端
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            WebView.applyPreferredUserAgent(to: webView)
            decisionHandler(.allow)
        }

        // 仅保留题面，隐藏其他模块，减少多滚动区域
        private func injectCodeforcesProblemReader(on webView: WKWebView) {
            let js = #"""
            (function(){
              try {
                var removeOverlay=function(){try{var l=document.getElementById('cf-reader-loading'); if(l&&l.parentNode){l.parentNode.removeChild(l);} }catch(e){}};
                // 若已注入，则不再重复处理，避免滚动位置被重置
                if (document.getElementById('cf-reader-container')) {
                  removeOverlay();
                  return;
                }
                const problem = document.querySelector('.problem-statement');
                if (!problem) { removeOverlay(); return; }

                // 记录当前滚动位置，注入后恢复
                const se = document.scrollingElement || document.documentElement || document.body;
                const savedTop = se.scrollTop || 0;
                const savedLeft = se.scrollLeft || 0;

                // 新容器
                const container = document.createElement('div');
                container.id = 'cf-reader-container';
                container.style.margin = '0';
                container.style.padding = '12px';
                container.style.fontSize = '15px';
                container.style.lineHeight = '1.55';
                container.style.color = 'var(--cf-text, #111)';

                // 复制题面节点，避免受站点布局影响
                const cloned = problem.cloneNode(true);
                container.appendChild(cloned);

                // 清空 body，仅保留题面容器
                document.documentElement.style.margin = '0';
                document.documentElement.style.padding = '0';
                document.documentElement.style.overflow = 'auto';
                document.body.innerHTML = '';
                document.body.style.margin = '0';
                document.body.style.padding = '0';
                document.body.style.overflow = 'auto';
                document.body.appendChild(container);

                // 基础样式与标题行 Copy 样式
                const style = document.createElement('style');
                style.textContent = `
                  html, body { height: 100%; }
                  .problem-statement { width: 100% !important; max-width: none !important; }
                  .sample-tests pre { white-space: pre-wrap !important; word-wrap: break-word !important; }
                  pre { overflow: auto; -webkit-overflow-scrolling: touch; position: relative; }
                  img { max-width: 100% !important; height: auto !important; }
                  table { width: 100% !important; display: block; overflow-x: auto; }
                  .header { margin-bottom: 8px; }
                  /* 使 input/output 标题与 Copy 同行并右对齐 */
                  .sample-tests .input > .title,
                  .sample-tests .output > .title {
                    display: flex; align-items: center; justify-content: space-between;
                    font-weight: 700; font-size: 20px; text-transform: lowercase;
                    padding: 8px 10px; background: #fff;
                    border: 1px solid rgba(0,0,0,0.15); border-bottom: 0;
                  }
                  .sample-tests .input > pre,
                  .sample-tests .output > pre {
                    margin: 0; padding: 10px; background: #f7f7f7;
                    border: 1px solid rgba(0,0,0,0.15); border-top: 0;
                  }
                  .cf-copy-title-btn {
                    appearance: none; -webkit-appearance: none;
                    border: 1px solid rgba(0,0,0,0.35); border-radius: 4px;
                    background: #f8f8f8; color: #333; padding: 4px 10px;
                    font-size: 14px; line-height: 1; cursor: pointer;
                  }
                  .cf-copy-title-btn:hover { background: #fff; }
                  .cf-copy-title-btn:active { transform: translateY(1px); }
                  .cf-mini-tip { margin-left: 8px; font-size: 12px; color: #4caf50; opacity: 0; transition: opacity .18s ease; }
                  .cf-mini-tip.show { opacity: 1; }
                  /* MathJax：让上/下标更明显一些（兼容 v2/v3） */
                  mjx-container .mjx-script,
                  mjx-container [class*="mjx-script"],
                  .MJXc-script { font-size: 0.9em !important; }
                  mjx-container .mjx-math { font-weight: 500; }
                  mjx-container[jax="CHTML"], .MathJax, .MathJax_Display { color: #0f0f10; }
                `;
                document.head.appendChild(style);

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

                // 触发 MathJax 排版（兼容 v2/v3），解决 LaTeX 渲染问题
                if (window.MathJax) {
                  try {
                    if (window.MathJax.typesetPromise) {
                      window.MathJax.typesetPromise([container]).catch(function(){});
                    } else if (window.MathJax.Hub && window.MathJax.Hub.Queue) {
                      window.MathJax.Hub.Queue(["Typeset", window.MathJax.Hub, container]);
                    }
                  } catch (e) {}
                }

                // 恢复滚动位置（防止注入后页面跳动）
                se.scrollTop = savedTop;
                se.scrollLeft = savedLeft;

                // 延迟一次仅做排版刷新（不再替换 DOM），避免首屏后加载导致公式漏排版
                setTimeout(function(){
                  if (window.MathJax && window.MathJax.typesetPromise) {
                    try { window.MathJax.typesetPromise([container]); } catch(e){}
                  }
                }, 800);

                // 已移除“我的提交记录”页面内区块，相关功能已集成到原生判题状态面板
              } catch (e) { /* no-op */ }
            })();
            """#
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

    }

    // MARK: - UA Helper
    private static func currentUAMode() -> String {
        UserDefaults.standard.string(forKey: "web.uaMode") ?? "system"
    }

    private static func applyPreferredUserAgent(to web: WKWebView) {
        switch currentUAMode() {
        case "mobile":
            web.customUserAgent = mobileSafariUserAgent()
        case "desktop":
            web.customUserAgent = desktopSafariUserAgent()
        default:
            web.customUserAgent = nil
        }
    }
    static func mobileSafariUserAgent() -> String {
        // 构造一个常见的 iPhone Safari UA；无需完全精确到补丁版本
        let iosVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "Mozilla/5.0 (iPad; CPU OS \(iosVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        } else {
            return "Mozilla/5.0 (iPhone; CPU iPhone OS \(iosVersion) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        }
    }

    static func desktopSafariUserAgent() -> String {
        // 使用 macOS Safari UA（常用于绕过对移动 WebKit 的特殊风控）
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    }
}
