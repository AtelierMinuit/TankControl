import Foundation
import Network

/// Servicio que anuncia la impresora HP Smart Tank 500 en la red local como objetivo AirPrint para iOS y macOS.
/// Utiliza mDNS/Bonjour nativo mediante Foundation.NetService y configuración de cola CUPS compartida.
public final class AirPrintBridgeService: NSObject, ObservableObject, NetServiceDelegate {
    public static let shared = AirPrintBridgeService()

    @Published public private(set) var isAdvertising: Bool = false
    @Published public private(set) var isCUPSShared: Bool = false
    @Published public private(set) var statusMessage: String = "Inactivo"

    private var netService: NetService?
    private let printerQueueName = "HP_Smart_Tank_500"
    private let defaultPort: Int32 = 631

    private override init() {
        super.init()
        checkCUPSSharingStatus()
    }

    /// Comprueba si la cola CUPS está configurada como compartida
    public func checkCUPSSharingStatus() {
        ProcessRunner.runAsync("/usr/bin/lpoptions", arguments: ["-p", printerQueueName, "-l"]) { [weak self] output, _ in
            let isShared = output.contains("printer-is-shared=true") || output.contains("printer-is-shared/true")
            DispatchQueue.main.async {
                self?.isCUPSShared = isShared
            }
        }
    }

    /// Inicia el anuncio AirPrint (Bonjour/mDNS) y habilita la compartición en CUPS
    public func startAdvertising() {
        guard !isAdvertising else { return }

        // 1. Configurar CUPS para permitir compartición de impresoras
        ProcessRunner.runAsync("/usr/sbin/cupsctl", arguments: ["--share-printers"]) { _, _ in }
        ProcessRunner.runAsync("/usr/sbin/lpadmin", arguments: ["-p", self.printerQueueName, "-o", "printer-is-shared=true"]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.isCUPSShared = true
            }
        }

        // 2. Anunciar servicio IPP / AirPrint con registros TXT requeridos por iOS
        let service = NetService(domain: "local.", type: "_ipp._tcp.", name: "HP Smart Tank 500", port: defaultPort)
        service.delegate = self

        var txtDict: [String: Data] = [:]
        txtDict["txtvers"] = "1".data(using: .utf8)
        txtDict["qtotal"] = "1".data(using: .utf8)
        txtDict["rp"] = "printers/\(printerQueueName)".data(using: .utf8)
        txtDict["ty"] = "HP Smart Tank 500".data(using: .utf8)
        txtDict["note"] = "Atelier Minuit AirPrint Bridge".data(using: .utf8)
        txtDict["pdl"] = "application/pdf,image/urf,application/postscript".data(using: .utf8)
        txtDict["URF"] = "W8,SRGB24,CP1,RS600".data(using: .utf8)
        txtDict["product"] = "(HP Smart Tank 500)".data(using: .utf8)
        txtDict["adminurl"] = "http://localhost:631/printers/\(printerQueueName)".data(using: .utf8)
        txtDict["priority"] = "10".data(using: .utf8)
        txtDict["Color"] = "T".data(using: .utf8)
        txtDict["Duplex"] = "F".data(using: .utf8)
        txtDict["UUID"] = "e2d7c588-b2a1-432a-9bc5-c89b1c7f5000".data(using: .utf8)

        service.setTXTRecord(NetService.data(fromTXTRecord: txtDict))
        service.publish(options: .listenForConnections)

        self.netService = service
        self.isAdvertising = true
        self.statusMessage = "Activo en red local (AirPrint)"
    }

    /// Detiene el anuncio AirPrint
    public func stopAdvertising() {
        netService?.stop()
        netService = nil
        isAdvertising = false
        statusMessage = "Inactivo"

        ProcessRunner.runAsync("/usr/sbin/lpadmin", arguments: ["-p", printerQueueName, "-o", "printer-is-shared=false"]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.isCUPSShared = false
            }
        }
    }

    // MARK: - NetServiceDelegate
    public func netServiceDidPublish(_ sender: NetService) {
        DispatchQueue.main.async {
            self.isAdvertising = true
            self.statusMessage = "Transmitiendo AirPrint para iOS y macOS"
        }
    }

    public func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        DispatchQueue.main.async {
            self.isAdvertising = false
            self.statusMessage = "Error al publicar servicio Bonjour"
        }
    }

    public func netServiceDidStop(_ sender: NetService) {
        DispatchQueue.main.async {
            self.isAdvertising = false
            self.statusMessage = "Inactivo"
        }
    }
}
