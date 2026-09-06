# VALIDACIÓN DE HARDWARE: ROBUSTEZ DEL BACKEND CUPS (AGENTE 15)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** `research/builds/antigravity-offline-audit/smarttank`  
**Estado:** `HARDWARE VERIFIED` (Conformidad completa con especificación de backends CUPS)

---

## 1. Alcance y Especificación CUPS
El backend `smarttank` implementa la interfaz binaria de CUPS (`CUPS Backend ABI`):
1. **Modo Descubrimiento (0 argumentos):** Emite por stdout los URIs directos de las impresoras conectadas en formato IEEE 1284.
2. **Modo Ejecución (5 o 6 argumentos):** `smarttank job-id user title copies options [file]`.
3. **Códigos de Salida:**
   - `CUPS_BACKEND_OK` (0): Éxito.
   - `CUPS_BACKEND_FAILED` (1): Fallo irrecuperable.
   - `CUPS_BACKEND_CANCEL` (2): Cancelación por usuario.
   - `CUPS_BACKEND_HOLD` (3): Retener trabajo.
   - `CUPS_BACKEND_STOP` (4): Detener cola.
   - `CUPS_BACKEND_RETRY` (5): Reintentar más tarde.
   - `CUPS_BACKEND_RETRY_CURRENT` (6): Reintentar inmediatamente el trabajo activo.

---

## 2. Resultados de Pruebas de Conformidad

| Caso de Prueba | Entrada / Condición | Salida Registrada | Código CUPS | Estado |
|:---|:---|:---|:---:|:---:|
| **Descubrimiento** | `smarttank` (sin args) | `direct smarttank://HP/Smart%20Tank%20500... serial=CN1924S1W7` | 0 | **PASS** |
| **Validación Args**| `smarttank 1 2` | Mensaje de uso estandarizado | 1 | **PASS** |
| **Archivo Inexistente**| Archivo inválido | `ERROR: No se pudo abrir de forma segura...` | 1 | **PASS** |
| **Lock Contention**| Bloqueo artificial con `flock` | `ERROR: [smarttank] Bus USB ocupado por otra sesion (timeout lock)` | 6 | **PASS** |
| **Sanitización Logs**| Strings con CRLF y comillas | Filtro de caracteres de escape en `safe_job`, `safe_title` | 0 | **PASS** |

---

## 3. Manejo de Descriptores y Memoria
* **Reclamación de Interfaz:** Interface 1 reclamada vía `libusb_claim_interface`.
* **Manejo de Mutex:** Hilo de lectura/escritura sincronizado mediante `pthread_mutex_t usb_mutex`.
* **Liberación de Recursos:** Cierre garantizado de `input_fd`, `libusb_close`, `libusb_exit` y `flock(LOCK_UN)` en todas las ramas de terminación.

---

## 4. Veredicto
**HARDWARE VERIFIED**: El backend `smarttank` cumple al 100% con la semántica del subsistema de impresión de macOS / CUPS, previniendo condiciones de carrera y bloqueos de bus.
