import SwiftUI

/// Vista General / Dashboard: Responde en <10 segundos a las 4 preguntas críticas del usuario:
/// 1. ¿Está conectada?
/// 2. ¿Está lista?
/// 3. ¿Hay algún problema?
/// 4. ¿Cuánta tinta queda?
/// Y proporciona los 3 botones de acción primaria: Escanear, Abrir cola, Actualizar.
public struct DashboardView: View {
    @ObservedObject var printer: PrinterManager

    private var statusColor: Color {
        switch printer.connectionState {
        case .ready: return DesignTokens.Colors.statusNormal
        case .printing, .scanning, .busy, .connecting: return DesignTokens.Colors.statusProcessing
        case .warning: return DesignTokens.Colors.statusAttention
        case .error: return DesignTokens.Colors.statusError
        case .disconnected: return DesignTokens.Colors.statusUnavailable
        }
    }

    private var statusTitle: String {
        switch printer.connectionState {
        case .ready: return "Lista para usar"
        case .printing: return "Imprimiendo documento"
        case .scanning: return "Digitalizando en escáner"
        case .busy: return "Procesando tarea..."
        case .connecting: return "Comprobando conexión…"
        case .warning: return "Atención requerida"
        case .error: return "Error en el equipo"
        case .disconnected: return "Desconectada o apagada"
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // MARK: - Tarjeta de Decisión Rápida (<10 segundos)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("HP Smart Tank 500")
                                .font(DesignTokens.Fonts.title)
                                .foregroundColor(.primary)

                            // 1. ¿Está conectada? & 2. ¿Está lista?
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)

                                Text(statusTitle)
                                    .font(DesignTokens.Fonts.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Text("•")
                                    .foregroundColor(.secondary)

                                Text(printer.connectionState.isConnected ? "Conectada por USB" : "Sin conexión")
                                    .font(DesignTokens.Fonts.callout)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        // MARK: - 3 Botones de Acción Inmediata
                        HStack(spacing: 8) {
                            Button(action: { printer.selectedSection = .scanner }) {
                                Label("Escanear", systemImage: "scanner")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)

                            Button(action: { printer.selectedSection = .printing }) {
                                Label("Abrir Cola", systemImage: "doc.text")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Button(action: { printer.refresh() }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .help("Actualizar estado de la impresora")
                            .accessibilityLabel("Actualizar estado")
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }

                    // 3. ¿Hay algún problema? (Alerta mecánica contextual)
                    if case .warning(let msg) = printer.connectionState {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Aviso del equipo: \(msg)")
                                .font(DesignTokens.Fonts.callout)
                                .foregroundColor(.primary)
                        }
                        .padding(DesignTokens.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(DesignTokens.Radii.small)
                    } else if case .error(let msg) = printer.connectionState {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundColor(.red)
                            Text("Problema detectado: \(msg)")
                                .font(DesignTokens.Fonts.callout)
                                .foregroundColor(.primary)
                        }
                        .padding(DesignTokens.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(DesignTokens.Radii.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.surfaceGrouped)
                .cornerRadius(DesignTokens.Radii.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                        .stroke(DesignTokens.Colors.border, lineWidth: 1)
                )

                // MARK: - 4. ¿Cuánta tinta queda? (Niveles CISS y Aviso Visual)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack {
                        Text("Tinta")
                            .font(DesignTokens.Fonts.sectionHeader)
                        Spacer()
                        Text("Nivel estimado")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: DesignTokens.Spacing.sm) {
                        if printer.supplies.isEmpty || !printer.connectionState.isConnected {
                            EmptyStateView(
                                icon: "drop.triangle",
                                title: "Sin Lectura de Tinta",
                                message: "Conecta la impresora por USB y pulsa Actualizar."
                            )
                            .frame(minHeight: 130)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                        } else {
                            HStack(spacing: DesignTokens.Spacing.lg) {
                                Spacer()
                                ForEach(printer.supplies.sorted { (["K", "C", "M", "Y"].firstIndex(of: $0.code) ?? 4) < (["K", "C", "M", "Y"].firstIndex(of: $1.code) ?? 4) }) { item in
                                    InkTankGauge(item: item)
                                }
                                Spacer()
                            }
                            .padding(.vertical, DesignTokens.Spacing.md)

                            // Nota de honestidad física
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "eye.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Comprueba el nivel real en los depósitos transparentes antes de rellenar. La lectura de software es una estimación.")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.bottom, DesignTokens.Spacing.sm)
                        }
                    }
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                Button("Ver actividad de la impresora") { printer.selectedSection = .activity }
                    .buttonStyle(.link)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
