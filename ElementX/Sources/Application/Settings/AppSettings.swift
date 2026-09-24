//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

#if IS_MAIN_APP
import EmbeddedElementCall
#endif

import Combine
import Foundation
import Macros
import SwiftUI

/// Common settings between app and NSE
nonisolated protocol CommonSettingsProtocol: AnyObject, Sendable {
    var lastNotificationBootTime: TimeInterval? { get set }
    var selectedNotificationTone: NotificationTone? { get set }
    
    var logLevel: LogLevel { get }
    var traceLogPacks: Set<TraceLogPack> { get }
    var bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> { get }
    var contentScannerURL: RemotePreference<URL?> { get }
    var forceDisableE2EE: RemotePreference<Bool> { get }
    
    var enableOnlySignedDeviceIsolationMode: Bool { get }
    var threadsEnabled: Bool { get }
    var hideQuietNotificationAlerts: Bool { get }
}

nonisolated enum AppBuildType {
    case debug
    case nightly
    case release
    
    static var current: AppBuildType {
        #if DEBUG
        return .debug
        #else
        if InfoPlistReader.main.isNightlyBuild {
            .nightly
        } else {
            .release
        }
        #endif
    }
}

/// Store Element specific app settings.
///
/// State is persisted in `UserDefaults`, which is thread-safe per Apple's documentation, hence `@unchecked`.
final nonisolated class AppSettings: @unchecked Sendable {
    static var suiteName: String? {
        let appGroupIdentifier = InfoPlistReader.main.appGroupIdentifier
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) == nil ? nil : appGroupIdentifier
    }
    
    /// UserDefaults to be used on reads and writes.
    private let store: UserDefaultsProtocol
    
    static var appBuildType: AppBuildType {
        AppBuildType.current
    }
    
    func resetAllSettings() {
        MXLog.warning("Resetting the AppSettings.")
        store.reset()
    }
    
    func resetSessionSpecificSettings() {
        MXLog.warning("Resetting the user session specific AppSettings.")
        resetHasRunIdentityConfirmationOnboarding()
    }
    
    // MARK: - Hooks
    
    // swiftlint:disable:next function_parameter_count
    func override(accountProviders: [String],
                  allowOtherAccountProviders: Bool,
                  hideBrandChrome: Bool,
                  pushGatewayBaseURL: URL,
                  oAuthRedirectURL: URL,
                  oAuthClientURIPath: String?,
                  websiteURL: URL,
                  logoURL: URL,
                  copyrightURL: URL,
                  acceptableUseURL: URL,
                  privacyURL: URL,
                  encryptionURL: URL,
                  deviceVerificationURL: URL,
                  chatBackupDetailsURL: URL,
                  identityPinningViolationDetailsURL: URL,
                  historySharingDetailsURL: URL,
                  bugReportApplicationID: String) {
        self.accountProviders = accountProviders
        self.allowOtherAccountProviders = allowOtherAccountProviders
        self.hideBrandChrome = hideBrandChrome
        self.pushGatewayBaseURL = pushGatewayBaseURL
        self.oAuthRedirectURL = oAuthRedirectURL
        self.oAuthClientURIPath = oAuthClientURIPath
        self.websiteURL = websiteURL
        self.logoURL = logoURL
        self.copyrightURL = copyrightURL
        self.acceptableUseURL = acceptableUseURL
        self.privacyURL = privacyURL
        self.encryptionURL = encryptionURL
        self.deviceVerificationURL = deviceVerificationURL
        self.chatBackupDetailsURL = chatBackupDetailsURL
        self.identityPinningViolationDetailsURL = identityPinningViolationDetailsURL
        self.historySharingDetailsURL = historySharingDetailsURL
        self.bugReportApplicationID = bugReportApplicationID
    }
    
    // MARK: - Application
    
    /// The last known version of the app that was launched on this device, which is
    /// used to detect when migrations should be run. When `nil` the app may have been
    /// deleted between runs so should clear data in the shared container and keychain.
    @UserPreference
    var lastVersionLaunched: String?
    
    /// The Set of room identifiers of invites that the user already saw in the invites list.
    /// This Set is being used to implement badges for unread invites.
    @UserPreference(defaultValue: Set<String>())
    var seenInvites: Set<String>
    
    /// Defaults to `true` for new users, and we use a migration to set it to `false` for existing users.
    @UserPreference(defaultValue: true)
    var hasSeenNewSoundBanner: Bool
    
    /// The initial set of account providers shown to the user in the authentication flow.
    ///
    /// Account provider is the friendly term for the server name. It should not contain an `https` prefix and should
    /// match the last part of the user ID. For example `example.com` and not `https://matrix.example.com`.
    private(set) var accountProviders = ["matrix.org"]
    /// Whether or not the user is allowed to manually enter their own account provider or must select from one of `defaultAccountProviders`.
    private(set) var allowOtherAccountProviders = true
    /// Whether the components surrounding the app brand/logo should be hidden or not
    private(set) var hideBrandChrome = false
    
    /// The task identifier used for background app refresh. Also used in main target's the Info.plist
    let backgroundAppRefreshTaskIdentifier = "me.softtryme.whistlepig.background.refresh"
    
    /// Whistlepig's own public website and policy. Concept docs still point at matrix.org below.
    private(set) var websiteURL: URL = "https://softtrymee.github.io/Whistlepig/support.html"
    private(set) var logoURL: URL = "https://matrix.org"
    private(set) var copyrightURL: URL = "https://matrix.org"
    private(set) var acceptableUseURL: URL = "https://matrix.org"
    private(set) var privacyURL: URL = "https://softtrymee.github.io/Whistlepig/privacy.html"
    private(set) var encryptionURL: URL = "https://matrix.org/docs/"
    private(set) var deviceVerificationURL: URL = "https://matrix.org/docs/"
    private(set) var chatBackupDetailsURL: URL = "https://matrix.org/docs/"
    private(set) var identityPinningViolationDetailsURL: URL = "https://matrix.org/docs/"
    private(set) var historySharingDetailsURL: URL = "https://matrix.org/docs/"
    
    @UserPreference(defaultValue: AppAppearance.system)
    var appAppearance: AppAppearance
    
    @UserPreference(defaultValue: "iris")
    var whistlepigAccent: String
    
    /// Tracks previous servers the user connected to for autocompletion purposes. Entries are made lowercase on write.
    @UserPreference(key: "previousServers", defaultValue: [])
    var previousServers: [String]
    
    var defaultServer: String {
        previousServers.first ?? accountProviders[0]
    }
    
    // MARK: - Security
    
    /// The app must be locked with a PIN code as part of the authentication flow.
    let appLockIsMandatory = false
    /// The amount of time the app can remain in the background for without requesting the PIN/TouchID/FaceID.
    let appLockGracePeriod: TimeInterval = 0
    /// Any codes that the user isn't allowed to use for their PIN.
    let appLockPINCodeBlockList = ["0000", "1234"]
    /// The number of attempts the user has made to unlock the app with a PIN code (resets when unlocked).
    @UserPreference(defaultValue: 0)
    var appLockNumberOfPINAttempts: Int
    
    // MARK: - Authentication
    
    /// No third-party issuer is pre-registered. Homeserver-provided OAuth is used.
    let oAuthStaticRegistrations: [URL: String] = [:]
    /// Custom callback registered by the main app. The same scheme is declared in
    /// Info.plist and is accepted by the existing ASWebAuthenticationSession/parser.
    private(set) nonisolated(unsafe) var oAuthRedirectURL: URL! = URL(string: "\(InfoPlistReader.main.baseBundleIdentifier)://oauth")
    /// A path that is appended to `websiteURL` to form the OAuth `clientURI`. MAS uses `clientURI` as the identifier for a specific app, allowing us to
    /// distinguish the various clients we have for Android, iOS and Web from each other.
    /// Intentionally a distinct property so it can be easily overridden without having to manipulate the website URL.
    private(set) var oAuthClientURIPath: String? = "apps/ios"
    
    var oAuthConfiguration: OAuthConfiguration {
        OAuthConfiguration(clientName: InfoPlistReader.main.bundleDisplayName,
                           redirectURI: oAuthRedirectURL,
                           clientURI: oAuthClientURIPath.map { websiteURL.appending(path: $0) } ?? websiteURL,
                           logoURI: logoURL,
                           tosURI: acceptableUseURL,
                           policyURI: privacyURL,
                           staticRegistrations: oAuthStaticRegistrations.mapKeys { $0.absoluteString })
    }
    
    /// Whether or not the Create Account button is shown on the start screen.
    ///
    /// **Note:** Setting this to false doesn't prevent someone from creating an account when the selected homeserver's MAS allows registration.
    let showCreateAccountButton = true
    
    // MARK: - Notifications
    
    var pusherAppID: String {
        #if DEBUG
        InfoPlistReader.main.baseBundleIdentifier + ".ios.dev"
        #else
        InfoPlistReader.main.baseBundleIdentifier + ".ios.prod"
        #endif
    }
    
    private(set) var pushGatewayBaseURL: URL = "https://matrix.org"
    var pushGatewayNotifyEndpoint: URL {
        pushGatewayBaseURL.appending(path: "_matrix/push/v1/notify")
    }
    
    @UserPreference(defaultValue: true)
    var enableNotifications: Bool
    
    @UserPreference(defaultValue: true)
    var enableInAppNotifications: Bool
    
    @UserPreference(defaultValue: false)
    var hideQuietNotificationAlerts: Bool
    
    /// Tag describing which set of device specific rules a pusher executes.
    @UserPreference
    var pusherProfileTag: String?
    
    /// The device's last boot time as recorded by the NSE.
    @UserPreference
    var lastNotificationBootTime: TimeInterval?
    
    /// The sound played when delivering noisy notifications. If nil, use the ElementX default
    @UserPreference
    var selectedNotificationTone: NotificationTone?
    
    // MARK: - Logging
    
    @UserPreference(defaultValue: LogLevel.info)
    var logLevel: LogLevel
    
    @UserPreference(defaultValue: Set<TraceLogPack>())
    var traceLogPacks: Set<TraceLogPack>
    
    // MARK: - Bug report
    
    let bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> = .init(Secrets.rageshakeURL.map { .url(URL(string: $0)!) } ?? .disabled) // swiftlint:disable:this force_unwrapping
    let bugReportSentryURL: URL? = Secrets.sentryDSN.map { URL(string: $0)! } // swiftlint:disable:this force_unwrapping
    let bugReportSentryRustURL: URL? = Secrets.sentryRustDSN.map { URL(string: $0)! } // swiftlint:disable:this force_unwrapping
    /// The name allocated by the bug report server
    private(set) var bugReportApplicationID = "element-x-ios"
    
    // MARK: - Content scanner
    
    /// The base URL of the content scanner server used to scan media before it is downloaded.
    /// `nil` when content scanning is disabled.
    let contentScannerURL: RemotePreference<URL?> = .init(nil)
    
    // MARK: - Encryption
    
    /// Whether the server forbids the use of E2EE: new rooms are created unencrypted and
    /// enabling encryption on existing rooms is not offered.
    let forceDisableE2EE: RemotePreference<Bool> = .init(false)
    
    @UserPreference(defaultValue: false)
    var hasRunNotificationPermissionsOnboarding: Bool
    
    @UserPreference(defaultValue: false)
    var hasRunIdentityConfirmationOnboarding: Bool
    
    @UserPreference(defaultValue: [FrequentlyUsedEmoji]())
    var frequentlyUsedSystemEmojis: [FrequentlyUsedEmoji]
    
    // MARK: - Home Screen
    
    @UserPreference(defaultValue: RoomListActivityVisibility.current)
    var roomListActivityVisibility: RoomListActivityVisibility
    
    // MARK: - Room Screen
    
    @UserPreference(defaultValue: AppBuildType.current == .debug)
    var viewSourceEnabled: Bool
    
    @UserPreference(defaultValue: true)
    var optimizeMediaUploads: Bool
    
    @UserPreference(defaultValue: AudioPlaybackSpeed.default)
    var voiceMessagePlaybackSpeed: AudioPlaybackSpeed
    
    /// Whether or not to show a warning on the media caption composer so the user knows
    /// that captions might not be visible to users who are using other Matrix clients.
    let shouldShowMediaCaptionWarning = true
    
    // MARK: - Element Call
    
    #if IS_MAIN_APP
    // swiftlint:disable:next force_unwrapping
    let elementCallBaseURL: URL = EmbeddedElementCall.appURL!
    #endif
    
    @UserPreference
    var elementCallBaseURLOverride: URL?
    
    // MARK: - Users
    
    /// Whether to hide the display name and avatar of ignored users as these may contain objectionable content.
    let hideIgnoredUserProfiles = true
    
    // MARK: - Presence
    
    @UserPreference(defaultValue: true)
    var sharePresence: Bool
    
    // MARK: - Feature Flags
    
    /// Others
    @UserPreference(defaultValue: false)
    var fuzzyRoomListSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var lowPriorityFilterEnabled: Bool
    
    /// Configuration to enable only signed device isolation mode for  crypto. In this mode only devices signed by their owner will be considered in e2ee rooms.
    @UserPreference(defaultValue: false)
    var enableOnlySignedDeviceIsolationMode: Bool
    
    @UserPreference(defaultValue: false)
    var knockingEnabled: Bool
    
    @UserPreference(defaultValue: true)
    var threadsEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var roomThreadListEnabled: Bool
    
    @UserPreference(defaultValue: ProcessInfo().isiOSAppOnMac)
    var globalSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var focusEventOnNotificationTap: Bool
    
    @UserPreference(defaultValue: false)
    var linkPreviewsEnabled: Bool
    
    /// Enables *sending* gallery messages (multiple media in a single message).
    /// Received galleries are always rendered regardless of this flag.
    @UserPreference(defaultValue: false)
    var galleryEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var jumpToReadMarkerEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var linkNewDeviceEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var automaticBackPaginationEnabled: Bool
    
    @UserPreference(key: "clientPausingAndResumingEnabledV2", defaultValue: false, volatile: true)
    var clientPausingAndResumingEnabled: Bool
    
    @UserPreference(defaultValue: AppBuildType.current != .release)
    var developerOptionsEnabled: Bool
    
    func hiddenRoomIDs(forAccountID accountID: String) -> Set<String> {
        store["whistlepig.hiddenRoomIDs.\(accountID)"] ?? []
    }
    
    func setHiddenRoomIDs(_ roomIDs: Set<String>, forAccountID accountID: String) {
        store["whistlepig.hiddenRoomIDs.\(accountID)"] = roomIDs
    }
    
    init(store: UserDefaultsProtocol) {
        self.store = store
    }
    
    static func volatile() -> AppSettings {
        AppSettings(store: VolatileUserDefaults())
    }
}

nonisolated extension AppSettings: CommonSettingsProtocol { }
