import SwiftUI

/// Vista "Acerca de TankControl" con arquitectura técnica, créditos y descargo legal de responsabilidad.
public struct AboutView: View {
    public var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Icono y Título
                VStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)

                    Text("TankControl")
                        .font(.system(size: 24, weight: .bold))

                    Text("Versión " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Desarrollo"))
                        .font(DesignTokens.Fonts.callout)
                        .foregroundColor(.secondary)

                    Text("Utilidad para HP Smart Tank 500 en macOS")
                        .font(DesignTokens.Fonts.captionBold)
                        .foregroundColor(DesignTokens.Colors.brandTeal)
                }
                .padding(.top, DesignTokens.Spacing.sm)

                // Resumen de Arquitectura y Subsistemas
                DisclosureGroup("Arquitectura de controladores · referencia") {

                    VStack(alignment: .leading, spacing: 6) {
                        LabeledRow("Motor de Impresión:") {
                            Text("PCL3GUI (rastertopcl3gui v1.0.0)")
                                .font(DesignTokens.Fonts.mono)
                        }
                        Divider()
                        LabeledRow("Motor de Escáner:") {
                            Text("SANE / libusb (hp_scan v1.0.0)")
                                .font(DesignTokens.Fonts.mono)
                        }
                        Divider()
                        LabeledRow("Interfases USB:") {
                            Text("0xFF/0xCC/0x00 (Print) • 0xFF/0x04/0x01 (Scan)")
                                .font(DesignTokens.Fonts.mono)
                        }
                        Divider()
                        LabeledRow("Hardware Objetivo:") {
                            Text("HP Smart Tank 500 (VID 0x03F0 : PID 0x2B54)")
                                .font(DesignTokens.Fonts.mono)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }
                .frame(maxWidth: 540)

                // Aviso Legal
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aviso Legal y de Marcas")
                        .font(DesignTokens.Fonts.captionBold)
                        .foregroundColor(.primary)

                    Text("HP® y Smart Tank® son marcas comerciales registradas propiedad de HP Inc. TankControl es un proyecto independiente de código abierto bajo licencias MIT y GPL, desarrollado sin afiliación, patrocinio ni respaldo alguno por parte de HP Inc. La mención de modelos y especificaciones se efectúa exclusivamente a título nominativo para describir la compatibilidad de hardware.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.surfaceGrouped)
                .cornerRadius(DesignTokens.Radii.small)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                        .stroke(DesignTokens.Colors.border, lineWidth: 1)
                )
                .frame(maxWidth: 540)

                Text("Construido con SwiftUI y C nativo para macOS 12 Monterey y posteriores.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.bottom, DesignTokens.Spacing.md)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity)
        }
    }
}
