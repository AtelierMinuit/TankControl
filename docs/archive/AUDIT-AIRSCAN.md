# Auditoría del Protocolo AirScan / eSCL — 2026

**Fecha:** 2026-09-04  
**Componente:** `tools/hp_escl_bridge.py`  
**Protocolo:** eSCL (Apple AirScan) v2.63 sobre HTTP REST  
**Puerto de servicio:** `127.0.0.1:8089`  
**Modo:** 100% OFFLINE (Simulación y Mocks)  

---

## 1. Validación de Endpoints eSCL

| Endpoint eSCL | Método HTTP | Caso de Prueba | Código Esperado | Estado Verificado |
| :--- | :---: | :--- | :---: | :--- |
| `/eSCL/ScannerCapabilities` | `GET` | Capacidades de cama plana (Platen) | `200 OK` | `VERIFICADO EN MOCK` |
| `/eSCL/ScannerStatus` | `GET` | Estado del motor (`Idle`, `Processing`) | `200 OK` | `VERIFICADO EN MOCK` |
| `/eSCL/ScanJobs` | `POST` | Creación de trabajo con `ScanSettings` | `201 Created` | `VERIFICADO EN MOCK` |
| `/eSCL/ScanJobs/{id}/NextDocument` | `GET` | Descarga de documento escaneado (JPEG) | `200 OK` | `VERIFICADO EN MOCK` |
| `/eSCL/ScanJobs/{id}` | `DELETE` | Cancelación y limpieza de job temporal | `200 OK` | `VERIFICADO EN MOCK` |
| `/eSCL/NonExistentEndpoint` | `GET` | Rutas no reconocidas | `404 Not Found` | `VERIFICADO EN MOCK` |

---

## 2. Robustez y Manejo de Concurrencia

1. **Creación Concurrente de Trabajos (`ThreadPoolExecutor(8)`):**
   - Se probaron 24 solicitudes simultáneas de creación de jobs de escaneo.
   - Cada trabajo recibió un identificador correlativo estrictamente único (`job-1` a `job-24`) bajo control de `threading.Lock()`.
2. **Escalado Geométrico de Regiones de Escaneo:**
   - La especificación eSCL envía coordenadas de offset y ventana a resolución base de 300 DPI (`ScanRegion`).
   - El puente escala matemáticamente el rectángulo de escaneo según la resolución seleccionada (p. ej. a 600 DPI, el factor $2.0\times$ mapea $(150, 300, 600, 900) \to (300, 600, 1200, 1800)$ píxeles).
3. **Manejo de Fragmentación TCP:**
   - Se verificó mediante sockets raw que solicitudes POST fragmentadas en bloques de 7 bytes son recibidas y procesadas íntegramente una vez completado el `Content-Length`.
4. **Rechazo de Transfer-Encoding Chunked:**
   - El puente devuelve `411 Content-Length required` para impedir desincronizaciones en buffers con el cliente macOS.

---

## 3. Seguridad de Parseo XML y Resguardo Local

- **Vulnerabilidad Billion Laughs / DoS:** `xml.etree.ElementTree` protegido rechazando declaraciones `DOCTYPE` y entidades externas.
- **Enlace de red:** Limitado estrictamente a `127.0.0.1` en lugar de `0.0.0.0` para evitar exposición involuntaria en la LAN.
- **Aislamiento de Archivos Temporales:** Cada trabajo genera una imagen temporal aislada bajo `tempfile.TemporaryDirectory` con permisos 0700 que se destruye automáticamente tras la entrega o cancelación.

---

## 4. Veredicto del Componente

- **Protocolo eSCL y API REST:** `VERIFICADO EN MOCK` (12 tests unitarios pasando al 100%).
- **Integración con Captura de Imagen / Hardware:** `HARDWARE REQUIRED` (La captura física requiere la respuesta del escáner óptico real en hardware).
