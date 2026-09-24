//
// Copyright 2026 Whistlepig
//

import Compound
import SwiftUI

struct WhistlepigRoomListHeader: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    
    var body: some View {
        VStack(alignment: .leading, spacing: WhistlepigTheme.Spacing.lg) {
            HStack(alignment: .center, spacing: WhistlepigTheme.Spacing.md) {
                Text("Chats")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
                
                Spacer()
                
                if context.viewState.shouldShowSpaceFilters {
                    Button {
                        context.send(viewAction: .spaceFilters)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 40, height: 40)
                    }
                    .accessibilityLabel(L10n.screenRoomlistYourSpaces)
                }
                
                Button {
                    context.send(viewAction: .startChat)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .foregroundStyle(WhistlepigTheme.ColorToken.accentPrimary)
                .accessibilityLabel(L10n.actionStartChat)
                
                Button {
                    context.send(viewAction: .showSettings)
                } label: {
                    AvatarSettingsButtonLabel(userProfile: context.viewState.userProfile,
                                              mediaProvider: context.mediaProvider)
                }
                .accessibilityLabel(L10n.commonSettings)
            }
            
            if context.viewState.isRoomListSearchEnabled {
                HStack(spacing: WhistlepigTheme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(WhistlepigTheme.ColorToken.textTertiary)
                    
                    TextField("Search chats", text: $context.searchQuery)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 16))
                        .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
                }
                .padding(.horizontal, WhistlepigTheme.Spacing.md)
                .frame(height: 40)
                .background(WhistlepigTheme.ColorToken.elevated, in: RoundedRectangle(cornerRadius: WhistlepigTheme.Radius.control, style: .continuous))
            }
        }
        .padding(.horizontal, WhistlepigTheme.Spacing.lg)
        .padding(.top, WhistlepigTheme.Spacing.sm)
        .padding(.bottom, WhistlepigTheme.Spacing.md)
        .onAppear {
            context.isSearchFieldFocused = false
        }
    }
}

struct WhistlepigRoomListCompactHeader: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    let onSearch: () -> Void
    
    var body: some View {
        HStack(spacing: WhistlepigTheme.Spacing.sm) {
            Text("Chats")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
            
            Spacer()
            
            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Search chats")
            
            Button {
                context.send(viewAction: .startChat)
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .foregroundStyle(WhistlepigTheme.ColorToken.accentPrimary)
            .accessibilityLabel(L10n.actionStartChat)
            
            Button {
                context.send(viewAction: .showSettings)
            } label: {
                AvatarSettingsButtonLabel(userProfile: context.viewState.userProfile,
                                          mediaProvider: context.mediaProvider)
            }
            .accessibilityLabel(L10n.commonSettings)
        }
        .padding(.horizontal, WhistlepigTheme.Spacing.md)
        .frame(height: 52)
        .whistlepigGlassSurface(Capsule(), interactive: true)
        .padding(.horizontal, WhistlepigTheme.Spacing.md)
        .accessibilityElement(children: .contain)
    }
}

struct WhistlepigCompactSearchHeader: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    let onClose: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: WhistlepigTheme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(WhistlepigTheme.ColorToken.textTertiary)
            
            TextField("Search chats", text: $context.searchQuery)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($isFocused)
                .font(.system(size: 16))
                .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel(L10n.actionClose)
        }
        .padding(.horizontal, WhistlepigTheme.Spacing.md)
        .frame(height: 52)
        .whistlepigGlassSurface(Capsule(), interactive: true)
        .padding(.horizontal, WhistlepigTheme.Spacing.md)
        .onAppear {
            isFocused = true
        }
    }
}
