import SwiftUI

/// Asistente de bienvenida y primera configuración de TankControl (5 pasos).
public struct OnboardingView: View {
    public let onDismiss: () -> Void
    @State private var currentStep: Int = 0

    private let steps: [(icon: String, title: String, subtitle: String, body: String, tint: Color)] = [
        (
            icon: "sparkles",
            title: "Bienvenido a TankControl",
            subtitle: "Controlador Nativo Apple Silicon",
            body: "Una experiencia moderna, rápida y sin telemetría para tu impresora y escáner HP Smart Tank 500 series en macOS.",
            tint: DesignTokens.Colors.brandTeal
        ),
        (
            icon: "cable.connector",
            title: "Conexión USB Directa",
            subtitle: "Sin Dependencias de Nube",
            body: "Conecta tu impresora directamente a un puerto USB de tu Mac. TankControl se comunica mediante protocolos de hardware nativos y CUPS local.",
            tint: .blue
        ),
        (
            icon: "drop.triangle.fill",
            title: "Depósitos de Tinta CISS",
            subtitle: "Monitoreo Transparente",
            body: "Observa los niveles estimados de tus depósitos K, C, M y Y. Recuerda que los tanques CISS no tienen flotadores electrónicos: el nivel físico definitivo se verifica en las ventanas frontales.",
            tint: .purple
        ),
        (
            icon: "leaf.fill",
            title: "Ahorro Inteligente InkSaver",
            subtitle: "Preserva Tinta y Nitidez",
            body: "Activa perfiles ecológicos que reducen la densidad de tinta en rellenos y gráficos mientras mantienen el texto 100% nítido en negro puro.",
            tint: .green
        ),
        (
            icon: "checkmark.seal.fill",
            title: "Todo Listo para Empezar",
            subtitle: "Tu Impresora está Bajo Control",
            body: "Puedes acceder a TankControl en cualquier momento desde tu barra de menú o desde la ventana principal.",
            tint: DesignTokens.Colors.brandTeal
        )
    ]

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            let step = steps[currentStep]

            Spacer()

            Image(systemName: step.icon)
                .font(.system(size: 54))
                .foregroundColor(step.tint)
                .frame(width: 90, height: 90)
                .background(step.tint.opacity(0.12))
                .cornerRadius(24)

            VStack(spacing: 4) {
                Text(step.title)
                    .font(DesignTokens.Fonts.headline)
                Text(step.subtitle)
                    .font(DesignTokens.Fonts.captionBold)
                    .foregroundColor(step.tint)
            }

            Text(step.body)
                .font(DesignTokens.Fonts.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Spacer()

            // Indicador de Pasos
            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentStep ? step.tint : Color.gray.opacity(0.3))
                        .frame(width: idx == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(), value: currentStep)
                }
            }

            // Botones de Navegación
            HStack {
                if currentStep > 0 {
                    Button("Atrás") {
                        currentStep -= 1
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Siguiente") {
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(step.tint)
                } else {
                    Button("Comenzar a Usar TankControl") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.Colors.brandTeal)
                }
            }
            .padding(.top, DesignTokens.Spacing.md)
        }
        .padding(DesignTokens.Spacing.xxl)
        .frame(width: 480, height: 420)
        .background(DesignTokens.Colors.windowBackground)
    }
}
