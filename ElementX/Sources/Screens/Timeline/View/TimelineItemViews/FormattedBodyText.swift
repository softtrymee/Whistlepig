//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct FormattedBodyText: View {
    private let attributedString: AttributedString
    private let trailingReservedSize: CGSize
    private let boostFontSize: Bool
    
    private let defaultAttributesContainer: AttributeContainer = {
        var container = AttributeContainer()
        // Equivalent to compound's bodyLG
        container.font = UIFont.preferredFont(forTextStyle: .body)
        container.foregroundColor = UIColor.compound.textPrimary
        return container
    }()
    
    private var attributedComponents: [AttributedStringBuilderComponent] {
        var adjustedAttributedString = attributedString
        
        // Required to allow the underlying TextView to use  body font when no font is specified in the AttributedString.
        adjustedAttributedString.mergeAttributes(defaultAttributesContainer, mergePolicy: .keepCurrent)
        
        let string = String(attributedString.characters)
        
        if boostFontSize, let range = adjustedAttributedString.range(of: string) {
            adjustedAttributedString[range].font = UIFont.systemFont(ofSize: 48.0)
        }
        
        return adjustedAttributedString.formattedComponents
    }
    
    init(attributedString: AttributedString,
         trailingReservedSize: CGSize = .zero,
         boostFontSize: Bool = false) {
        self.attributedString = attributedString
        self.trailingReservedSize = trailingReservedSize
        self.boostFontSize = boostFontSize
    }
    
    init(text: String, trailingReservedSize: CGSize = .zero, boostFontSize: Bool = false) {
        self.init(attributedString: AttributedString(text),
                  trailingReservedSize: trailingReservedSize,
                  boostFontSize: boostFontSize)
    }
    
    var body: some View {
        layout
            .tint(.compound.textLinkExternal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(attributedString))
    }
    
    /// The attributed components laid out for the bubbles timeline style.
    var layout: some View {
        // The trailing reserved area must only be applied to the last plain text
        // component so that the bubble's natural size accommodates the overlaid
        // timestamp, and TextKit decides whether to keep the timestamp on the last
        // line or push it to a new one.
        var components = attributedComponents
        // When the body ends in a block component (blockquote/codeBlock) the overlaid
        // timestamp would land on top of it, so append an empty trailing plain-text
        // component that exists solely to reserve space for the timestamp underneath.
        if trailingReservedSize != .zero, let last = components.last, last.type != .plainText {
            components.append(AttributedStringBuilderComponent(id: "",
                                                               attributedString: AttributedString(),
                                                               type: .plainText))
        }
        let lastPlainTextIndex = components.lastIndex { $0.type == .plainText }
        
        return TimelineBubbleLayout(spacing: 8) {
            // The `ForEach` needs to iterate over the id of the element to allow
            // SwiftUI animations to work properly ater any edit.
            ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                switch component.type {
                case .blockquote:
                    BlockquoteView(attributedString: component.attributedString, mode: .rendering)
                        .environment(\.messageTextSelectionEnabled, false)
                        .timelineBubbleLayoutSize(.bubbleWidth(mode: .rendering))
                case .codeBlock:
                    CodeBlockView(attributedString: component.attributedString, mode: .rendering)
                        .environment(\.messageTextSelectionEnabled, false)
                        .timelineBubbleLayoutSize(.bubbleWidth(mode: .rendering))
                        .contextMenu {
                            Button(L10n.actionCopy) {
                                UIPasteboard.general.string = component.attributedString.string
                            }
                        }
                case .table(let table):
                    TableView(table: table, mode: .rendering)
                        .environment(\.messageTextSelectionEnabled, false)
                        .timelineBubbleLayoutSize(.bubbleWidth(mode: .rendering))
                case .plainText:
                    MessageText(attributedString: component.attributedString,
                                trailingReservedSize: index == lastPlainTextIndex ? trailingReservedSize : .zero)
                        .padding(.horizontal, 4)
                        .fixedSize(horizontal: false, vertical: true)
                        .timelineBubbleLayoutSize(.natural)
                }
            }
            
            // Make a second iteration through the components adding naturally sized versions of the
            // block quotes and code blocks which are used for layout calculations but won't be rendered.
            ForEach(components) { component in
                switch component.type {
                case .blockquote:
                    BlockquoteView(attributedString: component.attributedString, mode: .layout)
                        .timelineBubbleLayoutSize(.bubbleWidth(mode: .layout))
                        .hidden()
                case .codeBlock:
                    CodeBlockView(attributedString: component.attributedString, mode: .layout)
                        .timelineBubbleLayoutSize(.bubbleWidth(mode: .layout))
                        .hidden()
                case .table(let table):
                    TableView(table: table, mode: .layout)
                        .timelineBubbleLayoutSize(.bubbleWidth(mode: .layout))
                        .hidden()
                case .plainText:
                    EmptyView()
                }
            }
        }
    }
    
    // MARK: - Component Views
    
    /// The view used to render a blockquote component. It can be configured in one of 2 modes:
    /// - `.layout`: The view is given it's natural size to be used for layout calculations.
    /// - `.rendering`: The view has a greedy width that, in combination with the custom layout,
    /// will fill any available space, whilst remaining constrained by the bubble's calculated width.
    struct BlockquoteView: View {
        let attributedString: AttributedString
        let mode: TimelineBubbleLayout.Size.BubbleWidthMode
        
        var body: some View {
            MessageText(attributedString: attributedString.mergingAttributes(blockquoteAttributes))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: mode == .rendering ? .infinity : nil, alignment: .leading)
                .padding(.leading, 12.0)
                .overlay(alignment: .leading) {
                    // Use an overlay here so that the rectangle's infinite height doesn't take priority
                    if mode == .rendering {
                        Capsule()
                            .frame(width: 2.0)
                            .padding(.leading, 5.0)
                            .foregroundColor(.compound.textSecondary)
                            .padding(.vertical, 2)
                    }
                }
        }
        
        private var blockquoteAttributes: AttributeContainer {
            // The paragraph style removes the block style paragraph that the parser adds by default
            // Set directly in the constructor to avoid `Conformance to 'Sendable'` warnings
            var container = AttributeContainer([.paragraphStyle: NSParagraphStyle.default])
            // Sadly setting SwiftUI fonts do not work so we would need UIFont equivalents for compound, this one is bodyMD
            container.font = UIFont.preferredFont(forTextStyle: .subheadline)
            container.foregroundColor = UIColor.compound.textSecondary
            
            return container
        }
    }
    
    /// The view used to render a code block component. It can be configured in one of 2 modes:
    /// - `.layout`: The view is given it's natural size to be used for layout calculations.
    /// - `.rendering`: The view has a greedy width that, in combination with the custom layout,
    /// will fill any available space, whilst remaining constrained by the bubble's calculated width.
    private struct CodeBlockView: View {
        let attributedString: AttributedString
        let mode: TimelineBubbleLayout.Size.BubbleWidthMode
        
        @State private var maxWidth: CGFloat = .zero
        
        var body: some View {
            ScrollView(.horizontal) {
                MessageText(attributedString: attributedString)
                    .padding([.horizontal, .top], 4)
                    .padding(.bottom, 8)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { maxWidth = $0 }
            }
            .frame(maxWidth: mode == .layout ? maxWidth : nil)
            .background(.compound._bgCodeBlock)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollIndicatorsFlash(onAppear: true)
            .padding(.horizontal, 4)
        }
    }

    /// Renders a Matrix HTML table as a horizontally scrollable block.
    ///
    /// A SwiftUI `Grid` looks like the natural fit here, but it can size a view produced by a
    /// `ForEach` independently when that view contains a UIKit representable. That is exactly
    /// what made the original implementation draw a separate, text-sized rectangle around each
    /// cell. `TableGridLayout` measures every cell first and then places all cells in a shared
    /// column/row matrix, so borders from neighbouring cells always meet.
    private struct TableView: View {
        let table: TableAttribute.Value
        let mode: TimelineBubbleLayout.Size.BubbleWidthMode

        var body: some View {
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 4) {
                    if let caption = table.caption {
                        MessageText(attributedString: caption)
                            .fixedSize(horizontal: true, vertical: true)
                    }

                    TableGridLayout(columnCount: table.rows.first?.cells.count ?? 0) {
                        let cells = table.rows.flatMap(\.cells)
                        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                            TableCellView(cell: cell)
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(maxWidth: mode == .rendering ? .infinity : nil, alignment: .leading)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            .scrollIndicatorsFlash(onAppear: true)
            .padding(.horizontal, 4)
        }
    }

    /// A rectangular layout for table cells.
    ///
    /// The layout intentionally measures with an unspecified proposal. This gives each column
    /// the width of its widest cell and lets the surrounding horizontal `ScrollView` handle a
    /// table wider than the message bubble. During placement every cell receives the shared
    /// column width and row height, which is important for `MessageText` (a UIKit view) because
    /// its intrinsic size otherwise leaks through the cell's border.
    private struct TableGridLayout: Layout {
        let columnCount: Int

        func sizeThatFits(proposal: ProposedViewSize,
                          subviews: Subviews,
                          cache: inout ()) -> CGSize {
            let dimensions = dimensions(for: subviews)
            return CGSize(width: dimensions.columnWidths.reduce(0, +),
                          height: dimensions.rowHeights.reduce(0, +))
        }

        func placeSubviews(in bounds: CGRect,
                           proposal: ProposedViewSize,
                           subviews: Subviews,
                           cache: inout ()) {
            let dimensions = dimensions(for: subviews)
            guard columnCount > 0 else { return }

            var y = bounds.minY
            for row in dimensions.rowHeights.indices {
                var x = bounds.minX
                let rowHeight = dimensions.rowHeights[row]
                for column in 0..<columnCount {
                    let index = row * columnCount + column
                    guard subviews.indices.contains(index) else { break }
                    let width = dimensions.columnWidths[column]
                    subviews[index].place(at: CGPoint(x: x, y: y),
                                          anchor: .topLeading,
                                          proposal: ProposedViewSize(width: width,
                                                                     height: rowHeight))
                    x += width
                }
                y += rowHeight
            }
        }

        private func dimensions(for subviews: Subviews) -> (columnWidths: [CGFloat], rowHeights: [CGFloat]) {
            guard columnCount > 0, !subviews.isEmpty else {
                return ([], [])
            }

            var columnWidths = Array(repeating: CGFloat.zero, count: columnCount)
            var rowHeights = Array(repeating: CGFloat.zero,
                                   count: (subviews.count + columnCount - 1) / columnCount)

            for index in subviews.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: nil, height: nil))
                let row = index / columnCount
                let column = index % columnCount
                columnWidths[column] = max(columnWidths[column], size.width)
                rowHeights[row] = max(rowHeights[row], size.height)
            }

            return (columnWidths, rowHeights)
        }
    }

    private struct TableCellView: View {
        let cell: TableAttribute.Cell

        private var attributedString: AttributedString {
            var value = cell.attributedString
            var defaults = AttributeContainer()
            defaults.font = UIFont.preferredFont(forTextStyle: .body)
            defaults.foregroundColor = UIColor.compound.textPrimary
            value.mergeAttributes(defaults, mergePolicy: .keepCurrent)
            if cell.isHeader {
                value.bold()
            }
            return value
        }

        var body: some View {
            MessageText(attributedString: attributedString)
                // The custom table layout supplies a shared width and height while placing the
                // cell. Keep the text's vertical size, but let this outer frame consume the full
                // cell rectangle so the border is never wrapped tightly around the glyphs.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .overlay {
                    Rectangle()
                        .stroke(Color(uiColor: UIColor.compound.textSecondary).opacity(0.45), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Previews

struct FormattedBodyText_Previews: PreviewProvider, TestablePreview {
    static let attributedStringBuilder = AttributedStringBuilder(cacheKey: "FormattedBodyText", mentionBuilder: MentionBuilder())
    static var previews: some View {
        htmlFixtures
        
        basicText
            .previewLayout(.sizeThatFits)
            .previewDisplayName("basicText")
        
        singleColumnComponents
            .previewLayout(.sizeThatFits)
            .previewDisplayName("singleColumnComponents")
    }
    
    static var basicText: some View {
        VStack(alignment: .leading, spacing: 4.0) {
            FormattedBodyText(attributedString: AttributedString("Some plain text wrapped in an AttributedString."))
                .bubbleBackground()
            
            FormattedBodyText(text: "Some plain text that's not an attributed component.")
                .bubbleBackground()
            
            FormattedBodyText(text: "❤️", boostFontSize: true)
                .bubbleBackground()
        }
        .padding()
    }
    
    /// A preview to help ensure that none of the component types we support result
    /// in a bubble's width becoming wider than the natural width of its contents.
    @ViewBuilder
    static var singleColumnComponents: some View {
        let html = """
        <blockquote>A</blockquote>
        <pre><code>B</code></pre>
        <p>C</p>
        """
        
        if let attributedString = attributedStringBuilder.fromHTML(html) {
            FormattedBodyText(attributedString: attributedString)
                .bubbleBackground()
                .padding(4.0)
        }
    }
    
    @ViewBuilder
    static var htmlFixtures: some View {
        let htmlFixtures = HTMLFixtures.allCases
        
        ForEach(htmlFixtures, id: \.rawValue) { htmlFixture in
            HStack(alignment: .top, spacing: 0) {
                let htmlString = htmlFixture.rawValue
                Text(htmlString)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .padding(4.0)
                
                Divider()
                    .background(.black)
                
                if let attributedString = attributedStringBuilder.fromHTML(htmlString) {
                    FormattedBodyText(attributedString: attributedString)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        .bubbleBackground()
                        .padding(4.0)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .border(.black)
            .padding()
            .previewLayout(.sizeThatFits)
            .previewDisplayName("\(htmlFixture)")
        }
    }
}
