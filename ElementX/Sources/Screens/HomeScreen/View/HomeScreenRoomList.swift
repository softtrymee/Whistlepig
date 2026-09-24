//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct HomeScreenRoomList: View {
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.isInSidebar) private var isInSidebar
    
    @ObservedObject var context: HomeScreenViewModel.Context
    
    var body: some View {
        // Hide the room list when the search bar is focused but the query is empty
        // This works hand in hand with the room list service layer filtering and
        // avoids glitches when focusing the search bar
        if !context.viewState.shouldHideRoomList {
            content
        }
    }
    
    private var favouriteRooms: [HomeScreenRoom] {
        context.viewState.visibleRooms.filter { $0.type == .room && $0.isFavourite }
    }
    
    private var standardRooms: [HomeScreenRoom] {
        context.viewState.visibleRooms.filter { $0.type == .room && !$0.isFavourite }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(WhistlepigTheme.ColorToken.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WhistlepigTheme.Spacing.lg)
            .padding(.top, WhistlepigTheme.Spacing.lg)
            .padding(.bottom, WhistlepigTheme.Spacing.xs)
    }
    
    private var nonRoomItems: [HomeScreenRoom] {
        context.viewState.visibleRooms.filter { $0.type != .room }
    }
    
    @ViewBuilder
    private var content: some View {
        ForEach(nonRoomItems) { room in
            switch room.type {
            case .placeholder:
                HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: context.mediaProvider, action: context.send)
                    .redacted(reason: .placeholder)
            case .invite:
                HomeScreenInviteCell(room: room, context: context, hideInviteAvatars: context.viewState.hideInviteAvatars)
            case .knock:
                HomeScreenKnockedCell(room: room, context: context)
            case .room:
                EmptyView()
            }
        }
        
        if !favouriteRooms.isEmpty {
            sectionHeader("Pinned")
            ForEach(favouriteRooms) { room in
                roomRow(room)
            }
        }
        
        if !standardRooms.isEmpty {
            if !favouriteRooms.isEmpty {
                sectionHeader("All Chats")
            }
            ForEach(standardRooms) { room in
                roomRow(room)
            }
        }
    }
    
    private func roomRow(_ room: HomeScreenRoom) -> some View {
        let isSelected = isInSidebar && context.viewState.selectedRoomID == room.id
        
        return WhistlepigRoomRow(room: room,
                                 mediaProvider: context.mediaProvider,
                                 isSelected: isSelected,
                                 action: context.send)
            .contextMenu {
                if room.badges.isDotShown {
                    Button {
                        context.send(viewAction: .markRoomAsRead(roomIdentifier: room.id))
                    } label: {
                        Label(L10n.screenRoomlistMarkAsRead, icon: \.markAsRead)
                    }
                } else {
                    Button {
                        context.send(viewAction: .markRoomAsUnread(roomIdentifier: room.id))
                    } label: {
                        Label(L10n.screenRoomlistMarkAsUnread, icon: \.markAsUnread)
                    }
                }
                
                if supportsMultipleWindows {
                    Button {
                        context.send(viewAction: .detachRoom(roomIdentifier: room.id))
                    } label: {
                        Label("Open in new window", icon: \.spotlight)
                    }
                }
                
                if room.isFavourite {
                    Button {
                        context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: false))
                    } label: {
                        Label(L10n.commonFavourited, icon: \.favouriteSolid)
                    }
                } else {
                    Button {
                        context.send(viewAction: .markRoomAsFavourite(roomIdentifier: room.id, isFavourite: true))
                    } label: {
                        Label(L10n.commonFavourite, icon: \.favourite)
                    }
                }
                
                Divider()
                
                let isHidden = context.viewState.bindings.hiddenRoomIDs.contains(room.id)
                Button {
                    context.send(viewAction: .setRoomHidden(roomIdentifier: room.id, isHidden: !isHidden))
                } label: {
                    Label(isHidden ? "Unhide Chat" : "Hide Chat", systemImage: isHidden ? "eye" : "eye.slash")
                }
                
                Divider()
                
                Button {
                    context.send(viewAction: .showRoomDetails(roomIdentifier: room.id))
                } label: {
                    Label(L10n.commonSettings, icon: \.settings)
                }
                
                if context.viewState.reportRoomEnabled {
                    Button(role: .destructive) {
                        context.send(viewAction: .reportRoom(roomIdentifier: room.id))
                    } label: {
                        Label(L10n.actionReportRoom, icon: \.chatProblem)
                    }
                }
                
                Button(role: .destructive) {
                    context.send(viewAction: .leaveRoom(roomIdentifier: room.id))
                } label: {
                    Label(L10n.actionLeaveRoom, icon: \.leave)
                }
            }
    }
}
