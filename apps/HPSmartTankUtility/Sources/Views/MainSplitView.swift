import SwiftUI

/// Vista principal de navegación con barra lateral nativa macOS (Sidebar) y panel de detalle.
/// Cumple con las 6 secciones canónicas: General, Impresión, Escáner, Tinta, Mantenimiento, Actividad.
/// Configuración está accesible vía barra de herramientas y comando estándar ⌘,.
public struct MainSplitView: View {
    @ObservedObject var printer: PrinterManager
    @State private var showingSettingsSheet: Bool = false

    public init(printer: PrinterManager) {
        self.printer = printer
    }

    // NavigationView can write its selection during a SwiftUI update on macOS.
    // Publish the shared model change on the next main-loop turn.
    private var navigationSelection: Binding<SidebarSection?> {
        Binding(get: { printer.selectedSection }, set: { section in
            DispatchQueue.main.async {
                if printer.selectedSection != section { printer.selectedSection = section }
            }
        })
    }

    public var body: some View {
        NavigationView {
            // MARK: - Barra Lateral (Sidebar Canónica de 6 Secciones)
            List {
                Section(header: Text("Impresora").font(.caption.weight(.bold))) {
                    NavigationLink(
                        destination: DashboardView(printer: printer),
                        tag: SidebarSection.general,
                        selection: navigationSelection
                    ) {
                        Label(SidebarSection.general.rawValue, systemImage: SidebarSection.general.icon)
                    }

                    NavigationLink(
                        destination: PrintCenterView(printer: printer),
                        tag: SidebarSection.printing,
                        selection: navigationSelection
                    ) {
                        Label(SidebarSection.printing.rawValue, systemImage: SidebarSection.printing.icon)
                    }

                    NavigationLink(
                        destination: ScannerView(printer: printer),
                        tag: SidebarSection.scanner,
                        selection: navigationSelection
                    ) {
                        Label(SidebarSection.scanner.rawValue, systemImage: SidebarSection.scanner.icon)
                    }

                    NavigationLink(
                        destination: StatusView(printer: printer),
                        tag: SidebarSection.ink,
                        selection: navigationSelection
                    ) {
                        Label(SidebarSection.ink.rawValue, systemImage: SidebarSection.ink.icon)
                    }
                }

                Section(header: Text("Mantenimiento y Uso").font(.caption.weight(.bold))) {
                    NavigationLink(
                        destination: MaintenanceView(printer: printer),
                        tag: SidebarSection.maintenance,
                        selection: navigationSelection
                    ) {
                        Label(SidebarSection.maintenance.rawValue, systemImage: SidebarSection.maintenance.icon)
                    }

                    NavigationLink(
                        destination: ActivityView(printer: printer),
                        tag: SidebarSection.activity,
                        selection: navigationSelection
                    ) {
                        Label(SidebarSection.activity.rawValue, systemImage: SidebarSection.activity.icon)
                    }
                }

                // MARK: - Modo Desarrollador (Condicional / Oculto por defecto)
                if printer.developerMode {
                    Section(header: Text("Avanzado").font(.caption.weight(.bold))) {
                        NavigationLink(
                            destination: DeveloperModeView(printer: printer),
                            tag: SidebarSection.developer,
                            selection: navigationSelection
                        ) {
                            Label(SidebarSection.developer.rawValue, systemImage: SidebarSection.developer.icon)
                        }
                    }
                }

                // Vistas complementarias para enrutamiento
                if printer.selectedSection == .about {
                    NavigationLink(
                        destination: AboutView(),
                        tag: SidebarSection.about,
                        selection: navigationSelection
                    ) {
                        Label(SidebarSection.about.rawValue, systemImage: SidebarSection.about.icon)
                    }
                }

                // Pie de barra lateral con versión técnica
                Section {
                    HStack {
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Desarrollo")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 190, idealWidth: 210, maxWidth: 250)

            // Vista por defecto al inicio (General)
            DashboardView(printer: printer)
        }
        .frame(minWidth: 760, minHeight: 436)
        .toolbar {
            ToolbarItem(placement: .status) {
                HStack(spacing: 6) {
                    StatusBadge(state: printer.connectionState)

                    if printer.connectionState.isConnected {
                        Text("LIVE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(3)
                            .fixedSize()
                    }
                }
                .fixedSize()
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { printer.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Actualizar estado de hardware")
                .accessibilityLabel("Actualizar estado")
                .keyboardShortcut("r", modifiers: .command)
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { showingSettingsSheet = true }) {
                    Image(systemName: "gearshape")
                }
                .help("Configuración (⌘,)")
                .accessibilityLabel("Configuración")
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .onAppear {
            if printer.selectedSection == .settings {
                showingSettingsSheet = true
                printer.selectedSection = .general
            }
        }
        .onChange(of: printer.selectedSection) { section in
            if section == .about { showingSettingsSheet = false }
            if section == .settings {
                showingSettingsSheet = true
                printer.selectedSection = .general
            }
        }
        .sheet(isPresented: $showingSettingsSheet) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Cerrar") {
                        showingSettingsSheet = false
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.small)
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
                SettingsView(printer: printer)
            }
            .frame(width: 520, height: 410)
        }
    }
}
