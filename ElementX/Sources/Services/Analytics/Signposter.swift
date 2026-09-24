//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// A local, intentionally inert performance interface.
///
/// Whistlepig doesn't export telemetry or crash-performance spans. Keeping this
/// narrow API lets the Matrix client remain decoupled from any analytics vendor
/// while existing UI timing calls stay harmless.
class Signposter {
    private var transactions = Set<TransactionName>()
    
    enum TransactionName: Hashable {
        case cachedRoomList
        case upToDateRoomList
        case notificationToMessage
        case openRoom
        case sendMessage(uuid: String)
        
        var id: String {
            switch self {
            case .cachedRoomList:
                "Cached room list"
            case .upToDateRoomList:
                "Up-to-date room list"
            case .notificationToMessage:
                "Notification to message"
            case .openRoom:
                "Open a room"
            case .sendMessage:
                "Send a message"
            }
        }
    }
    
    enum SpanName: String {
        case timelineLoad = "Timeline load"
    }
    
    struct Span {
        func finish() { }
    }
    
    enum TagName: String {
        case homeserver
    }
    
    // MARK: - Transactions
    
    func startTransaction(_ transactionName: TransactionName, operation: String = "ux", tags: [TagName: String] = [:]) {
        transactions.insert(transactionName)
    }
    
    func finishTransaction(_ transactionName: TransactionName) {
        transactions.remove(transactionName)
    }
    
    func resetTransactions() {
        transactions.removeAll()
    }
    
    // MARK: - Spans
    
    func addSpan(_ spanName: SpanName, toTransaction transactionName: TransactionName) -> Span? {
        guard transactions.contains(transactionName) else {
            return nil
        }
        return Span()
    }
    
    // MARK: - Tags
    
    func addGlobalTag(_ tagName: TagName, value: String) {
        // Deliberately do not retain hostnames or any other user data locally.
    }
}
