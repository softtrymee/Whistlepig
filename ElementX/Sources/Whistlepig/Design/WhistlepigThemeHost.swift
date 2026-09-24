//
// Copyright 2026 Whistlepig
//

import SwiftUI

struct WhistlepigThemeHost<Content: View>: View {
    let appSettings: AppSettings
    let content: Content
    
    @State private var accent: WhistlepigAccent
    
    init(appSettings: AppSettings, @ViewBuilder content: () -> Content) {
        self.appSettings = appSettings
        self.content = content()
        _accent = State(initialValue: WhistlepigAccent(rawValue: appSettings.whistlepigAccent) ?? .iris)
    }
    
    var body: some View {
        content
            .id(accent)
            .environment(\.whistlepigAccent, accent)
            .tint(accent.primary)
            .onReceive(appSettings.whistlepigAccentPublisher) { accent in
                self.accent = WhistlepigAccent(rawValue: accent) ?? .iris
            }
    }
}
