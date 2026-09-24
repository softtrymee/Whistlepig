//
// Copyright 2026 Whistlepig contributors.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Combine

typealias StickerPickerViewModelType = StateStoreViewModelV2<StickerPickerViewState, StickerPickerViewAction>

final class StickerPickerViewModel: StickerPickerViewModelType, Identifiable {
    private let stickerPackService: StickerPackService
    private let actionsSubject = PassthroughSubject<StickerPickerViewModelAction, Never>()
    
    var actions: AnyPublisher<StickerPickerViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(roomProxy: JoinedRoomProxyProtocol,
         clientProxy: ClientProxyProtocol,
         mediaProvider: MediaProviderProtocol) {
        stickerPackService = StickerPackService(roomProxy: roomProxy, clientProxy: clientProxy)
        super.init(initialViewState: .init(), mediaProvider: mediaProvider)
        loadPacks()
    }
    
    override func process(viewAction: StickerPickerViewAction) {
        switch viewAction {
        case .dismiss:
            actionsSubject.send(.dismiss)
        case .retry:
            loadPacks()
        case .select(let sticker):
            actionsSubject.send(.sendSticker(sticker))
        }
    }
    
    private func loadPacks() {
        state.isLoading = true
        state.didFailLoading = false
        
        Task { [weak self] in
            guard let self else { return }
            
            switch await stickerPackService.loadStickerPacks() {
            case .success(let packs):
                state.packs = packs
            case .failure:
                state.didFailLoading = true
            }
            state.isLoading = false
        }
    }
}
