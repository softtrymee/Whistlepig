//
// Copyright 2026 Whistlepig contributors.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

final class StickerPackService {
    private enum EventType {
        static let accountImagePack = "m.image_pack"
        static let imagePack = "m.room.image_pack"
        static let imagePackRooms = "m.image_pack.rooms"
        static let unstableAccountImagePack = "im.ponies.user_emotes"
        static let unstableImagePack = "im.ponies.room_emotes"
        static let unstableImagePackRooms = "im.ponies.emote_rooms"
    }
    
    private let roomProxy: JoinedRoomProxyProtocol
    private let clientProxy: ClientProxyProtocol
    
    init(roomProxy: JoinedRoomProxyProtocol, clientProxy: ClientProxyProtocol) {
        self.roomProxy = roomProxy
        self.clientProxy = clientProxy
    }
    
    func loadStickerPacks() async -> Result<[StickerPickerPack], Error> {
        var stickerPacks: [StickerPickerPack] = []
        
        for eventType in [EventType.accountImagePack, EventType.unstableAccountImagePack] {
            guard case .success(let json?) = await accountData(eventType: eventType),
                  let pack = makePack(contentJSON: json, id: "account|\(eventType)", fallbackName: L10n.commonSticker) else {
                continue
            }
            stickerPacks.append(pack)
        }
        
        for reference in await globalPackReferences() {
            switch await clientProxy.fetchStateEventsRaw(roomID: reference.roomID) {
            case .success(let events):
                stickerPacks.append(contentsOf: packs(events: events,
                                                      roomID: reference.roomID,
                                                      stateKeys: reference.stateKeys,
                                                      eventTypes: Set([EventType.imagePack, EventType.unstableImagePack])))
            case .failure:
                guard case .joined(let packRoom) = await clientProxy.roomForIdentifier(reference.roomID) else {
                    continue
                }
                await stickerPacks.append(contentsOf: packs(in: packRoom, stateKeys: reference.stateKeys))
            }
        }
        
        await stickerPacks.append(contentsOf: packs(in: roomProxy, stateKeys: nil))
        return .success(stickerPacks)
    }
    
    private func globalPackReferences() async -> [PackReference] {
        var stateKeysByRoomID: [String: Set<String>] = [:]
        
        for eventType in [EventType.imagePackRooms, EventType.unstableImagePackRooms] {
            guard case .success(let json?) = await accountData(eventType: eventType),
                  let data = json.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let rooms = object["rooms"] as? [String: [String: Any]] else {
                continue
            }
            
            for (roomID, entries) in rooms {
                stateKeysByRoomID[roomID, default: []].formUnion(entries.keys)
            }
        }
        
        return stateKeysByRoomID
            .map { PackReference(roomID: $0.key, stateKeys: $0.value) }
            .sorted { $0.roomID < $1.roomID }
    }
    
    private func accountData(eventType: String) async -> Result<String?, ClientProxyError> {
        let result = await clientProxy.fetchAccountData(eventType: eventType)
        switch result {
        case .success:
            return result
        case .failure:
            return await clientProxy.accountData(eventType: eventType)
        }
    }
    
    private func packs(in room: JoinedRoomProxyProtocol, stateKeys: Set<String>?) async -> [StickerPickerPack] {
        var packs: [StickerPickerPack] = []
        var packIDs = Set<String>()
        
        for eventType in [EventType.imagePack, EventType.unstableImagePack] {
            guard case .success(let events) = await room.stateEventsRaw(eventType: eventType) else {
                continue
            }
            
            for event in events {
                guard let pack = makePack(from: event, roomID: room.id, stateKeys: stateKeys),
                      packIDs.insert(pack.id).inserted else {
                    continue
                }
                packs.append(pack)
            }
        }
        
        return packs.sorted { $0.id < $1.id }
    }
    
