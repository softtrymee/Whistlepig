//
// Copyright 2025 Element Creations Ltd.
// Copyright 2023-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

private nonisolated enum FormattedBlockKind: Equatable {
    case plainText
    case blockquote
    case codeBlock
}

nonisolated extension AttributedString {
    /// faster than doing `String(characters)`: https://forums.swift.org/t/attributedstring-to-string/61667
    var string: String {
        String(characters[...])
    }
    
    var formattedComponents: [AttributedStringBuilderComponent] {
        var components = [AttributedStringBuilderComponent]()
        
        var currentKind: FormattedBlockKind?
        var currentString = AttributedString()

        func appendCurrent() {
            guard let currentKind, !currentString.characters.isEmpty else { return }
            
            // Remove the separator newline added by block-level HTML tags.
            if currentString.characters.last?.isNewline ?? false,
               let range = currentString.range(of: "\n", options: .backwards, locale: nil) {
                currentString.removeSubrange(range)
            }
            
            let componentType: AttributedStringBuilderComponent.ComponentType = switch currentKind {
            case .plainText: .plainText
            case .blockquote: .blockquote
            case .codeBlock: .codeBlock
            }
            
            components.append(AttributedStringBuilderComponent(id: String(currentString.characters),
                                                               attributedString: currentString,
                                                               type: componentType))
            currentString = AttributedString()
        }
        
        for run in runs {
            if let table = run.elementX.table {
                appendCurrent()
                components.append(AttributedStringBuilderComponent(id: "table-\(components.count)",
                                                                   attributedString: AttributedString(),
                                                                   type: .table(table)))
                currentKind = nil
                continue
            }

            let kind: FormattedBlockKind
            if run.elementX.blockquote == true {
                kind = .blockquote
            } else if run.elementX.codeBlock == true {
                kind = .codeBlock
            } else {
                kind = .plainText
            }

            if currentKind == nil {
                currentKind = kind
            } else if currentKind != kind {
                appendCurrent()
                currentKind = kind
        }

            currentString.append(AttributedString(self[run.range]))
        }

        appendCurrent()

        return components
    }
    
    /// Replaces the specified placeholder with the supplied attributed string.
    /// - Parameters:
    ///   - placeholder: The text in the string that will be replaced. Make sure this is unique within the string.
    ///   - attributedString: The text for the link that will be substituted into the placeholder.
    mutating func replace(_ placeholder: String, with replacement: AttributedString) {
        guard let range = range(of: placeholder) else {
            MXLog.failure("Failed to find the placeholder to be replaced.")
            return
        }
        
        // Replace the placeholder.
        replaceSubrange(range, with: replacement)
    }
    
    /// Returns a new attributed string, created by replacing any hard coded `UIFont` with
    /// a simple presentation intent. This allows simple formatting to respond to Dynamic Type.
    ///
    /// Currently only supports regular and bold weights.
    func replacingFontWithPresentationIntent() -> AttributedString {
        var newValue = self
        for run in newValue.runs {
            guard let font = run.uiKit.font else { continue }
            newValue[run.range].inlinePresentationIntent = font.fontDescriptor.symbolicTraits.contains(.traitBold) ? .stronglyEmphasized : nil
            newValue[run.range].uiKit.font = nil
        }
        return newValue
    }
    
    /// Makes the entire string bold by setting the presentation intent to strongly emphasized.
    ///
    /// In practice, this is rendered as semibold for smaller font sizes and just so happens to nicely
    /// line up with the semibold → bold font switch used by compound.
    mutating func bold() {
        self[startIndex..<endIndex].inlinePresentationIntent = .stronglyEmphasized
    }
}
