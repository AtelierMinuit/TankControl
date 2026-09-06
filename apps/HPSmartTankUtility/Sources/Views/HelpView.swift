import SwiftUI

/// Asistente de solución de problemas interactivo y documentación de ayuda offline.
public struct HelpView: View {
    @ObservedObject var printer: PrinterManager

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Cabecera
                VStack(alignment: .leading, spacing: 2) {
                    Text("Centro de Ayuda y Solución de Problemas")
                        .font(DesignTokens.Fonts.headline)
                    Text("Guía de resolución de incidencias basada en el árbol de diagnóstico de hardware.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(spacing: DesignTokens.Spacing.md) {
                    // Caso 1: USB
                    HelpDisclosureItem(
                        icon: "cable.connector",
                        title: "1. La impresora no se detecta por USB",
                        content: """
                        • Verifique que el cable USB esté conectado directamente a un puerto del Mac o a un adaptador multipuerto con alimentación.
                        • Compruebe que la impresora esté encendida y la pantalla frontal no muestre códigos de error fijos (E1, E2, E3).
                        • Abra la app 'Información del Sistema' > USB y busque un dispositivo con Vendor ID '0x03f0' y Product ID '0x2b54'.
                        • Si usa macOS Sequoia, confirme que ha concedido permiso de 'Acceso a Accesorios USB'.
                        """
                    )

                    // Caso 2: Trabajos atascados
                    HelpDisclosureItem(
                        icon: "printer.fill",
                        title: "2. Trabajos de impresión atascados o en pausa",
                        content: """
                        • Abra la sección 'Imprimir' en TankControl y compruebe si hay trabajos pendientes.
                        • Puede reiniciar el servicio de impresión de macOS abriendo Terminal y ejecutando:
                          sudo launchctl kickstart -k system/org.cups.cupsd
                        • Verifique si la bandeja de papel tiene hojas cargadas (tamaño A4 o Carta) y la guía lateral ajustada.
                        """
                    )

                    // Caso 3: Impresión en blanco o sin negro
                    HelpDisclosureItem(
                        icon: "drop.triangle.fill",
                        title: "3. La página sale en blanco o le falta el color negro",
                        content: """
                        • En impresoras de tanque continuo (CISS), si la impresora estuvo inactiva varias semanas, la tinta puede retroceder en las mangueras.
                        • Diríjase a la sección 'Mantenimiento' y ejecute un ciclo de 'Limpieza Básica' seguido de un 'Patrón de Inyectores'.
                        • Si el patrón muestra líneas entrecortadas, repita la limpieza hasta 3 veces con intervalos de 10 minutos.
                        • Verifique visualmente en los depósitos frontales que el nivel de tinta no esté por debajo de la línea mínima.
                        """
                    )

                    // Caso 4: Escáner
                    HelpDisclosureItem(
                        icon: "scanner.fill",
                        title: "4. El escáner no responde en Captura de Imagen",
                        content: """
                        • La HP Smart Tank 500 utiliza una interfaz USB dedicada (Interface 2, Clase 0xFF) para el escáner.
                        • En la sección 'Escanear', pulse 'Abrir Captura de Imagen'.
                        • Si no aparece en la barra lateral de Captura de Imagen, verifique en la sección 'Diagnóstico' que el servicio de puente eSCL esté activo.
                        """
                    )

                    // Caso 5: Niveles de Tinta
                    HelpDisclosureItem(
                        icon: "cylinder.split.1x2.fill",
                        title: "5. ¿Por qué el porcentaje de tinta no coincide exactamente con mi tanque?",
                        content: """
                        • La HP Smart Tank 500 no cuenta con flotadores electrónicos en sus depósitos de plástico.
                        • El sistema estima el consumo contando las micro-gotas disparadas por cada inyector térmico.
                        • El nivel definitivo y real SIEMPRE debe verificarse visualmente a través de las ventanas transparentes en el frontal de la impresora.
                        """
                    )
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}

struct HelpDisclosureItem: View {
    let icon: String
    let title: String
    let content: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: icon)
                        .foregroundColor(DesignTokens.Colors.brandTeal)
                        .frame(width: 24, height: 24)

                    Text(title)
                        .font(DesignTokens.Fonts.bodyMedium)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(content)
                    .font(DesignTokens.Fonts.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 32)
                    .padding(.top, 4)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.cardBackground)
        .cornerRadius(DesignTokens.Radii.card)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }
}
