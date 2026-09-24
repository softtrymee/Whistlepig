//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import UIKit

@preconcurrency import MatrixRustSDK

actor MediaLoader: MediaLoaderProtocol {
    private let requestQueue = MediaRequestQueue(maximumConcurrentRequests: 4)
    // We noticed that the keyboard appears to hold onto a reference to the `Context` of the last
    // screen that had text input focus, resulting in its MediaProvider staying alive which in
    // turn keeps this loader alive: https://github.com/element-hq/element-x-ios/issues/4465
    // Therefore the client is `weak` so that the underlying `MatrixRustSDK.Client` is released
    // when e.g. clearing the cache, otherwise we have the potential for 2 `Client`s to be alive
    // at the same time causing havoc.
    //
    // Whilst a more correct fix would be to make `Context.mediaProvider` weak, this requires a
    // bunch of workarounds in our preview tests to keep the mock provider alive as some ViewModels
    // don't have an accompanying ClientMock to own it.
    private weak var client: ClientProtocol?
    private var ongoingRequests = [MediaSourceProxy: Task<Data, Error>]()
    
    init(client: ClientProtocol) {
        self.client = client
    }
    
    func loadMediaContentForSource(_ source: MediaSourceProxy) async throws -> Data {
        try await enqueueLoadMediaRequest(forSource: source) { [weak client] in
            guard let client else { throw MediaLoaderError.missingClient }
            return try await client.getMediaContent(mediaSource: source.underlyingSource)
        }
    }
    
    func loadMediaThumbnailForSource(_ source: MediaSourceProxy, width: UInt, height: UInt) async throws -> Data {
        try await enqueueLoadMediaRequest(forSource: source) { [weak client] in
            guard let client else { throw MediaLoaderError.missingClient }
            return try await client.getMediaThumbnail(mediaSource: source.underlyingSource, width: UInt64(width), height: UInt64(height))
        }
    }
    
    func loadMediaFileForSource(_ source: MediaSourceProxy, filename: String?) async throws -> MediaFileHandleProxy {
        guard let client else { throw MediaLoaderError.missingClient }
        let result = try await client.getMediaFile(mediaSource: source.underlyingSource,
                                                   filename: filename,
                                                   mimeType: source.mimeType ?? "application/octet-stream",
                                                   useCache: true,
                                                   tempDir: nil)
        
        return MediaFileHandleProxy(handle: result)
    }
    
    // MARK: - Private
    
    private func enqueueLoadMediaRequest(forSource source: MediaSourceProxy, operation: @escaping @Sendable () async throws -> Data) async throws -> Data {
        if let ongoingRequest = ongoingRequests[source] {
            return try await ongoingRequest.value
        }
        
        // Wrap the SDK call in a Task so `ongoingRequests` is only mutated when resuming from
        // `task.value` (a runtime-managed await that hops back onto the actor) rather than when
        // resuming directly from the SDK's continuation, which can fire on a Rust thread and
        // mutate the dictionary off-actor, corrupting its storage.
        let ongoingRequest = Task { [requestQueue] in
            await requestQueue.acquire()
            do {
                try Task.checkCancellation()
                let result = try await operation()
                await requestQueue.release()
                return result
            } catch {
                await requestQueue.release()
                throw error
            }
        }
        ongoingRequests[source] = ongoingRequest
        
        defer {
            ongoingRequests[source] = nil
        }
        
        return try await ongoingRequest.value
    }
}

private actor MediaRequestQueue {
    private let maximumConcurrentRequests: Int
    private var activeRequestCount = 0
    private var waitingRequests: [CheckedContinuation<Void, Never>] = []
    
    init(maximumConcurrentRequests: Int) {
        self.maximumConcurrentRequests = maximumConcurrentRequests
    }
    
    func acquire() async {
        guard activeRequestCount >= maximumConcurrentRequests else {
            activeRequestCount += 1
            return
        }
        
        await withCheckedContinuation { waitingRequests.append($0) }
    }
    
    func release() {
        if let waitingRequest = waitingRequests.first {
            waitingRequests.removeFirst()
            waitingRequest.resume()
        } else {
            activeRequestCount -= 1
        }
    }
}
