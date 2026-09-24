//
// Copyright 2026 Whistlepig
//

import SwiftUI

/// A calm, adaptive canvas shared by the splash and authentication screens.
struct AuthenticationStartScreenBackgroundImage: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    
    private var accentOpacity: Double {
        reduceTransparency ? 0.06 : (colorScheme == .dark ? 0.18 : 0.10)
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: colorScheme == .dark ? .systemBackground : .secondarySystemBackground)
            
            LinearGradient(colors: [Color.accentColor.opacity(accentOpacity), .clear],
                           startPoint: .topLeading,
                           endPoint: .center)
            
            Ellipse()
                .fill(Color.accentColor.opacity(accentOpacity))
                .frame(width: 340, height: 250)
                .blur(radius: reduceTransparency ? 18 : 58)
                .offset(x: 120, y: -270)
            
            Ellipse()
                .fill(Color(red: 0.71, green: 0.55, blue: 0.43).opacity(colorScheme == .dark ? 0.09 : 0.045))
                .frame(width: 280, height: 220)
                .blur(radius: reduceTransparency ? 16 : 54)
                .offset(x: -145, y: 310)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
