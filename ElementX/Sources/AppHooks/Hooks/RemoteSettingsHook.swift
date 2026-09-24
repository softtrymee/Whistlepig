//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation
import MatrixRustSDK

enum RemoteSettingsError: Error { }

protocol RemoteSettingsHookProtocol: Sendable {
    #if IS_MAIN_APP
    @MainActor func initializeCache(using client: ClientProtocol, applyingTo appSettings: CommonSettingsProtocol) async -> Result<Void, RemoteSettingsError>
    func updateCache(using client: ClientProtocol) async
    @MainActor func reset(_ appSettings: CommonSettingsProtocol)
    #endif
    @MainActor func loadCache(forHomeserver homeserver: String, applyingTo appSettings: CommonSettingsProtocol)
}

struct DefaultRemoteSettingsHook: RemoteSettingsHookProtocol {
    #if IS_MAIN_APP
    func initializeCache(using client: ClientProtocol, applyingTo appSettings: CommonSettingsProtocol) async -> Result<Void, RemoteSettingsError> {
        // Whistlepig is a standalone Matrix client. It deliberately ignores
        // Element-specific well-known flags such as `enforce_element_pro`.
        .success(())
    }
    
    func updateCache(using client: ClientProtocol) async { }
    func reset(_ appSettings: any CommonSettingsProtocol) { }
    #endif
    
    func loadCache(forHomeserver homeserver: String, applyingTo appSettings: CommonSettingsProtocol) { }
}
