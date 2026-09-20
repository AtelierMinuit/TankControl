import SwiftUI

/// Centro de Mantenimiento con separación estricta de acciones normales vs avanzadas.
public struct MaintenanceView: View {
    @ObservedObject var printer: PrinterManager

    @State private var showingDeepCleanConfirmation = false
    @State private var showingPrimeTubesConfirmation = false

    private var isHardwareAvailable: Bool {
        printer.connectionState.isConnected && !printer.isBusy
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Cabecera
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mantenimiento")
                        .font(DesignTokens.Fonts.title)
                    Text("Herramientas para mantener la calidad de impresión y desobstruir inyectores.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                if !printer.connectionState.isConnected {
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
                                .frame(width: 135)
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

                // MARK: - Grupo 1.5: Auditoría de Almohadillas de Tinta Residual (Waste Ink Absorber)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Almohadillas de Tinta Residual (Absorber)")
                        .font(DesignTokens.Fonts.sectionHeader)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "drop.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.teal)
                                .frame(width: 36, height: 36)
                                .background(Color.teal.opacity(0.12))
                                .cornerRadius(DesignTokens.Radii.small)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text("Saturación de Almohadilla: ~12.3%")
                                        .font(DesignTokens.Fonts.bodyMedium)
                                    Text("Saludable")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.12))
                                        .cornerRadius(3)
                                }
                                Text("Estimación: ~14.8 ml recolectados de 120 ml de capacidad máxima (~36,800 páginas restantes).")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: { printer.showWasteInk() }) {
                                Text("Auditar Nivel…")
                                    .frame(width: 135)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!isHardwareAvailable)
                        }

                        // Barra de progreso
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.green)
                                    .frame(width: geo.size.width * 0.123, height: 6)
                            }
                        }
                        .frame(height: 6)
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

                            Button(action: { printer.cleanHeads() }) {
                                Text("Limpiar Cabezales")
                                    .frame(width: 135)
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

                            Button(action: { printer.alignHeads() }) {
                                Text("Alinear Cabezales")
                                    .frame(width: 135)
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

                            Button(action: { printer.cleanRollers() }) {
                                Text("Limpiar Rodillos")
                                    .frame(width: 135)
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

                // MARK: - Grupo 3: Mantenimiento Intensivo y Taller CISS
                DisclosureGroup("Mantenimiento avanzado · alto consumo y taller CISS") {
                    VStack(spacing: 8) {
                        // Fila 1: Limpieza Nivel 2
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
                                Text("Succión al vacío para obstrucciones severas. Consume aprox. 6 ml de tinta.")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: { showingDeepCleanConfirmation = true }) {
                                Text("Limpieza Nivel 2…")
                                    .frame(width: 135)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!isHardwareAvailable)
                        }

                        Divider()

                        // Fila 2: Cebado Forzado CISS (Prime Tubes)
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "aqi.medium")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                                .frame(width: 36, height: 36)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(DesignTokens.Radii.small)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Cebado de Mangueras CISS (Prime Tubes)")
                                        .font(DesignTokens.Fonts.bodyMedium)
                                    Text("Taller CISS")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.purple.opacity(0.12))
                                        .cornerRadius(3)
                                }
                                Text("Acciona la micro-bomba peristáltica para eliminar burbujas de aire tras semanas de inactividad.")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: { showingPrimeTubesConfirmation = true }) {
                                Text("Cebar Mangueras…")
                                    .frame(width: 135)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!isHardwareAvailable)
                        }
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
            .padding(DesignTokens.Spacing.md)
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
        .sheet(isPresented: $showingPrimeTubesConfirmation) {
            ConfirmationSheet(
                title: "Confirmar Cebado Forzado CISS",
                operationName: "Purga de Aire en Mangueras (Prime Tubes)",
                riskLevel: "Operación de Taller Hardware",
                inkConsumption: "Aprox. 4 ml succionados en circuito cerrado",
                estimatedDuration: "60 segundos",
                technicalWarning: "Esta operación acciona la bomba para llenar las 4 mangueras de tinta si entraron burbujas de aire tras meses sin imprimir. Asegúrate de que los 4 depósitos de tinta tengan más del 50% de llenado.",
                onConfirm: {
                    showingPrimeTubesConfirmation = false
                    printer.primeTubes()
                },
                onCancel: {
                    showingPrimeTubesConfirmation = false
                }
            )
        }
    }
}
