//
// Copyright 2026 Whistlepig
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
//

import Foundation

/// The Matrix representation of mention pills in a plain text editor.
///
/// Both the room composer and media caption composer use this conversion so a
/// selected member is sent as a Matrix mention rather than as display-name text.
struct PlainTextMentionContent {
    let text: String
    let intentionalMentions: IntentionalMentions
    
    init(attributedString source: NSAttributedString) {
        let attributedString = NSMutableAttributedString(attributedString: source)
        var shouldMakeAnotherPass = false
        var userIDs = Set<String>()
        var containsAtRoom = false
        
        repeat {
            shouldMakeAnotherPass = false
            attributedString.enumerateAttribute(.link,
                                                in: .init(location: 0, length: attributedString.length),
                                                options: []) { value, range, stop in
                guard let value else { return }
                attributedString.removeAttribute(.link, range: range)
                
                if let userID = attributedString.attribute(.MatrixUserID, at: range.location, effectiveRange: nil) as? String {
                    let displayName = attributedString.attribute(.MatrixUserDisplayName, at: range.location, effectiveRange: nil) as? String
                    attributedString.replaceCharacters(in: range, with: "[\(displayName ?? userID)](\(value))")
                    userIDs.insert(userID)
                    shouldMakeAnotherPass = true
                    stop.pointee = true
                } else if let roomAlias = attributedString.attribute(.MatrixRoomAlias, at: range.location, effectiveRange: nil) as? String {
                    let displayName = attributedString.attribute(.MatrixRoomDisplayName, at: range.location, effectiveRange: nil) as? String
                    attributedString.replaceCharacters(in: range, with: "[\(displayName ?? roomAlias)](\(value))")
                    shouldMakeAnotherPass = true
                    stop.pointee = true
                }
            }
        } while shouldMakeAnotherPass
        
        repeat {
            shouldMakeAnotherPass = false
            attributedString.enumerateAttribute(.MatrixAllUsersMention,
                                                in: .init(location: 0, length: attributedString.length),
                                                options: []) { value, range, stop in
                guard value != nil else { return }
                attributedString.removeAttribute(.MatrixAllUsersMention, range: range)
                attributedString.replaceCharacters(in: range, with: PillUtilities.atRoom)
                containsAtRoom = true
                shouldMakeAnotherPass = true
                stop.pointee = true
            }
        } while shouldMakeAnotherPass
        
        text = attributedString.string
        intentionalMentions = .init(userIDs: userIDs, atRoom: containsAtRoom)
    }
}
