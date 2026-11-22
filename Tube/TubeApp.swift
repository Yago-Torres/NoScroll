import SwiftUI

extension Site {
    static let youtube = Site(
        url: URL(string: "https://m.youtube.com/")!,
        blocked: ["/shorts/"],
        css: """
        ytm-pivot-bar-item-renderer[tab-identifier="FEshorts"],
        ytm-reel-shelf-renderer,
        ytm-rich-section-renderer:has(ytm-reel-shelf-renderer),
        ytm-shorts-lockup-view-model, ytm-shorts-lockup-view-model-v2,
        [class*="shortsLockup"],
        ytm-item-section-renderer:has(a[href^="/shorts/"]),
        ytm-video-with-context-renderer:has(a[href^="/shorts/"]),
        grid-shelf-view-model:has(a[href^="/shorts/"]) { display: none !important; }
        """)
}

@main
struct TubeApp: App {
    var body: some Scene { WindowGroup { Shell(site: .youtube) } }
}
