//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import UIKit

nonisolated struct NoticeRoomTimelineItem: TextBasedRoomTimelineItem, Equatable {
    let id: TimelineItemIdentifier
    let timestamp: Date
    let isOutgoing: Bool
    let isEditable: Bool
    let canBeRepliedTo: Bool
    
    let sender: TimelineItemSender
    
    let content: NoticeRoomTimelineItemContent

    let liveActivityBody: String?
    let liveActivityFormattedBody: AttributedString?
    let liveActivityCompleted: Bool
    
    var properties = RoomTimelineItemProperties()

    init(id: TimelineItemIdentifier,
         timestamp: Date,
         isOutgoing: Bool,
         isEditable: Bool,
         canBeRepliedTo: Bool,
         sender: TimelineItemSender,
         content: NoticeRoomTimelineItemContent,
         liveActivityBody: String? = nil,
         liveActivityFormattedBody: AttributedString? = nil,
         liveActivityCompleted: Bool = false,
         properties: RoomTimelineItemProperties = .init()) {
        self.id = id
        self.timestamp = timestamp
        self.isOutgoing = isOutgoing
        self.isEditable = isEditable
        self.canBeRepliedTo = canBeRepliedTo
        self.sender = sender
        self.content = content
        self.liveActivityBody = liveActivityBody
        self.liveActivityFormattedBody = liveActivityFormattedBody
        self.liveActivityCompleted = liveActivityCompleted
        self.properties = properties
    }
    
    var body: String {
        content.body
    }
    
    var contentType: EventBasedMessageTimelineItemContentType {
        .notice(content)
    }
}
