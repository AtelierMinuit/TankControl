import SwiftUI

public struct PrintCenterView: View {
    @ObservedObject var printer: PrinterManager
    @StateObject private var service = PrinterService()
    @StateObject private var inkSaverService = InkSaverService()
    @State private var message = ""
    @State private var showingResult = false

    private var isHardwareReady: Bool {
        printer.connectionState.isConnected && !printer.isBusy
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // MARK: - Cabecera
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Impresión")
                            .font(DesignTokens.Fonts.title)
                        Text("Gestión de cola y preferencias del servidor de impresión CUPS de macOS.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Divider()

                // MARK: - Tarjeta de Cola CUPS Activa
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Cola del Sistema macOS")
                        .font(DesignTokens.Fonts.sectionHeader)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "printer.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.accentColor)
                                .frame(width: 48, height: 48)
                                .background(Color.accentColor.opacity(0.12))
                                .cornerRadius(DesignTokens.Radii.small)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text("HP_Smart_Tank_500")
                                        .font(DesignTokens.Fonts.headline)
                                    Text("Cola Predeterminada")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1)
                                        .background(Color.green.opacity(0.12))
                                        .cornerRadius(3)
                                }

                                Text("URI: usb://HP/Smart%20Tank%20500%20series")
                                    .font(DesignTokens.Fonts.mono)
                                    .foregroundColor(.secondary)

                                Text(printer.connectionState.isConnected ? "Conectada por USB • Lista para recibir trabajos" : "En espera de conexión física USB")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(printer.connectionState.isConnected ? .green : .secondary)
                            }

                            Spacer()
                        }

                        Divider()

                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Button(action: openCupsQueue) {
                                Label("Abrir Cola de Impresión…", systemImage: "doc.text.magnifyingglass")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)

                            Button(action: triggerTestPage) {
                                Label("Imprimir Página de Prueba", systemImage: "paperplane")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(!isHardwareReady)
                            .help(isHardwareReady ? "Envía la página de prueba oficial CUPS" : "Requiere impresora física conectada por USB")

                            Button(action: { printer.selectedSection = .inkSaver }) {
                                Label("Ahorro InkSaver…", systemImage: "leaf.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .help("Ajustar ahorro raster y presets de tinta GT51/GT52/GT53")
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // MARK: - Modo Rápido Borrador (Fast Draft)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack {
                        Label("Modo Rápido Borrador", systemImage: "bolt.fill")
                            .font(DesignTokens.Fonts.sectionHeader)
                            .foregroundColor(inkSaverService.isFastDraftActive ? .orange : .primary)

                        Spacer()

                        if inkSaverService.isApplying {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(inkSaverService.isFastDraftActive ? "● BORRADOR ACTIVO" : "○ MODO NORMAL")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(inkSaverService.isFastDraftActive ? .orange : .secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(inkSaverService.isFastDraftActive ? Color.orange.opacity(0.14) : Color.secondary.opacity(0.10))
                                .cornerRadius(DesignTokens.Radii.small)
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack(spacing: 12) {
                            Image(systemName: inkSaverService.isFastDraftActive ? "hare.fill" : "doc.text.fill")
                                .font(.system(size: 22))
                                .foregroundColor(inkSaverService.isFastDraftActive ? .orange : .secondary)
                                .frame(width: 40, height: 40)
                                .background((inkSaverService.isFastDraftActive ? Color.orange : Color.secondary).opacity(0.12))
                                .cornerRadius(DesignTokens.Radii.small)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(inkSaverService.isFastDraftActive ? "Impresión de Alta Velocidad (300 DPI • Eco70)" : "Impresión de Calidad Estándar (600 DPI)")
                                    .font(DesignTokens.Fonts.headline)

                                Text(inkSaverService.isFastDraftActive
                                     ? "El cabezal PCL opera en barrido rápido (Draft) con 70% de ahorro de tinta. Ideal para apuntes, textos y borradores inmediatos."
                                     : "Resolución normal a 600 DPI para presentaciones y documentos formales. Activa el modo borrador para máxima velocidad.")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Divider()

                        HStack(spacing: 10) {
                            Button(action: {
                                inkSaverService.setFastDraftMode(enabled: !inkSaverService.isFastDraftActive)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: inkSaverService.isFastDraftActive ? "arrow.uturn.backward" : "bolt.fill")
                                    Text(inkSaverService.isFastDraftActive ? "Volver a Calidad Normal" : "Activar Modo Rápido Borrador")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(inkSaverService.isFastDraftActive ? .gray : .orange)
                            .controlSize(.regular)
                            .disabled(inkSaverService.isApplying)

                            if !inkSaverService.cupsStatusMessage.isEmpty {
                                Text(inkSaverService.cupsStatusMessage)
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(inkSaverService.isFastDraftActive ? Color.orange.opacity(0.35) : DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // MARK: - Opciones de Controlador y Perfiles
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Configuración de Calidad y Medios")
                        .font(DesignTokens.Fonts.sectionHeader)

                    DisclosureGroup("Ajustes de calidad e InkSaver (PPD nativo)") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Los parámetros de impresión (resolución 300/600/1200 DPI, papel común o fotográfico, calibración de color y reducción de consumo InkSaver) se aplican automáticamente mediante el diálogo de impresión estándar de cada aplicación en macOS.")
                                .font(DesignTokens.Fonts.callout)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 12) {
                                Label("PPD: hp-smart_tank_500_series_mac.ppd", systemImage: "doc.badge.gearshape")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                                Label("Filtro: rastertopcl3gui", systemImage: "gearshape.2")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)

                            Divider()
                                .padding(.vertical, 4)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tecnología InkSaver")
                                        .font(DesignTokens.Fonts.captionBold)
                                    Text("Control de atenuación raster continuo, simulador comparativo y predeterminado CUPS.")
                                        .font(DesignTokens.Fonts.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button(action: {
                                    printer.selectedSection = .inkSaver
                                }) {
                                    Label("Abrir InkSaver Center", systemImage: "leaf.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .alert("Envío a la cola de impresión", isPresented: $showingResult) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(message)
        }
        .onAppear {
            inkSaverService.queryCupsSetting()
        }
    }

    private func openCupsQueue() {
        if let settingsUrl = URL(string: "x-apple.systempreferences:com.apple.Print-Scan-Settings.extension"),
           NSWorkspace.shared.open(settingsUrl) {
            return
        }
        let url = URL(fileURLWithPath: "/System/Library/PreferencePanes/PrintAndScan.prefPane")
        NSWorkspace.shared.open(url)
    }

    private func triggerTestPage() {
        service.sendTestPageAsync { result in
            switch result {
            case .success(let value):
                message = value
            case .failure(let error):
                message = error.localizedDescription
            }
            showingResult = true
        }
    }
}
