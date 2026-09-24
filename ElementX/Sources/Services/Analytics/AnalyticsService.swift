//
// Copyright 2026 Whistlepig contributors.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

/// Local no-op performance seam retained for inherited navigation code.
final class AnalyticsService: AnalyticsServiceProtocol {
    let signpost = Signposter()
}
