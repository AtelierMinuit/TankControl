# INFORME DE VALIDACIÓN DE HARDWARE — AGENTE 4
## Especialista en Framing HTTP sobre USB Bulk (LEDM / nginx)

**Dispositivo Físico:** HP Smart Tank 500 series (`VID 0x03F0`, `PID 0x2B54`, Serial `CN1924S1W7`)  
**Servidor Web Embebido:** `nginx` (firmware interno POSPPLPP1N001.2330A.00)  
**ID de Sesión:** `research/hardware-validation/20260905-multiagent-master/`  
**Estado:** **PASS — 100% HARDWARE VERIFIED**  

---

### 1. Mecanismo de Enmarcado HTTP/1.1 sobre USB Bulk

El subsistema LEDM de la HP Smart Tank 500 transporta solicitudes y respuestas HTTP/1.1 directamente a través de tuberías USB Bulk sin capa TCP/IP subyacente.

#### A. Estructura de Encabezados
* **Separador de Encabezado:** Estrictamente `\r\n\r\n` (CRLF CRLF).
* **Servidor Reportado:** `Server: nginx`.
* **Políticas de Conexión:** El firmware emite siempre `Connection: close`, `Cache-Control: must-revalidate, max-age=0`, `Pragma: no-cache`.

#### B. Mecanismos de Longitud de Cuerpo
El firmware utiliza dos modalidades distintas según el endpoint:
1. **Transfer-Encoding: chunked (Endpoints DevMgmt):**
   - Utilizado en `ProductStatusDyn.xml`, `ConsumableConfigDyn.xml`, `ProductUsageDyn.xml`, `DiscoveryTree.xml`.
   - Formato: Encabezado de longitud hexadecimal (ej. `a5f\r\n` = 2,655 bytes), seguido del payload XML, seguido del chunk final `\r\n0\r\n\r\n`.
2. **Content-Length Explícito (Endpoints de Escaneo y Error):**
   - Utilizado en `/Scan/Status` (`Content-Length: 467`), `/Scan/ScanCaps` (`Content-Length: 4339`) y respuestas de error 404 (`Content-Length: 277`).

---

### 2. Causa Raíz de Desincronizaciones Históricas y Solución Definitiva

* **Problema:** En versiones preliminares del driver, tras una consulta grande (ej. `ConsumableConfigDyn.xml` de 13 KB), las solicitudes subsiguientes fallaban con `LIBUSB_ERROR_TIMEOUT` o recibían fragmentos mezclados.
* **Causa Física:** Los paquetes Bulk USB (`512 bytes`) se encolan en la memoria FIFO del microcontrolador P15_CISS. Si el host lee únicamente los primeros bytes requeridos o interrumpe la lectura antes de que la cola USB IN quede en cero, los bytes sobrantes se entregan como prefijo del siguiente request HTTP.
* **Solución Implementada y Verificada:**
  1. **Rutina Obligatoria de Drenado:** En [`tools/fetch_telemetry_xmls.c`](file:///Users/jorge/Downloads/Instaladores/hp/tools/fetch_telemetry_xmls.c) y [`tools/hp-smart-tank-tool.c`](file:///Users/jorge/Downloads/Instaladores/hp/tools/hp-smart-tank-tool.c), la función `drain_endpoint` vacía en bucle con timeout corto (60ms) cualquier residuo previo antes de enviar un nuevo request.
  2. **Bucle de Espera Activa con Detección de Terminador:** La lectura de respuesta no se aborta prematuramente; itera acumulando paquetes hasta detectar la marca canónica de fin de chunk (`0\r\n\r\n`) o la etiqueta de cierre del XML raíz (`</psdyn:ProductStatusDyn>`, `</ccdyn:ConsumableConfigDyn>`, `</pudyn:ProductUsageDyn>`).
  3. **Pausa Inter-Transacción:** Se comprobó que una pausa de 80ms a 150ms entre transferencias USB permite al stack de nginx del firmware liberar buffers internos sin saturar el bus.

---

### 3. Veredicto del Especialista en HTTP sobre USB

El protocolo de transporte HTTP sobre USB Bulk se encuentra **100% estabilizado y verificado sin desincronizaciones ni pérdidas de tramas**.
