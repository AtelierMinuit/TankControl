# Auditoría del Backend CUPS y Simulación USB — 2026

**Fecha:** 2026-09-04  
**Componente:** `tools/cups_backend_smarttank.c`  
**Binario:** `research/builds/antigravity-offline-audit/smarttank`  
**Esquema de URI:** `smarttank://HP/Smart%20Tank%20500%20series?serial=...`  
**Modo:** 100% OFFLINE  

---

## 1. Arquitectura y Modelo de Hilos

El backend CUPS nativo implementa:
1. **Modo descubrimiento (`argc == 1`):** Enumera el bus USB buscando `VID 0x03f0 / PID 0x2b54`. En ausencia de hardware físico y bajo `HP_SMART_TANK_MOCK=1`, reporta la URI del gemelo digital mock.
2. **Hilo principal de transmisión:** Lee el spool de entrada (stdin o archivo) en fragmentos de 16 KB (`CHUNK_SIZE`) y los transmite al Endpoint `0x02` (Bulk OUT) de la Interfaz 1 (Printer Class).
3. **Hilo secundario de telemetría (`status_monitor_thread`):** Sondea periódicamente el estado del motor cada 3 segundos emitiendo directivas estándar de CUPS a `stderr`:
   - `STATE: +media-empty-error` / `STATE: -media-empty-error`
   - `STATE: +media-jam-error` / `STATE: -media-jam-error`
   - `STATE: +door-open-error` / `STATE: -door-open-error`
   - `PAGE: <num> <total>`
4. **Sincronización:** Ambos hilos comparten el descriptor de dispositivo libusb protegido mediante `pthread_mutex_t usb_mutex`.

---

## 2. Códigos de Retorno CUPS Verificados

| Código de Salida | Constante CUPS | Condición en Backend | Estado Verificado |
| :---: | :--- | :--- | :--- |
| **0** | `CUPS_BACKEND_OK` | Impresión finalizada con éxito / Descubrimiento completado | `VERIFICADO EN MOCK` |
| **1** | `CUPS_BACKEND_FAILED` | Argumentos inválidos (`argc < 6`), copias no numéricas, fallo de apertura de spool | `VERIFICADO EN MOCK` |
| **2** | `CUPS_BACKEND_CANCEL` | Interrupción de trabajo por `SIGTERM` o `SIGINT` (cancelación de usuario) | `VERIFICADO EN MOCK` |
| **3** | `CUPS_BACKEND_RETRY` | Timeout al intentar adquirir el lock USB (`acquire_usb_lock` tras 10 s) | `VERIFICADO OFFLINE` |
| **4** | `CUPS_BACKEND_RETRY_CURRENT` | Impresora no conectada en inicio / Timeout de reconexión tras desconexión en caliente (30 s) | `VERIFICADO OFFLINE` |

---

## 3. Auditoría de Concurrencia y Cerrojo USB

### Estado Actual: Cerrojo Global Monolítico
- Archivo: `/tmp/hp_smart_tank_usb.lock`
- Apertura: `open(..., O_RDWR | O_CREAT | O_NOFOLLOW, 0600)`
- Bloqueo: `flock(fd, LOCK_EX | LOCK_NB)` con reintentos hasta 10 segundos.

### Evaluación Técnica de Granularidad por Subsistema:
La HP Smart Tank 500 expone 4 interfaces USB:
- **Interfaz 0 (ff/cc/00):** LEDM / EWS (Endpoints 0x01 / 0x81).
- **Interfaz 1 (07/01/02):** Impresión Bulk (Endpoints 0x02 / 0x82).
- **Interfaz 2 (ff/04/01):** Escáner / Vendor (Endpoints 0x03 / 0x83).
- **Interfaz 3 (ff/04/01):** Escáner / Telemetría.

**Conclusión de Ingeniería:**
Aunque las interfaces USB son lógicamente independientes a nivel del descriptor, el procesador embebido de la Smart Tank 500 (`P15_CISS`) comparte un único bus serie interno.
- **Riesgo:** Si dos procesos acceden concurrentemente a la interfaz de impresión y a la de escáner a alta tasa de transferencia, el hardware genera condiciones de stall (`LIBUSB_ERROR_PIPE`).
- **Dictamen:** Mantener el cerrojo global `/tmp/hp_smart_tank_usb.lock` es la decisión **más segura y conservadora** para evitar atascos de hardware no recuperables sin reinicio físico. La división en cerrojos por subsistema (`print.lock`, `scan.lock`) debe permanecer como **EXPERIMENTAL** hasta contar con instrumentación en hardware real.

---

## 4. Manejo de Señales y Limpieza de Recursos

- **`SIGPIPE`:** Ignorado explícitamente (`signal(SIGPIPE, SIG_IGN)`) para evitar que la desconexión abrupta de la tubería CUPS cause terminación anormal del proceso sin liberar locks.
- **`SIGTERM` / `SIGINT`:** Marcador atómico `g_cancel_job = 1` permite al bucle principal abortar la transferencia, detener el hilo monitor con `pthread_join` y liberar el cerrojo `flock` antes de salir con `CUPS_BACKEND_CANCEL`.
- **Descriptores:** `input_fd`, `lock_fd` y los contextos de libusb se liberan en todas las ramas de retorno sin memory leaks.
