//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import MatrixRustSDK
import SwiftUI

typealias MediaUploadPreviewScreenViewModelType = StateStoreViewModelV2<MediaUploadPreviewScreenViewState, MediaUploadPreviewScreenViewAction>

class MediaUploadPreviewScreenViewModel: MediaUploadPreviewScreenViewModelType, MediaUploadPreviewScreenViewModelProtocol {
    private let timelineController: TimelineControllerProtocol
    private let userIndicatorController: UserIndicatorControllerProtocol
    
    private let mediaUploadingPreprocessor: MediaUploadingPreprocessor
    private var mediaURLs: [URL]
    
    private var processingTask: Task<Result<[MediaInfo], MediaUploadingPreprocessorError>, Never>
    private var requestHandle: SendAttachmentJoinHandleProtocol?
    private let clientProxy: ClientProxyProtocol
    private let galleryEnabled: Bool
    private let completionSuggestionService: CompletionSuggestionServiceProtocol
    
    private var actionsSubject: PassthroughSubject<MediaUploadPreviewScreenViewModelAction, Never> = .init()
    
    var actions: AnyPublisher<MediaUploadPreviewScreenViewModelAction, Never> {
        actionsSubject.eraseToAnyPublisher()
    }
    
    init(mediaURLs: [URL],
         caption: NSAttributedString?,
         title: String?,
         shouldShowCaptionWarning: Bool,
         galleryEnabled: Bool,
         mediaUploadingPreprocessor: MediaUploadingPreprocessor,
         timelineController: TimelineControllerProtocol,
         clientProxy: ClientProxyProtocol,
         userIndicatorController: UserIndicatorControllerProtocol,
         mediaProvider: MediaProviderProtocol,
         completionSuggestionService: CompletionSuggestionServiceProtocol) {
        self.mediaURLs = mediaURLs
        self.mediaUploadingPreprocessor = mediaUploadingPreprocessor
        self.timelineController = timelineController
        self.clientProxy = clientProxy
        self.userIndicatorController = userIndicatorController
        self.galleryEnabled = galleryEnabled
        self.completionSuggestionService = completionSuggestionService
        
        // Start processing the media whilst the user is reviewing it/adding a caption.
        processingTask = Self.processMedia(at: mediaURLs, preprocessor: mediaUploadingPreprocessor, clientProxy: clientProxy)
        
        super.init(initialViewState: MediaUploadPreviewScreenViewState(mediaURLs: mediaURLs,
                                                                       title: title,
                                                                       shouldShowCaptionWarning: shouldShowCaptionWarning,
                                                                       bindings: .init(caption: caption ?? NSAttributedString())),
                   mediaProvider: mediaProvider)
        completionSuggestionService.suggestionsPublisher
            .weakAssign(to: \.state.suggestions, on: self)
            .store(in: &cancellables)
    }
    
    override func process(viewAction: MediaUploadPreviewScreenViewAction) {
        let captionContent = PlainTextMentionContent(attributedString: state.bindings.caption)
        let caption = captionContent.text.isBlank ? nil : captionContent.text
        
        switch viewAction {
        case .send:
            startLoading()
            Task {
                defer { stopLoading() }
                switch await processingTask.value {
                case .success(let mediaInfos):
                    if galleryEnabled, mediaInfos.count > 1 {
                        switch await sendGallery(mediaInfos: mediaInfos, caption: caption, intentionalMentions: captionContent.intentionalMentions) {
                        case .success: break
                        case .failure: showError(label: L10n.screenMediaUploadPreviewErrorFailedSending)
                        }
                    } else {
                        var perItemCaption = caption
                        for mediaInfo in mediaInfos {
                            let mentions = perItemCaption == nil ? IntentionalMentions.empty : captionContent.intentionalMentions
                            switch await sendAttachment(mediaInfo: mediaInfo, caption: perItemCaption, intentionalMentions: mentions) {
                            case .success: perItemCaption = nil
                            case .failure: showError(label: L10n.screenMediaUploadPreviewErrorFailedSending)
                            }
                        }
                    }
                    actionsSubject.send(.dismiss)
                case .failure(.maxUploadSizeUnknown):
                    showAlert(.maxUploadSizeUnknown)
                case .failure(.maxUploadSizeExceeded(let limit)):
                    showAlert(.maxUploadSizeExceeded(limit: limit))
                case .failure(let error):
                    MXLog.error("Failed processing media to upload with error: \(error)")
                    showError(label: L10n.screenMediaUploadPreviewErrorFailedProcessing)
                }
            }
        case .cancel:
            requestHandle?.cancel()
            actionsSubject.send(.dismiss)
        case .editedMedia(let image, let index):
            guard mediaURLs.indices.contains(index), let data = image.jpegData(compressionQuality: 1.0) else { return }
            do {
                try data.write(to: mediaURLs[index], options: .atomic)
                state.mediaEditVersion += 1
                processingTask.cancel()
                processingTask = Self.processMedia(at: mediaURLs, preprocessor: mediaUploadingPreprocessor, clientProxy: clientProxy)
            } catch {
                MXLog.error("Failed writing cropped image")
            }
        case .captionTextChanged, .selectedTextChanged:
            completionSuggestionService.processTextMessage(state.bindings.caption.string, selectedRange: state.bindings.selectedRange)
        case .selectedSuggestion(let suggestion):
            handleSuggestion(suggestion)
        }
    }
    
