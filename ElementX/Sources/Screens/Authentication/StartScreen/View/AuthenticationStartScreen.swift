//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The screen shown at the beginning of the onboarding flow.
struct AuthenticationStartScreen: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @Bindable var context: AuthenticationStartScreenViewModel.Context
    
    var body: some View {
        standardContent
    }
    
    var standardContent: some View {
        // This view uses a GeometryReader instead of FullscreenDialog so its content takes the full
        // height available (after taking the buttons out of the equation) in order for the logo
        // and title to appear vertically centred and equally spaced within this content area.
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                        .frame(height: UIConstants.spacerHeight(in: geometry))
                    
                    content
                        .frame(width: geometry.size.width)
                        .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.hidden)
                    
                    buttons
                        .frame(width: geometry.size.width)
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? 0 : 16)
                        .padding(.top, 8)
                    
                    Spacer()
                        .frame(height: UIConstants.spacerHeight(in: geometry))
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background {
            AuthenticationStartScreenBackgroundImage()
        }
        .navigationBarHidden(true)
        .alert(item: $context.alertInfo)
        .introspect(.window, on: .supportedVersions) { window in
            context.send(viewAction: .updateWindow(window))
        }
    }
    
    var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: verticalSizeClass == .compact ? 12 : 28)
            
            if verticalSizeClass == .regular {
                VStack(spacing: 14) {
                    brandSignature
                    AuthenticationStartLogo(hideBrandChrome: context.viewState.hideBrandChrome,
                                            isOnGradient: !context.viewState.hideBrandChrome)
                }
            }
            
            Spacer().frame(height: 18)
            
            if !context.viewState.hideBrandChrome {
                VStack(spacing: 10) {
                    Text(InfoPlistReader.main.productionAppName)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundColor(.compound.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Private conversations, made personal.")
                        .font(.compound.bodyLG)
                        .foregroundColor(.compound.textSecondary)
                        .multilineTextAlignment(.center)
                    Label("Private by default", systemImage: "lock.fill")
                        .font(.compound.bodySMSemibold)
                        .foregroundStyle(WhistlepigBrand.marmotBrown)
                        .padding(.top, 4)
                }
                .padding()
                .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 20)
        }
        .padding(.bottom)
        .padding(.horizontal, 16)
        .readableFrame()
    }
    
    /// The main action buttons.
    var buttons: some View {
        VStack(spacing: 16) {
            if context.viewState.showQRCodeLoginButton {
                Button { context.send(viewAction: .loginWithQR) } label: {
                    Label(L10n.screenOnboardingSignInWithQrCode, icon: \.qrCode)
                }
                .buttonStyle(WhistlepigPrimaryButtonStyle())
                .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.signInWithQr)
            }
            
            Button { context.send(viewAction: .login) } label: {
                Text(context.viewState.loginButtonTitle)
            }
            .buttonStyle(WhistlepigPrimaryButtonStyle())
            .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.signIn)
            
            if context.viewState.showCreateAccountButton {
                Button { context.send(viewAction: .register) } label: {
                    Text(L10n.screenCreateAccountTitle)
                }
                .buttonStyle(.compound(.tertiary))
            }
            
            versionText
                .font(.compound.bodySM)
                .foregroundColor(.compound.textSecondary)
                .onTapGesture(count: 7) {
                    context.send(viewAction: .reportProblem)
                }
                .accessibilityIdentifier(A11yIdentifiers.authenticationStartScreen.appVersion)
                .overlay(alignment: .trailing) {
                    developerOptionsButton
                        .scaledOffset(x: 32, y: -0.5, relativeTo: .compound.bodySM)
                }
                .padding(.top, 16)
        }
        .padding(.horizontal, verticalSizeClass == .compact ? 128 : 24)
        .padding(.vertical, 20)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.24), lineWidth: 0.75)
                }
        }
        .padding(.horizontal, verticalSizeClass == .compact ? 104 : 16)
        .readableFrame()
    }
    
    var versionText: Text {
        // Let's not deal with snapshotting a changing version string.
        let shortVersionString = ProcessInfo.isRunningTests ? "0.0.0" : InfoPlistReader.main.bundleShortVersionString
        return Text(L10n.screenOnboardingAppVersion(shortVersionString))
    }
    
    @ViewBuilder
    var developerOptionsButton: some View {
        if AppSettings.appBuildType != .release, !ProcessInfo.isRunningTests {
            Button { context.send(viewAction: .developerOptions) } label: {
                CompoundIcon(\.code)
                    .foregroundStyle(.compound.iconSecondary)
            }
            .accessibilityLabel(L10n.commonDeveloperOptions)
        }
    }
}

// MARK: - Previews

struct AuthenticationStartScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = makeViewModel()
    
    static var previews: some View {
        AuthenticationStartScreen(context: viewModel.context)
            .previewDisplayName("Default")
    }
    
    static func makeViewModel() -> AuthenticationStartScreenViewModel {
        AuthenticationStartScreenViewModel(authenticationService: AuthenticationService.mock,
                                           isBugReportServiceEnabled: true,
                                           appMediator: AppMediatorMock(),
                                           appSettings: .volatile(),
                                           mediaProvider: MediaProviderMock(.init()),
                                           userIndicatorController: UserIndicatorControllerMock())
    }
}

private extension AuthenticationStartScreen {
    var brandSignature: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(WhistlepigBrand.marmotBrown)
                .frame(width: 7, height: 7)
            Text("WHISTLEPIG  /  PRIVATE MATRIX")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.1)
        }
        .foregroundStyle(WhistlepigBrand.marmotBrown)
        .accessibilityHidden(true)
    }
}
