import SwiftUI

extension Site {
    static let instagram = Site(
        url: URL(string: "https://www.instagram.com/")!,
        blocked: ["/reels/", "/reel/"],
        css: """
        a[href^="/reels"], a[href*="/reels/"],
        [role="tablist"] a[href*="/reels"],
        section:has(> a[href*="/reel/"]),
        article:has(a[href*="/reel/"]),
        div[style*="flex-direction"]:has(> a[href*="/reel/"]) { display: none !important; }
        """)
}

@main
struct InstaApp: App {
    var body: some Scene { WindowGroup { Shell(site: .instagram) } }
}
