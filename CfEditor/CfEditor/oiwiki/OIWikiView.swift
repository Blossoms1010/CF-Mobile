import SwiftUI
import WebKit

// WebView管理器，确保WebView在视图重建时保持状态
class OIWikiWebViewManager: ObservableObject {
    let webView = WKWebView()
    @Published var isLoading = true
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var hasLoaded = false
}

struct OIWikiView: View {
    @StateObject private var webViewManager = OIWikiWebViewManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // 导航工具栏
            HStack {
                Button(action: { webViewManager.webView.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(webViewManager.canGoBack ? .primary : .secondary)
                }
                .disabled(!webViewManager.canGoBack)
                
                Button(action: { webViewManager.webView.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(webViewManager.canGoForward ? .primary : .secondary)
                }
                .disabled(!webViewManager.canGoForward)
                
                Spacer()
                
                Button(action: { webViewManager.webView.reload() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                }
                
                Button(action: { 
                    if let url = URL(string: "https://oi-wiki.org") {
                        webViewManager.webView.load(URLRequest(url: url))
                    }
                }) {
                    Image(systemName: "house")
                        .font(.title2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(UIColor.separator)),
                alignment: .bottom
            )
            
            // WebView容器
            ZStack {
                OIWikiWebViewRepresentable(
                    webView: webViewManager.webView,
                    isLoading: $webViewManager.isLoading,
                    canGoBack: $webViewManager.canGoBack,
                    canGoForward: $webViewManager.canGoForward
                )
                
                if webViewManager.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在加载 OI Wiki...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                }
            }
        }
        .navigationTitle("OI Wiki")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            // 只在第一次加载时才请求网页，之后保持状态
            if !webViewManager.hasLoaded {
                loadOIWiki()
                webViewManager.hasLoaded = true
            }
        }
    }
    
    private func loadOIWiki() {
        guard let url = URL(string: "https://oi-wiki.org") else { return }
        webViewManager.webView.load(URLRequest(url: url))
    }
}

