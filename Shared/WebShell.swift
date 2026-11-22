import SwiftUI
import WebKit
import AVFoundation

struct Site {
    let name: String
    let icon: String
    let url: URL
    /// Rutas que no se abren nunca.
    let blocked: [String]
    /// CSS que esconde los puntos de entrada al scroll infinito.
    let css: String
    /// Sigue sonando con la pantalla apagada o la app en segundo plano.
    var backgroundAudio = false
}

/// Quita los gestos que delatan que esto es un navegador.
private let nativeFeelCSS = """
* { -webkit-touch-callout: none !important; }
html, body { -webkit-user-select: none !important; user-select: none !important;
             overscroll-behavior-y: contain; }
input, textarea, [contenteditable] { -webkit-user-select: text !important; user-select: text !important; }
"""

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
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let ucc = WKUserContentController()
        ucc.addUserScript(script(cssInjector(site.css + nativeFeelCSS)))
        if site.backgroundAudio {
            ucc.addUserScript(script(Self.keepPlayingJS))
            // Sin esto el audio se corta al bloquear la pantalla.
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .moviePlayback)
            try? session.setActive(true)
        }
        config.userContentController = ucc

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.backgroundColor = .systemBackground      // sin flashes blancos en modo oscuro
        web.scrollView.backgroundColor = .systemBackground
        web.load(URLRequest(url: site.url))
        context.coordinator.attach(web)
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func script(_ source: String) -> WKUserScript {
        WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
    }

    /// Reinyecta el CSS en cada navegacion de la SPA.
    private func cssInjector(_ css: String) -> String {
        """
        (function(){
          var id='noscroll-css';
          function put(){
            if(document.getElementById(id)||!document.head) return;
            var s=document.createElement('style'); s.id=id;
            s.textContent=\(Self.jsLiteral(css));
            document.head.appendChild(s);
          }
          put();
          new MutationObserver(put).observe(document.documentElement,{childList:true});
        })();
        """
    }

    /// ponytail: la web pausa el video cuando la pagina se oculta, asi que le mentimos
    /// con la Page Visibility API. Si YouTube cambia de tactica, se arregla aqui.
    private static let keepPlayingJS = """
    (function(){
      var d=document;
      function fake(prop, val){
        try { Object.defineProperty(d, prop, { get: function(){ return val; }, configurable: true }); } catch(e) {}
      }
      fake('hidden', false); fake('webkitHidden', false);
      fake('visibilityState', 'visible'); fake('webkitVisibilityState', 'visible');
      ['visibilitychange','webkitvisibilitychange','pagehide','blur','freeze'].forEach(function(ev){
        var eat = function(e){ e.stopImmediatePropagation(); };
        d.addEventListener(ev, eat, true);
        window.addEventListener(ev, eat, true);
      });
    })();
    """

    /// JSONEncoder sobre un String da siempre un literal JS valido.
    static func jsLiteral(_ s: String) -> String {
        String(data: try! JSONEncoder().encode(s), encoding: .utf8)!
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let site: Site
        private weak var web: WKWebView?
        private var observer: NSObjectProtocol?

        init(site: Site) { self.site = site }

        deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }

        func attach(_ web: WKWebView) {
            self.web = web
            guard site.backgroundAudio else { return }
            // Cinturon y tirantes: si iOS lo pausa igualmente, se le vuelve a dar al play.
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: .main) { [weak self] _ in
                    self?.web?.evaluateJavaScript(
                        "document.querySelectorAll('video').forEach(function(v){ if(!v.ended) v.play(); })")
                }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let path = navigationAction.request.url?.path ?? ""
            decisionHandler(site.blocked.contains(where: path.contains) ? .cancel : .allow)
        }
    }
}
