//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDK
import Testing

@MainActor
struct TimelineItemFactoryTests {
    @Test
    func callInvite() throws {
        let ownUserID = "@alice:matrix.org"
        let senderUserID = "@bob:matrix.org"
        
        let factory = RoomTimelineItemFactory(userID: ownUserID,
                                              attributedStringBuilder: AttributedStringBuilder(mentionBuilder: MentionBuilder()),
                                              stateEventStringBuilder: RoomStateEventStringBuilder(userID: ownUserID))
        
        let eventTimelineItem = EventTimelineItem.mockCallInvite(sender: senderUserID)
        
        let eventTimelineItemProxy = EventTimelineItemProxy(item: eventTimelineItem, uniqueID: .init("0"))
        
        let item = try #require(factory.buildTimelineItem(for: eventTimelineItemProxy, isDM: false) as? CallInviteRoomTimelineItem,
                                "Incorrect item type")
        
        #expect(item.isReactable == false)
        #expect(item.canBeRepliedTo == false)
        #expect(item.isEditable == false)
        #expect(item.sender == TimelineItemSender(id: senderUserID))
        #expect(item.properties.isEdited == false)
        #expect(item.properties.reactions == [])
        #expect(item.properties.deliveryStatus == nil)
    }
    
    // MARK: - MSC4357 live activity
    
    @Test
    func liveActivityInitialRootTextNoEditYet() throws {
        let originalJSON = """
        {
          "event_id": "$root1",
          "content": {
            "msgtype": "m.text",
            "body": "🐸 摸索中……",
            "formatted_body": "🐸 摸索中……",
            "format": "org.matrix.custom.html",
            "org.matrix.msc4357.live": {}
          }
        }
        """
        
        let item = try buildTimelineItem(content: makeMessageContent(body: "🐸 摸索中……", formattedBody: "🐸 摸索中……"),
                                         originalJSON: originalJSON,
                                         latestEditJSON: nil)
        
        let textItem = try #require(item as? TextRoomTimelineItem, "Incorrect item type")
        #expect(textItem.liveActivityBody == "🐸 摸索中……")
        #expect(textItem.liveActivityCompleted == false)
        #expect(textItem.liveActivityFormattedBody != nil)
    }
    
    @Test
    func liveActivityIntermediateReplaceUpdatesBodyAndFormat() throws {
        let rootID = "$root2"
        let originalJSON = """
        {
          "event_id": "\(rootID)",
          "content": {
            "msgtype": "m.text",
            "body": "🐸 摸索中……",
            "formatted_body": "🐸 摸索中……",
            "format": "org.matrix.custom.html",
            "org.matrix.msc4357.live": {}
          }
        }
        """
        
        let latestEditJSON = """
        {
          "event_id": "$edit2",
          "content": {
            "org.matrix.msc4357.live": {},
            "m.relates_to": {
              "rel_type": "m.replace",
              "event_id": "\(rootID)"
            },
            "m.new_content": {
              "msgtype": "m.text",
              "body": "更新：拿到 4×RTX PRO 6000 线索",
              "format": "org.matrix.custom.html",
              "formatted_body": "更新：拿到 <code>4×RTX PRO 6000</code> 线索",
              "org.matrix.msc4357.live": {}
            }
          }
        }
        """
        
        let item = try buildTimelineItem(content: makeMessageContent(body: "🐸 摸索中……", formattedBody: "🐸 摸索中……"),
                                         originalJSON: originalJSON,
                                         latestEditJSON: latestEditJSON)
        
        let textItem = try #require(item as? TextRoomTimelineItem, "Incorrect item type")
        #expect(textItem.liveActivityBody == "更新：拿到 4×RTX PRO 6000 线索")
        #expect(textItem.liveActivityCompleted == false)
        let formattedBody = try #require(textItem.liveActivityFormattedBody)
        #expect(String(formattedBody.characters).contains("4×RTX PRO 6000"))
    }
    
    @Test
    func liveActivityTerminalReplaceRemovesMarker() throws {
        let rootID = "$root3"
        let originalJSON = """
        {
          "event_id": "\(rootID)",
          "content": {
            "msgtype": "m.text",
            "body": "🐸 摸索中……",
            "formatted_body": "🐸 摸索中……",
            "format": "org.matrix.custom.html",
            "org.matrix.msc4357.live": {}
          }
        }
        """
        
        let latestEditJSON = """
        {
          "event_id": "$edit3",
          "content": {
            "m.relates_to": {
              "rel_type": "m.replace",
              "event_id": "\(rootID)"
            },
            "m.new_content": {
              "msgtype": "m.text",
              "body": "最终答案：552B MoE"
            }
          }
        }
        """
        
        let item = try buildTimelineItem(content: makeMessageContent(body: "最终答案：552B MoE"),
                                         originalJSON: originalJSON,
                                         latestEditJSON: latestEditJSON)
        
        let textItem = try #require(item as? TextRoomTimelineItem, "Incorrect item type")
        #expect(textItem.liveActivityBody == nil)
    }
    
    @Test
    func liveActivityBodyChangesAcrossSuccessiveReplaces() throws {
        let rootID = "$root4"
        let originalJSON = """
        {
          "event_id": "\(rootID)",
          "content": {
            "msgtype": "m.text",
            "body": "🐸 摸索中……",
            "formatted_body": "🐸 摸索中……",
            "format": "org.matrix.custom.html",
            "org.matrix.msc4357.live": {}
          }
        }
        """
        
        func replaceJSON(eventID: String, body: String) -> String {
            """
            {
              "event_id": "\(eventID)",
              "content": {
                "org.matrix.msc4357.live": {},
                "m.relates_to": {
                  "rel_type": "m.replace",
                  "event_id": "\(rootID)"
                },
                "m.new_content": {
                  "msgtype": "m.text",
                  "body": "\(body)",
                  "org.matrix.msc4357.live": {}
                }
              }
            }
            """
        }
        
        let itemA = try buildTimelineItem(content: makeMessageContent(body: "🐸 摸索中……"),
                                          originalJSON: originalJSON,
                                          latestEditJSON: replaceJSON(eventID: "$edit4a", body: "第一段"))
        let itemB = try buildTimelineItem(content: makeMessageContent(body: "🐸 摸索中……"),
                                          originalJSON: originalJSON,
                                          latestEditJSON: replaceJSON(eventID: "$edit4b", body: "第二段"))
        
        let textItemA = try #require(itemA as? TextRoomTimelineItem, "Incorrect item type")
        let textItemB = try #require(itemB as? TextRoomTimelineItem, "Incorrect item type")
        
        #expect(textItemA.liveActivityBody == "第一段")
        #expect(textItemB.liveActivityBody == "第二段")
        #expect(textItemA.liveActivityBody != textItemB.liveActivityBody)
    }
    
    @Test
    func liveActivityOrdinaryEditNoMarkerIsNotMisclassified() throws {
        let rootID = "$root5"
        let originalJSON = """
        {
          "event_id": "\(rootID)",
          "content": {
            "msgtype": "m.text",
            "body": "hello"
          }
        }
        """
        
        let latestEditJSON = """
        {
          "event_id": "$edit5",
          "content": {
            "m.relates_to": {
              "rel_type": "m.replace",
              "event_id": "\(rootID)"
            },
            "m.new_content": {
              "msgtype": "m.text",
              "body": "hello edited"
            }
          }
        }
        """
        
        let item = try buildTimelineItem(content: makeMessageContent(body: "hello edited"),
                                         originalJSON: originalJSON,
                                         latestEditJSON: latestEditJSON)
        
        let textItem = try #require(item as? TextRoomTimelineItem, "Incorrect item type")
        #expect(textItem.liveActivityBody == nil)
    }
    
    @Test
    func liveActivityInitialNoticeIsLive() throws {
        let originalJSON = """
        {
          "event_id": "$root6",
          "content": {
            "msgtype": "m.notice",
            "body": "🐸 摸索中……",
            "formatted_body": "🐸 摸索中……",
            "format": "org.matrix.custom.html",
            "org.matrix.msc4357.live": {}
          }
        }
        """
        
        let item = try buildTimelineItem(content: makeMessageContent(body: "🐸 摸索中……", formattedBody: "🐸 摸索中……", isNotice: true),
                                         originalJSON: originalJSON,
                                         latestEditJSON: nil)
        
        let noticeItem = try #require(item as? NoticeRoomTimelineItem, "Incorrect item type")
        #expect(noticeItem.liveActivityBody != nil)
        #expect(noticeItem.liveActivityCompleted == false)
    }
    
    @Test
    func plainMessageWithNoMarkerIsNotACard() throws {
        let originalJSON = """
        {
          "event_id": "$root7",
          "content": {
            "msgtype": "m.text",
            "body": "just a plain message"
          }
        }
        """
        
        let item = try buildTimelineItem(content: makeMessageContent(body: "just a plain message"),
                                         originalJSON: originalJSON,
                                         latestEditJSON: nil)
        
        let textItem = try #require(item as? TextRoomTimelineItem, "Incorrect item type")
        #expect(textItem.liveActivityBody == nil)
    }
    
    // MARK: - Helpers
    
    private func buildTimelineItem(content: TimelineItemContent, originalJSON: String?, latestEditJSON: String?) throws -> RoomTimelineItemProtocol? {
        let ownUserID = "@alice:matrix.org"
        
        let factory = RoomTimelineItemFactory(userID: ownUserID,
                                              attributedStringBuilder: AttributedStringBuilder(mentionBuilder: MentionBuilder()),
                                              stateEventStringBuilder: RoomStateEventStringBuilder(userID: ownUserID))
        
        let eventTimelineItem = EventTimelineItem(configuration: .init(content: content,
                                                                       originalJSON: originalJSON,
                                                                       latestEditJSON: latestEditJSON))
        
        let eventTimelineItemProxy = EventTimelineItemProxy(item: eventTimelineItem, uniqueID: .init("0"))
        
        return factory.buildTimelineItem(for: eventTimelineItemProxy, isDM: false)
    }
    
    private func makeMessageContent(body: String, formattedBody: String? = nil, isNotice: Bool = false) -> TimelineItemContent {
        let formatted = formattedBody.map { FormattedBody(format: .html, body: $0) }
        
        let messageType: MessageType = isNotice
            ? .notice(content: .init(body: body, formatted: formatted))
            : .text(content: .init(body: body, formatted: formatted))
        
        return .msgLike(content: .init(kind: .message(content: .init(msgType: messageType,
                                                                     body: body,
                                                                     isEdited: false,
                                                                     mentions: nil)),
                                       reactions: [],
                                       inReplyTo: nil,
                                       threadRoot: nil,
                                       threadSummary: nil))
    }
}
