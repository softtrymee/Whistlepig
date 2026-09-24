//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Compound
import ObjectiveC
import SwiftUI
import UIKit
import WysiwygComposer

struct RoomScreen: View {
    @ObservedObject private var context: RoomScreenViewModelType.Context
    @ObservedObject private var timelineContext: TimelineViewModelType.Context
    let composerToolbar: ComposerToolbar
    @Environment(\.accessibilityVoiceOverEnabled) private var isVoiceOverEnabled
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.tabViewHorizontalSizeClass) private var tabViewHorizontalSizeClass
    
    enum MarkAsReadSource {
        case up
        case down
    }
    
    /// Which scroll button (if any) currently has the "Mark as read" pill displayed alongside it.
    /// Set when the user long-presses one of the scroll buttons; the pill anchors to that button.
    @State private var markAsReadSource: MarkAsReadSource?
    
    init(context: RoomScreenViewModelType.Context,
         timelineContext: TimelineViewModelType.Context,
         composerToolbar: ComposerToolbar) {
        self.context = context
        self.timelineContext = timelineContext
        self.composerToolbar = composerToolbar
    }
    
    var body: some View {
        TimelineView(timelineContext: timelineContext)
            .ignoresSafeArea(edges: .top)
            .overlay {
                // Sits below the bottom-trailing overlay in z-order, so taps on the pill or
                // buttons still go to them; taps anywhere else dismiss the pill.
                if markAsReadSource != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { dismissMarkAsReadPill() }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 16) {
                    HStack(spacing: 8) {
                        if markAsReadSource == .up {
                            markAsReadPill
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        jumpToReadMarkerButton
                    }
                    HStack(spacing: 8) {
                        if markAsReadSource == .down {
                            markAsReadPill
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        TimelineScrollButton(isHidden: !timelineContext.viewState.shouldShowScrollToBottomButton,
                                             showsBadge: scrollToBottomShowsBadge,
                                             onLongPress: scrollToBottomShowsBadge ? { revealMarkAsReadPill(source: .down) } : nil) {
                            dismissMarkAsReadPill()
                            timelineContext.send(viewAction: .scrollToBottom)
                        }
                        .accessibilityIdentifier(A11yIdentifiers.roomScreen.scrollToBottom)
                    }
                }
                .padding()
                .animation(.elementDefault, value: markAsReadSource)
            }
            .background(WhistlepigChatAmbientBackground())
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 60)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .top) { topOverlay }
            .topBanners([
                TopBannerLayer(verticalBanners: [
                    TopBannerItem(pinnedItemsBanner, isVisible: context.viewState.shouldShowPinnedEventsBanner && !isVoiceOverEnabled)
                ]),
                // This can overlay on top of the stacked banners
                TopBannerLayer(knockRequestsBanner, isVisible: context.viewState.shouldSeeKnockRequests)
            ])
            .safeAreaInset(edge: .top) {
                // When VoiceOver is enabled the scroll gestures don't trigger, so the banner never
                // hides itself and the .overlay layout above would permanently obscure the top of
                // the timeline. So whenever VoiceOver is enabled we use a safe area inset to
                // vertically stack it above the timeline instead.
                if context.viewState.shouldShowPinnedEventsBanner, isVoiceOverEnabled {
                    VStack(spacing: 0) {
                        if context.viewState.shouldShowPinnedEventsBanner {
                            pinnedItemsBanner
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    RoomScreenFooterView(details: context.viewState.footerDetails,
                                         mediaProvider: context.mediaProvider) { action in
                        context.send(viewAction: .footerViewAction(action))
                    }
                    
                    composer
                        .background(Color.compound.bgCanvasDefault.ignoresSafeArea())
                        .environmentObject(timelineContext)
                        .environment(\.timelineContext, timelineContext)
                        // Make sure the reply header honours the hideTimelineMedia setting too.
                        .environment(\.shouldAutomaticallyLoadImages, !timelineContext.viewState.hideTimelineMedia)
                }
                .opacity(isTextSelectionMode ? 0.82 : 1)
                .animation(.easeInOut(duration: 0.18), value: isTextSelectionMode)
            }
            .toolbar(.hidden, for: .navigationBar)
            .introspect(.navigationStack, on: .supportedVersions, scope: .ancestor) { navigationController in
                // The full-screen swipe-back replaces the edge gesture on compact layouts only.
                // A regular-width split detail keeps the stock system behavior.
                guard isCompactLayout else { return }
                RoomFullScreenBackTransition.install(on: navigationController)
            }
            .navigationTitle(L10n.screenRoomTitle) // Hidden but used for back button text.
            .navigationBarTitleDisplayMode(.inline)
            .overlay { loadingIndicator }
            .alert(item: $context.alertInfo)
            .timelineMediaPreview(viewModel: $context.mediaPreviewViewModel)
            .onChange(of: pillSourceButtonIsVisible) { _, isVisible in
                if !isVisible {
                    dismissMarkAsReadPill()
                }
            }
    }
    
    private var isTextSelectionMode: Bool {
        timelineContext.viewState.bindings.textSelectionItemID != nil
    }
    
    /// Whether the room is pushed onto a compact navigation stack (iPhone, or iPad
    /// in Slide Over / narrow multitasking). This mirrors the signal
    /// `NavigationSplitCoordinatorView` uses to choose stack vs. split layout.
    private var isCompactLayout: Bool {
        (tabViewHorizontalSizeClass ?? horizontalSizeClass) != .regular
    }
    
    /// Floating header overlay, kept as its own property so the
    /// compiler can type-check `body` in smaller pieces.
    private var topOverlay: some View {
        ZStack(alignment: .top) {
            WhistlepigChatHeaderBackdrop()
            WhistlepigChatAmbientBackground(includesCanvas: false)
                .allowsHitTesting(false)
            VStack(spacing: WhistlepigTheme.Spacing.xs) {
                WhistlepigChatHeader(roomName: context.viewState.roomTitle,
                                     roomAvatar: context.viewState.roomAvatar,
                                     subtitle: nil,
                                     mediaProvider: context.mediaProvider,
                                     onBack: { dismiss() },
                                     onDetails: { context.send(viewAction: .displayRoomDetails) },
                                     showCall: !ProcessInfo.processInfo.isiOSAppOnMac && context.viewState.shouldShowCallButton,
                                     showThreads: context.viewState.roomThreadListEnabled,
                                     onCall: { context.send(viewAction: .displayCall(isVoiceCall: true)) },
                                     onThreads: { context.send(viewAction: .displayThreadList) },
                                     showsBackButton: isCompactLayout)
                dateBadge
            }
            .padding(.top, WhistlepigTheme.Spacing.sm)
        }
        .opacity(isTextSelectionMode ? 0.82 : 1)
        .animation(.easeInOut(duration: 0.18), value: isTextSelectionMode)
    }

    private var pinnedItemsBanner: some View {
        PinnedItemsBannerView(state: context.viewState.pinnedEventsBannerState,
                              onMainButtonTap: { context.send(viewAction: .tappedPinnedEventsBanner) },
                              onViewAllButtonTap: { context.send(viewAction: .viewAllPins) })
    }
    
    private var knockRequestsBanner: some View {
        KnockRequestsBannerView(requests: context.viewState.displayedKnockRequests,
                                onDismiss: dismissKnockRequestsBanner,
                                onAccept: context.viewState.canAcceptKnocks ? acceptKnockRequest : nil,
                                onViewAll: onViewAllKnockRequests,
                                mediaProvider: context.mediaProvider)
            .padding(.top, 16)
    }
    
    @ViewBuilder
    private var dateBadge: some View {
        if !isVoiceOverEnabled {
            FloatingDateBadge(dateText: timelineContext.floatingDate?.formattedDateSeparator()) {
                timelineContext.send(viewAction: .scrollToFirstItemForCurrentDate)
            }
        }
    }
    
    private func dismissKnockRequestsBanner() {
        context.send(viewAction: .dismissKnockRequests)
    }
    
    private func acceptKnockRequest(eventID: String) {
        context.send(viewAction: .acceptKnock(eventID: eventID))
    }
    
    private func onViewAllKnockRequests() {
        context.send(viewAction: .viewKnockRequests)
    }
    
    @ViewBuilder
    private var jumpToReadMarkerButton: some View {
        if timelineContext.viewState.shouldShowJumpToReadMarker {
            TimelineScrollButton(direction: .up,
                                 showsBadge: true) {
                revealMarkAsReadPill(source: .up)
            } callback: {
                dismissMarkAsReadPill()
                timelineContext.send(viewAction: .scrollToReadMarker)
            }
        }
    }
    
    private var markAsReadPill: some View {
        Button {
            timelineContext.send(viewAction: .markAllAsRead)
            dismissMarkAsReadPill()
        } label: {
            markAsReadPillLabel
        }
    }
    
    @ViewBuilder
    private var markAsReadPillLabel: some View {
        // Font scales with Dynamic Type via the Compound token; padding is a fixed point value
        // so the pill grows with the text instead of growing twice over.
        let label = Label {
            Text(L10n.screenRoomlistMarkAsRead)
        } icon: {
            CompoundIcon(\.markAsRead, size: .medium, relativeTo: .compound.bodyLG)
        }
        .font(.compound.bodyLG)
        .foregroundStyle(.compound.textPrimary)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        if #available(iOS 26, *) {
            label.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            label.background(.regularMaterial, in: Capsule())
        }
    }
    
    private func revealMarkAsReadPill(source: MarkAsReadSource) {
        markAsReadSource = source
    }
    
    private func dismissMarkAsReadPill() {
        markAsReadSource = nil
    }
    
    /// Whether the scroll button that the pill is anchored to is still being rendered.
    /// Used to dismiss an orphaned pill when the source button gets hidden — without
    /// this, the pill can render alongside an invisible button. Returns `true` when no
    /// pill is shown so the `onChange` doesn't fire spuriously when the source clears.
    private var pillSourceButtonIsVisible: Bool {
        switch markAsReadSource {
        case .up: timelineContext.viewState.shouldShowJumpToReadMarker
        case .down: timelineContext.viewState.shouldShowScrollToBottomButton
        case .none: true
        }
    }
    
    /// Hide the new-messages dot when the jump-to-read-marker feature is disabled.
    private var scrollToBottomShowsBadge: Bool {
        timelineContext.viewState.jumpToReadMarkerEnabled
            && timelineContext.viewState.bindings.hasNewMessagesAtBottom
    }
    
    @ViewBuilder
    private var composer: some View {
        if context.viewState.hasSuccessor {
            tombstonedDialogue
        } else if context.viewState.canSendMessage, !ProcessInfo.isRunningAccessibilityTests {
            // We are not sure why but when wrapped in the room screen the composer toolbar breaks the accessibility tests
            composerToolbar
        } else {
            ComposerDisabledView()
        }
    }
    
    private var tombstonedDialogue: some View {
        VStack(spacing: 16) {
            Text(L10n.screenRoomTimelineTombstonedRoomMessage)
                .font(.compound.bodyMD)
                .foregroundStyle(.compound.textPrimary)
            
            Button {
                context.send(viewAction: .displaySuccessorRoom)
            } label: {
                Text(L10n.screenRoomTimelineTombstonedRoomAction)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.compound(.primary, size: .medium))
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .highlight(gradient: .compound.info, borderColor: .compound.borderInfoSubtle)
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        if timelineContext.viewState.showLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.compound.textPrimary)
                .padding(16)
                .background(.ultraThickMaterial)
                .cornerRadius(8)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // .principal + .primaryAction works better than .navigation leading + trailing
        // as the latter disables interaction in the action button for rooms with long names
        ToolbarItem(placement: .principal) {
            RoomHeaderView(roomName: context.viewState.roomTitle,
                           roomAvatar: context.viewState.roomAvatar,
                           dmRecipientDetails: context.viewState.dmRecipientDetails,
                           roomHistorySharingState: context.viewState.roomHistorySharingState,
                           mediaProvider: context.mediaProvider) {
                context.send(viewAction: .displayRoomDetails)
            }
        }
        
        if !ProcessInfo.processInfo.isiOSAppOnMac {
            if context.viewState.shouldShowCallButton {
                RoomCallControlsToolbar(viewState: context.viewState) { isVoiceCall in
                    context.send(viewAction: .displayCall(isVoiceCall: isVoiceCall))
                }
            }
        }
        
        if context.viewState.roomThreadListEnabled {
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    context.send(viewAction: .displayThreadList)
                } label: {
                    CompoundIcon(\.threads)
                }
            }
        }
    }
}

