//
// Copyright 2026 Whistlepig
//

import SwiftUI

struct WhistlepigRoomRow: View {
    let room: HomeScreenRoom
    let mediaProvider: MediaProviderProtocol!
    let isSelected: Bool
    let action: (HomeScreenViewAction) -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    var body: some View {
        Button {
            guard let roomID = room.roomID else { return }
            action(.selectRoom(roomIdentifier: roomID))
        } label: {
            HStack(spacing: WhistlepigTheme.Spacing.md) {
                if dynamicTypeSize < .accessibility3 {
                    roomAvatar
                }
                
                VStack(alignment: .leading, spacing: WhistlepigTheme.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: WhistlepigTheme.Spacing.sm) {
                        roomTitle
                        Spacer(minLength: WhistlepigTheme.Spacing.sm)
                        timestamp
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: WhistlepigTheme.Spacing.sm) {
                        preview
                        Spacer(minLength: WhistlepigTheme.Spacing.sm)
                        status
                    }
                }
                .frame(minHeight: 52, alignment: .center)
            }
            .padding(.horizontal, WhistlepigTheme.Spacing.lg)
            .padding(.vertical, WhistlepigTheme.Spacing.sm + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(WhistlepigRoomRowButtonStyle(isSelected: isSelected))
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                action(room.badges.isDotShown ? .markRoomAsRead(roomIdentifier: room.id) : .markRoomAsUnread(roomIdentifier: room.id))
            } label: {
                Label(room.badges.isDotShown ? L10n.screenRoomlistMarkAsRead : L10n.screenRoomlistMarkAsUnread, systemImage: room.badges.isDotShown ? "checkmark" : "circle")
            }
            .tint(WhistlepigTheme.ColorToken.accentPrimary)
            
            Button {
                action(.markRoomAsFavourite(roomIdentifier: room.id, isFavourite: !room.isFavourite))
            } label: {
                Label(room.isFavourite ? L10n.commonFavourited : L10n.commonFavourite, systemImage: room.isFavourite ? "star.slash" : "star")
            }
            .tint(.orange)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                action(.showRoomDetails(roomIdentifier: room.id))
            } label: {
                Label(L10n.commonSettings, systemImage: "ellipsis")
            }
            .tint(.gray)
            
            Button(role: .destructive) {
                action(.leaveRoom(roomIdentifier: room.id))
            } label: {
                Label(L10n.actionLeaveRoom, systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
        .accessibilityIdentifier(A11yIdentifiers.homeScreen.roomName(room.name))
    }
    
    private var roomAvatar: some View {
        ZStack {
            if room.hasUnreads {
                Circle()
                    .fill(WhistlepigTheme.ColorToken.accentPrimary.opacity(reduceTransparency ? 0.14 : 0.24))
                    .scaleEffect(1.34)
                    .blur(radius: reduceTransparency ? 0 : 9)
                
                Circle()
                    .fill(WhistlepigTheme.ColorToken.accentSoft.opacity(reduceTransparency ? 0.74 : 1))
                    .scaleEffect(1.2)
                    .blur(radius: reduceTransparency ? 0 : 4)
                
                Circle()
                    .stroke(WhistlepigTheme.ColorToken.accentPrimary.opacity(0.76), lineWidth: 2.75)
                    .padding(-2)
            }
            
            RoomAvatarImage(avatar: room.avatar,
                            avatarSize: .custom(52),
                            mediaProvider: mediaProvider)
                .accessibilityHidden(true)
        }
        .frame(width: 52, height: 52)
    }
    
    private var roomTitle: some View {
        HStack(spacing: WhistlepigTheme.Spacing.xs) {
            Text(room.name)
                .lineLimit(1)
            if let statusEmoji = room.statusEmoji {
                Text(String(statusEmoji))
            }
        }
        .font(.system(size: 17, weight: room.hasUnreads ? .semibold : .medium))
        .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
    }
    
    @ViewBuilder
    private var timestamp: some View {
        if let timestamp = room.timestamp {
            Text(timestamp)
                .font(.system(size: 12, weight: room.hasUnreads ? .semibold : .regular))
                .foregroundStyle(room.hasUnreads ? WhistlepigTheme.ColorToken.accentPrimary : WhistlepigTheme.ColorToken.textTertiary)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private var preview: some View {
        if let text = room.displayedLastMessage {
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(room.lastMessageState == .failed ? .red : room.hasUnreads ? WhistlepigTheme.ColorToken.textPrimary.opacity(0.78) : WhistlepigTheme.ColorToken.textSecondary)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private var status: some View {
        if room.badges.isMentionShown {
            Image(systemName: "at")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(WhistlepigTheme.ColorToken.accentPrimary, in: Circle())
        } else if room.badges.isDotShown {
            if room.hasUnreads {
                Text("•")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(WhistlepigTheme.ColorToken.accentPrimary)
                    .frame(width: 18, height: 18)
            } else {
                Circle()
                    .fill(WhistlepigTheme.ColorToken.unreadMuted)
                    .frame(width: 8, height: 8)
            }
        } else if room.badges.isMuteShown {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 11))
                .foregroundStyle(WhistlepigTheme.ColorToken.textTertiary)
        }
    }
}

private struct WhistlepigRoomRowButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if isSelected || configuration.isPressed {
                    RoundedRectangle(cornerRadius: WhistlepigTheme.Radius.control, style: .continuous)
                        .fill(WhistlepigTheme.ColorToken.accentSoft.opacity(isSelected ? 1 : 0.82))
                        .padding(.horizontal, WhistlepigTheme.Spacing.sm)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
