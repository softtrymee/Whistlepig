//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

/// A minimal compatibility seam for inherited coordinators.
///
/// Whistlepig does not collect product analytics. The seam only keeps the
/// existing dependency graph stable while screens are incrementally simplified.
protocol AnalyticsServiceProtocol: AnyObject {
    /// A signpost client for performance testing the app. This client doesn't respect the
    /// `isRunning` state or behave any differently when `start`/`reset` are called.
    var signpost: Signposter { get }
}
