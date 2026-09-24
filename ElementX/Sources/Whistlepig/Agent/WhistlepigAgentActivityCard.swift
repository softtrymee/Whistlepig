//
// Copyright 2026 Whistlepig
//

import SwiftUI

/// The visual lifecycle of an Agent activity. Text and business state stay with the caller.
enum WhistlepigAgentActivityStatus: Equatable {
    case active
    case completed
    case error
}

struct WhistlepigAgentActivityRow: Identifiable, Equatable {
    let id: String
    let title: String
    let isComplete: Bool

    init(id: String, title: String, isComplete: Bool = false) {
        self.id = id
        self.title = title
        self.isComplete = isComplete
    }
}

/// A compact, passive activity surface. Each animated decoration (indicator, border, wash)
/// drives its own native-refresh TimelineView, so the moving layers stay smooth while the
/// text content is only re-evaluated when the underlying data actually changes.
struct WhistlepigAgentActivityCard: View {
    let status: WhistlepigAgentActivityStatus
    let rows: [WhistlepigAgentActivityRow]
    let commentary: String?
    let formattedCommentary: AttributedString?

    init(status: WhistlepigAgentActivityStatus,
         rows: [WhistlepigAgentActivityRow] = [],
         commentary: String? = nil,
         formattedCommentary: AttributedString? = nil) {
        self.status = status
        self.rows = rows
        self.commentary = commentary
        self.formattedCommentary = formattedCommentary
    }

    var body: some View {
        WhistlepigAgentActivityCardContent(status: status,
                                           rows: rows,
                                           commentary: commentary,
                                           formattedCommentary: formattedCommentary)
    }
}

private struct WhistlepigAgentActivityCardContent: View {
    let status: WhistlepigAgentActivityStatus
    let rows: [WhistlepigAgentActivityRow]
    let commentary: String?
    let formattedCommentary: AttributedString?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var isActive: Bool { status == .active }
    private var activityLines: [Substring] {
        commentary?.split(separator: "\n", omittingEmptySubsequences: false) ?? []
    }
    private var primaryLabel: String {
        activityLines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    private var detailText: String? {
        guard activityLines.count > 1 else { return nil }
        let text = activityLines.dropFirst().joined(separator: "\n")
        return text.isEmpty ? nil : text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WhistlepigTheme.Spacing.md) {
            HStack(alignment: .center, spacing: WhistlepigTheme.Spacing.sm) {
                WhistlepigAgentActivityIndicator(status: status)
                // A formatted commentary is rendered as one rich body below. Do not
                // split it into a plain status line (which would lose markup or
                // duplicate the first line); the indicator still conveys activity.
                if formattedCommentary == nil, !primaryLabel.isEmpty {
                    Text(primaryLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }

            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: WhistlepigTheme.Spacing.sm) {
                    ForEach(rows) { row in
                        WhistlepigAgentActivityRowView(row: row, isActive: isActive)
                    }
                }
                .padding(.leading, 8)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(WhistlepigTheme.ColorToken.separator.opacity(reduceTransparency ? 0.7 : 0.45))
                        .frame(width: 1)
                }
            }

            if let formattedCommentary {
                // Keep the same rich HTML/markdown rendering path as ordinary messages.
                // In particular this preserves tables, code blocks and links in edits.
                FormattedBodyText(attributedString: formattedCommentary)
                    .contentTransition(.opacity)
            } else if let detailText {
                Text(detailText)
                    .font(.system(size: 15))
                    .foregroundStyle(WhistlepigTheme.ColorToken.textPrimary)
                    .lineLimit(4)
                    .contentTransition(.opacity)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, WhistlepigTheme.Spacing.lg)
        .padding(.vertical, WhistlepigTheme.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: WhistlepigTheme.Radius.control, style: .continuous)
                .fill(WhistlepigTheme.ColorToken.elevated)
                .overlay {
                    if isActive {
                        WhistlepigAgentActiveWash(colorScheme: colorScheme,
                                                  reduceTransparency: reduceTransparency,
                                                  reduceMotion: reduceMotion)
                            .clipShape(RoundedRectangle(cornerRadius: WhistlepigTheme.Radius.control, style: .continuous))
                    }
                }
        }
        .overlay {
            if isActive {
                WhistlepigAgentActiveBorder(reduceTransparency: reduceTransparency,
                                            reduceMotion: reduceMotion)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: WhistlepigTheme.Radius.control, style: .continuous))
        .accessibilityElement(children: .combine)
        .animation(.elementDefault, value: status)
        .animation(.elementDefault, value: rows)
        .animation(.elementDefault, value: commentary)
    }
}

