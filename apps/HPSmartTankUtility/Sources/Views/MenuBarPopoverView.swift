import SwiftUI

/// Popover interactivo que se despliega al hacer clic en el icono de la barra de menús de macOS.
/// Proporciona telemetría de tinta CISS en tiempo real, control rápido de InkSaver y accesos directos.
public struct MenuBarPopoverView: View {
    @ObservedObject var printer: PrinterManager
    @ObservedObject private var airPrint = AirPrintBridgeService.shared
    @ObservedObject private var inkSaver = InkSaverService.shared
    @ObservedObject private var loc = LocalizationService.shared

    let onOpenMainWindow: () -> Void
    let onScan: () -> Void
    let onOpenQueue: () -> Void
    let onCleanHeads: () -> Void
    let onQuit: () -> Void

    public init(
        printer: PrinterManager,
        onOpenMainWindow: @escaping () -> Void,
        onScan: @escaping () -> Void,
        onOpenQueue: @escaping () -> Void,
        onCleanHeads: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.printer = printer
        self.onOpenMainWindow = onOpenMainWindow
        self.onScan = onScan
        self.onOpenQueue = onOpenQueue
        self.onCleanHeads = onCleanHeads
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: 1. Cabecera y Estado USB
            HStack(spacing: 8) {
                Image(systemName: "printer.fill")
                    .foregroundColor(DesignTokens.Colors.brandTeal)
                    .font(.system(size: 15, weight: .bold))

                VStack(alignment: .leading, spacing: 1) {
                    Text("TankControl")
                        .font(.system(size: 13, weight: .bold))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(printer.connectionState.statusColor)
                            .frame(width: 6, height: 6)
                        Text(printer.connectionState.label)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: onOpenMainWindow) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Abrir Utilidad Completa")
            }
            .padding(.bottom, 2)

            Divider()

            // MARK: 2. Niveles Físicos de Tinta CISS (K, C, M, Y)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(loc.t("section_ink"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("HP GT51 / GT52 / GT53")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                }

                HStack(spacing: 8) {
                    miniInkTank(code: "K", name: "Negro", color: Color(red: 0.15, green: 0.15, blue: 0.18), level: supplyLevel("K"))
                    miniInkTank(code: "C", name: "Cian", color: Color(red: 0.0, green: 0.65, blue: 0.90), level: supplyLevel("C"))
                    miniInkTank(code: "M", name: "Magenta", color: Color(red: 0.90, green: 0.10, blue: 0.55), level: supplyLevel("M"))
                    miniInkTank(code: "Y", name: "Amarillo", color: Color(red: 0.95, green: 0.75, blue: 0.05), level: supplyLevel("Y"))
                }
            }

            Divider()

            // MARK: 3. Ajuste Rápido InkSaver
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                    Text("InkSaver™ Rápido")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(inkSaver.savingsPercent)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                }

                HStack(spacing: 4) {
                    saverPresetButton(title: "0%", percent: 0)
                    saverPresetButton(title: "25%", percent: 25)
                    saverPresetButton(title: "35% ★", percent: 35)
                    saverPresetButton(title: "50%", percent: 50)
                    saverPresetButton(title: "75%", percent: 75)
                }
            }

            Divider()

            // MARK: 4. Puente AirPrint Local
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(airPrint.isAdvertising ? .blue : .secondary)
                    .font(.system(size: 11))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Puente AirPrint")
                        .font(.system(size: 11, weight: .semibold))
                    Text(airPrint.isAdvertising ? "Activo para iPhone/iPad" : "Compartición inactiva")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                    if airPrint.isAdvertising {
                        airPrint.stopAdvertising()
                    } else {
                        airPrint.startAdvertising()
                    }
                }) {
                    Text(airPrint.isAdvertising ? "Pausar" : "Activar")
                        .font(.system(size: 10, weight: .medium))
                }
                .controlSize(.mini)
            }

            Divider()

            // MARK: 5. Acciones Rápidas y Salida
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    Button(action: onScan) {
                        Label(loc.t("btn_scan"), systemImage: "doc.viewfinder")
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)

                    Button(action: onOpenQueue) {
                        Label(loc.t("btn_open_queue"), systemImage: "printer")
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)
                }

                HStack(spacing: 6) {
                    Button(action: onCleanHeads) {
                        Label("Limpiar", systemImage: "sparkles")
                            .font(.system(size: 11))
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)

                    Button(action: onQuit) {
                        Label("Salir", systemImage: "power")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(width: 290)
    }

    // MARK: - Helpers visuales
    private func supplyLevel(_ code: String) -> Int {
        if let s = printer.supplies.first(where: { $0.code.uppercased() == code }) {
            return s.level
        }
        return 75
    }

    private func miniInkTank(code: String, name: String, color: Color, level: Int) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 44, height: 48)

                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 44, height: max(4, CGFloat(level) * 0.48))

                Text("\(level)%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 1.5, x: 0, y: 1)
                    .padding(.bottom, 2)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            Text(code)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func saverPresetButton(title: String, percent: Int) -> some View {
        let isSelected = inkSaver.savingsPercent == percent
        return Button(action: {
            inkSaver.applyPresetToCUPS(percent: percent)
        }) {
            Text(title)
                .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.green.opacity(0.25) : Color.secondary.opacity(0.12))
                .foregroundColor(isSelected ? .green : .primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
