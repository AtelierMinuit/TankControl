import SwiftUI

public struct SettingsView: View {
    @ObservedObject var printer: PrinterManager
    @State private var showingDeveloperModeConfirmation = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Cabecera
                VStack(alignment: .leading, spacing: 2) {
                    Text("Configuración")
                        .font(DesignTokens.Fonts.title)
                    Text("Preferencias generales y opciones de desarrollo de TankControl.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Grupo 1: Preferencias del Sistema
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Notificaciones y Sistema")
                        .font(DesignTokens.Fonts.sectionHeader)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.accentColor)
                            Text("Avisos de Hardware y Tinta Baja")
                                .font(DesignTokens.Fonts.bodyMedium)
                            Spacer()
                            Text("Activas")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.green)
                        }
                        Text("Notifica automáticamente si algún depósito CISS cae por debajo del 12% o si la impresora reporta un atasco.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // Grupo 2: Herramientas de Desarrollo
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Opciones de Desarrollo")
                        .font(DesignTokens.Fonts.sectionHeader)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Mostrar sección de Desarrollo en la barra lateral", isOn: Binding(
                            get: { printer.developerMode },
                            set: { enabled in
                                if enabled { showingDeveloperModeConfirmation = true }
                                else { printer.developerMode = false }
                            }
                        ))
                        .font(DesignTokens.Fonts.bodyMedium)

                        Text("Habilita el visor de descriptores USB, volcados XML de firmware y diagnósticos de subsistemas.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)

                        if printer.developerMode {
                            Divider()
                            Toggle("Modo Simulación Offline (MOCK STATE)", isOn: $printer.useMock)
                                .font(DesignTokens.Fonts.bodyMedium)
                            Text("Genera lecturas sintéticas para evaluar la interfaz cuando el hardware está desconectado.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
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

                // Grupo 3: Identidad y Versión
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TankControl")
                                .font(DesignTokens.Fonts.headline)
                            Text("Versión " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0-alpha") + " (Apple Silicon ARM64)")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Acerca de…") {
                            printer.selectedSection = .about
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .confirmationDialog("¿Mostrar herramientas de desarrollo?", isPresented: $showingDeveloperModeConfirmation, titleVisibility: .visible) {
            Button("Mostrar herramientas") { printer.developerMode = true }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Incluye operaciones que consumen tinta o envían comandos directos al equipo. Activar esta sección no ejecuta ninguna operación sin confirmación adicional.")
        }
    }
}