private struct WhistlepigAgentActivityIndicator: View {
    let status: WhistlepigAgentActivityStatus

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if status == .active {
                if reduceMotion {
                    Circle()
                        .stroke(WhistlepigTheme.ColorToken.accentPrimary, lineWidth: 1.75)
                        .transition(.opacity)
                } else {
                    SwiftUI.TimelineView(.animation) { context in
                        let phase = Self.phase(at: context.date)
                        Circle()
                            .trim(from: 0.12, to: 0.80)
                            .stroke(WhistlepigTheme.ColorToken.accentPrimary, style: .init(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(phase * 360))
                            .scaleEffect(0.92 + 0.08 * sin(phase * 2 * .pi))
                    }
                    .transition(.opacity)
                }
            } else {
                Image(systemName: status == .error ? "exclamationmark" : "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(status == .error ? WhistlepigTheme.ColorToken.textSecondary : WhistlepigTheme.ColorToken.accentPrimary)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 16, height: 16)
        .contentTransition(.opacity)
        .animation(.elementDefault, value: status)
        .accessibilityHidden(true)
    }

    private static func phase(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
    }
}

private struct WhistlepigAgentActivityRowView: View {
    let row: WhistlepigAgentActivityRow
    let isActive: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: WhistlepigTheme.Spacing.sm) {
            Image(systemName: row.isComplete ? "checkmark" : "circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(row.isComplete ? WhistlepigTheme.ColorToken.accentPrimary : WhistlepigTheme.ColorToken.textTertiary)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(row.title)
                .font(.system(size: 15))
                .foregroundStyle(WhistlepigTheme.ColorToken.textSecondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
        .background {
            if isActive, !row.isComplete {
                Capsule()
                    .fill(WhistlepigTheme.ColorToken.accentSoft.opacity(reduceTransparency ? 0.10 : 0.08))
                    .padding(.vertical, -2)
            }
        }
        .contentTransition(.opacity)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

private struct WhistlepigAgentActiveWash: View {
    let colorScheme: ColorScheme
    let reduceTransparency: Bool
    let reduceMotion: Bool

    private var maxOpacity: Double {
        reduceTransparency ? 0.10 : (colorScheme == .dark ? 0.22 : 0.14)
    }

    var body: some View {
        GeometryReader { geo in
            let radius = max(geo.size.width, geo.size.height)
            if reduceMotion {
                nebula(time: 0, radius: radius)
            } else {
                SwiftUI.TimelineView(.animation) { context in
                    nebula(time: context.date.timeIntervalSinceReferenceDate, radius: radius)
                }
            }
        }
    }

    private func nebula(time: Double, radius: Double) -> some View {
        ZStack {
            nebulaBlob(color: WhistlepigTheme.ColorToken.accentPrimary,
                       cx: 0.30, cy: 0.38, ax: 0.20, ay: 0.16,
                       fx: 0.33, fy: 0.44, fo: 0.38,
                       phx: 0.0, phy: 1.7, pho: 0.5,
                       base: maxOpacity, time: time, radius: radius)
            nebulaBlob(color: WhistlepigTheme.ColorToken.accentSoft,
                       cx: 0.66, cy: 0.54, ax: 0.18, ay: 0.22,
                       fx: 0.29, fy: 0.52, fo: 0.47,
                       phx: 2.1, phy: 0.4, pho: 3.1,
                       base: maxOpacity * 0.9, time: time, radius: radius)
            nebulaBlob(color: WhistlepigTheme.ColorToken.accentPrimary,
                       cx: 0.52, cy: 0.30, ax: 0.24, ay: 0.18,
                       fx: 0.41, fy: 0.35, fo: 0.31,
                       phx: 4.2, phy: 2.6, pho: 1.2,
                       base: maxOpacity * 0.75, time: time, radius: radius)
        }
        .blur(radius: 28)
    }

    // Each blob drifts and breathes on sines of real time at mutually non-integer
    // frequencies, so the composite never settles into a visible repeat and — since sine is
    // smooth and continuous — never snaps.
    private func nebulaBlob(color: Color, cx: Double, cy: Double, ax: Double, ay: Double,
                            fx: Double, fy: Double, fo: Double,
                            phx: Double, phy: Double, pho: Double,
                            base: Double, time: Double, radius: Double) -> some View {
        let ux = cx + ax * sin(time * fx + phx)
        let uy = cy + ay * sin(time * fy + phy)
        let breath = 0.5 + 0.5 * sin(time * fo + pho)
        return RadialGradient(colors: [color.opacity(base * breath), .clear],
                              center: UnitPoint(x: ux, y: uy),
                              startRadius: 0,
                              endRadius: radius * 0.55)
    }
}

private struct WhistlepigAgentActiveBorder: View {
    let reduceTransparency: Bool
    let reduceMotion: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WhistlepigTheme.Radius.control, style: .continuous)
        return Group {
            if reduceMotion {
                shape.stroke(WhistlepigTheme.ColorToken.accentPrimary.opacity(reduceTransparency ? 0.4 : 0.6),
                             lineWidth: 2)
            } else {
                SwiftUI.TimelineView(.animation) { context in
                    // Roaming highlight arc. Bound the angle to [0,360): an angular gradient wraps
                    // 360°→0° seamlessly, and bounding avoids the extreme magnitudes (time is
                    // ~7.8e8 seconds) that break rendering. ~90°/sec travel.
                    let angle = (context.date.timeIntervalSinceReferenceDate * 90).truncatingRemainder(dividingBy: 360)
                    shape.stroke(AngularGradient(gradient: Gradient(colors: [.clear,
                                                                             WhistlepigTheme.ColorToken.accentPrimary.opacity(reduceTransparency ? 0.7 : 1.0),
                                                                             .clear]),
                                                 center: .center,
                                                 startAngle: .degrees(angle - 60),
                                                 endAngle: .degrees(angle + 60)),
                                 lineWidth: 2)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
