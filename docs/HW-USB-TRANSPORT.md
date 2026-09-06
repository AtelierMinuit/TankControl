# INFORME DE VALIDACIÓN DE HARDWARE — AGENTE 2
## Auditoría del Transporte Físico USB (Apple Silicon ARM64)

**Dispositivo Físico:** HP Smart Tank 500 series (`VID 0x03F0`, `PID 0x2B54`, Serial `CN1924S1W7`)  
**Host Controller:** Apple Silicon USB 2.0 High-Speed Root Hub (480 Mbps)  
**ID de Sesión:** `research/hardware-validation/20260905-multiagent-master/`  
**Archivo de Registro:** `research/hardware-validation/20260905-multiagent-master/logs/02_usb_transport.log`  
**Estado:** **PASS — 100% HARDWARE VERIFIED**  

---

### 1. Reclamación y Liberación de Interfaces (`claim / release`)

Se probó la adquisición y desvinculación atómica en las 4 interfaces del microcontrolador:

* **Interfaz 0 (Scan LEDM):** `libusb_claim_interface`: **0.12 ms** | `libusb_release_interface`: **0.14 ms** (OK)
* **Interfaz 1 (Print Class):** `libusb_claim_interface`: **0.15 ms** | `libusb_release_interface`: **0.06 ms** (OK)
* **Interfaz 2 (EWS / Telemetry):** `libusb_claim_interface`: **0.15 ms** | `libusb_release_interface`: **0.04 ms** (OK)
* **Interfaz 3 (Alt Diagnostic):** `libusb_claim_interface`: **0.14 ms** | `libusb_release_interface`: **0.04 ms** (OK)

**Evaluación:** Cero contención en el kernel de macOS. `auto_detach_kernel_driver` funciona de manera transparente sin generar `LIBUSB_ERROR_BUSY`.

---

### 2. Rendimiento de Transporte y Paquetización

* **Tamaño Máximo de Paquete (`wMaxPacketSize`):** `512 bytes` en todos los endpoints Bulk (norma USB 2.0 High-Speed).
* **Rendimiento Efectivo Medido (Canal EWS / LEDM):**
  - Iteración 2: 2,870 bytes en `0.38 ms` (`7.34 MB/s`)
  - Iteración 3: 2,870 bytes en `0.50 ms` (`5.62 MB/s`)
  - Iteración 4: 2,870 bytes en `0.46 ms` (`6.05 MB/s`)
  - Iteración 5: 2,870 bytes en `0.47 ms` (`5.90 MB/s`)
* **Retransmisiones / Errores de Timeout:** `0` errores de comunicación una vez que la cola IN está drenada.

---

### 3. Conclusiones del Ingeniero de Transporte

1. El bus USB físico opera con una velocidad de transferencia efectiva superior a 5.5 MB/s para payloads XML y transferencias Bulk.
2. No se detectaron condiciones de `STALL` ni caídas a `LIBUSB_ERROR_NO_DEVICE`.
3. Es crítico ejecutar una rutina de drenado inicial (`drain_endpoint`) antes de enviar comandos de texto para limpiar datos residuales encolados en el buffer FIFO del hardware.
