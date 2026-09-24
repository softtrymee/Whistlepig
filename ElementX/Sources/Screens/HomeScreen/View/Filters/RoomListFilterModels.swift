//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import MatrixRustSDK
import OrderedCollections

enum RoomListFilter: Int, CaseIterable, Identifiable {
    var id: Int {
        rawValue
    }
    
    case unreads
    case people
    case rooms
    case favourites
    case invites
    case lowPriority
    case hidden
    
    static var availableFilters: [RoomListFilter] {
        RoomListFilter.allCases
    }
    
    var localizedName: String {
        switch self {
        case .people:
            return L10n.screenRoomlistFilterPeople
        case .rooms:
            return L10n.screenRoomlistFilterRooms
        case .unreads:
            return L10n.screenRoomlistFilterUnreads
        case .favourites:
            return L10n.screenRoomlistFilterFavourites
        case .invites:
            return L10n.screenRoomlistFilterInvites
        case .lowPriority:
            return L10n.screenRoomlistFilterLowPriority
        case .hidden:
            return "Hidden"
        }
    }
    
    var incompatibleFilters: [RoomListFilter] {
        switch self {
        case .people:
            return [.rooms, .invites, .hidden]
        case .rooms:
            return [.people, .invites, .hidden]
        case .unreads:
            return [.invites, .hidden]
        case .favourites:
            return [.invites, .lowPriority, .hidden]
        case .invites:
            return [.rooms, .people, .unreads, .favourites, .lowPriority, .hidden]
        case .lowPriority:
            return [.favourites, .invites, .hidden]
        case .hidden:
            return RoomListFilter.allCases.filter { $0 != .hidden }
        }
    }
    
    var rustFilter: RoomListEntriesDynamicFilterKind {
        switch self {
        case .people:
            return .all(filters: [.category(expect: .people), .joined])
        case .rooms:
            return .all(filters: [.category(expect: .group), .joined])
        case .unreads:
            return .all(filters: [.unread, .joined])
        case .favourites:
            return .all(filters: [.favourite, .joined])
        case .invites:
            return .invite
        case .lowPriority:
            // Note: When not activated, the setFilter method automatically applies the .nonLowPriority filter.
            return .all(filters: [.lowPriority, .joined])
        case .hidden:
            return .all(filters: [])
        }
    }
}

struct RoomListFiltersState {
    private(set) var activeFilters: OrderedSet<RoomListFilter>
    private let appSettings: AppSettings
    
    init(activeFilters: OrderedSet<RoomListFilter> = [], appSettings: AppSettings) {
        self.activeFilters = .init(activeFilters)
        self.appSettings = appSettings
    }
    
    var availableFilters: [RoomListFilter] {
        var availableFilters = OrderedSet(RoomListFilter.availableFilters)
        
        if !appSettings.lowPriorityFilterEnabled {
            availableFilters.remove(.lowPriority)
        }
        
        for filter in activeFilters {
            availableFilters.remove(filter)
            filter.incompatibleFilters.forEach { availableFilters.remove($0) }
        }
        
        return availableFilters.elements
    }
    
    var isFiltering: Bool {
        !activeFilters.isEmpty
    }
    
    var providerFilters: Set<RoomListFilter> {
        activeFilters.set
    }
    
    var isShowingHiddenRooms: Bool {
        activeFilters.contains(.hidden)
    }
    
    mutating func activateFilter(_ filter: RoomListFilter) {
        filter.incompatibleFilters.forEach { incompatibleFilter in
            if activeFilters.contains(incompatibleFilter) {
                fatalError("[RoomListFiltersState] adding mutually exclusive filters is not allowed")
            }
        }
        
        // We always want the most recently enabled filter to be at the bottom of the others.
        activeFilters.append(filter)
    }
    
    mutating func deactivateFilter(_ filter: RoomListFilter) {
        activeFilters.remove(filter)
    }
    
    mutating func clearFilters() {
        activeFilters.removeAll()
    }
    
    func isFilterActive(_ filter: RoomListFilter) -> Bool {
        activeFilters.contains(filter)
    }
}
