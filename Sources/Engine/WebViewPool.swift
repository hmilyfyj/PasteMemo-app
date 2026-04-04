import Foundation
import WebKit

@MainActor
final class WebViewPool {
    static let shared = WebViewPool()
    
    private var availableWebViews: [WKWebView] = []
    private var activeWebViews: [String: WKWebView] = [:]
    private var lruQueue: [String] = []
    
    private let maxPoolSize = 3
    private let maxActiveSize = 5
    
    private var cleanupTimer: Timer?
    
    private init() {
        startCleanupTimer()
    }
    
    // MARK: - Public API
    
    func getWebView(for key: String) -> WKWebView {
        if let active = activeWebViews[key] {
            updateLRU(key)
            return active
        }
        
        if activeWebViews.count >= maxActiveSize {
            evictLRU()
        }
        
        let webView: WKWebView
        if !availableWebViews.isEmpty {
            webView = availableWebViews.removeLast()
        } else {
            webView = createNewWebView()
        }
        
        activeWebViews[key] = webView
        lruQueue.append(key)
        
        return webView
    }
    
    func returnWebView(_ webView: WKWebView, for key: String) {
        guard activeWebViews[key] === webView else { return }
        
        activeWebViews.removeValue(forKey: key)
        lruQueue.removeAll { $0 == key }
        
        resetWebView(webView)
        
        if availableWebViews.count < maxPoolSize {
            availableWebViews.append(webView)
        } else {
            webView.removeFromSuperview()
        }
    }
    
    func clearAll() {
        for webView in activeWebViews.values {
            webView.stopLoading()
            webView.loadHTMLString("", baseURL: nil)
            webView.removeFromSuperview()
        }
        
        for webView in availableWebViews {
            webView.removeFromSuperview()
        }
        
        activeWebViews.removeAll()
        availableWebViews.removeAll()
        lruQueue.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func createNewWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = .all
        
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs
        
        let viewportScript = WKUserScript(
            source: """
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, shrink-to-fit=yes';
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        
        let muteScript = WKUserScript(
            source: """
            document.querySelectorAll('video, audio').forEach(function(el) {
                el.pause();
                el.muted = true;
                el.autoplay = false;
                el.removeAttribute('autoplay');
            });
            var obs = new MutationObserver(function(mutations) {
                document.querySelectorAll('video, audio').forEach(function(el) {
                    el.pause();
                    el.muted = true;
                    el.autoplay = false;
                    el.removeAttribute('autoplay');
                });
            });
            obs.observe(document.body || document.documentElement, { childList: true, subtree: true });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        
        config.userContentController.addUserScript(viewportScript)
        config.userContentController.addUserScript(muteScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsMagnification = true
        webView.allowsBackForwardNavigationGestures = false
        webView.setValue(false, forKey: "drawsBackground")
        
        return webView
    }
    
    private func resetWebView(_ webView: WKWebView) {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.navigationDelegate = nil
    }
    
    private func updateLRU(_ key: String) {
        lruQueue.removeAll { $0 == key }
        lruQueue.append(key)
    }
    
    private func evictLRU() {
        guard !lruQueue.isEmpty else { return }
        
        let key = lruQueue.removeFirst()
        if let webView = activeWebViews.removeValue(forKey: key) {
            resetWebView(webView)
            
            if availableWebViews.count < maxPoolSize {
                availableWebViews.append(webView)
            } else {
                webView.removeFromSuperview()
            }
        }
    }
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performCleanup()
            }
        }
    }
    
    private func performCleanup() {
        let inactiveKeys = activeWebViews.keys.filter { key in
            !lruQueue.suffix(3).contains(key)
        }
        
        for key in inactiveKeys.prefix(2) {
            if let webView = activeWebViews.removeValue(forKey: key) {
                resetWebView(webView)
                
                if availableWebViews.count < maxPoolSize {
                    availableWebViews.append(webView)
                } else {
                    webView.removeFromSuperview()
                }
            }
            lruQueue.removeAll { $0 == key }
        }
    }
    
    // MARK: - Statistics
    
    var activeCount: Int {
        return activeWebViews.count
    }
    
    var availableCount: Int {
        return availableWebViews.count
    }
    
    var totalMemoryUsage: Int {
        let activeMemory = activeWebViews.values.reduce(0) { total, _ in
            return total + 50
        }
        let availableMemory = availableWebViews.reduce(0) { total, _ in
            return total + 30
        }
        return activeMemory + availableMemory
    }
}
