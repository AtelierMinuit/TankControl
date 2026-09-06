# Auditoría del Motor de Escáner LEDM y Framing HTTP sobre USB — 2026

**Fecha:** 2026-09-04  
**Componentes analizados:**  
- `tools/hp_scan.c` (Motor nativo C de escaneo USB)  
- `tools/hp_escl_bridge.py` (Puente HTTP eSCL a USB)  
- `tests/test_ledm_http_framing.py` (Arnés de simulación de framing HTTP)  
**Comparativa de referencia:** HPLIP `bb_ledm.c` y bundles macOS `HPLEDMScan.bundle` / `HPDM.framework`.  
**Modo:** 100% OFFLINE  

---

## 1. Principio Fundamental: `1 USB read != 1 HTTP response`

En los escáneres multifunción HP que implementan LEDM (Low-End Data Model) sobre USB Bulk (Interfaz 0, endpoints `0x01` OUT y `0x81` IN):
1. **Fragmentación:** Una respuesta HTTP puede llegar dividida en múltiples transferencias USB (p. ej., cabeceras en un paquete y cuerpo en paquetes sucesivos).
2. **Concatenación:** Si el firmware de la impresora encola respuestas pendientes o eventos de estado, un único `libusb_bulk_transfer()` puede recibir el final de una respuesta anterior concatenado con el inicio de una nueva respuesta.
3. **Residuos Post-Imagen:** El stream de escaneo JPEG contiene datos binarios delimitados por `0xFFD8` (SOI) y `0xFFD9` (EOI). El firmware puede rellenar el último paquete USB con ceros o bytes de padding que **no pertenecen al archivo JPEG** y deben ser descartados.

---

## 2. Comparativa con HPLIP `bb_ledm.c` y macOS `HPLEDMScan.bundle`

| Aspecto | HPLIP `bb_ledm.c` | macOS `HPLEDMScan.bundle` | Implementación `hp_scan.c` / `bridge` | Estado |
| :--- | :--- | :--- | :--- | :--- |
| **Endpoint USB** | Interfaz 0 (EP 0x01/0x81) | Interfaz 0 (EP 0x01/0x81) | Interfaz 0 (EP 0x01/0x81) | `CORRECTO` |
| **Pre-verificación de estado** | `GET /Scan/Status` obligatorio | `GET /Scan/Status` obligatorio | Comprueba `Idle` antes de `POST /Scan/Jobs` | `VERIFICADO OFFLINE` |
| **Framing HTTP** | Bucle de `Content-Length` | Pipe HTTP interno | Bucle acumulativo con validación `body_bytes >= len` | `VERIFICADO OFFLINE` |
| **Chunked Encoding** | Soportado con deschunker | Soportado nativamente | Rechazado explícitamente en C para evitar buffers desfasados; soportado en Python | `SEGURO / RESTRICTIVO` |
| **Extracción JPEG** | Delimitadores SOI/EOI | Parser CoreGraphics | Delimitación estricta SOI (`0xFFD8`) y EOI (`0xFFD9`) | `VERIFICADO OFFLINE` |
| **Namespaces XML** | Parser expat con prefijos dinámicos | NSXMLParser con resolución de URI | Extracción agnóstica de namespace (`tag.split('}')[-1]`) | `VERIFICADO OFFLINE` |

---

## 3. Estado de Seguridad del Parser LEDM

- **Protección contra Billion Laughs / DoS:** `hp_escl_bridge.py` prohíbe `DOCTYPE` y expansiones de entidades antes del parsing XML (`test_fuzz_malformed_xml_payloads` pasa satisfactoriamente).
- **Rutas y Permisos:** `hp_scan` exige una ruta de salida explícita y la abre con `O_NOFOLLOW` y permisos `0600`, evitando la sobreescritura accidental de archivos predecibles en `/tmp`.
- **Timeouts de lectura:** Timeout de 2.000 ms en transferencias USB para evitar bloqueos perpetuos si el escáner físico no responde.

---

## 4. Veredicto del Componente

- **Parser y Framing HTTP:** `VERIFICADO OFFLINE` (100% de los fixtures de fragmentación y concatenación superados).
- **Captura física real:** `HARDWARE REQUIRED` (La calibración de tiempos y la sincronización con el motor óptico CIS físico requiere la impresora conectada).
