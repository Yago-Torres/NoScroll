import SwiftUI
import WebKit

struct Site {
    let url: URL
    /// Rutas que no se abren nunca.
    let blocked: [String]
    /// CSS que esconde los puntos de entrada al scroll infinito.
    let css: String
}

struct Shell: View {
    let site: Site
    var body: some View {
        WebView(site: site).ignoresSafeArea(edges: .bottom)
    }
}

struct WebView: UIViewRepresentable {
    let site: Site

    func makeCoordinator() -> Coordinator { Coordinator(site: site) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // sesion persistente: el login aguanta
        config.allowsInlineMediaPlayback = true
        // Inyectado en cada navegacion, incluidas las de la SPA.
        let js = """
        (function(){
          var id='noscroll-css';
          function put(){
            if(document.getElementById(id)||!document.head) return;
            var s=document.createElement('style'); s.id=id;
            s.textContent=\(Self.jsLiteral(site.css));
            document.head.appendChild(s);
          }
          put();
          new MutationObserver(put).observe(document.documentElement,{childList:true});
        })();
        """
        config.userContentController.addUserScript(
            WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.load(URLRequest(url: site.url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    /// JSONEncoder sobre un String da siempre un literal JS valido.
    static func jsLiteral(_ s: String) -> String {
        String(data: try! JSONEncoder().encode(s), encoding: .utf8)!
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let site: Site
        init(site: Site) { self.site = site }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let path = navigationAction.request.url?.path ?? ""
            decisionHandler(site.blocked.contains(where: path.contains) ? .cancel : .allow)
        }
    }
}