    private func packs(events: [String], roomID: String, stateKeys: Set<String>?, eventTypes: Set<String>) -> [StickerPickerPack] {
        var packs: [StickerPickerPack] = []
        var packIDs = Set<String>()
        
        for event in events {
            guard let pack = makePack(from: event,
                                      roomID: roomID,
                                      stateKeys: stateKeys,
                                      expectedEventTypes: eventTypes),
                packIDs.insert(pack.id).inserted else {
                continue
            }
            packs.append(pack)
        }
        
        return packs.sorted { $0.id < $1.id }
    }
    
    private func makePack(from eventJSON: String,
                          roomID: String,
                          stateKeys: Set<String>?,
                          expectedEventTypes: Set<String>? = nil) -> StickerPickerPack? {
        guard let data = eventJSON.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              expectedEventTypes?.contains(event["type"] as? String ?? "") ?? true,
              let stateKey = event["state_key"] as? String,
              stateKeys?.contains(stateKey) ?? true,
              let content = event["content"] as? [String: Any] else {
            return nil
        }
        
        return makePack(content: content, id: "\(roomID)|\(stateKey)", fallbackName: roomID)
    }
    
    private func makePack(contentJSON: String, id: String, fallbackName: String) -> StickerPickerPack? {
        guard let data = contentJSON.data(using: .utf8),
              let content = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        return makePack(content: content, id: id, fallbackName: fallbackName)
    }
    
    private func makePack(content: [String: Any], id: String, fallbackName: String) -> StickerPickerPack? {
        let images = images(in: content)
        guard !images.isEmpty else {
            return nil
        }
        
        let usage = ((content["pack"] as? [String: Any])?["usage"] as? [String]) ?? []
        let stickers = images
            .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
            .compactMap { shortcode, image in
                makeSticker(image: image, shortcode: shortcode, packUsage: usage, packID: id)
            }
        guard !stickers.isEmpty else {
            return nil
        }
        
        let name = ((content["pack"] as? [String: Any])?["display_name"] as? String) ?? fallbackName
        return StickerPickerPack(id: id, name: name, stickers: stickers)
    }
    
    private func images(in content: [String: Any]) -> [String: [String: Any]] {
        if let images = content["images"] as? [String: [String: Any]] {
            return images
        }
        if let images = content["emoticons"] as? [String: [String: Any]] {
            return Dictionary(uniqueKeysWithValues: images.map { shortcode, image in
                (shortcode.trimmingCharacters(in: CharacterSet(charactersIn: ":")), image)
            })
        }
        if let shortcodes = content["short"] as? [String: String] {
            return Dictionary(uniqueKeysWithValues: shortcodes.map { shortcode, url in
                (shortcode.trimmingCharacters(in: CharacterSet(charactersIn: ":")), ["url": url])
            })
        }
        return [:]
    }
    
    private func makeSticker(image: [String: Any], shortcode: String, packUsage: [String], packID: String) -> StickerPickerSticker? {
        let usage = (image["usage"] as? [String]) ?? packUsage
        guard usage.isEmpty || usage.contains("sticker") else {
            return nil
        }
        
        let body = (image["body"] as? String) ?? shortcode
        var eventContent = image
        eventContent["body"] = body
        let url = (image["url"] as? String) ?? ((image["file"] as? [String: Any])?["url"] as? String)
        guard let url,
              let mediaURL = URL(string: url),
              let source = try? MediaSourceProxy(url: mediaURL, mimeType: (image["info"] as? [String: Any])?["mimetype"] as? String),
              JSONSerialization.isValidJSONObject(eventContent),
              let contentData = try? JSONSerialization.data(withJSONObject: eventContent),
              let content = String(data: contentData, encoding: .utf8) else {
            return nil
        }
        
        return StickerPickerSticker(id: "\(packID)|\(shortcode)",
                                    shortcode: shortcode,
                                    body: body,
                                    source: source,
                                    content: content)
    }
}

private struct PackReference {
    let roomID: String
    let stateKeys: Set<String>
}
