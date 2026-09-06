import SwiftUI

/// Tarjeta de acción nativa macOS para rutinas de mantenimiento y utilidades.
public struct ActionCard: View {
    public let icon: String
    public let title: String
    public let description: String
    public let buttonLabel: String
    public let tintColor: Color
    public var badge: String? = nil
    public var isDangerous: Bool = false
    public var isLoading: Bool = false
    public let action: () -> Void

    public init(
        icon: String,
        title: String,
        description: String,
        buttonLabel: String,
        tintColor: Color = .accentColor,
        badge: String? = nil,
        isDangerous: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.buttonLabel = buttonLabel
        self.tintColor = tintColor
        self.badge = badge
        self.isDangerous = isDangerous
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tintColor)
                    .frame(width: 26, height: 26)
                    .background(tintColor.opacity(0.12))
                    .cornerRadius(DesignTokens.Radii.small)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(title)
                            .font(DesignTokens.Fonts.bodyMedium)
                            .foregroundColor(.primary)

                        if let badge = badge {
                            Text(badge)
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(isDangerous ? .red : .secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background((isDangerous ? Color.red : Color.secondary).opacity(0.12))
                                .cornerRadius(3)
                        }
                    }

                    Text(description)
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            Button(action: action) {
                HStack {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(height: 12)
                    } else {
                        Text(buttonLabel)
                            .font(DesignTokens.Fonts.captionBold)
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor)
            .disabled(isLoading)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfaceGrouped)
        .cornerRadius(DesignTokens.Radii.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                .stroke(isDangerous ? Color.red.opacity(0.3) : DesignTokens.Colors.border, lineWidth: 1)
        )
    }
}
