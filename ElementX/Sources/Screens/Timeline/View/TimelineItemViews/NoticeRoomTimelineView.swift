//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct NoticeRoomTimelineView: View, TextBasedRoomTimelineViewProtocol {
    let timelineItem: NoticeRoomTimelineItem
    
    var body: some View {
        TimelineStyler(timelineItem: timelineItem) {
            // Spacing: 6 = label spacing - formatted text padding

            // Wrapped in a Group so the crossfade below (card <-> resolved message) has a
            // single enclosing view to animate from; TimelineStyler's closure otherwise
            // returns the if/else branches directly with nothing to attach `.animation` to.
            Group {
                if let activityBody = timelineItem.liveActivityBody {
                    WhistlepigAgentActivityCard(status: timelineItem.liveActivityCompleted ? .completed : .active,
                                                 commentary: activityBody,
                                                 formattedCommentary: timelineItem.liveActivityFormattedBody)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    Label {
                        if let attributedString = timelineItem.content.formattedBody {
                        FormattedBodyText(attributedString: attributedString,
                                          trailingReservedSize: timelineItem.trailingReservedSize)
                        } else {
                        FormattedBodyText(text: timelineItem.content.body,
                                          trailingReservedSize: timelineItem.trailingReservedSize)
                        }
                    } icon: {
                        CompoundIcon(\.info, size: .small, relativeTo: .compound.bodyLG)
                            .foregroundColor(.compound.iconSecondary)
                    }
                    .labelStyle(.custom(spacing: 6.0, alignment: .top))
                    .padding(.leading, 4) // Trailing padding is provided by FormattedBodyText
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: timelineItem.liveActivityBody != nil)
        }
    }
}

struct NoticeRoomTimelineView_Previews: PreviewProvider, TestablePreview {
    static let viewModel = TimelineViewModel.mock
    
    static var previews: some View {
        body.environmentObject(viewModel.context)
    }
    
    static var body: some View {
        VStack(alignment: .leading, spacing: 20.0) {
            NoticeRoomTimelineView(timelineItem: itemWith(text: "Short loin ground round tongue hamburger, fatback salami shoulder. Beef turkey sausage kielbasa strip steak. Alcatra capicola pig tail pancetta chislic.",
                                                          timestamp: .mock,
                                                          senderId: "Bob"))
            
            NoticeRoomTimelineView(timelineItem: itemWith(text: "Some other text",
                                                          timestamp: .mock,
                                                          senderId: "Anne"))
        }
    }
    
    private static func itemWith(text: String, timestamp: Date, senderId: String) -> NoticeRoomTimelineItem {
        NoticeRoomTimelineItem(id: .randomEvent,
                               timestamp: timestamp,
                               isOutgoing: false,
                               isEditable: false,
                               canBeRepliedTo: true,
                               sender: .init(id: senderId),
                               content: .init(body: text))
    }
}
