//
// Copyright 2026 Whistlepig contributors.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Compound
import SwiftUI

struct StickerPickerScreen: View {
    let context: StickerPickerViewModel.Context
    
    @ScaledMetric(relativeTo: .title) private var minimumWidth: CGFloat = 56
    @State private var selectedPackID: StickerPickerPack.ID?
    @State private var stickerDataByID = [StickerPickerSticker.ID: Data]()
    @State private var unavailableStickerIDs = Set<StickerPickerSticker.ID>()
    
    var body: some View {
        ElementNavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(L10n.commonSticker)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.actionCancel) {
                            context.send(viewAction: .dismiss)
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private var content: some View {
        if context.viewState.isLoading {
            ProgressView()
        } else if context.viewState.didFailLoading {
            Button(L10n.actionRetry) {
                context.send(viewAction: .retry)
            }
        } else if context.viewState.packs.isEmpty {
            Text(L10n.commonNoResults)
                .foregroundStyle(.compound.textSecondary)
        } else {
            VStack(spacing: 12) {
                StickerPackSelector(packs: context.viewState.packs,
                                    selectedPackID: $selectedPackID)
                
                if let selectedPack {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth))], spacing: 12) {
                            StickerPickerPackView(pack: selectedPack,
                                                  minimumWidth: minimumWidth,
                                                  stickerDataByID: stickerDataByID) { sticker in
                                context.send(viewAction: .select(sticker))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .id(selectedPack.id)
                    .task(id: selectedPack.id) {
                        await preloadStickers(in: selectedPack)
                    }
                }
            }
        }
    }
    
    private var selectedPack: StickerPickerPack? {
        context.viewState.packs.first { $0.id == selectedPackID } ?? context.viewState.packs.first
    }
    
    private func preloadStickers(in pack: StickerPickerPack) async {
        guard let mediaProvider = context.mediaProvider else {
            return
        }
        
        let stickers = pack.stickers.filter { stickerDataByID[$0.id] == nil && !unavailableStickerIDs.contains($0.id) }
        
        await withTaskGroup(of: (StickerPickerSticker.ID, Data?).self) { group in
            for sticker in stickers {
                group.addTask {
                    for attempt in 0..<3 {
                        guard !Task.isCancelled else {
                            return (sticker.id, nil)
                        }
                        
                        if case let .success(data) = await mediaProvider.loadImageDataFromSource(sticker.source) {
                            return (sticker.id, data)
                        }
                        
                        if attempt < 2 {
                            try? await Task.sleep(for: .seconds(1))
                        }
                    }
                    
                    return (sticker.id, nil)
                }
            }
            
            for await (stickerID, data) in group {
                guard !Task.isCancelled else {
                    return
                }
                
                if let data {
                    stickerDataByID[stickerID] = data
                } else {
                    unavailableStickerIDs.insert(stickerID)
                }
            }
        }
    }
}

private struct StickerPickerPackView: View {
    let pack: StickerPickerPack
    let minimumWidth: CGFloat
    let stickerDataByID: [StickerPickerSticker.ID: Data]
    let action: (StickerPickerSticker) -> Void
    
    var body: some View {
        ForEach(pack.stickers.filter { stickerDataByID[$0.id] != nil }) { sticker in
            Button {
                action(sticker)
            } label: {
                if let data = stickerDataByID[sticker.id] {
                    AnimatedStickerImage(data: data)
                        .frame(width: minimumWidth, height: minimumWidth)
                        .accessibilityLabel(sticker.body)
                }
            }
        }
    }
}

private struct StickerPackSelector: View {
    let packs: [StickerPickerPack]
    @Binding var selectedPackID: StickerPickerPack.ID?
    
    var body: some View {
        if packs.count > 1 {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(packs) { pack in
                            Button {
                                selectedPackID = pack.id
                            } label: {
                                Text(pack.name)
                                    .lineLimit(1)
                                    .frame(maxWidth: geometry.size.width / 4)
                            }
                            .buttonStyle(.compound(isSelected(pack) ? .primary : .tertiary, size: .small))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(height: 32)
        }
    }
    
    private func isSelected(_ pack: StickerPickerPack) -> Bool {
        pack.id == selectedPackID || (selectedPackID == nil && pack.id == packs.first?.id)
    }
}
