//
// Copyright 2026 Whistlepig
//

import SwiftUI

struct WhistlepigChatHeader: View {
    let roomName: String
    let roomAvatar: RoomAvatar
    let subtitle: String?
    let mediaProvider: MediaProviderProtocol?
    let onBack: () -> Void
    let onDetails: () -> Void
    let showCall: Bool
    let showThreads: Bool
    let onCall: (() -> Void)?
    let onThreads: (() -> Void)?
    /// In a regular-width split the detail sits side-by-side with the list,
    /// so there is nowhere to go back to and the button would be dead.
    var showsBackButton = true
    
    var body: some View {
        HStack(spacing: WhistlepigTheme.Spacing.sm) {
            if showsBackButton {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.actionBack)
            }
            
            Button(action: onDetails) {
                HStack(spacing: WhistlepigTheme.Spacing.sm) {
                    RoomAvatarImage(avatar: roomAvatar,
                                    avatarSize: .custom(32),
                                    mediaProvider: mediaProvider)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(roomName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
                            .lineLimit(1)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(WhistlepigTheme.ColorToken.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel(roomName)
            
            Menu {
                if showCall, let onCall {
                    Button(action: onCall) {
                        Label("Voice call", systemImage: "phone")
                    }
                }
                if showThreads, let onThreads {
                    Button(action: onThreads) {
                        Label("Threads", systemImage: "bubble.left.and.bubble.right")
                    }
                }
                Button(action: onDetails) {
                    Label(L10n.commonSettings, systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.commonSettings)
        }
        .padding(.horizontal, WhistlepigTheme.Spacing.sm)
        .frame(height: 52)
        .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
        .whistlepigGlassSurface(RoundedRectangle(cornerRadius: WhistlepigTheme.Radius.floatingSurface, style: .continuous), interactive: true)
        .padding(.horizontal, 10)
    }
}