private final class RoomFullScreenBackTransition: NSObject, UINavigationControllerDelegate, UIGestureRecognizerDelegate, UIViewControllerAnimatedTransitioning {
    private weak var navigationController: UINavigationController?
    private weak var originalDelegate: UINavigationControllerDelegate?
    private weak var panGesture: UIPanGestureRecognizer?
    private var interactionController: UIPercentDrivenInteractiveTransition?
    private var isInteractivePopInProgress = false
    private var traitRegistration: UITraitChangeRegistration?
    
    private static var associationKey: UInt8 = 0
    
    static func install(on navigationController: UINavigationController) {
        if let transition = objc_getAssociatedObject(navigationController, &associationKey) as? RoomFullScreenBackTransition {
            transition.refresh()
            return
        }
        
        let transition = RoomFullScreenBackTransition(navigationController: navigationController)
        objc_setAssociatedObject(navigationController, &associationKey, transition, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        transition.refresh()
    }
    
    private init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    private func refresh() {
        guard panGesture == nil, let navigationController else { return }
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = false
        navigationController.view.addGestureRecognizer(pan)
        panGesture = pan
        traitRegistration = navigationController.registerForTraitChanges([UITraitHorizontalSizeClass.self]) { [weak self] (_: UINavigationController, _: UITraitCollection) in
            self?.updateGestureForTraits()
        }
        updateGestureForTraits()
    }
    
    /// Enables the full-screen pan (and disables the system edge gesture) in compact
    /// layouts only, so rotation and multitasking resize keep the correct behavior.
    private func updateGestureForTraits() {
        guard let navigationController else { return }
        let isCompact = navigationController.traitCollection.horizontalSizeClass == .compact
        panGesture?.isEnabled = isCompact
        navigationController.interactivePopGestureRecognizer?.isEnabled = !isCompact
    }
    
    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let navigationController else { return }
        
        let translation = pan.translation(in: navigationController.view)
        let progress = max(0, min(1, translation.x / max(navigationController.view.bounds.width, 1)))
        
        switch pan.state {
        case .began:
            guard canBeginPop(with: pan) else { return }
            isInteractivePopInProgress = true
            originalDelegate = navigationController.delegate
            navigationController.delegate = self
            let interaction = UIPercentDrivenInteractiveTransition()
            interaction.completionCurve = .easeOut
            interaction.completionSpeed = 0.95
            interactionController = interaction
            navigationController.popViewController(animated: true)
        case .changed:
            interactionController?.update(progress)
        case .ended:
            let velocity = pan.velocity(in: navigationController.view).x
            if velocity > 700 || progress > 0.35 {
                interactionController?.finish()
            } else {
                interactionController?.cancel()
            }
        case .cancelled, .failed:
            interactionController?.cancel()
        default:
            break
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        return canBeginPop(with: pan)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !isInsideExclusiveHorizontalControl(touch.view)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        otherGestureRecognizer is UIPanGestureRecognizer && isHorizontallyScrollable(otherGestureRecognizer.view)
    }
    
    private func canBeginPop(with pan: UIPanGestureRecognizer) -> Bool {
        guard let navigationController,
              navigationController.viewControllers.count > 1,
              !isInteractivePopInProgress,
              navigationController.transitionCoordinator == nil else {
            return false
        }
        
        let velocity = pan.velocity(in: navigationController.view)
        return velocity.x > 0 && abs(velocity.x) > abs(velocity.y)
    }
    
    private func isInsideExclusiveHorizontalControl(_ view: UIView?) -> Bool {
        var currentView = view
        while let candidate = currentView {
            if candidate is UIControl || candidate is UITextView || candidate is UITextField || isHorizontallyScrollable(candidate) {
                return true
            }
            currentView = candidate.superview
        }
        return false
    }
    
    private func isHorizontallyScrollable(_ view: UIView?) -> Bool {
        guard let scrollView = view as? UIScrollView else { return false }
        return scrollView.contentSize.width > scrollView.bounds.width + 1
    }
    
    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        originalDelegate?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }
    
    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        originalDelegate?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }
    
    func navigationController(_ navigationController: UINavigationController,
                              animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController,
                              to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        isInteractivePopInProgress && operation == .pop ? self : nil
    }
    
    func navigationController(_ navigationController: UINavigationController,
                              interactionControllerFor animationController: any UIViewControllerAnimatedTransitioning) -> (any UIViewControllerInteractiveTransitioning)? {
        animationController === self ? interactionController : nil
    }
    
    func transitionDuration(using transitionContext: (any UIViewControllerContextTransitioning)?) -> TimeInterval {
        UIAccessibility.isReduceMotionEnabled ? 0.2 : 0.36
    }
    
    func animateTransition(using transitionContext: any UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        
        let container = transitionContext.containerView
        let bounds = container.bounds
        let offset = bounds.width * 0.28
        toView.frame = bounds.offsetBy(dx: -offset, dy: 0)
        container.insertSubview(toView, belowSubview: fromView)
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext),
                       delay: 0,
                       options: [.curveLinear, .allowUserInteraction]) {
            fromView.frame = bounds.offsetBy(dx: bounds.width, dy: 0)
            toView.frame = bounds
        } completion: { _ in
            let completed = !transitionContext.transitionWasCancelled
            if !completed {
                fromView.frame = bounds
                toView.removeFromSuperview()
            }
            self.interactionController = nil
            self.isInteractivePopInProgress = false
            self.navigationController?.delegate = self.originalDelegate
            self.originalDelegate = nil
            transitionContext.completeTransition(completed)
        }
    }
}

