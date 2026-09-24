//
// Copyright 2026 Whistlepig
//

import SwiftUI

/// A deliberately light-weight welcome mark. It is not the app icon enlarged:
/// its translucent mounting surface gives the mark room to breathe.
struct AuthenticationStartLogo: View {
    var size: CGFloat?
    let hideBrandChrome: Bool
    let isOnGradient: Bool
    
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    
    private var markSize: CGFloat {
        size ?? 112
    }
    
    var body: some View {
        Image(asset: Asset.Images.whistlepigWelcomeMark)
            .resizable()
            .scaledToFit()
            .frame(width: markSize, height: markSize)
            .padding(markSize * 0.14)
            .background {
                Circle()
                    .fill(reduceTransparency ? Color.accentColor.opacity(0.12) : Color.clear)
                    .background {
                        if !reduceTransparency {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(colorScheme == .dark ? 0.18 : 0.5), lineWidth: 0.75)
                    }
            }
            .shadow(color: Color.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.09), radius: 18, y: 8)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 28) {
        AuthenticationStartLogo(hideBrandChrome: false, isOnGradient: true)
        AuthenticationStartLogo(size: 64, hideBrandChrome: false, isOnGradient: false)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AuthenticationStartScreenBackgroundImage())
}
