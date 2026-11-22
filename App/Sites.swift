import SwiftUI

extension Site {
    static let instagram = Site(
        name: "Insta",
        icon: "camera",
        url: URL(string: "https://www.instagram.com/")!,
        blocked: ["/reels/", "/reel/"],
        css: """
        a[href^="/reels"], a[href*="/reels/"],
        [role="tablist"] a[href*="/reels"],
        section:has(> a[href*="/reel/"]),
        article:has(a[href*="/reel/"]),
        div[style*="flex-direction"]:has(> a[href*="/reel/"]) { display: none !important; }
        """)

    static let youtube = Site(
        name: "Tube",
        icon: "play.rectangle",
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
        """,
        backgroundAudio: true)
}

@main
struct NoScrollApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ForEach([Site.instagram, .youtube], id: \.name) { site in
                    Shell(site: site)
                        .tabItem { Label(site.name, systemImage: site.icon) }
                }
            }
        }
    }
}
