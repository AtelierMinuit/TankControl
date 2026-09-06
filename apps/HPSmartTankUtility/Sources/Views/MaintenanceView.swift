import SwiftUI

/// Centro de Mantenimiento con separación estricta de acciones normales vs avanzadas.
public struct MaintenanceView: View {
    @ObservedObject var printer: PrinterManager

    @State private var showingDeepCleanConfirmation = false

    private var isHardwareAvailable: Bool {
        (printer.connectionState.isConnected || printer.useMock) && !printer.isBusy
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Cabecera
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mantenimiento")
                        .font(DesignTokens.Fonts.title)
                    Text("Herramientas para mantener la calidad de impresión y desobstruir inyectores.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                if !printer.connectionState.isConnected && !printer.useMock {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "wrench.and.screwdriver")
                            .foregroundColor(.secondary)
                        Text("La impresora está desconectada o apagada. Conecta el cable USB para ejecutar operaciones mecánicas.")
                            .font(DesignTokens.Fonts.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                }

                // MARK: - Grupo 1: Diagnóstico No Invasivo
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Diagnóstico de Impresión")
                        .font(DesignTokens.Fonts.sectionHeader)

                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                            .frame(width: 36, height: 36)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(DesignTokens.Radii.small)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Comprobar inyectores")
                                .font(DesignTokens.Fonts.bodyMedium)
                            Text("Imprime una cuadrícula de prueba de 4 colores para detectar boquillas obstruidas.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: { printer.nozzleTest() }) {
                            Text("Imprimir Patrón")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(!isHardwareAvailable)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // MARK: - Grupo 2: Mantenimiento Rutinario (Inset Grouped)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Rutinas de Mantenimiento")
                        .font(DesignTokens.Fonts.sectionHeader)

                    VStack(spacing: 0) {
                        // Fila 1: Limpieza Básica
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.0, green: 0.64, blue: 0.88))
                                .frame(width: 32, height: 32)
                                .background(Color(red: 0.0, green: 0.64, blue: 0.88).opacity(0.12))
                                .cornerRadius(DesignTokens.Radii.small)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Limpieza de Cabezales (Nivel 1)")
                                    .font(DesignTokens.Fonts.bodyMedium)
                                Text("Purga ligera de tinta para eliminar burbujas o residuos secos en las boquillas.")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Limpiar Cabezales") {
                                printer.cleanHeads()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!isHardwareAvailable)
                        }
                        .padding(DesignTokens.Spacing.sm)

                        Divider()
                            .padding(.leading, 48)

                        // Fila 2: Alineación
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16))
                                .foregroundColor(.indigo)
                                .frame(width: 32, height: 32)
                                .background(Color.indigo.opacity(0.12))
                                .cornerRadius(DesignTokens.Radii.small)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Alineación de Cabezales")
                                    .font(DesignTokens.Fonts.bodyMedium)
                                Text("Calibra el avance de micropaso bidireccional si las líneas verticales salen quebradas.")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Alinear Cabezales") {
                                printer.alignHeads()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!isHardwareAvailable)
                        }
                        .padding(DesignTokens.Spacing.sm)

                        Divider()
                            .padding(.leading, 48)

                        // Fila 3: Limpieza Rodillos
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "circle.grid.cross.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .frame(width: 32, height: 32)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(DesignTokens.Radii.small)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Limpieza de Rodillos")
                                    .font(DesignTokens.Fonts.bodyMedium)
                                Text("Acciona el motor de arrastre para retirar residuos de polvo de papel.")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Limpiar Rodillos") {
                                printer.cleanRollers()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!isHardwareAvailable)
                        }
                        .padding(DesignTokens.Spacing.sm)
                    }
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // MARK: - Grupo 3: Mantenimiento Intensivo (Consumo Alto)
                DisclosureGroup("Mantenimiento avanzado · alto consumo de tinta") {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                            .frame(width: 36, height: 36)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(DesignTokens.Radii.small)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Limpieza Profunda (Nivel 2)")
                                    .font(DesignTokens.Fonts.bodyMedium)
                                Text("Alto Consumo")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(3)
                            }
                            Text("Succión al vacío para obstrucciones severas. Consume tinta; la cantidad depende del equipo.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: { showingDeepCleanConfirmation = true }) {
                            Text("Iniciar Limpieza Profunda...")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .disabled(!isHardwareAvailable)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showingDeepCleanConfirmation) {
            ConfirmationSheet(
                title: "Confirmar Limpieza Profunda",
                operationName: "Limpieza Nivel 2 (Deep Clean)",
                riskLevel: "Consumo Alto de Tinta (~6 ml)",
                inkConsumption: "Aprox. 6 ml drenados a la almohadilla",
                estimatedDuration: "2 a 3 minutos",
                technicalWarning: "Esta rutina somete los inyectores a vacío para disolver obstrucciones severas. No ejecutes este proceso más de 2 veces consecutivas.",
                onConfirm: {
                    showingDeepCleanConfirmation = false
                    printer.deepClean()
                },
                onCancel: {
                    showingDeepCleanConfirmation = false
                }
            )
        }
    }
}
