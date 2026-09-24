//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

final class AnalyticsServiceMock: AnalyticsServiceProtocol, @unchecked Sendable {
    struct Configuration {
        var signpost = Signposter()
    }
    
    let signpost: Signposter
    
    init(_ configuration: Configuration = .init()) {
        signpost = configuration.signpost
    }
}
