import Foundation

/// Implementación Mock completa de la Smart Tank 500 para pruebas y desarrollo 100% offline.
public final class MockSmartTankService: SmartTankServiceProtocol {
    public var isMockMode: Bool { true }

    public init() {}

    public func fetchStatus() -> (state: PrinterConnectionState, description: String) {
        return (.ready, "HP Smart Tank 500 series (Modo Simulación Offline)")
    }

    public func fetchSupplies() -> [SupplyItem] {
        return [
            SupplyItem(code: "K", name: "Negro", level: 82, state: "inSensorRange", isDemo: true),
            SupplyItem(code: "C", name: "Cian", level: 68, state: "inSensorRange", isDemo: true),
            SupplyItem(code: "M", name: "Magenta", level: 64, state: "inSensorRange", isDemo: true),
            SupplyItem(code: "Y", name: "Amarillo", level: 88, state: "inSensorRange", isDemo: true)
        ]
    }

    public func fetchOdometer() -> OdometerResponse? {
        return OdometerResponse(
            connected: true,
            mock: true,
            total_pages: 1420,
            mono_pages: 890,
            color_pages: 530,
            borderless_pages: 85,
            scans: 142,
            jams: 1,
            pick_failures: 2,
            drops: OdometerDrops(k: 4820100, c: 2110500, m: 1945300, y: 2310200)
        )
    }

    public func fetchDiagnostics() -> [DiagnosticItem] {
        return [
            DiagnosticItem(
                id: "diag-macos",
                subsystem: "macOS",
                name: "Arquitectura del Sistema",
                status: .pass,
                message: "Apple Silicon ARM64 (macOS 12+ compatible)",
                technicalDetails: "Darwin Kernel ARM64 nativo. Instrucciones NEON y hardware acceleration disponibles."
            ),
            DiagnosticItem(
                id: "diag-cups",
                subsystem: "CUPS",
                name: "Servidor de Impresión",
                status: .pass,
                message: "cupsd en ejecución (Socket local activo)",
                technicalDetails: "CUPS 2.3.4 conectado en /var/run/cupsd."
            ),
            DiagnosticItem(
                id: "diag-filter",
                subsystem: "Driver",
                name: "Filtro rastertopcl3gui",
                status: .pass,
                message: "Binario auditado y funcional",
                technicalDetails: "Soporte PCL3GUI Mode 10, InkSaver adaptativo, dot gain calibration."
            ),
            DiagnosticItem(
                id: "diag-ppd",
                subsystem: "PPD",
                name: "Archivo PPD Validado",
                status: .pass,
                message: "Conforme con especificación cupstestppd",
                technicalDetails: "hp-smart_tank_500_series_mac.ppd sin errores críticos."
            ),
            DiagnosticItem(
                id: "diag-usb",
                subsystem: "USB",
                name: "Conexión USB Hardware",
                status: .warning,
                message: "Hardware desconectado (Simulación Mock activa)",
                technicalDetails: "VID 0x03F0 PID 0x2B54 emulado por Virtual Smart Tank Engine.",
                remediationSuggestion: "Conecte el cable USB físicamente a su Mac para operar en vivo."
            ),
            DiagnosticItem(
                id: "diag-scan",
                subsystem: "Escáner",
                name: "Driver hp_scan y AirScan",
                status: .pass,
                message: "Compatibilidad eSCL / Image Capture disponible",
                technicalDetails: "Bridge HTTP/eSCL en puerto localhost:8080 listo para escanear."
            ),
            DiagnosticItem(
                id: "diag-color",
                subsystem: "ColorSync",
                name: "Perfiles de Color ICC",
                status: .pass,
                message: "Perfiles instalados para Papel Común, Satinado y Mate",
                technicalDetails: "ICC RGB sRGB D65 calibrados para HP GT51/GT52."
            )
        ]
    }

    public func cleanHeads() -> Result<String, Error> {
        return .success("[MOCK] Ciclo de limpieza básica Nivel 1 simulado exitosamente. Se purgaron 1.2 ml estimados.")
    }

