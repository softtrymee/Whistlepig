//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Algorithms
import UIKit

nonisolated struct TextRoomTimelineItem: TextBasedRoomTimelineItem, Equatable {
    let id: TimelineItemIdentifier
    let timestamp: Date
    let isOutgoing: Bool
    let isEditable: Bool
    let canBeRepliedTo: Bool
    var shouldBoost = false
    
    let sender: TimelineItemSender
    
    let content: TextRoomTimelineItemContent

    /// Present only for a root message carrying the MSC4357 live marker.
    let liveActivityBody: String?
    let liveActivityFormattedBody: AttributedString?
    let liveActivityCompleted: Bool
    
    var properties = RoomTimelineItemProperties()

    init(id: TimelineItemIdentifier,
         timestamp: Date,
         isOutgoing: Bool,
         isEditable: Bool,
         canBeRepliedTo: Bool,
         shouldBoost: Bool = false,
         sender: TimelineItemSender,
         content: TextRoomTimelineItemContent,
         liveActivityBody: String? = nil,
         liveActivityFormattedBody: AttributedString? = nil,
         liveActivityCompleted: Bool = false,
         properties: RoomTimelineItemProperties = .init()) {
        self.id = id
        self.timestamp = timestamp
        self.isOutgoing = isOutgoing
        self.isEditable = isEditable
        self.canBeRepliedTo = canBeRepliedTo
        self.shouldBoost = shouldBoost
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
        .text(content)
    }
    
    var links: [URL] {
        guard let attributedString = content.formattedBody else {
            return []
        }
        
        let links = attributedString.runs.compactMap { (run: AttributedString.Runs.Run) -> URL? in
            if run.link == nil {
                return nil
            }
            
            guard run.elementX.eventOnRoomAlias == nil,
                  run.elementX.eventOnRoomID == nil,
                  run.elementX.roomAlias == nil,
                  run.elementX.roomID == nil,
                  run.elementX.userID == nil else {
                return nil
            }
            
            return run.link
        }
        
        return Array(links.uniqued())
    }
}
