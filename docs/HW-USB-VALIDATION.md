# INFORME DE VALIDACIÓN DE HARDWARE — AGENTE 1
## Identidad de Dispositivo y Topología USB (Read-Only)

**Dispositivo Físico:** HP Smart Tank 500 series (`VID 0x03F0`, `PID 0x2B54`, Serial `CN1924S1W7`)  
**Bus / Dirección USB:** Bus 1, Address 5 (USB 2.0 High-Speed, 480 Mbps)  
**ID de Sesión:** `research/hardware-validation/20260905-multiagent-master/`  
**Archivo de Evidencia:** `research/hardware-validation/20260905-multiagent-master/usb/descriptors.txt`  
**Estado:** **PASS — 100% HARDWARE VERIFIED**  

---

### 1. Descriptores Estándar del Dispositivo

* **Vendor ID (VID):** `0x03F0` (Hewlett Packard)
* **Product ID (PID):** `0x2B54` (Smart Tank 500 series / ASIC P15_CISS)
* **Versión USB (`bcdUSB`):** `0x0200` (USB 2.0 High-Speed, 480 Mbps)
* **Versión Dispositivo (`bcdDevice`):** `0x0409`
* **Clase / Subclase / Protocolo de Dispositivo:** `0x00 / 0x00 / 0x00` (Definido por interfaces)
* **Tamaño Máximo Paquete EP0 (`bMaxPacketSize0`):** `64` bytes
* **Número de Configuraciones:** `1`
* **Índices de Cadenas:**
  - `iManufacturer = 1` -> `"HP"`
  - `iProduct = 2` -> `"Smart Tank 500 series"`
  - `iSerialNumber = 3` -> `"CN1924S1W7"`

---

### 2. Topología de Interfaces y Endpoints (Confrontación Canónica)

Se comprobó la estructura completa de descriptores frente a `docs/USB-INTERFACE-MAP.md`:

| Interfaz | Alt | Clase / Subclase / Protocolo | Endpoints Físicos | Función en Hardware Real | Concordancia con Especificación |
|:---:|:---:|:---:|:---|:---|:---:|
| **0** | 0 | `0xFF / 0xCC / 0x00` | Bulk IN `0x81` (512B)<br>Bulk OUT `0x02` (512B)<br>Interrupt IN `0x83` (64B, 7ms) | Canal LEDM de Escaneo CIS (`hp_scan`, AirScan eSCL) | **100% MATCH** |
| **1** | 0 | `0x07 / 0x01 / 0x02` | Bulk IN `0x84` (512B)<br>Bulk OUT `0x05` (512B) | Canal de Inyección PCL3GUI / Impresión (`cups_backend_smarttank`) | **100% MATCH** |
| **2** | 0 | `0xFF / 0x04 / 0x01` | Bulk IN `0x86` (512B)<br>Bulk OUT `0x07` (512B) | Servidor Web EWS / Telemetría DevMgmt LEDM (`status`, `supplies`, `odometer`) | **100% MATCH** |
| **3** | 0 | `0xFF / 0x04 / 0x01` | Bulk IN `0x88` (512B)<br>Bulk OUT `0x09` (512B) | Canal de Diagnóstico Alternativo de Fábrica | **100% MATCH** |

---

### 3. Conclusiones y Certificación de Topología

1. **Resolución de Endpoints de Impresión:** Queda refutado definitivamente el uso estático de OUT `0x02` / IN `0x82` para la clase Printer (`0x07/0x01/0x02`). El hardware real asigna OUT `0x05` e IN `0x84`. El backend C implementa descubrimiento dinámico conforme a norma.
2. **Ausencia de Payloads Intrusivos:** La extracción se completó mediante llamadas pasivas de control (`libusb_get_device_descriptor`, `libusb_get_active_config_descriptor`). Cero riesgo para el hardware.
3. **Certificación:** La topología física es idéntica a la norma canónica del repositorio.
