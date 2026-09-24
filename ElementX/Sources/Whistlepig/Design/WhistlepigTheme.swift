//
// Copyright 2026 Whistlepig
//

import SwiftUI
import UIKit

/// Semantic surfaces owned by Whistlepig. Feature views consume these names instead of palette values.
enum WhistlepigTheme {
    enum ColorToken {
        static let canvas = Color(uiColor: .systemBackground)
        static let elevated = Color(uiColor: .secondarySystemBackground)
        static let glassFallback = Color(uiColor: .tertiarySystemBackground)
        static let separator = Color(uiColor: .separator)
        
        static var accentPrimary: Color {
            WhistlepigAccent.current.primary
        }
        
        static let accentSecondary = Color(red: 92 / 255, green: 207 / 255, blue: 196 / 255)
        static var accentSoft: Color {
            WhistlepigAccent.current.soft
        }
        
        static let messageIncoming = Color(uiColor: .secondarySystemBackground)
        static var messageOutgoing: Color {
            accentSoft
        }
        
        static let reactionNormal = Color(uiColor: .tertiarySystemFill)
        static var reactionSelected: Color {
            accentSoft
        }
        
        static let unreadMuted = Color(uiColor: .systemGray)
        
        static let textPrimary = Color(uiColor: .label)
        static let textSecondary = Color(uiColor: .secondaryLabel)
        static let textTertiary = Color(uiColor: .tertiaryLabel)
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }
    
    enum Radius {
        static let control: CGFloat = 11
        static let reaction: CGFloat = 12
        static let media: CGFloat = 16
        static let message: CGFloat = 18
        static let floatingSurface: CGFloat = 22
    }
}

extension View {
    @ViewBuilder
    func whistlepigGlassSurface<S: Shape>(_ shape: S, interactive: Bool = false) -> some View {
        if #available(iOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(WhistlepigTheme.ColorToken.separator.opacity(0.16), lineWidth: 0.5))
        }
    }
}

/// The warm, earth-toned primary action used throughout Whistlepig-owned flows.
enum WhistlepigBrand {
    static let marmotBrown = Color(red: 112 / 255, green: 78 / 255, blue: 59 / 255)
    static let marmotBrownPressed = Color(red: 88 / 255, green: 60 / 255, blue: 45 / 255)
    static let marmotMist = Color(red: 112 / 255, green: 78 / 255, blue: 59 / 255).opacity(0.13)
}

struct WhistlepigChatAmbientBackground: View {
    var includesCanvas = true
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    private var glowOpacity: Double {
        guard !reduceTransparency else { return 0.069 }
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return colorScheme == .dark ? 0.176 : 0.089
        }
        return colorScheme == .dark ? 0.546 : 0.273
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            if includesCanvas {
                Color(uiColor: .systemBackground)
            }
            RadialGradient(colors: [WhistlepigTheme.ColorToken.accentPrimary.opacity(glowOpacity),
                                    WhistlepigTheme.ColorToken.accentPrimary.opacity(glowOpacity * 0.42),
                                    WhistlepigTheme.ColorToken.accentPrimary.opacity(glowOpacity * 0.10),
                                    .clear],
                           center: .top,
                           startRadius: 0,
                           endRadius: 560)
                .frame(height: 276)
                .frame(maxWidth: .infinity, alignment: .top)
                .compositingGroup()
                .mask {
                    LinearGradient(stops: [.init(color: .white, location: 0),
                                           .init(color: .white.opacity(0.88), location: 0.26),
                                           .init(color: .white.opacity(0.34), location: 0.68),
                                           .init(color: .clear, location: 1)],
                                   startPoint: .top,
                                   endPoint: .bottom)
                }
        }
        .ignoresSafeArea()
    }
}

/// A light native-material fade keeps scrolling content visually behind the floating header.
struct WhistlepigChatHeaderBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        Group {
            if reduceTransparency {
                Color(uiColor: .systemBackground).opacity(0.9)
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
        .mask {
            LinearGradient(colors: [.black, .black.opacity(0.68), .clear],
                           startPoint: .top,
                           endPoint: .bottom)
        }
        .frame(height: 132)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

struct WhistlepigPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.compound.bodyLGSemibold)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background {
                Capsule()
                    .fill(isEnabled ? (configuration.isPressed ? WhistlepigBrand.marmotBrownPressed : WhistlepigBrand.marmotBrown) : Color(uiColor: .systemGray3))
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}