// MARK: - Previews

struct RoomScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModels = makeViewModels()
    static let readOnlyViewModels = makeViewModels(canSendMessage: false)
    static let tombstonedViewModels = makeViewModels(hasSuccessor: true)
    static let composerViewModel = ComposerToolbarViewModel.mock()
    
    static var previews: some View {
        ElementNavigationStack {
            RoomScreen(context: viewModels.room.context,
                       timelineContext: viewModels.timeline.context,
                       composerToolbar: ComposerToolbar(context: composerViewModel.context))
        }
        .previewDisplayName("Normal")
        
        ElementNavigationStack {
            RoomScreen(context: readOnlyViewModels.room.context,
                       timelineContext: readOnlyViewModels.timeline.context,
                       composerToolbar: ComposerToolbar(context: composerViewModel.context))
        }
        .previewDisplayName("Read-only")
        .snapshotPreferences(expect: readOnlyViewModels.room.context.$viewState.map { !$0.canSendMessage })
        
        ElementNavigationStack {
            RoomScreen(context: tombstonedViewModels.room.context,
                       timelineContext: tombstonedViewModels.timeline.context,
                       composerToolbar: ComposerToolbar(context: composerViewModel.context))
        }
        .previewDisplayName("Tombstoned")
        .snapshotPreferences(expect: tombstonedViewModels.room.context.$viewState.map(\.hasSuccessor))
    }
    
    static func makeViewModels(canSendMessage: Bool = true, hasSuccessor: Bool = false) -> ViewModels {
        let roomProxyMock = JoinedRoomProxyMock(.init(id: "stable_id",
                                                      name: "Preview room",
                                                      hasOngoingCall: true,
                                                      successor: hasSuccessor ? .init(roomId: UUID().uuidString, reason: nil) : nil,
                                                      powerLevelsConfiguration: .init(canUserSendMessage: canSendMessage)))
        let roomViewModel = RoomScreenViewModel.mock(roomProxyMock: roomProxyMock)
        
        let appSettings = AppSettings.volatile()
        let timelineViewModel = TimelineViewModel(roomProxy: roomProxyMock,
                                                  timelineController: TimelineControllerMock(.init()),
                                                  userSession: UserSessionMock(.init()),
                                                  mediaPlayerProvider: MediaPlayerProviderMock(),
                                                  userIndicatorController: UserIndicatorControllerMock(),
                                                  appMediator: AppMediatorMock(.init()),
                                                  appSettings: appSettings,
                                                  analyticsService: AnalyticsServiceMock(.init()),
                                                  emojiProvider: EmojiProvider(appSettings: appSettings),
                                                  linkMetadataProvider: LinkMetadataProvider(),
                                                  timelineControllerFactory: TimelineControllerFactoryMock(.init()))
        
        return .init(room: roomViewModel, timeline: timelineViewModel)
    }
    
    struct ViewModels {
        let room: RoomScreenViewModelProtocol
        let timeline: TimelineViewModelProtocol
    }
}
