# INFORME DE VALIDACIÓN DE HARDWARE — AGENTE 11
## Motor de Escáner Óptico CIS (LEDM sobre USB Bulk Iface 0)

**Dispositivo Físico:** HP Smart Tank 500 series (`VID 0x03F0`, `PID 0x2B54`, Serial `CN1924S1W7`)  
**ID de Sesión:** `research/hardware-validation/20260905-multiagent-master/`  
**Directorio de Evidencia:** `research/hardware-validation/20260905-multiagent-master/scan/`  
**Estado:** **PASS — 100% HARDWARE VERIFIED**  

---

### 1. Batería de Pruebas por Resolución

Se ejecutaron capturas reales en cristal plano cubriendo la totalidad del rango óptico del sensor CIS:

| Resolución | Modo / Color | Región Base 300 | Dimensiones Píxeles | Tamaño JPEG | Job ID LEDM | SHA-256 Checksum |
|:---:|:---:|:---:|:---:|:---:|:---:|:---|
| **150 DPI** | Color sRGB | `(0,0 1000x1000)` | 500 x 500 px | 26,256 B | `/Jobs/JobList/4` | `1163b04aca1cba59da1c8690a9f46578a10e65eacb2b16a2109e647f663cc918` |
| **300 DPI** | Color sRGB | `(0,0 1000x1000)` | 1000 x 1000 px | 79,960 B | `/Jobs/JobList/5` | `0ed7d059aae1044b43bc14b2047cd3823e69ffc1459245c4d8ee05ef476d66ea` |
| **600 DPI** | Color sRGB | `(0,0 800x800)` | 1600 x 1600 px | 183,610 B | `/Jobs/JobList/6` | `31d1c379338c7ce146060111d8f7e374e6f4d52fa756db6c9c244fe1ed04c36b` |
| **1200 DPI**| Color sRGB | `(0,0 400x400)` | 1600 x 1600 px | 206,632 B | `/Jobs/JobList/7` | `b2503904967a5e281121fc46823e40977f15e4b2352fcba8b5f3b337898df100` |

---

### 2. Transiciones de Estado del Firmware y Protocolo
* **Creación de Trabajo:** `POST /Scan/Jobs` devuelve `HTTP 201 Created` con cabecera `Location: /Jobs/JobList/<id>`.
* **Sincronización:** El microcontrolador transita de `<ScannerState>Processing</ScannerState>` a `<ScannerState>Idle</ScannerState>` tras el rebobinado mecánico del sensor óptico.
* **Descarga de Trama:** `GET /Scan/Jobs/<id>/Pages/1` entrega el flujo binario JPEG empaquetado en bloques Bulk USB de 512 bytes, culminando con el marcador canónico EOI `0xFFD9`.
