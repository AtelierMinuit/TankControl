import Cocoa
import SwiftUI
import UserNotifications

// MARK: - Entrada Principal de la Aplicación (TankControl / HP Smart Tank macOS Utility)

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    let printer = PrinterManager()
    private var activeAlertKeys = Set<String>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Autorización de Notificaciones
        NotificationManager.shared.requestAuthorization()

        // 2. Argumentos de Línea de Comandos para Inspección y Control Visual
        var targetSection: SidebarSection = .general
        var targetAppearance: String? = nil
        var targetWidth: CGFloat = 860
        var targetHeight: CGFloat = 560
        var capturePath: String? = nil

        let args = CommandLine.arguments
        var i = 1
        while i < args.count {
            if args[i] == "--section" && i + 1 < args.count {
                let sec = args[i + 1].lowercased()
                switch sec {
                case "general", "dashboard": targetSection = .general
                case "printing", "print": targetSection = .printing
                case "scanner", "scan": targetSection = .scanner
                case "ink", "tinta": targetSection = .ink
                case "inksaver", "ahorro": targetSection = .inkSaver
                case "maintenance", "mantenimiento": targetSection = .maintenance
                case "activity", "actividad": targetSection = .activity
                case "developer", "desarrollo":
                    printer.developerMode = true
                    targetSection = .developer
                case "settings", "configuracion": targetSection = .settings
                case "about", "acerca": targetSection = .about
                default: break
                }
                i += 2
            } else if args[i] == "--appearance" && i + 1 < args.count {
                targetAppearance = args[i + 1].lowercased()
                i += 2
            } else if args[i] == "--window-size" && i + 1 < args.count {
                let parts = args[i + 1].split(separator: "x")
                if parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]) {
                    targetWidth = CGFloat(w)
                    targetHeight = CGFloat(h)
                }
                i += 2
            } else if args[i] == "--capture-and-exit" && i + 1 < args.count {
                capturePath = args[i + 1]
                i += 2
            } else {
                i += 1
            }
        }

        printer.selectedSection = targetSection

        // 3. Ventana Principal de la Aplicación
        let rootView = MainSplitView(printer: printer)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.minSize = NSSize(width: 760, height: 520)
        window.contentView = NSHostingView(rootView: rootView)
        window.title = "HP Smart Tank 500"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        if targetAppearance == "dark" {
            window.appearance = NSAppearance(named: .darkAqua)
        } else if targetAppearance == "light" {
            window.appearance = NSAppearance(named: .aqua)
        }

        // CLI sizes describe the complete window, including the native toolbar.
        window.setFrame(NSRect(x: window.frame.origin.x, y: window.frame.origin.y,
                               width: targetWidth, height: targetHeight), display: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 4. Captura programada si se solicita por CLI
        if let outPath = capturePath {
            let delay: Double = 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                try? FileManager.default.removeItem(atPath: outPath)
                let wid = self.window.windowNumber
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                proc.arguments = ["-l\(wid)", "-o", outPath]
                try? proc.run()
                proc.waitUntilExit()

                // Si screencapture por window ID falló, intentar captura de rectángulo de ventana
                if !FileManager.default.fileExists(atPath: outPath) {
                    let frame = self.window.frame
                    let screenH = NSScreen.main?.frame.height ?? 1080
                    let rx = max(0, Int(frame.origin.x))
                    let ry = max(0, Int(screenH - frame.origin.y - frame.height))
                    let rw = Int(frame.width)
                    let rh = Int(frame.height)
                    let rectProc = Process()
                    rectProc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    rectProc.arguments = ["-x", "-R\(rx),\(ry),\(rw),\(rh)", outPath]
                    try? rectProc.run()
                    rectProc.waitUntilExit()
                }

                // Fallback final: renderizado directo via NSView cacheDisplay
                if !FileManager.default.fileExists(atPath: outPath), let contentView = self.window.contentView {
                    let bounds = contentView.bounds
                    if let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) {
                        contentView.cacheDisplay(in: bounds, to: rep)
                        if let data = rep.representation(using: .png, properties: [:]) {
                            try? data.write(to: URL(fileURLWithPath: outPath))
                        }
                    }
                }

                exit(0)
            }
        }

        // 5. Agente Residente Sobrio en Barra de Menú (Menu Bar)
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "printer", accessibilityDescription: "HP Smart Tank")
            button.imagePosition = .imageLeft
            button.title = " Smart Tank"
        }
        updateStatusMenu()

        printer.onUpdate = { [weak self] in
            self?.updateStatusMenu()
        }
    }

    private func updateStatusMenu() {
        let menu = NSMenu()

        // 1. Estado del Dispositivo
        let headerItem = NSMenuItem(
            title: "HP Smart Tank 500: \(printer.connectionState.label)",
            action: nil,
            keyEquivalent: ""
        )
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Niveles de Tinta Condensados
        let suppliesSummary: String
        if !printer.supplies.isEmpty {
            suppliesSummary = printer.supplies.map { "\($0.code): \($0.level)%" }.joined(separator: " • ")
        } else {
            suppliesSummary = "Sin lectura disponible"
        }
        let suppliesItem = NSMenuItem(title: "Tinta: \(suppliesSummary)", action: nil, keyEquivalent: "")
        suppliesItem.isEnabled = false
        menu.addItem(suppliesItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Acciones Cotidianas (Scan, Queue, Open)
        let openItem = NSMenuItem(title: "Abrir Utilidad...", action: #selector(showMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let scanItem = NSMenuItem(title: "Escanear Documento...", action: #selector(menuScan), keyEquivalent: "s")
        scanItem.target = self
        menu.addItem(scanItem)

        let queueItem = NSMenuItem(title: "Ver Cola de Impresión...", action: #selector(menuQueue), keyEquivalent: "p")
        queueItem.target = self
        menu.addItem(queueItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Salir
        let quitItem = NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu

        // Comprobación y envío de notificaciones locales
        checkAndTriggerNotifications()
    }

    private func checkAndTriggerNotifications() {
        var currentAlertKeys = Set<String>()
        func notifyOnce(key: String, title: String, body: String) {
            currentAlertKeys.insert(key)
            if !activeAlertKeys.contains(key) {
                NotificationManager.shared.notifyOnce(key: key, title: title, body: body)
            }
        }

        if case .warning(let msg) = printer.connectionState {
            notifyOnce(key: "state_warning", title: "Aviso de Impresora", body: msg)
        } else if case .error(let msg) = printer.connectionState {
            notifyOnce(key: "state_error", title: "Error en Impresora", body: msg)
        }

        for item in printer.supplies {
            if item.level > 0 && item.level <= 12 {
                notifyOnce(
                    key: "supply_low_\(item.code)",
                    title: "Tinta Baja (\(item.colorName))",
                    body: "El depósito de tinta \(item.colorName) está al \(item.level)%. Verifique el nivel físico."
                )
            }
        }
        activeAlertKeys = currentAlertKeys
    }

    @objc func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func menuScan() {
        printer.selectedSection = .scanner
        showMainWindow()
    }

    @objc func menuQueue() {
        printer.selectedSection = .printing
        showMainWindow()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Mantener activo el monitor en la barra de menú al cerrar la ventana principal
    }
}

// MARK: - Hardened Tool Path & Hardware Command Bridge (Requerido para auditoría y seguridad)

extension PrinterManager {
    func toolBinaryPath() -> String? {
        let bundlePath = Bundle.main.bundlePath
        let possiblePaths = [
            Bundle.main.path(forResource: "hp-smart-tank-tool", ofType: nil),
            bundlePath + "/Contents/Helpers/hp-smart-tank-tool"
        ]
        for p in possiblePaths {
            if let p = p,
               FileManager.default.isExecutableFile(atPath: p),
               let values = try? URL(fileURLWithPath: p).resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
               values.isRegularFile == true,
               values.isSymbolicLink != true {
                return URL(fileURLWithPath: p).standardizedFileURL.path
            }
        }
        return nil
    }

    func runToolCommand(_ args: [String]) -> String {
        guard let bin = toolBinaryPath() else {
            return "[ERROR] No se encontró un helper regular y ejecutable dentro del bundle."
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: bin)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "[ERROR] No se pudo ejecutar la herramienta: \(error.localizedDescription)"
        }
    }

    func executeAction(name: String, command: String, completionDesc: String) {
        let output = runToolCommand([command, "--confirm-hardware"])
        _ = output
    }

    func legacyInjectRaw(testFile: String) -> String {
        return runToolCommand(["inject-raw", testFile, "--confirm-hardware"])
    }

    func legacyTestPattern(type: String) -> String {
        return runToolCommand(["test-pattern", type, "--confirm-hardware"])
    }

    func legacyPrimeTubes() -> String {
        return runToolCommand(["prime-tubes", "--confirm-hardware"])
    }
}

// Iniciar ciclo de vida de la aplicación
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
