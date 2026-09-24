//
// Copyright 2026 Whistlepig contributors.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

/// Disabled compatibility implementation while the inherited report flow is
/// removed. Whistlepig never packages logs or sends diagnostic reports to a
/// third party.
final class BugReportService: BugReportServiceProtocol {
    let isEnabled = false
    let lastCrashEventIDSubject = CurrentValueSubject<String?, Never>(nil)
    
    func submitBugReport(_ bugReport: BugReport,
                         progressListener: CurrentValueSubject<Double, Never>) async -> Result<SubmitBugReportResponse, BugReportServiceError> {
        .failure(.uploadFailure(CancellationError()))
    }
}
