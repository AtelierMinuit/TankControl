# Plan Maestro de Validación en Hardware Físico — HP Smart Tank 500

**Fecha:** 2026-09-04  
**Dispositivo:** HP Smart Tank 500 All-in-One (`0x03f0:0x2b54`, microcontrolador P15_CISS)  
**Host de Prueba:** macOS Apple Silicon ARM64 (macOS 12.0+)  
**Objetivo:** Protocolo paso a paso para la primera sesión con la impresora física conectada por USB, verificando impresión, escaneo, telemetría y puentes locales.

---

## 1. Requisitos Previos y Materiales de Laboratorio

1. **Hardware y Conectividad:**
   * Impresora HP Smart Tank 500 encendida con cable USB 2.0 de alta velocidad conectado directamente al Mac (o mediante adaptador USB-C a USB-A oficial de Apple; evitar hubs pasivos no alimentados).
   * Tanques de tinta CISS verificados visualmente (niveles por encima de la línea de llenado mínimo).
   * Al menos 20 hojas de papel común (Bond 75-80 \(g/m^2\)) tamaño Carta o A4 en la bandeja de entrada.
   * Al menos 2 hojas de papel fotográfico brillante (Glossy Photo Paper) para prueba de resolución y calibración cromática.
2. **Herramientas de Software:**
   * Script automatizado: `tools/run_hardware_validation.sh`.
   * Permisos de administrador local (`sudo`) para interactuar con la cola del planificador CUPS.

---

## 2. Protocolo de Ejecución Paso a Paso

### Fase 1: Enumeración y Descriptores USB
* **Comando del Arnés:**
  ```bash
  tools/run_hardware_validation.sh --probe
  ```
* **Comando Manual de Diagnóstico:**
  ```bash
  research/builds/antigravity-offline-audit/usb-descriptor-inventory
  ```
* **Verificación esperada:**
  * Detección de VID `0x03f0` y PID `0x2b54` (HP Smart Tank 500 / P15_CISS).
  * **Mapeo Real de Interfaces USB (Auditado):**
    * **Interfaz 0 (`ff/cc/00`):** Vendor-Specific LEDM Scan (Bulk OUT `0x02`, Bulk IN `0x81`).
    * **Interfaz 1 (`07/01/02`):** USB Printer Class (Bulk OUT `0x02`, Bulk IN `0x82`).
    * **Interfaz 2 (`ff/04/01`):** Vendor-Specific LEDM Management / EWS (Bulk OUT `0x02`, Bulk IN `0x82`).
  * Confirmación del IEEE-1284 Device ID: `MFG:HP;MDL:HP Smart Tank 500 series;CMD:PCL3GUI,LEDM;`.

### Fase 2: Telemetría LEDM y Lectura de Consumibles
* **Comando del Arnés:**
  ```bash
  tools/run_hardware_validation.sh --telemetry
  ```
* **Comandos Manuales:**
  ```bash
  research/builds/antigravity-offline-audit/hp-smart-tank-tool status
  research/builds/antigravity-offline-audit/hp-smart-tank-tool supplies
  research/builds/antigravity-offline-audit/hp-smart-tank-tool odometer
  ```
* **Verificación esperada:**
  * Estado de la impresora en `Ready` (o advertencia si la tapa está abierta o no hay papel).
  * Niveles de tinta reportados en formato JSON legible (K, C, M, Y).
  * Odómetro: Contador de páginas totales y páginas a color impresas por el equipo.

### Fase 3: Impresión Física PCL3GUI (Modo 10)
* **Comando del Arnés:**
  ```bash
  tools/run_hardware_validation.sh --print
  ```
* **Comando Manual:**
  ```bash
  # Impresión de la página de prueba estandarizada con parches de color y rejilla
  lp -d HP_Smart_Tank_500 research/hardware-validation/hardware-smoke-test.pdf
  ```
* **Verificación esperada:**
  * El operador confirma explícitamente la presencia de papel en la bandeja.
  * La impresora toma la hoja sin atasco ni doble alimentación.
  * Los cabezales térmicos expulsan tinta uniformemente sin bandas blancas (*banding*).
  * Se genera el manifiesto del stream con el PDF original, el CUPS Raster y el PCL3GUI final.

### Fase 4: Digitalización Óptica (Escáner USB)
* **Comando del Arnés:**
  ```bash
  tools/run_hardware_validation.sh --scan
  ```
* **Comando Manual:**
  ```bash
  # Escaneo de prueba a 150 DPI Color sobre Interfaz 0 (ff/cc/00)
  research/builds/antigravity-offline-audit/hp_scan --resolution 150 --mode Color --output /tmp/test_scan_150.jpg
  ```
* **Verificación esperada:**
  * Conexión a la Interfaz 0 (`ff/cc/00`).
  * Movimiento fluido y retorno seguro del carro del sensor CIS sin ruidos de colisión.
  * Archivo JPEG válido delimitado por SOI (`0xFFD8`) y EOI (`0xFFD9`).

### Fase 5: Validación de Image Capture / AirScan (eSCL)
* **Pasos:**
  1. Iniciar el puente: `python3 tools/hp_escl_bridge.py --port 8080`
  2. Abrir la aplicación nativa **Image Capture** (Captura de Imagen) en macOS.
  3. Comprobar que la HP Smart Tank 500 aparezca en la barra lateral bajo dispositivos compartidos/eSCL.
  4. Realizar un escaneo directamente desde la interfaz de Apple.

### Fase 6: Validación de AirPrint Local
* **Pasos:**
  1. Iniciar el demonio AirPrint: `tools/hp_airprint_daemon.sh --port 8631`
  2. Desde un iPhone o iPad conectado a la misma red Wi-Fi (o desde el diálogo de impresión de Safari en el Mac):
  3. Seleccionar "HP Smart Tank 500 (AirPrint)".
  4. Lanzar una impresión y comprobar la conversión de `image/urf` a PostScript y su despacho a la cola CUPS.

---

## 3. Procedimientos de Contingencia y Mitigación de Riesgos

1. **Atasco de Papel Mecánico:**
   * No tirar del papel con fuerza hacia adelante. Apagar el equipo, abrir la compuerta frontal y retirar el papel atascado en la dirección natural del flujo de arrastre.
2. **Boquillas Obstruidas tras Desuso:**
   * Si la página de prueba presenta líneas en blanco, ejecutar:
     ```bash
     research/builds/antigravity-offline-audit/hp-smart-tank-tool clean-heads
     ```
   * Si la obstrucción persiste, ejecutar el ciclo de segundo nivel `deep-clean`.
   * **PRECAUCIÓN:** No ejecutar `prime-tubes` a menos que se hayan cambiado los cabezales o se observe aire continuo en las mangueras de los tanques CISS.