    private func handleSuggestion(_ suggestion: SuggestionItem) {
        let attributedString = NSMutableAttributedString(attributedString: state.bindings.caption)
        let replacementRange = suggestion.range
        let replacement: String
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        switch suggestion.suggestionType {
        case let .user(user):
            guard let url = try? URL(string: matrixToUserPermalink(userId: user.id)) else { return }
            replacement = "@" + (user.displayName ?? user.id)
            attributes = [.link: url,
                          .MatrixUserID: user.id]
            if let displayName = user.displayName {
                attributes[.MatrixUserDisplayName] = displayName
            }
        case .allUsers:
            replacement = PillUtilities.atRoom
            attributes = [.MatrixAllUsersMention: true]
        case let .room(room):
            guard let url = try? URL(string: matrixToRoomAliasPermalink(roomAlias: room.canonicalAlias)) else { return }
            replacement = "#" + room.name
            attributes = [.link: url,
                          .MatrixRoomAlias: room.canonicalAlias,
                          .MatrixRoomDisplayName: room.name]
        }
        
        attributedString.replaceCharacters(in: replacementRange, with: replacement)
        let insertedRange = NSRange(location: replacementRange.location, length: (replacement as NSString).length)
        attributedString.addAttributes(attributes, range: insertedRange)
        
        // Caption previews do not own a timeline context, so mention pills cannot safely be
        // rendered here. The semantic attributes preserve the same Matrix mention payload.
        completionSuggestionService.setSuggestionTrigger(nil)
        state.bindings.caption = attributedString
        state.bindings.selectedRange = .init(location: NSMaxRange(insertedRange), length: 0)
    }
    
    private func sendGallery(mediaInfos: [MediaInfo], caption: String?, intentionalMentions: IntentionalMentions) async -> Result<Void, TimelineControllerError> {
        let itemInfos: [GalleryItemInfo] = mediaInfos.map { mediaInfo in
            switch mediaInfo {
            case let .image(imageURL, thumbnailURL, imageInfo):
                .image(imageInfo: imageInfo,
                       source: .file(filename: imageURL.path(percentEncoded: false)),
                       caption: nil,
                       formattedCaption: nil,
                       thumbnailSource: .file(filename: thumbnailURL.path(percentEncoded: false)))
            case let .video(videoURL, thumbnailURL, videoInfo):
                .video(videoInfo: videoInfo,
                       source: .file(filename: videoURL.path(percentEncoded: false)),
                       caption: nil,
                       formattedCaption: nil,
                       thumbnailSource: .file(filename: thumbnailURL.path(percentEncoded: false)))
            case let .audio(audioURL, audioInfo):
                .audio(audioInfo: audioInfo,
                       source: .file(filename: audioURL.path(percentEncoded: false)),
                       caption: nil,
                       formattedCaption: nil)
            case let .file(fileURL, fileInfo):
                .file(fileInfo: fileInfo,
                      source: .file(filename: fileURL.path(percentEncoded: false)),
                      caption: nil,
                      formattedCaption: nil)
            }
        }
        
        return await timelineController.sendGallery(itemInfos: itemInfos,
                                                    caption: caption,
                                                    intentionalMentions: intentionalMentions,
                                                    inReplyToEventID: nil)
    }
    
    func stopProcessing() {
        processingTask.cancel()
    }
    
