# INFORME DE VALIDACIÓN DE HARDWARE — AGENTE 3
## Telemetría LEDM, Repetibilidad y Árboles XML

**Dispositivo Físico:** HP Smart Tank 500 series (`VID 0x03F0`, `PID 0x2B54`, Serial `CN1924S1W7`)  
**ID de Sesión:** `research/hardware-validation/20260905-multiagent-master/`  
**Directorio de Evidencia XML:** `research/hardware-validation/20260905-multiagent-master/telemetry/`  
**Estado:** **PASS — 100% HARDWARE VERIFIED**  

---

### 1. Inventario de Árboles XML Capturados y Hashed (SHA-256)

Todos los árboles XML emitidos por el servidor web embebido (nginx) y el subsistema LEDM fueron respaldados directamente desde el bus USB:

| Endpoint LEDM | Interfaz USB | HTTP Status | Tamaño (Bytes) | SHA-256 Checksum |
|:---|:---:|:---:|:---:|:---|
| `/DevMgmt/ProductStatusDyn.xml` | Iface 2 | 200 OK | 2,870 | `a55fb57feff8feda1e7c8d94659830ba69d4b0652b3c6ac3e7313403127383c2` |
| `/DevMgmt/ConsumableConfigDyn.xml` | Iface 2 | 200 OK | 13,148 | `48b93aafaae7480bfc4b5287a39867c05a153f5741bc9afceb7c56eee807d5c3` |
| `/DevMgmt/ProductUsageDyn.xml` | Iface 2 | 200 OK | 8,264 | `5b5cc47ab8fdfa229a865d7f63319eb70eb06c3db595e779be8266718fe85567` |
| `/DevMgmt/ProductConfigDyn.xml` | Iface 2 | 200 OK | 5,909 | `c4c5c7548b5a9d481cf320765065eba19a860e75c272b5ff098fa410dd4d77d7` |
| `/DevMgmt/DiscoveryTree.xml` | Iface 2 | 200 OK | 11,252 | `7a6a4cdbbd41d204d78e7fbeeb4b0b254ffe73a976724a1050897c658e17974b` |
| `/DevMgmt/MediaCapabilities.xml` | Iface 2 | 404 Not Found| 277 | `1047e3834d138e53f8f7989a183e59bfe87eb059471616f0299dc5fbfc52082d` |
| `/Scan/Status` | Iface 0 | 200 OK | 467 | `d8064a93142e0f2836b1a4887d91b620720849dfa5c8acbafe1396d1563f428f` |
| `/Scan/ScanCaps` | Iface 0 | 200 OK | 4,339 | `365766d93ea1681e605efc92c293659b32fb66ddc844d33c35140c42a9437ef3` |

---

### 2. Prueba de Estrés de Repetibilidad (60 Consultas Consecutivas)

Se sometió a la impresora a un ciclo de estrés de 60 peticiones consecutivas (20 por tipo de comando):

* **`status` (Iface 2, DevMgmt):**
  - Éxito: **20 / 20 (100.0% PASS)**
  - Latencia media: **88.1 ms** (Mínima: 82.7 ms, Máxima: 91.8 ms)
* **`supplies` (Iface 2, Consumibles):**
  - Éxito: **20 / 20 (100.0% PASS)**
  - Latencia media: **162.6 ms** (Mínima: 156.0 ms, Máxima: 169.0 ms)
* **`scan-status` (Iface 0, Escáner):**
  - Éxito: **20 / 20 (100.0% PASS)**
  - Latencia media: **107.7 ms** (Mínima: 100.1 ms, Máxima: 116.7 ms)

**Tasa Global de Éxito:** **60 / 60 OK (100.0%)** | Timeouts: 0 | Paquetes corruptos: 0 | Desincronizaciones: 0.

---

### 3. Estado Físico y Consumibles Reportados

1. **Estado Operativo:** `Ready` / `Depós. llenos` (`genuineHP`).
2. **Nivel de Tanques:** K=100%, C=100%, M=100%, Y=100% (Modo `dropCount`).
3. **Odómetro Acumulado:**
   - Impresiones Totales: **9,732**
   - Color: **6,646**
   - Monocromo: **3,077**
   - Atascos de Papel (*JamEvents*): **8**
   - Fallos de Alimentación (*PickFailures*): **0**
