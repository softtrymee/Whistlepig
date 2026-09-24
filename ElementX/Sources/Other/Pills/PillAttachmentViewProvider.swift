//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI
import SwiftUIIntrospect
import UIKit
import WysiwygComposer

protocol PillAttachmentViewProviderDelegate: AnyObject {
    var timelineContext: TimelineViewModel.Context? { get }
    
    func registerPillView(_ pillView: UIView)
    func invalidateTextAttachmentsDisplay()
}

final class PillAttachmentViewProvider: NSTextAttachmentViewProvider, NSSecureCoding {
    private weak var delegate: PillAttachmentViewProviderDelegate?
    
    // MARK: - Override
    
    override nonisolated init(textAttachment: NSTextAttachment, parentView: UIView?, textLayoutManager: NSTextLayoutManager?, location: NSTextLocation) {
        super.init(textAttachment: textAttachment, parentView: parentView, textLayoutManager: textLayoutManager, location: location)
        
        // TextKit isn't annotated but creates the view providers on the main thread,
        // the assumeIsolated below would trap otherwise.
        nonisolated(unsafe) let provider = self
        MainActor.assumeIsolated {
            // SwiftUI/TextKit can insert one or more wrapper views around MessageTextView. Walk
            // the complete ancestor chain so captions rendered inside QuickLook receive the same
            // room context as timeline bubbles.
            var candidate = parentView
            while let view = candidate {
                if let delegate = view as? PillAttachmentViewProviderDelegate {
                    provider.delegate = delegate
                    break
                }
                candidate = view.superview
            }
        }
        tracksTextAttachmentViewBounds = true
    }
    
    override nonisolated func loadView() {
        super.loadView()
        
        // TextKit isn't annotated but loads the view on the main thread,
        // the assumeIsolated below would trap otherwise.
        nonisolated(unsafe) let provider = self
        MainActor.assumeIsolated {
            guard let textAttachment = provider.textAttachment as? PillTextAttachment,
                  let pillData = textAttachment.pillData else {
                MXLog.failure("Attachment is missing data or not of expected class")
                // TextKit may still ask this provider for a view after a malformed attachment was
                // decoded. Give it an inert view rather than leaving `view` nil and letting the
                // framework crash during caption layout.
                provider.view = UIView(frame: .zero)
                return
            }
            
            let context: PillContext
            if ProcessInfo.isXcodePreview || ProcessInfo.isRunningTests {
                // The mock viewModel simulates the loading logic for testing purposes
                context = PillContext.mock(viewState: .mention(isOwnMention: false, displayText: "Alice", statusEmoji: nil),
                                           delay: .seconds(2))
            } else if let timelineContext = provider.delegate?.timelineContext {
                context = PillContext(timelineContext: timelineContext, data: pillData)
            } else {
                // A preview can outlive its room timeline during dismissal or room switching.
                // Preserve a readable mention without requiring a live room context.
                let fallbackView = Self.makeFallbackView(for: pillData)
                provider.view = fallbackView
                provider.delegate?.registerPillView(fallbackView)
                return
            }
            
            let view = PillView(context: context) { [weak provider] in
                provider?.delegate?.invalidateTextAttachmentsDisplay()
            }
            let controller = UIHostingController(rootView: view)
            controller.view.backgroundColor = .clear
            // This allows the text view to handle it as a link
            controller.view.isUserInteractionEnabled = false
            provider.view = controller.view
            provider.delegate?.registerPillView(controller.view)
        }
    }
    
    @MainActor
    private static func makeFallbackView(for data: PillTextAttachmentData) -> UIView {
        let label = UILabel()
        label.text = fallbackText(for: data.type)
        label.font = .systemFont(ofSize: max(10, data.fontData.lineHeight * 0.72), weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.systemBlue
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.textAlignment = .center
        label.numberOfLines = 1
        label.sizeToFit()
        label.bounds.size.width += 10
        label.bounds.size.height = max(label.bounds.height + 2, data.fontData.lineHeight)
        return label
    }

    private static func fallbackText(for type: PillType) -> String {
        switch type {
        case .user(let userID), .roomAlias(let userID), .roomID(let userID):
            userID
        case .allUsers:
            PillUtilities.atRoom
        case .event(let room):
            switch room {
            case .roomAlias(let roomAlias):
                roomAlias
            case .roomID(let roomID):
                roomID
            }
        }
    }

    // MARK: - NSSecureCoding
    
    // Fixes crashes when inserting mention pills in the composer on Mac
    // https://github.com/element-hq/element-x-ios/issues/2070
    
    // periphery:ignore - read comment above
    static var supportsSecureCoding = false
    
    // periphery:ignore - read comment above
    func encode(with coder: NSCoder) { }
    
    // periphery:ignore - read comment above
    init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
}

final class ComposerMentionDisplayHelper: MentionDisplayHelper {
    weak var timelineContext: TimelineViewModel.Context?
    
    init(timelineContext: TimelineViewModel.Context) {
        self.timelineContext = timelineContext
    }
    
    static var mock: Self {
        Self(timelineContext: TimelineViewModel.mock.context)
    }
}

extension WysiwygTextView: PillAttachmentViewProviderDelegate {
    var timelineContext: TimelineViewModel.Context? {
        (mentionDisplayHelper as? ComposerMentionDisplayHelper)?.timelineContext
    }
    
    func invalidateTextAttachmentsDisplay() { }
}
