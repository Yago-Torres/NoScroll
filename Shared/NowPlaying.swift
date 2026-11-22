import MediaPlayer
import WebKit

/// Pinta el video en la pantalla de bloqueo y enruta sus botones al <video> de la web.
final class NowPlaying: NSObject, WKScriptMessageHandler {
    static let handlerName = "media"

    private weak var web: WKWebView?
    private var artURL: String?

    init(web: WKWebView) {
        self.web = web
        super.init()

        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.run("v.play()") ?? .commandFailed }
        c.pauseCommand.addTarget { [weak self] _ in self?.run("v.pause()") ?? .commandFailed }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.run("v.paused ? v.play() : v.pause()") ?? .commandFailed
        }
        for (cmd, delta) in [(c.skipForwardCommand, 15.0), (c.skipBackwardCommand, -15.0)] {
            cmd.preferredIntervals = [15]
            cmd.addTarget { [weak self] _ in self?.run("v.currentTime += \(delta)") ?? .commandFailed }
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            return self?.run("v.currentTime = \(e.positionTime)") ?? .commandFailed
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    @discardableResult
    private func run(_ js: String) -> MPRemoteCommandHandlerStatus {
        web?.evaluateJavaScript("(function(){var v=document.querySelector('video');if(v){\(js)}})()")
        return .success
    }

    func userContentController(_ u: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let d = message.body as? [String: Any] else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: d["title"] as? String ?? "",
            MPMediaItemPropertyArtist: d["author"] as? String ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: d["time"] as? Double ?? 0,
            MPMediaItemPropertyPlaybackDuration: d["duration"] as? Double ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: d["rate"] as? Double ?? 0,
            MPNowPlayingInfoPropertyIsLiveStream: (d["duration"] as? Double ?? 0) == 0,
        ]
        let center = MPNowPlayingInfoCenter.default()
        if let art = center.nowPlayingInfo?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork,
           artURL == d["art"] as? String {
            info[MPMediaItemPropertyArtwork] = art // la que ya habia, no se redescarga
        }
        center.nowPlayingInfo = info
        loadArtwork(d["art"] as? String)
    }

    /// La miniatura, una sola vez por video.
    private func loadArtwork(_ urlString: String?) {
        guard let urlString, !urlString.isEmpty, urlString != artURL,
              let url = URL(string: urlString) else { return }
        artURL = urlString
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                guard self.artURL == urlString else { return }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] =
                    MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }.resume()
    }
}

extension NowPlaying {
    /// Le cuenta a la pantalla de bloqueo que suena, por donde va y cuanto dura.
    static let reporterJS = """
    (function(){
      var last = 0;
      function send(){
        var v = document.querySelector('video'); if(!v) return;
        var art = document.querySelector('meta[property="og:image"]');
        var author = document.querySelector('link[itemprop="name"]');
        webkit.messageHandlers.\(handlerName).postMessage({
          title: (document.title || '').replace(/ - YouTube$/, ''),
          author: author ? author.content : '',
          time: v.currentTime || 0,
          duration: isFinite(v.duration) ? v.duration : 0,
          rate: v.paused ? 0 : (v.playbackRate || 1),
          art: art ? art.content : ''
        });
      }
      // Los eventos de <video> no burbujean: hay que escucharlos en captura.
      ['play','pause','seeked','ratechange','loadedmetadata'].forEach(function(e){
        document.addEventListener(e, send, true);
      });
      document.addEventListener('timeupdate', function(){
        var n = Date.now(); if (n - last > 2000) { last = n; send(); }
      }, true);
    })();
    """
}