    public func cleanRollers() -> Result<String, Error> {
        return .success("[MOCK] Ciclo de limpieza de rodillos de tracción simulado con éxito.")
    }

    public func nozzleTest() -> Result<String, Error> {
        return .success("[MOCK] Patrón de inyectores enviado a la cola virtual. Resultado: 100% inyectores operativos.")
    }

    public func alignHeads() -> Result<String, Error> {
        return .success("[MOCK] Calibración y alineación de cabezal completada virtualmente (Desfase K-CMY: 0.0mm).")
    }

    public func printTestPattern(type: String) -> Result<String, Error> {
        return .success("[MOCK] Patrón de prueba tipo '\(type)' renderizado y procesado en modo simulación.")
    }

    public func getAccounting() -> Result<String, Error> {
        let text = """
        === AUDITORÍA DE COSTES Y CONSUMO (MOCK) ===
        Páginas Totales: 1,420
        Páginas Monocromo: 890 (62.7%)
        Páginas Color: 530 (37.3%)
        Gotas Totales K: 4,820,100 (~57.8 ml de tinta negra consumida)
        Gotas Totales CMY: 6,366,000 (~76.4 ml de tinta de color consumida)
        Ahorro con InkSaver Activo: ~32.4 ml de tinta preservada (aprox. $14.20 USD)
        Coste medio por página: $0.008 USD
        """
        return .success(text)
    }

    public func getWasteInk() -> Result<String, Error> {
        let text = """
        === ESTADO DE ALMOHADILLAS DE DESECHO (WASTE INK) ===
        Capacidad de almohadilla absorbente: 18.4% utilizada.
        Estado: ÓPTIMO (Vida útil remanente estimada: 18,200 páginas).
        No se requiere reemplazo ni servicio técnico en este momento.
        """
        return .success(text)
    }

    public func getHeadHealth() -> Result<String, Error> {
        let text = """
        === DIAGNÓSTICO DE SALUD DE CABEZALES (PRINTHEAD HEALTH) ===
        Cabezal Negro (K):
          - Temperatura actual: 34°C (Normal < 65°C)
          - Resistencia térmica de resistencias: 28.4 Ohm (Nominal: 28.0 Ohm)
          - Estado de contactos flex: EXCELENTE (0 fallos de continuidad)
        Cabezal Tri-Color (CMY):
          - Temperatura actual: 36°C (Normal < 65°C)
          - Resistencias térmicas: C: 27.9 Ohm, M: 28.2 Ohm, Y: 28.1 Ohm
          - Estado de contactos flex: EXCELENTE (0 fallos de continuidad)
        """
        return .success(text)
    }

    public func deepClean() -> Result<String, Error> {
        return .success("[MOCK] Purga profunda Nivel 2 ejecutada en entorno simulado. 5.8 ml consumidos.")
    }

    public func primeTubes() -> Result<String, Error> {
        return .success("[MOCK] Cebado forzado de mangueras CISS simulado correctamente. Burbujas de aire evacuadas.")
    }

    public func dumpFirmwareTree() -> Result<String, Error> {
        let xml = """
        <DevInfo xmlns="http://www.hp.com/schemas/imaging/con/ledm/devinfo/2009/03/12">
            <Model>HP Smart Tank 500 series</Model>
            <ProductNumber>4SR29A</ProductNumber>
            <SerialNumber>TH01234567</SerialNumber>
            <FirmwareVersion>SPP1FN2021AR</FirmwareVersion>
            <ASIC>P15_CISS</ASIC>
            <EngineType>Thermal Inkjet 2-Head</EngineType>
            <Interfaces>
                <Interface num="0" class="ff" sub="cc" proto="00">Vendor Printing</Interface>
                <Interface num="1" class="07" sub="01" proto="02">1284.4 Bidirectional Printer</Interface>
                <Interface num="2" class="ff" sub="04" proto="01">Vendor Scanner</Interface>
            </Interfaces>
        </DevInfo>
        """
        return .success(xml)
    }

    public func injectRawDemo() -> Result<String, Error> {
        return .success("[MOCK] Inyección de paquete PJL de prueba transferida con éxito al Endpoint 0x02 virtual.")
    }
}
