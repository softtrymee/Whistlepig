//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementX
import Foundation
import Testing

@MainActor
final class BugReportServiceTests {
    var appSettings: AppSettings!
    var bugReportService: BugReportServiceProtocol!
    
    init() throws {
        appSettings = AppSettings.volatile()
        appSettings.bugReportRageshakeURL.reset()
        
        let bugReportServiceMock = BugReportServiceMock()
        bugReportServiceMock.lastCrashEventIDSubject = .init(nil)
        bugReportServiceMock.submitBugReportProgressListenerReturnValue = .success(SubmitBugReportResponse(reportURL: "https://www.example.com/123"))
        bugReportService = bugReportServiceMock
    }
    
    deinit {
        appSettings.bugReportRageshakeURL.reset()
    }
    
    @Test
    func initialStateWithMockService() {
        #expect(bugReportService.lastCrashEventIDSubject.value == nil)
    }
    
    @Test
    func submitBugReportWithMockService() async throws {
        let bugReport = BugReport(userID: "@mock:client.com",
                                  deviceID: nil,
                                  ed25519: nil,
                                  curve25519: nil,
                                  text: "i cannot send message",
                                  logFiles: [URL(filePath: "/logs/1.log"), URL(filePath: "/logs/2.log")],
                                  canContact: false,
                                  githubLabels: [],
                                  files: [])
        let progressSubject = CurrentValueSubject<Double, Never>(0.0)
        let response = try await bugReportService.submitBugReport(bugReport, progressListener: progressSubject).get()
        let reportURL = try #require(response.reportURL)
        #expect(!reportURL.isEmpty)
    }
}
