import SwiftUI

/// Componente nativo de fila con etiqueta y valor compatible con macOS 12+ (reemplazo de LabeledContent).
public struct LabeledRow<Content: View>: View {
    public let label: String
    public let content: Content

    public init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .center) {
            Text(label)
                .font(DesignTokens.Fonts.body)
                .foregroundColor(.secondary)
            Spacer()
            content
        }
        .padding(.vertical, 2)
    }
}
