import SwiftUI

/// Vista sobria de estado vacío inspirada en los inspectores del Finder y Utilidad de Discos.
public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public let message: String
    public var actionTitle: String? = nil
    public var action: (() -> Void)? = nil

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary)
                .padding(.bottom, 2)

            Text(title)
                .font(DesignTokens.Fonts.sectionHeader)
                .foregroundColor(.primary)

            Text(message)
                .font(DesignTokens.Fonts.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
