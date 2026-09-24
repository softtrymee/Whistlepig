//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

// MARK: - Routes

enum AppRoute: Hashable {
    /// An external callback used to complete login with OAuth. This is only used when authentication
    /// requires an external app so cannot be handled directly by the web authentication session.
    case oAuthCallback(url: URL)
    
    /// The app's home screen.
    case roomList
    /// A room, shown as the root of the stack (popping any child rooms).
    case room(roomID: String, via: [String])
    /// The same as ``room`` but using a room alias.
    case roomAlias(String)
    /// A room, pushed as a child of any existing rooms on the stack.
    case childRoom(roomID: String, via: [String])
    /// The same as ``childRoom`` but using a room alias.
    case childRoomAlias(String)
    /// The information about a particular room.
    case roomDetails(roomID: String)
    /// The profile of a member within the current room.
    case roomMemberDetails(userID: String)
    /// An event within a room, shown as the root of the stack (popping any child rooms).
    case event(eventID: String, roomID: String, via: [String])
    /// The same as ``event`` but using a room alias.
    case eventOnRoomAlias(eventID: String, alias: String)
    /// An event within a room, either within the last child on the stack or pushing a new child if needed.
    case childEvent(eventID: String, roomID: String, via: [String])
    /// The same as ``childEvent`` but using a room alias.
    case childEventOnRoomAlias(eventID: String, alias: String)
    /// The profile of a matrix user (outside of a room).
    case userProfile(userID: String)
    /// An Element Call running in a particular room
    case call(roomID: String, isVoiceCall: Bool)
    /// The settings screen.
    case settings
    /// The setting screen for key backup.
    case chatBackupSettings
    /// An external share request e.g. from the ShareExtension
    case share(ShareExtensionPayload)
    /// The change roles screen of a room with the transfer ownership setting
    case transferOwnership(roomID: String)
    /// A thread within a room, only to be used to handle tap on notification for threaded events.
    case thread(roomID: String, threadRootEventID: String, focusEventID: String?)
    /// The search screen
    case search
    
    /// Whether or not the route should be handled by the authentication flow.
    var isAuthenticationRoute: Bool {
        switch self {
        case .oAuthCallback: true
        default: false
        }
    }
}

struct AppRouteURLParser {
    let urlParsers: [URLParser]
    
    init(appSettings: AppSettings) {
        urlParsers = [
            AppGroupURLParser(),
            MatrixPermalinkParser(),
            OAuthCallbackURLParser(redirectURL: appSettings.oAuthRedirectURL)
        ]
    }
    
    func route(from url: URL) -> AppRoute? {
        for parser in urlParsers {
            if let appRoute = parser.route(from: url) {
                return appRoute
            }
        }
        
        return nil
    }
}

// MARK: - URL Parsers

/// Represents a type that can parse a `URL` into an `AppRoute`.
///
protocol URLParser {
    func route(from url: URL) -> AppRoute?
}

/// The parser for routes that come from app extensions such as the Share Extension.
private struct AppGroupURLParser: URLParser {
    func route(from url: URL) -> AppRoute? {
        guard let scheme = url.scheme,
              scheme == InfoPlistReader.app.appScheme,
              url.pathComponents.last == ShareExtensionConstants.urlPath else {
            return nil
        }
        
        guard let query = url.query(percentEncoded: false),
              let queryData = query.data(using: .utf8) else {
            MXLog.error("Failed processing share parameters")
            return nil
        }
        
        do {
            let payload = try JSONDecoder().decode(ShareExtensionPayload.self, from: queryData)
            return .share(payload)
        } catch {
            MXLog.error("Failed decoding share payload with error: \(error)")
            return nil
        }
    }
}

private struct MatrixPermalinkParser: URLParser {
    func route(from url: URL) -> AppRoute? {
        guard let entity = parseMatrixEntityFrom(uri: url.absoluteString) else { return nil }
        
        switch entity.id {
        case .room(let id):
            return .room(roomID: id, via: entity.via)
        case .roomAlias(let alias):
            return .roomAlias(alias)
        case .user(let id):
            return .userProfile(userID: id)
        case .eventOnRoomId(let roomID, let eventID):
            return .event(eventID: eventID, roomID: roomID, via: entity.via)
        case .eventOnRoomAlias(let alias, let eventID):
            return .eventOnRoomAlias(eventID: eventID, alias: alias)
        }
    }
}

/// The parser for the OAuth callback URL. This always returns an `.oAuthCallback`.
struct OAuthCallbackURLParser: URLParser {
    let redirectURL: URL
    
    func route(from url: URL) -> AppRoute? {
        guard url.absoluteString.starts(with: redirectURL.absoluteString) else { return nil }
        return .oAuthCallback(url: url)
    }
}
