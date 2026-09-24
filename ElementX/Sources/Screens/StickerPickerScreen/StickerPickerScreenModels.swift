//
// Copyright 2026 Whistlepig contributors.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

struct StickerPickerSticker: Identifiable, Equatable {
    let id: String
    let shortcode: String
    let body: String
    let source: MediaSourceProxy
    let content: String
}

struct StickerPickerPack: Identifiable, Equatable {
    let id: String
    let name: String
    let stickers: [StickerPickerSticker]
}

struct StickerPickerViewState: BindableState {
    var packs: [StickerPickerPack] = []
    var isLoading = true
    var didFailLoading = false
}

enum StickerPickerViewAction {
    case dismiss
    case retry
    case select(StickerPickerSticker)
}

enum StickerPickerViewModelAction {
    case dismiss
    case sendSticker(StickerPickerSticker)
}
