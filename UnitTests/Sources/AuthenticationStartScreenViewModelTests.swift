//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDKMocks
import Testing
import UIKit

@MainActor
final class AuthenticationStartScreenViewModelTests {
    var clientFactory: AuthenticationClientFactoryMock!
    var client: ClientSDKMock!
    var notificationCenter: NotificationCenter!
    var appSettings: AppSettings!
    var authenticationService: AuthenticationServiceProtocol!
    
    var viewModel: AuthenticationStartScreenViewModel!
    var context: AuthenticationStartScreenViewModel.Context {
        viewModel.context
    }
    
    init() {
        appSettings = AppSettings.volatile()
    }
    
    @Test
    func initialState() async throws {
        // Given a view model that has no provisioning parameters.
        await setupViewModel()
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 0)
        
        // When tapping any of the buttons on the screen
        let actions: [(AuthenticationStartScreenViewAction, AuthenticationStartScreenViewModelAction)] = [
            (.loginWithQR, .loginWithQR),
            (.login, .login),
            (.register, .register),
            (.reportProblem, .reportProblem)
        ]
        
        for action in actions {
            let deferred = deferFulfillment(viewModel.actions) { $0 == action.1 }
            context.send(viewAction: action.0)
            try await deferred.fulfill()
            
            // Then the authentication service should not be used yet.
            #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 0)
            #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 0)
            #expect(authenticationService.homeserver.value.loginMode == .unknown)
        }
    }
    
    @Test
    func singleProviderOAuthState() async throws {
        // Given a view model that for an app that only allows the use of a single provider that supports OAuth.
        setAllowedAccountProviders(["company.com"])
        await setupViewModel()
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 0)
        
        // When tapping the login button the authentication service should be used and the screen
        // should request to continue the flow without any server selection needed.
        let deferred = deferFulfillment(viewModel.actions) { $0.isLoginDirectlyWithOAuth }
        context.send(viewAction: .login)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 1)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesReceivedArguments?.prompt == .consent)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesReceivedArguments?.loginHint == nil)
        #expect(authenticationService.homeserver.value.loginMode == .oAuth(supportsCreatePrompt: false))
    }
    
    @Test
    func singleProviderPasswordState() async throws {
        // Given a view model that for an app that only allows the use of a single provider that does not support OAuth.
        setAllowedAccountProviders(["company.com"])
        await setupViewModel(supportsOAuth: false)
        #expect(authenticationService.homeserver.value.loginMode == .unknown)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 0)
        
        // When tapping the login button the authentication service should be used and the screen
        // should request to continue the flow without any server selection needed.
        let deferred = deferFulfillment(viewModel.actions) { $0.isLoginDirectlyWithPassword }
        context.send(viewAction: .login)
        try await deferred.fulfill()
        
        // Then a call to configure service should be made.
        #expect(clientFactory.makeClientHomeserverAddressSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 1)
        #expect(authenticationService.homeserver.value.loginMode == .password)
    }
    
    // MARK: - Helpers
    
    private func setupViewModel(supportsOAuth: Bool = true,
                                supportsPasswordLogin: Bool = true) async {
        // Manually create a configuration as the default homeserver address setting is immutable.
        client = ClientSDKMock(.init(oAuthLoginURL: supportsOAuth ? "https://account.company.com/authorize" : nil,
                                     supportsOAuthCreatePrompt: false,
                                     supportsPasswordLogin: supportsPasswordLogin))
        // Map both the server name and the homeserver URL so fallback lookups work.
        let homeserverClients: [String: ClientSDKMock] = ["company.com": client,
                                                          "https://matrix.company.com": client]
        let configuration = AuthenticationClientFactoryMock.Configuration(homeserverClients: homeserverClients)
        
        notificationCenter = NotificationCenter()
        
        clientFactory = AuthenticationClientFactoryMock(configuration)
        authenticationService = AuthenticationService(userSessionStore: UserSessionStoreMock(.init()),
                                                      encryptionKeyProvider: EncryptionKeyProvider(),
                                                      clientFactory: clientFactory,
                                                      appSettings: appSettings,
                                                      appHooks: AppHooks())
        
        viewModel = AuthenticationStartScreenViewModel(authenticationService: authenticationService,
                                                       isBugReportServiceEnabled: true,
                                                       appMediator: AppMediatorMock(),
                                                       appSettings: appSettings,
                                                       mediaProvider: MediaProviderMock(.init()),
                                                       notificationCenter: notificationCenter,
                                                       userIndicatorController: UserIndicatorControllerMock())
        
        // Add a fake window in order for the OAuth flow to continue
        viewModel.context.send(viewAction: .updateWindow(UIWindow()))
    }
    
    private func setAllowedAccountProviders(_ providers: [String]) {
        appSettings.override(accountProviders: providers,
                             allowOtherAccountProviders: false,
                             hideBrandChrome: false,
                             pushGatewayBaseURL: appSettings.pushGatewayBaseURL,
                             oAuthRedirectURL: appSettings.oAuthRedirectURL,
                             oAuthClientURIPath: appSettings.oAuthClientURIPath,
                             websiteURL: appSettings.websiteURL,
                             logoURL: appSettings.logoURL,
                             copyrightURL: appSettings.copyrightURL,
                             acceptableUseURL: appSettings.acceptableUseURL,
                             privacyURL: appSettings.privacyURL,
                             encryptionURL: appSettings.encryptionURL,
                             deviceVerificationURL: appSettings.deviceVerificationURL,
                             chatBackupDetailsURL: appSettings.chatBackupDetailsURL,
                             identityPinningViolationDetailsURL: appSettings.identityPinningViolationDetailsURL,
                             historySharingDetailsURL: appSettings.historySharingDetailsURL,
                             bugReportApplicationID: appSettings.bugReportApplicationID)
    }
}

extension AuthenticationStartScreenViewModelAction {
    var isLoginDirectlyWithOAuth: Bool {
        switch self {
        case .loginDirectlyWithOAuth: true
        default: false
        }
    }
    
    var isLoginDirectlyWithPassword: Bool {
        switch self {
        case .loginDirectlyWithPassword: true
        default: false
        }
    }
}