    // MARK: - Private
    
    private static func processMedia(at urls: [URL],
                                     preprocessor: MediaUploadingPreprocessor,
                                     clientProxy: ClientProxyProtocol) -> Task<Result<[MediaInfo], MediaUploadingPreprocessorError>, Never> {
        Task {
            guard case let .success(maxUploadSize) = await clientProxy.maxMediaUploadSize else { return .failure(.maxUploadSizeUnknown) }
            return await preprocessor.processMedia(at: urls, maxUploadSize: maxUploadSize)
        }
    }
    
    private func sendAttachment(mediaInfo: MediaInfo, caption: String?, intentionalMentions: IntentionalMentions) async -> Result<Void, TimelineControllerError> {
        let requestHandle: (@MainActor @Sendable (SendAttachmentJoinHandleProtocol) -> Void) = { [weak self] handle in
            self?.requestHandle = handle
        }
        
        switch mediaInfo {
        case let .image(imageURL, thumbnailURL, imageInfo):
            return await timelineController.sendImage(url: imageURL,
                                                      thumbnailURL: thumbnailURL,
                                                      imageInfo: imageInfo,
                                                      caption: caption,
                                                      intentionalMentions: intentionalMentions,
                                                      requestHandle: requestHandle)
        case let .video(videoURL, thumbnailURL, videoInfo):
            return await timelineController.sendVideo(url: videoURL,
                                                      thumbnailURL: thumbnailURL,
                                                      videoInfo: videoInfo,
                                                      caption: caption,
                                                      intentionalMentions: intentionalMentions,
                                                      requestHandle: requestHandle)
        case let .audio(audioURL, audioInfo):
            return await timelineController.sendAudio(url: audioURL,
                                                      audioInfo: audioInfo,
                                                      caption: caption,
                                                      intentionalMentions: intentionalMentions,
                                                      requestHandle: requestHandle)
        case let .file(fileURL, fileInfo):
            return await timelineController.sendFile(url: fileURL,
                                                     fileInfo: fileInfo,
                                                     caption: caption,
                                                     intentionalMentions: intentionalMentions,
                                                     requestHandle: requestHandle)
        }
    }
    
    private static let loadingIndicatorIdentifier = "\(MediaUploadPreviewScreenViewModel.self)-Loading"
    
    private func startLoading() {
        userIndicatorController.submitIndicator(UserIndicator(id: Self.loadingIndicatorIdentifier,
                                                              type: .modal(progress: .indeterminate, interactiveDismissDisabled: false, allowsInteraction: true),
                                                              title: L10n.commonPreparing,
                                                              persistent: true),
                                                delay: .milliseconds(100))
        
        state.shouldDisableInteraction = true
    }
    
    private func stopLoading() {
        userIndicatorController.retractIndicatorWithId(Self.loadingIndicatorIdentifier)
        state.shouldDisableInteraction = false
        requestHandle = nil
    }
    
    private func showError(label: String) {
        userIndicatorController.submitIndicator(UserIndicator(title: label))
    }
    
    private func showAlert(_ alertType: MediaUploadPreviewAlertType) {
        switch alertType {
        case .maxUploadSizeUnknown:
            state.bindings.alertInfo = .init(id: alertType,
                                             title: L10n.commonSomethingWentWrong,
                                             message: L10n.screenMediaUploadPreviewErrorCouldNotBeUploaded,
                                             primaryButton: .init(title: L10n.actionTryAgain) { [weak self] in
                                                 guard let self else { return }
                                                 processingTask = Self.processMedia(at: mediaURLs, preprocessor: mediaUploadingPreprocessor, clientProxy: clientProxy)
                                                 process(viewAction: .send)
                                             },
                                             secondaryButton: .init(title: L10n.actionCancel, role: .cancel) { })
        case .maxUploadSizeExceeded(let limit):
            state.bindings.alertInfo = .init(id: alertType,
                                             title: L10n.screenMediaUploadPreviewErrorTooLargeTitle,
                                             message: L10n.screenMediaUploadPreviewErrorTooLargeMessage(limit.formatted(.byteCount(style: .file))),
                                             primaryButton: .init(title: L10n.actionCancel, role: .cancel) { })
        }
    }
}

extension NSAttributedString {
    var nonBlankString: String? {
        guard !string.isBlank else { return nil }
        return string
    }
}