struct OIWikiWebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    @Binding var isLoading: Bool
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // 配置WebView设置
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        #if !os(macOS)
        webView.configuration.allowsInlineMediaPlayback = true
        #endif
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 设置用户代理，避免移动端适配问题
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 更新导航状态
        DispatchQueue.main.async {
            canGoBack = uiView.canGoBack
            canGoForward = uiView.canGoForward
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: OIWikiWebViewRepresentable
        
        init(_ parent: OIWikiWebViewRepresentable) {
            self.parent = parent
        }
        
        // 控制导航，只允许在oi-wiki.org域名内跳转
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            
            // 允许的域名
            let allowedHosts = ["oi-wiki.org", "www.oi-wiki.org"]
            
            if let host = url.host, allowedHosts.contains(host) {
                decisionHandler(.allow)
            } else {
                // 禁止跳转到外部网站
                decisionHandler(.cancel)
                
                // 可以选择显示提示
                DispatchQueue.main.async {
                    // 这里可以添加提示用户不能跳转到外部链接的逻辑
                    print("阻止跳转到外部链接: \(url)")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            
            // 彻底移除所有评论相关UI元素的JavaScript代码
            let hideCommentsScript = """
            function removeTextSelectionElements() {
                // CSS样式注入 - 隐藏文字选择相关元素，禁用评论交互
                const style = document.createElement('style');
                style.textContent = `
                    /* 彻底隐藏所有评论相关元素 */
                    .giscus,
                    #giscus-container,
                    .utterances,
                    #utterances-container,
                    .gitalk-container,
                    #gitalk-container,
                    .valine,
                    #valine,
                    .disqus,
                    #disqus_thread,
                    .md-content__button,
                    [data-md-component="content"] button,
                    button[title*="评论"],
                    button[title*="comment"],
                    button[aria-label*="评论"],
                    button[aria-label*="comment"],
                    .md-content__button[data-md-component="comments"],
                    button[data-md-component="comments"],
                    .md-typeset .admonition.comment,
                    .comment-box,
                    .comments-section,
                    .comments-container,
                    .comment-form,
                    .comment-input,
                    .md-header__button[data-md-component="comments"],
                    .md-header__option[data-md-component="comments"],
                    .md-content__inner .md-content__button,
                    .md-source-file__fact,
                    .md-footer-meta__inner button,
                    .md-footer__inner button,
                    button[data-toggle="comments"],
                    a[href*="comment"],
                    a[onclick*="comment"],
                    .giscus-frame,
                    .utterances-frame,
                    [class*="comment"],
                    [id*="comment"],
                    iframe[src*="giscus"],
                    iframe[src*="utterances"],
                    iframe[src*="disqus"],
                    script[src*="giscus"],
                    script[src*="utterances"],
                    script[src*="disqus"] {
                        display: none !important;
                        visibility: hidden !important;
                        opacity: 0 !important;
                        pointer-events: none !important;
                        position: absolute !important;
                        left: -9999px !important;
                        top: -9999px !important;
                        width: 0 !important;
                        height: 0 !important;
                        overflow: hidden !important;
                        z-index: -9999 !important;
                    }
                    /* 文字选择相关的UI元素 */
                    .md-tooltip,
                    .md-tooltip__inner,
                    .md-annotation,
                    .md-annotation__index,
                    .md-annotation__list,
                    /* 选择工具和弹出框 */
                    .md-select,
                    .md-select__inner,
                    .md-clipboard,
                    .md-clipboard__message,
                    /* 文字选择后的工具栏/按钮 */
                    .selection-toolbar,
                    .text-selection-toolbar,
                    .selection-popup,
                    .selection-menu,
                    /* 高亮框和选择框 */
                    .highlight-box,
                    .selection-box,
                    .text-highlight,
                    .selection-highlight,
                    /* 悬浮按钮和工具提示 */
                    .floating-button,
                    .hover-button,
                    .popup-button,
                    .tooltip,
                    .popover,
                    /* Material Design 相关选择元素 */
                    .md-typeset .md-button--primary,
                    .md-typeset .md-button--secondary,
                    /* 保留评论相关选择器 - 注释掉 */
                    /*
                    [class*="comment"],
                    [id*="comment"],
                    [class*="discuss"],
                    [id*="discuss"],
                    */
                    /* 通用选择和工具提示相关 */
                    [class*="selection"],
                    [id*="selection"],
                    [class*="tooltip"],
                    [id*="tooltip"],
                    [class*="popup"],
                    [id*="popup"],
                    [class*="hover"],
                    [id*="hover"] {
                        display: none !important;
                        visibility: hidden !important;
                        opacity: 0 !important;
                        height: 0 !important;
                        width: 0 !important;
                        overflow: hidden !important;
                        position: absolute !important;
                        left: -9999px !important;
                    }
                `;
                
                // 如果样式已存在，先移除再添加
                const existingStyle = document.getElementById('hide-comments-style');
                if (existingStyle) {
                    existingStyle.remove();
                }
                
                style.id = 'hide-comments-style';
                document.head.appendChild(style);
                
                // 移除所有评论相关和文字选择相关的DOM元素
                const elementsToRemove = document.querySelectorAll([
                    // 评论系统相关元素
                    '.giscus',
                    '#giscus-container', 
                    '.utterances',
                    '#utterances-container',
                    '.gitalk-container',
                    '#gitalk-container',
                    '.valine',
                    '#valine',
                    '.disqus',
                    '#disqus_thread',
                    // 评论按钮相关元素
                    '.md-content__button',
                    '[data-md-component="content"] button',
                    'button[title*="评论"]',
                    'button[title*="comment"]',
                    'button[aria-label*="评论"]',
                    'button[aria-label*="comment"]',
                    'button[data-md-component="comments"]',
                    '.md-header__button[data-md-component="comments"]',
                    '.md-header__option[data-md-component="comments"]',
                    '.md-footer-meta__inner button',
                    '.md-footer__inner button',
                    'button[data-toggle="comments"]',
                    'a[href*="comment"]',
                    'a[onclick*="comment"]',
                    '.giscus-frame',
                    '.utterances-frame',
                    // 评论容器相关元素
                    '.comment-box',
                    '.comments-section',
                    '.comments-container',
                    '.comment-form',
                    '.comment-input',
                    '[class*="comment"]',
                    '[id*="comment"]',
                    'iframe[src*="giscus"]',
                    'iframe[src*="utterances"]',
                    'iframe[src*="disqus"]',
                    // 文字选择相关UI元素
                    '.md-tooltip',
                    '.md-tooltip__inner',
                    '.md-annotation',
                    '.md-annotation__index',
                    '.md-annotation__list',
                    '.md-select',
                    '.md-select__inner',
                    '.md-clipboard',
                    '.md-clipboard__message',
                    // 选择工具和弹出框
                    '.selection-toolbar',
                    '.text-selection-toolbar',
                    '.selection-popup',
                    '.selection-menu',
                    '.highlight-box',
                    '.selection-box',
                    '.text-highlight',
                    '.selection-highlight',
                    // 悬浮按钮和工具提示
                    '.floating-button',
                    '.hover-button',
                    '.popup-button',
                    '.tooltip',
                    '.popover',
                    // 保留评论元素 - 注释掉通用评论选择器
                    // '[class*="comment"]:not(.md-content):not(.md-main):not(.md-nav):not(.md-sidebar)',
                    // '[id*="comment"]', 
                    // '[class*="discuss"]',
                    // '[id*="discuss"]',
                    // 通用选择和工具提示相关
                    '[class*="selection"]',
                    '[id*="selection"]',
                    '[class*="tooltip"]',
                    '[id*="tooltip"]',
                    '[class*="popup"]',
                    '[id*="popup"]',
                    '[class*="hover"]',
                    '[id*="hover"]'
                ].join(', '));
                
                elementsToRemove.forEach(element => {
                    if (element && element.parentNode) {
                        element.parentNode.removeChild(element);
                    }
                });
                
                // 保留评论按钮 - 注释掉特殊处理逻辑
                // const allButtons = document.querySelectorAll('button, a[role="button"], .button, [class*="btn"]');
                // allButtons.forEach(button => {
                //     const text = button.textContent || button.innerText || '';
                //     const title = button.title || '';
                //     const ariaLabel = button.getAttribute('aria-label') || '';
                //     
                //     if (text.includes('评论') || text.includes('comment') || 
                //         title.includes('评论') || title.includes('comment') ||
                //         ariaLabel.includes('评论') || ariaLabel.includes('comment')) {
                //         if (button.parentNode) {
                //             button.parentNode.removeChild(button);
                //         }
                //     }
                // });
                
                console.log('已移除文字选择相关UI元素，保留评论功能');
            }
            
            // 添加强制隐藏样式 - 最强力的隐藏方案
            function addForceHideStyles() {
                const forceHideStyle = document.createElement('style');
                forceHideStyle.id = 'force-hide-selection-elements';
                forceHideStyle.textContent = `
                    /* 强制隐藏任何可能的弹出、选择、工具提示元素 */
                    .tippy-box,
                    .tippy-content,
                    .tippy-popper,
                    [class*="tippy"],
                    [data-tippy-root],
                    .popper,
                    [class*="popper"],
                    [data-popper-placement],
                    .floating-ui,
                    [class*="floating"]:not(.md-nav):not(.md-header):not(.md-sidebar),
                    .overlay:not(.md-overlay):not(.md-search__overlay),
                    [class*="overlay"]:not(.md-overlay):not(.md-search__overlay),
                    .dropdown:not(.md-nav__item--nested),
                    [class*="dropdown"]:not(.md-nav__item--nested),
                    .contextmenu,
                    [class*="contextmenu"],
                    .toolbar:not(.md-header):not(.md-nav),
                    [class*="toolbar"]:not(.md-header):not(.md-nav),
                    .selection-toolbar,
                    .text-selection-toolbar,
                    .selection-popup,
                    .selection-menu,
                    .selection-box,
                    .highlight-box,
                    .text-highlight,
                    .selection-highlight,
                    .tooltip:not(.md-nav__link),
                    .popover,
                    .hover-button,
                    .floating-button,
                    .popup-button,
                    [role="tooltip"]:not(.md-nav__link),
                    [role="popup"],
                    [data-tooltip],
                    [data-popup],
                    /* 绝对定位的可疑元素 */
                    body > div[style*="position: absolute"]:not([class*="md-"]),
                    body > div[style*="position: fixed"]:not([class*="md-"]),
                    body > div[class*="portal"],
                    /* 任何z-index很高的元素（除了MkDocs自身元素） */
                    div[style*="z-index: 9"]:not([class*="md-"]),
                    div[style*="z-index: 1000"]:not([class*="md-"]),
                    div[style*="z-index: 2000"]:not([class*="md-"]) {
                        display: none !important;
                        visibility: hidden !important;
                        opacity: 0 !important;
                        height: 0 !important;
                        width: 0 !important;
                        overflow: hidden !important;
                        position: absolute !important;
                        left: -99999px !important;
                        top: -99999px !important;
                        z-index: -999999 !important;
                        pointer-events: none !important;
                        transform: scale(0) !important;
                        clip: rect(0,0,0,0) !important;
                        border: none !important;
                        padding: 0 !important;
                        margin: 0 !important;
                    }
                    
                    /* 完全禁用文字选择高亮 */
                    * {
                        -webkit-user-select: none !important;
                        -moz-user-select: none !important;
                        -ms-user-select: none !important;
                        user-select: none !important;
                    }
                    
                    /* 允许正常内容区域的文字选择 */
                    .md-content__inner * {
                        -webkit-user-select: text !important;
                        -moz-user-select: text !important;
                        -ms-user-select: text !important;
                        user-select: text !important;
                    }
                    
                    /* 但是禁用选择高亮效果 */
                    ::selection {
                        background: transparent !important;
                        color: inherit !important;
                    }
                    ::-moz-selection {
                        background: transparent !important;
                        color: inherit !important;
                    }
                `;
                
                // 移除已存在的强制隐藏样式
                const existing = document.getElementById('force-hide-selection-elements');
                if (existing) existing.remove();
                
                document.head.appendChild(forceHideStyle);
                console.log('已添加强制隐藏样式');
            }
            
            // 强制移除所有可疑的弹出元素
            function forceRemoveSuspiciousElements() {
                // 查找所有可能的弹出元素
                const suspiciousSelectors = [
                    'div[style*="position: absolute"]',
                    'div[style*="position: fixed"]',
                    'div[style*="z-index"]',
                    '[class*="tippy"]',
                    '[class*="popper"]',
                    '[class*="floating"]',
                    '[class*="overlay"]',
                    '[class*="dropdown"]',
                    '[class*="tooltip"]',
                    '[class*="popup"]',
                    '[class*="selection"]',
                    '[class*="hover"]',
                    '[data-tippy-root]',
                    '[data-popper-placement]',
                    '[role="tooltip"]',
                    '[role="popup"]'
                ];
                
                suspiciousSelectors.forEach(selector => {
                    try {
                        const elements = document.querySelectorAll(selector);
                        elements.forEach(element => {
                            // 跳过MkDocs自身的元素
                            if (element.className && element.className.includes('md-')) {
                                return;
                            }
                            
                            // 跳过主要内容区域
                            if (element.closest('.md-content') || 
                                element.closest('.md-nav') || 
                                element.closest('.md-header') ||
                                element.closest('.md-sidebar')) {
                                return;
                            }
                            
                            if (element && element.parentNode) {
                                element.parentNode.removeChild(element);
                            }
                        });
                    } catch (e) {
                        console.log('移除可疑元素时出错:', selector, e);
                    }
                });
                
                console.log('已强制移除所有可疑的弹出元素');
            }
            
            // 禁用文字选择相关的交互功能
            function disableTextSelectionFeatures() {
                // 禁用文字选择后的上下文菜单和工具栏
                document.addEventListener('selectionchange', function(e) {
                    // 延迟执行，确保选择相关的UI元素被创建后立即移除
                    setTimeout(() => {
                        const selectionElements = document.querySelectorAll([
                            '.md-tooltip',
                            '.selection-toolbar',
                            '.text-selection-toolbar',
                            '.selection-popup',
                            '.hover-button',
                            '.floating-button',
                            '[class*="selection"]',
                            '[class*="tooltip"]',
                            '[class*="popup"]'
                        ].join(', '));
                        
                        selectionElements.forEach(element => {
                            if (element && element.parentNode) {
                                element.parentNode.removeChild(element);
                            }
                        });
                    }, 10);
                }, true);
                
                // 禁用鼠标悬停事件
                document.addEventListener('mouseover', function(e) {
                    // 移除可能因为悬停而出现的工具提示
                    setTimeout(() => {
                        const hoverElements = document.querySelectorAll([
                            '.tooltip',
                            '.popover',
                            '.hover-button',
                            '[class*="hover"]',
                            '[class*="tooltip"]'
                        ].join(', '));
                        
                        hoverElements.forEach(element => {
                            if (element && element.parentNode) {
                                element.parentNode.removeChild(element);
                            }
                        });
                    }, 50);
                }, true);
                
                console.log('已禁用文字选择相关交互功能');
            }
            
            // 彻底禁用评论功能的交互性 - 完全阻止点击事件
            function disableCommentInteractions() {
                // 更全面的评论相关选择器
                const commentSelectors = [
                    '.md-content__button',
                    '[data-md-component="content"] button',
                    'button[title*="评论"]',
                    'button[title*="comment"]', 
                    'button[aria-label*="评论"]',
                    'button[aria-label*="comment"]',
                    '.md-content__button[data-md-component="comments"]',
                    'button[data-md-component="comments"]',
                    '.md-header__button[data-md-component="comments"]',
                    '.md-header__option[data-md-component="comments"]',
                    '.md-content__inner .md-content__button',
                    '[class*="comment"] button',
                    '[id*="comment"] button',
                    '.comment-button',
                    '.comments-toggle',
                    '.comment-form button',
                    '.comment-submit',
                    // 添加更多可能的选择器
                    '.md-footer-meta__inner button',
                    '.md-footer__inner button',
                    'button[data-toggle="comments"]',
                    'a[href*="comment"]',
                    'a[onclick*="comment"]',
                    '.giscus-frame',
                    '.utterances-frame'
                ];
                
                // 第一步：完全移除评论相关元素
                commentSelectors.forEach(selector => {
                    try {
                        const elements = document.querySelectorAll(selector);
                        elements.forEach(element => {
                            // 直接移除元素而不是禁用
                            if (element.parentNode) {
                                element.parentNode.removeChild(element);
                            }
                        });
                    } catch (error) {
                        console.log('移除评论按钮时出错:', error);
                    }
                });
                
                // 第二步：对剩余的可疑元素进行最强力的禁用
                const suspiciousSelectors = [
                    'button',
                    'a[href]',
                    '[onclick]',
                    '[data-toggle]',
                    '.clickable',
                    '[role="button"]'
                ];
                
                suspiciousSelectors.forEach(selector => {
                    try {
                        const elements = document.querySelectorAll(selector);
                        elements.forEach(element => {
                            const text = element.textContent?.toLowerCase() || '';
                            const title = element.title?.toLowerCase() || '';
                            const ariaLabel = element.getAttribute('aria-label')?.toLowerCase() || '';
                            const className = element.className?.toLowerCase() || '';
                            const id = element.id?.toLowerCase() || '';
                            const href = element.href?.toLowerCase() || '';
                            
                            // 检查是否与评论相关
                            const commentKeywords = ['comment', '评论', 'discuss', '讨论', 'giscus', 'utterances', 'disqus', 'gitalk'];
                            const isCommentRelated = commentKeywords.some(keyword => 
                                text.includes(keyword) || 
                                title.includes(keyword) || 
                                ariaLabel.includes(keyword) || 
                                className.includes(keyword) || 
                                id.includes(keyword) || 
                                href.includes(keyword)
                            );
                            
                            if (isCommentRelated) {
                                // 方法1：直接移除
                                try {
                                    if (element.parentNode) {
                                        element.parentNode.removeChild(element);
                                        return;
                                    }
                                } catch (e) {}
                                
                                // 方法2：如果无法移除，则彻底禁用
                                element.style.display = 'none !important';
                                element.style.visibility = 'hidden !important';
                                element.style.pointerEvents = 'none !important';
                                element.disabled = true;
                                element.setAttribute('disabled', 'true');
                                element.setAttribute('aria-disabled', 'true');
                                
                                // 移除所有事件监听器
                                const newElement = element.cloneNode(true);
                                try {
                                    element.parentNode.replaceChild(newElement, element);
                                    
                                    // 在新元素上添加强制阻止事件
                                    ['click', 'mousedown', 'mouseup', 'touchstart', 'touchend', 'pointerdown', 'pointerup', 'focus', 'blur'].forEach(eventType => {
                                        newElement.addEventListener(eventType, function(e) {
                                            e.preventDefault();
                                            e.stopPropagation();
                                            e.stopImmediatePropagation();
                                            console.log('评论功能已被彻底禁用:', eventType);
                                            return false;
                                        }, {
                                            passive: false,
                                            capture: true
                                        });
                                    });
                                    
                                    // 彻底隐藏
                                    newElement.style.display = 'none';
                                    newElement.style.visibility = 'hidden';
                                    newElement.style.opacity = '0';
                                    newElement.style.pointerEvents = 'none';
                                    
                                } catch (replaceError) {
                                    console.log('替换元素失败，直接隐藏:', replaceError);
                                    element.style.display = 'none';
                                }
                            }
                        });
                    } catch (error) {
                        console.log('处理可疑元素时出错:', error);
                    }
                });
                
                // 第三步：移除评论容器
                const commentContainers = [
                    '.giscus',
                    '#giscus-container', 
                    '.utterances',
                    '#utterances-container',
                    '.gitalk-container',
                    '#gitalk-container',
                    '.valine',
                    '#valine',
                    '.disqus',
                    '#disqus_thread',
                    '.comment-box',
                    '.comments-section',
                    '.comments-container',
                    '.comment-form',
                    '[class*="comment"]',
                    '[id*="comment"]'
                ];
                
                commentContainers.forEach(selector => {
                    try {
                        const elements = document.querySelectorAll(selector);
                        elements.forEach(element => {
                            // 直接移除整个容器
                            if (element.parentNode) {
                                element.parentNode.removeChild(element);
                            }
                        });
                    } catch (error) {
                        console.log('移除评论容器时出错:', error);
                    }
                });
                
                // 第四步：阻止页面级别的事件冒泡
                document.addEventListener('click', function(e) {
                    const target = e.target;
                    if (target) {
                        const text = target.textContent?.toLowerCase() || '';
                        const className = target.className?.toLowerCase() || '';
                        const id = target.id?.toLowerCase() || '';
                        const tagName = target.tagName?.toLowerCase() || '';
                        
                        const commentKeywords = ['comment', '评论', 'discuss', '讨论', 'giscus', 'utterances'];
                        const isCommentRelated = commentKeywords.some(keyword => 
                            text.includes(keyword) || 
                            className.includes(keyword) || 
                            id.includes(keyword)
                        ) || (tagName === 'button' && text.trim() === '');
                        
                        if (isCommentRelated) {
                            e.preventDefault();
                            e.stopPropagation();
                            e.stopImmediatePropagation();
                            console.log('阻止了评论相关的点击事件');
                            return false;
                        }
                    }
                }, {
                    passive: false,
                    capture: true
                });
                
                console.log('已彻底禁用所有评论功能');
            }
            
            // 立即执行 - 使用最强力的方案
            addForceHideStyles();
            removeTextSelectionElements();
            forceRemoveSuspiciousElements();
            disableTextSelectionFeatures();
            disableCommentInteractions();
            
            // 页面加载完成后执行
            if (document.readyState === 'complete') {
                addForceHideStyles();
                removeTextSelectionElements();
                forceRemoveSuspiciousElements();
                disableTextSelectionFeatures();
                disableCommentInteractions();
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    addForceHideStyles();
                    removeTextSelectionElements();
                    forceRemoveSuspiciousElements();
                    disableTextSelectionFeatures();
                    disableCommentInteractions();
                });
                window.addEventListener('load', function() {
                    addForceHideStyles();
                    removeTextSelectionElements();
                    forceRemoveSuspiciousElements();
                    disableTextSelectionFeatures();
                    disableCommentInteractions();
                });
            }
            
            // 延迟执行，确保动态内容加载完成
            setTimeout(() => {
                addForceHideStyles();
                removeTextSelectionElements();
                forceRemoveSuspiciousElements();
                disableTextSelectionFeatures();
                disableCommentInteractions();
            }, 500);
            setTimeout(() => {
                addForceHideStyles();
                removeTextSelectionElements();
                forceRemoveSuspiciousElements();
                disableTextSelectionFeatures();
                disableCommentInteractions();
            }, 1500);
            setTimeout(() => {
                addForceHideStyles();
                removeTextSelectionElements();
                forceRemoveSuspiciousElements();
                disableTextSelectionFeatures();
                disableCommentInteractions();
            }, 3000);
            
            // 监听DOM变化，立即移除动态添加的评论元素
            const observer = new MutationObserver(function(mutations) {
                let shouldRemove = false;
                let addedCommentElements = [];
                
                mutations.forEach(function(mutation) {
                    if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                        mutation.addedNodes.forEach(node => {
                            if (node.nodeType === 1) { // Element node
                                const className = (node.className || '').toLowerCase();
                                const id = (node.id || '').toLowerCase();
                                const tagName = (node.tagName || '').toLowerCase();
                                const textContent = (node.textContent || '').toLowerCase();
                                
                                // 检查是否为评论相关元素
                                const commentKeywords = ['comment', '评论', 'giscus', 'utterances', 'disqus', 'gitalk', 'valine'];
                                const isCommentElement = commentKeywords.some(keyword => 
                                    className.includes(keyword) || 
                                    id.includes(keyword) || 
                                    textContent.includes(keyword)
                                ) || (tagName === 'button' && (
                                    textContent.includes('评论') || 
                                    textContent.includes('comment') ||
                                    className.includes('md-content__button')
                                )) || (tagName === 'iframe' && (
                                    node.src && (
                                        node.src.includes('giscus') || 
                                        node.src.includes('utterances') || 
                                        node.src.includes('disqus')
                                    )
                                ));
                                
                                if (isCommentElement) {
                                    shouldRemove = true;
                                    addedCommentElements.push(node);
                                    
                                    // 立即移除该元素
                                    try {
                                        if (node.parentNode) {
                                            node.parentNode.removeChild(node);
                                        }
                                    } catch (e) {
                                        // 如果无法移除，立即隐藏
                                        node.style.display = 'none';
                                        node.style.visibility = 'hidden';
                                        node.style.pointerEvents = 'none';
                                    }
                                }
                                
                                // 检查子元素中是否包含评论相关内容
                                if (node.querySelectorAll) {
                                    const commentSelectors = [
                                        '.giscus', '#giscus-container', '.utterances', '#utterances-container',
                                        '.gitalk-container', '#gitalk-container', '.valine', '#valine',
                                        '.disqus', '#disqus_thread', '.md-content__button',
                                        'button[title*="评论"]', 'button[title*="comment"]',
                                        'button[aria-label*="评论"]', 'button[aria-label*="comment"]',
                                        'button[data-md-component="comments"]', '.comment-box',
                                        '.comments-section', '.comments-container', '.comment-form',
                                        '[class*="comment"]', '[id*="comment"]',
                                        'iframe[src*="giscus"]', 'iframe[src*="utterances"]', 'iframe[src*="disqus"]'
                                    ];
                                    
                                    commentSelectors.forEach(selector => {
                                        try {
                                            const childComments = node.querySelectorAll(selector);
                                            childComments.forEach(childNode => {
                                                shouldRemove = true;
                                                try {
                                                    if (childNode.parentNode) {
                                                        childNode.parentNode.removeChild(childNode);
                                                    }
                                                } catch (e) {
                                                    childNode.style.display = 'none';
                                                    childNode.style.visibility = 'hidden';
                                                    childNode.style.pointerEvents = 'none';
                                                }
                                            });
                                        } catch (e) {}
                                    });
                                }
                            }
                        });
                    }
                });
                
                if (shouldRemove) {
                    // 立即运行清理函数
                    setTimeout(() => {
                        addForceHideStyles();
                        removeTextSelectionElements();
                        forceRemoveSuspiciousElements();
                        disableTextSelectionFeatures();
                        disableCommentInteractions();
                    }, 10);
                    
                    // 再次延迟运行，确保彻底清理
                    setTimeout(() => {
                        addForceHideStyles();
                        removeTextSelectionElements();
                        forceRemoveSuspiciousElements();
                        disableTextSelectionFeatures();
                        disableCommentInteractions();
                    }, 100);
                }
            });
            
            observer.observe(document.body, { 
                childList: true, 
                subtree: true,
                attributes: true,
                attributeFilter: ['class', 'id', 'data-md-component']
            });
            
            // 页面滚动时检查，防止懒加载的评论元素和选择元素
            let scrollTimer;
            window.addEventListener('scroll', function() {
                clearTimeout(scrollTimer);
                scrollTimer = setTimeout(() => {
                    addForceHideStyles();
                    removeTextSelectionElements();
                    forceRemoveSuspiciousElements();
                    disableTextSelectionFeatures();
                }, 200);
            });
            
            // 添加更频繁的检查 - 每秒检查一次
            setInterval(() => {
                forceRemoveSuspiciousElements();
            }, 1000);
            """
            
            webView.evaluateJavaScript(hideCommentsScript, completionHandler: nil)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        // 禁止打开新窗口
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // 在当前WebView中加载，而不是创建新窗口
            if let url = navigationAction.request.url {
                if let host = url.host, ["oi-wiki.org", "www.oi-wiki.org"].contains(host) {
                    webView.load(navigationAction.request)
                }
            }
            return nil
        }
    }
}

#Preview {
    NavigationView {
        OIWikiView()
    }
}
