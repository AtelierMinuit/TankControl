import SwiftUI

/// Hoja modal de confirmación sobria y rigurosa ante operaciones con impacto físico sobre el hardware.
public struct ConfirmationSheet: View {
    public let title: String
    public let operationName: String
    public let riskLevel: String            // "Riesgo Alto", "Consumo Crítico", etc.
    public let inkConsumption: String       // "~6 ml de tinta"
    public let estimatedDuration: String     // "2 a 3 minutos"
    public let technicalWarning: String
    public let onConfirm: () -> Void
    public let onCancel: () -> Void

    @State private var acknowledged: Bool = false

    public init(
        title: String,
        operationName: String,
        riskLevel: String = "Consumo Elevado de Tinta",
        inkConsumption: String,
        estimatedDuration: String,
        technicalWarning: String,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.operationName = operationName
        self.riskLevel = riskLevel
        self.inkConsumption = inkConsumption
        self.estimatedDuration = estimatedDuration
        self.technicalWarning = technicalWarning
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Cabecera de Alerta
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(DesignTokens.Colors.statusAttention)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Fonts.sectionHeader)
                    Text("Operación: \(operationName)")
                        .font(DesignTokens.Fonts.captionBold)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Desglose de Impacto Físico
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                LabeledRow("Nivel de Riesgo:") {
                    Text(riskLevel)
                        .font(DesignTokens.Fonts.captionBold)
                        .foregroundColor(DesignTokens.Colors.statusAttention)
                }
                LabeledRow("Consumo Estimado:") {
                    Text(inkConsumption)
                        .font(DesignTokens.Fonts.captionBold)
                }
                LabeledRow("Duración Estimada:") {
                    Text(estimatedDuration)
                        .font(DesignTokens.Fonts.captionBold)
                }
            }
            .padding(DesignTokens.Spacing.sm)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(DesignTokens.Radii.small)

            // Advertencia técnica orientada a usuario
            Text(technicalWarning)
                .font(DesignTokens.Fonts.caption)
                .foregroundColor(.secondary)

            // Casilla de confirmación explícita
            Toggle(isOn: $acknowledged) {
                Text("Comprendo el impacto físico sobre el cabezal y deseo continuar.")
                    .font(DesignTokens.Fonts.caption)
            }
            .padding(.top, 4)

            Divider()

            // Botones de Acción
            HStack {
                Button("Cancelar", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Ejecutar Operación") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.Colors.statusAttention)
                .disabled(!acknowledged)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(width: 420)
        .background(DesignTokens.Colors.surfaceSubtle)
    }
}
