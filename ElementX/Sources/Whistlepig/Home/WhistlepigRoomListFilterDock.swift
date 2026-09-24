//
// Copyright 2026 Whistlepig
//

import SwiftUI

struct WhistlepigRoomListFilterDock: View {
    @Binding var state: RoomListFiltersState
    
    @Namespace private var selectionNamespace
    
    private let filters: [RoomListFilter?] = [nil, .people, .rooms, .hidden]
    
    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 0) {
                    dock
                }
            } else {
                dock
            }
        }
        .padding(.horizontal, WhistlepigTheme.Spacing.lg)
        .accessibilityElement(children: .contain)
    }
    
    private var dock: some View {
        HStack(spacing: 2) {
            ForEach(filters, id: \.self) { filter in
                filterButton(filter)
            }
        }
        .padding(4)
        .frame(height: 48)
        .whistlepigGlassSurface(Capsule(), interactive: true)
    }
    
    private func filterButton(_ filter: RoomListFilter?) -> some View {
        Button {
            select(filter)
        } label: {
            Text(title(for: filter))
                .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .medium))
                .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    if selectedFilter == filter {
                        selectionLens
                    }
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
    }
    
    private var selectionLens: some View {
        Capsule()
            .fill(WhistlepigTheme.ColorToken.accentSoft)
            .overlay(Capsule().stroke(WhistlepigTheme.ColorToken.accentPrimary.opacity(0.2), lineWidth: 0.5))
            .matchedGeometryEffect(id: "filter-selection", in: selectionNamespace)
    }
    
    private var selectedFilter: RoomListFilter? {
        state.activeFilters.count == 1 ? state.activeFilters.first : nil
    }
    
    private func title(for filter: RoomListFilter?) -> String {
        switch filter {
        case nil: "All"
        case .unreads: "Unread"
        case .people: "People"
        case .favourites: "Favorites"
        case .rooms: "Groups"
        case .hidden: "Hidden"
        case .invites, .lowPriority: filter?.localizedName ?? "All"
        }
    }
    
    private func select(_ filter: RoomListFilter?) {
        withAnimation(.smooth(duration: 0.24)) {
            state.clearFilters()
            if let filter {
                state.activateFilter(filter)
            }
        }
    }
}
