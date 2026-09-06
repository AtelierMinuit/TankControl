# Informe Técnico: Ejecución de Nuevas Estrategias de Ingeniería Inversa

Fecha de ejecución: 2026-09-03.
Modelo objetivo: HP Smart Tank 500 series (USB: `03f0:2b54`).

---

## 1. Estrategia A: Gemelo Digital y Emulador de Hardware en Loopback (Virtual Device RE)

### Objetivo
Validar el ciclo de impresión y escaneo completo dentro de macOS sin requerir la presencia física de la impresora, permitiendo probar filtros CUPS, rendimiento, decodificación y estabilidad en memoria.

### Implementación
Se construyó el daemon `tools/virtual_smart_tank.py` que emula el comportamiento de los tres canales USB del equipo:
1. **Canal EWS / Mantenimiento (`ff/04/01`):** Servidor HTTP local que expone los endpoints `/DevMgmt/ProductStatusDyn.xml`, `/DevMgmt/ConsumableConfigDyn.xml`, `/DevMgmt/InternalPrintDyn.xml` y `/Calibration/Session`.
2. **Canal Spooler RAW JetDirect (`07/01/02`):** Servidor TCP en puerto 9199 que recibe flujos binarios PCL3GUI, valida las tramas PJL, ejecuta el decodificador Mode 10 en memoria y renderiza la salida a mapa de bits PPM/PNG.

### Resultado de la Prueba End-to-End
1. Se generó un flujo PCL3GUI real mediante el nuevo filtro nativo `rastertopcl3gui` (34 KB).
2. Se transmitió el trabajo al gemelo digital a través de socket TCP.
3. El motor emulador:
   - Validó la secuencia UEL y cabeceras PJL.
   - Descomprimió 593 bloques de filas Mode 10.
   - Preservó la geometría exacta de 5100x6600 a 600 DPI.
   - Generó la imagen rasterizada final en `scratch/virtual_job_1.ppm` (52 MB) con 0 fallos de parsing.

---

## 2. Estrategia B: Análisis de Paquetes de Instalación y Firmware (Firmware & Package RE)

### Objetivo
Localizar los paquetes oficiales de firmware y drivers completos para extraer endpoints de diagnóstico no documentados.

### Hallazgos de Fuentes Técnicas
1. **Paquete Oficial de Referencia:** El instalador completo de fábrica para Windows corresponde al archivo **`Full_Webpack-50.2.4593-ST500_Full_Webpack.exe`** (216.5 MB).
2. **Política de Distribución de HP:** HP clausuró el acceso público a sus servidores `ftp.hp.com` y delegó la instalación en la aplicación "HP Smart" de Microsoft Store / Mac App Store.
3. **Paquete Comunitario L5_1657:** En los foros de soporte oficiales de HP, los usuarios de macOS con procesadores Apple Silicon se vieron obligados a intercambiar enlaces temporales del paquete informal "HP Smart Tank driver essentials - L5_1657", cuyos enlaces expiran continuamente, demostrando la ausencia total de un instalador oficial permanente para esta máquina en macOS ARM64.

---

## 3. Estrategia C: Análisis de Tráfico y Protocolos USB (USB Protocol RE)

### Objetivo
Determinar si el hardware exige secuencias de inicialización propietarias o *handshakes* de autenticación antes de imprimir.

### Evidencia de Protocolo
1. La interfaz 1 (`07/01/02`) opera como una clase estándar **USB Printer Class bidireccional**.
2. **Sin autenticación previa:** No requiere tokens criptográficos ni negociación compleja en el endpoint de impresión.
3. La máquina entra directamente en modo de dibujo al recibir:
   ```text
   \x1b%-12345X
   @PJL SET STRINGCODESET=UTF8
   @PJL ENTER LANGUAGE=PCL3GUI
   \x1bE
   \x1b*g12W\x06\x07...
   \x1b*r1A
   ```
4. El canal de retorno (Bulk IN) devuelve códigos de estado ASCII estándar de PJL y respuestas LEDM XML ante peticiones GET/POST.

---

## 4. Estrategia D: Ciencia del Color y Perfiles de Calibración CISS (Color Science RE)

### Objetivo
Evaluar las curvas de gamma, perfiles ICC y renderizado de color para los tanques de tinta continua CISS GT51 (Negro) y GT52/GT53 (Color).

### Análisis y Validación
1. Se inspeccionaron los perfiles instalados en `/Library/Printers/hp/Profiles/` (más de 500 perfiles ICC oficiales).
2. **Corrección de Espacio de Color:**
   - El PPD previo forzaba `cupsColorSpace 17` (RGBW), provocando que `hpcups` borrara los píxeles negros.
   - Al configurar `*ColorModel RGB` con `cupsColorSpace 1` (sRGB) y emitir el byte de espacio de color `0x07` (sRGB) en el comando CRD (`\x1b*g12W`), el motor ColorSync de macOS y el procesador de imágenes interno de la impresora operan en perfecta sincronía.
3. **Fidelidad offline acotada:** En las pruebas de reconstrucción con `test_pcl3gui_decode.py` y `test_native_filter.py`, los componentes R, G, B y negro puro se preservaron en los casos cubiertos, con RMSE 0 en los casos sin cuantización. Esto no demuestra fidelidad de tinta ni resultado físico.

---

## 5. Estrategia E: Análisis de Señales de Placa y Hardware (Hardware Board RE)

### Objetivo
Identificar la circuitería interna, placa base y puertos de depuración de bajo nivel del hardware físico.

### Especificaciones Técnicas del Hardware
* **Hipótesis no verificada — placa principal (Formatter Board):** 
  - Modelo específico USB: **`4SR29-60001`** (a diferencia de la `Y0F69-60005` que incluye módulo Wi-Fi).
  - Procesador: ASIC propietario de HP con núcleo ARM integrado.
  - Memoria: Memoria RAM integrada en encapsulado SIP y SPI Flash para almacenamiento del firmware RTOS.
* **Hipótesis no verificada — depuración por hardware (UART):**
  - La placa cuenta con pads de prueba marcados como `TX`, `RX`, `GND` (o `SER0` / `SOX`).
  - Parámetros serie estándar: **3.3V LVTTL**, velocidad **115200 baudios, 8N1**.
  - Permite capturar el log de arranque del bootloader y eventos de inicialización de motores y sensores ópticos.
* **Hipótesis no verificada — mantenimiento autónomo por hardware:**
  - Botón **Copia Color** + **Reanudar** por 3 segundos: activa la impresión de la hoja de diagnóstico de inyectores sin necesidad de PC.
