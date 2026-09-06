import SwiftUI

/// Pastilla sobria de estado de hardware con colores semánticos macOS.
public struct StatusBadge: View {
    public let state: PrinterConnectionState

    public init(state: PrinterConnectionState) {
        self.state = state
    }

    private var statusColor: Color {
        switch self.state {
        case .ready:
            return DesignTokens.Colors.statusNormal
        case .printing, .scanning, .busy, .connecting:
            return DesignTokens.Colors.statusProcessing
        case .warning:
            return DesignTokens.Colors.statusAttention
        case .error:
            return DesignTokens.Colors.statusError
        case .disconnected:
            return DesignTokens.Colors.statusUnavailable
        }
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            Text(state.shortBadge)
                .font(DesignTokens.Fonts.captionBold)
                .foregroundColor(state.isConnected ? .primary : .secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(statusColor.opacity(0.12))
        .cornerRadius(DesignTokens.Radii.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estado de la impresora: \(state.label)")
    }
}
