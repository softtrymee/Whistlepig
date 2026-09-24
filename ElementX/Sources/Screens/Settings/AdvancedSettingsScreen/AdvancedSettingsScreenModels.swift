//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Foundation

struct AdvancedSettingsScreenViewState: BindableState {
    init(timelineMediaVisibility: TimelineMediaVisibility, hideInviteAvatars: Bool, isWaitingTimelineMediaVisibility: Bool = false, isWaitingHideInviteAvatars: Bool = false, bindings: AdvancedSettingsScreenViewStateBindings) {
        self.timelineMediaVisibility = timelineMediaVisibility
        self.hideInviteAvatars = hideInviteAvatars
        self.isWaitingTimelineMediaVisibility = isWaitingTimelineMediaVisibility
        self.isWaitingHideInviteAvatars = isWaitingHideInviteAvatars
        self.bindings = bindings
    }
    
    var timelineMediaVisibility: TimelineMediaVisibility
    var hideInviteAvatars: Bool
    var isWaitingTimelineMediaVisibility: Bool
    var isWaitingHideInviteAvatars: Bool
    var bindings: AdvancedSettingsScreenViewStateBindings
}

@dynamicMemberLookup
struct AdvancedSettingsScreenViewStateBindings {
    private let advancedSettings: AdvancedSettingsProtocol
    
    init(advancedSettings: AdvancedSettingsProtocol) {
        self.advancedSettings = advancedSettings
    }
    
    subscript<Setting>(dynamicMember keyPath: ReferenceWritableKeyPath<AdvancedSettingsProtocol, Setting>) -> Setting {
        get { advancedSettings[keyPath: keyPath] }
        set { advancedSettings[keyPath: keyPath] = newValue }
    }
}

enum AdvancedSettingsScreenViewAction {
    case optimizeMediaUploadsChanged
    case updateTimelineMediaVisibility(TimelineMediaVisibility)
    case updateHideInviteAvatars(Bool)
}

protocol AdvancedSettingsProtocol: AnyObject {
    var viewSourceEnabled: Bool { get set }
    var appAppearance: AppAppearance { get set }
    var sharePresence: Bool { get set }
    var optimizeMediaUploads: Bool { get set }
}

extension AppSettings: AdvancedSettingsProtocol { }
