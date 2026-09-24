//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct HomeScreenContent: View {
    @ObservedObject var context: HomeScreenViewModel.Context
    let scrollViewAdapter: ScrollViewAdapter
    
    @State private var topSectionHeight: CGFloat = 0
    @State private var showsCompactHeader = false
    @State private var isCompactSearchPresented = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        roomList
            .overlay(alignment: .bottom) {
                if context.viewState.shouldShowFilters {
                    WhistlepigRoomListFilterDock(state: $context.filtersState)
                        .padding(.bottom, WhistlepigTheme.Spacing.sm)
                }
            }
            .overlay(alignment: .top) {
                if showsCompactHeader {
                    if isCompactSearchPresented {
                        WhistlepigCompactSearchHeader(context: context) {
                            isCompactSearchPresented = false
                        }
                        .padding(.top, WhistlepigTheme.Spacing.sm)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    } else {
                        WhistlepigRoomListCompactHeader(context: context) {
                            isCompactSearchPresented = true
                        }
                        .padding(.top, WhistlepigTheme.Spacing.sm)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showsCompactHeader)
    }
    
    private var roomList: some View {
        GeometryReader { geometry in
            ScrollView {
                switch context.viewState.roomListMode {
                case .skeletons:
                    LazyVStack(spacing: 0) {
                        ForEach(context.viewState.visibleRooms) { room in
                            HomeScreenRoomCell(room: room, isSelected: false, mediaProvider: context.mediaProvider, action: context.send)
                                .redacted(reason: .placeholder)
                                .shimmer() // Putting this directly on the LazyVStack creates an accordion animation on iOS 16.
                        }
                    }
                    .disabled(true)
                    .accessibilityRepresentation {
                        Text(L10n.commonLoading)
                    }
                case .empty:
                    HomeScreenEmptyStateLayout(minHeight: geometry.size.height) {
                        topSection
                        
                        HomeScreenEmptyStateView(context: context)
                            .layoutPriority(1)
                    }
                case .rooms:
                    LazyVStack(spacing: 0) {
                        Section {
                            if context.viewState.shouldShowEmptyFilterState {
                                RoomListFiltersEmptyStateView(state: context.filtersState)
                                    .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - topSectionHeight))
                            } else {
                                HomeScreenRoomList(context: context)
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                        } header: {
                            topSection
                        }
                    }
                }
            }
            .introspect(.scrollView, on: .supportedVersions) { scrollView in
                guard scrollView != scrollViewAdapter.scrollView else { return }
                scrollViewAdapter.scrollView = scrollView
            }
            .onReceive(scrollViewAdapter.didScroll) { _ in
                sendVisibleRange()
                guard let scrollView = scrollViewAdapter.scrollView else { return }
                let shouldShowCompactHeader = scrollView.contentOffset.y > 72
                if showsCompactHeader != shouldShowCompactHeader {
                    showsCompactHeader = shouldShowCompactHeader
                    if !shouldShowCompactHeader {
                        isCompactSearchPresented = false
                    }
                }
            }
            .onReceive(scrollViewAdapter.isScrolling) { _ in
                updateVisibleRange()
            }
            .onChange(of: context.searchQuery) {
                updateVisibleRange()
            }
            .onChange(of: context.viewState.visibleRooms) {
                updateVisibleRange()
                
                // We have been seeing a lot of issues around the room list not updating properly after
                // rooms shifting around:
                // * Tapping on the room list doesn't always take you to the right room  - https://github.com/element-hq/element-x-ios/issues/2386
                // * Big blank gaps in the room list - https://github.com/element-hq/element-x-ios/issues/3026
                //
                // We initially thought it's caused by the filters header or the geometry reader but
                // the problem is still reproducible without those.
                //
                // As a last attempt we will manually force it to update by shifting the
                // inner scroll view by a point every time the room list is updated
                DispatchQueue.main.async {
                    guard !scrollViewAdapter.isScrolling.value, let scrollView = scrollViewAdapter.scrollView else {
                        return
                    }
                    
                    let oldOffset = scrollView.contentOffset
                    var newOffset = scrollView.contentOffset
                    newOffset.y += 1
                    
                    scrollView.setContentOffset(newOffset, animated: false)
                    scrollView.setContentOffset(oldOffset, animated: false)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollDisabled(context.viewState.roomListMode == .skeletons)
            .scrollBounceBehavior(context.viewState.roomListMode == .empty ? .basedOnSize : .automatic)
            .animation(.elementDefault, value: context.viewState.roomListMode)
            .animation(.none, value: context.viewState.visibleRooms)
            .safeAreaPadding(.bottom, context.viewState.shouldShowFilters ? WhistlepigTheme.Spacing.sm : 0)
        }
    }
    
    private var topSection: some View {
        VStack(spacing: 0) {
            WhistlepigRoomListHeader(context: context)
            
            if case let .show(state) = context.viewState.securityBannerMode {
                HomeScreenRecoveryKeyConfirmationBanner(state: state, context: context)
            } else if context.viewState.shouldShowNewSoundBanner {
                HomeScreenNewSoundBanner { context.send(viewAction: .dismissNewSoundBanner) }
            }
        }
        .readHeight($topSectionHeight)
    }
    
    /// Often times the scroll view's content size isn't correct yet when this method is called e.g. when cancelling a search
    /// Dispatch it with a delay to allow the UI to update and the computations to be correct
    /// Once we move to iOS 17 we should remove all of this and use scroll anchors instead
    /// Update: We're on iOS 26 now and the scroll achors still don't work properly.
    private func updateVisibleRange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { delayedUpdateVisibleRange() }
    }
    
    private func delayedUpdateVisibleRange() {
        guard scrollViewAdapter.isScrolling.value == false else {
            // Scrolling reports live through didScroll
            return
        }
        sendVisibleRange()
    }
    
    private func sendVisibleRange() {
        guard let scrollView = scrollViewAdapter.scrollView,
              context.searchQuery.isEmpty == true, // Ignore while filtering
              !context.viewState.visibleRooms.isEmpty else {
            return
        }
        
        guard scrollView.contentSize.height > scrollView.bounds.height else {
            // This list never scrolls, publish the range manually.
            context.send(viewAction: .updateVisibleItemRange(0..<context.viewState.visibleRooms.count))
            return
        }
        
        let adjustedContentSize = max(scrollView.contentSize.height - scrollView.contentInset.top - scrollView.contentInset.bottom, scrollView.bounds.height)
        let cellHeight = adjustedContentSize / Double(context.viewState.visibleRooms.count)
        
        let firstIndex = Int(max(0.0, scrollView.contentOffset.y + scrollView.contentInset.top) / cellHeight)
        let lastIndex = Int(max(0.0, scrollView.contentOffset.y + scrollView.bounds.height) / cellHeight)
        
        // This will be deduped and throttled on the view model layer
        context.send(viewAction: .updateVisibleItemRange(firstIndex..<lastIndex))
    }
}

private extension View {
    @ViewBuilder
    func roomListSearchable(isEnabled: Bool, isSearchFieldFocused: Binding<Bool>, searchQuery: Binding<String>) -> some View {
        if isEnabled {
            isSearching(isSearchFieldFocused)
                .searchable(text: searchQuery, placement: .navigationBarDrawer(displayMode: .always))
                .compoundSearchField()
                .disableAutocorrection(true)
        } else {
            self
        }
    }
}
