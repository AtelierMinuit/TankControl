import SwiftUI

public struct ScannerView: View {
    @ObservedObject var printer: PrinterManager
    @StateObject private var service = ScannerService()
    @State private var preview: NSImage?
    @State private var errorMessage: String?
    @State private var successNotice: String?

    private var isHardwareReady: Bool {
        printer.connectionState.isConnected && !printer.isBusy && !service.isScanning
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // MARK: - Cabecera
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Escáner")
                            .font(DesignTokens.Fonts.title)
                        Text("Digitalización óptica en platina plana (Sensor CIS hasta 1200 DPI).")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Divider()

                // Estado de hardware del escáner
                if !printer.connectionState.isConnected {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "scanner")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        Text("El escáner está desconectado. Conecta la HP Smart Tank 500 por USB o abre Captura de Imagen.")
                            .font(DesignTokens.Fonts.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(DesignTokens.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                }

                // MARK: - Layout en dos columnas
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    // Columna 1: Panel de Ajustes Compacto
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Ajustes de Digitalización")
                            .font(DesignTokens.Fonts.sectionHeader)

                        VStack(alignment: .leading, spacing: 8) {
                            // Modo de Color
                            HStack {
                                Text("Modo:")
                                    .font(DesignTokens.Fonts.captionBold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Picker("", selection: $service.selectedColorMode) {
                                    ForEach(ScanColorMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            // Resolución
                            HStack {
                                Text("Resolución:")
                                    .font(DesignTokens.Fonts.captionBold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Picker("", selection: $service.selectedResolution) {
                                    ForEach(ScanResolution.allCases) { res in
                                        Text(res.label).tag(res)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            // Área / Tamaño
                            HStack {
                                Text("Tamaño:")
                                    .font(DesignTokens.Fonts.captionBold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Picker("", selection: $service.selectedPaperSize) {
                                    ForEach(ScanPaperSize.allCases) { size in
                                        Text(size.rawValue).tag(size)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            // Formato
                            HStack {
                                Text("Formato:")
                                    .font(DesignTokens.Fonts.captionBold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                Picker("", selection: $service.selectedFormat) {
                                    ForEach(ScanFormat.allCases) { fmt in
                                        Text(fmt.rawValue).tag(fmt)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }

                            // Destino
                            HStack {
                                Text("Destino:")
                                    .font(DesignTokens.Fonts.captionBold)
                                    .foregroundColor(.secondary)
                                    .frame(width: 80, alignment: .leading)
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(service.destinationFolder)
                                        .font(DesignTokens.Fonts.callout)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                        .padding(DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.surfaceGrouped)
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )

                        // Botones de Acción Inmediatos
                        VStack(spacing: 6) {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Button(action: triggerPreview) {
                                    Label("Previsualizar", systemImage: "eye")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .disabled(!isHardwareReady)

                                Button(action: triggerScan) {
                                    Label("Escanear", systemImage: "scanner")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                                .disabled(!isHardwareReady)
                            }

                            Button("Abrir en Captura de Imagen de macOS…") {
                                service.openImageCapture()
                            }
                            .buttonStyle(.link)
                            .font(DesignTokens.Fonts.caption)
                        }
                        .padding(.top, 4)

                        if let err = errorMessage {
                            Text(err)
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.red)
                        }

                        if let notice = successNotice {
                            Text(notice)
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .frame(width: 250)

                    // Columna 2: Canvas de Vista Previa
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack {
                            Text("Vista Previa del Documento")
                                .font(DesignTokens.Fonts.sectionHeader)
                            Spacer()
                            if let _ = preview {
                                Button("Limpiar") { preview = nil; successNotice = nil }
                                    .buttonStyle(.plain)
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        ZStack {
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                        .stroke(DesignTokens.Colors.border, lineWidth: 1)
                                )

                            if service.isScanning {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text(service.scanStatusMessage)
                                        .font(DesignTokens.Fonts.bodyMedium)
                                        .foregroundColor(.primary)
                                }
                            } else if let preview = preview {
                                VStack(spacing: 8) {
                                    Image(nsImage: preview)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .padding(10)
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                                    if let url = service.lastScanResultURL {
                                        Button("Mostrar en Finder") {
                                            NSWorkspace.shared.activateFileViewerSelecting([url])
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .padding(.bottom, 6)
                                    }
                                }
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.viewfinder")
                                        .font(.system(size: 36))
                                        .foregroundColor(.secondary.opacity(0.6))
                                    Text("Área de Vista Previa")
                                        .font(DesignTokens.Fonts.headline)
                                        .foregroundColor(.secondary)
                                    Text("Pulsa Previsualizar para comprobar el encuadre antes de escanear.")
                                        .font(DesignTokens.Fonts.caption)
                                        .foregroundColor(.secondary.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .frame(minHeight: 220, maxHeight: 260)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func triggerPreview() {
        errorMessage = nil
        successNotice = nil
        service.performScan(isPreview: true) { result in
            switch result {
            case .success(let url):
                preview = NSImage(contentsOf: url)
                successNotice = "Vista previa generada correctamente."
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
        }
    }

    private func triggerScan() {
        errorMessage = nil
        successNotice = nil
        service.performScan(isPreview: false) { result in
            switch result {
            case .success(let url):
                preview = NSImage(contentsOf: url)
                successNotice = "Documento escaneado y guardado en \(url.lastPathComponent)."
            case .failure(let err):
                errorMessage = err.localizedDescription
            }
        }
    }
}
