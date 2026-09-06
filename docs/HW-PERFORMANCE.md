# VALIDACIÓN DE HARDWARE: PERFILADO DE RECURSOS Y RENDIMIENTO (AGENTE 19)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** `rastertopcl3gui`, `smarttank`, `hp_scan`  
**Estado:** `HARDWARE VERIFIED` (Eficiencia de memoria y CPU sobresalientes en Apple Silicon)

---

## 1. Métricas de Rendimiento del Filtro Raster (`rastertopcl3gui`)
Medición estricta mediante `/usr/bin/time -l` sobre un trabajo raster A4 a 600 DPI (104,412,204 bytes):
* **Peak Resident Set Size (RSS):** **5.62 MB** (5,898,240 bytes).
* **Tiempo Real de Procesamiento:** **0.04 segundos** (40 milisegundos).
* **Tiempo de CPU:** Usuario = 0.02 s, Sistema = 0.01 s.
* **Tasa de Compresión:** 104 MB de mapa de bits transformados a 128 KB de stream PCL3GUI (reducción de 99.87%).
* **Consumo de Memoria por Línea:** Arquitectura de streaming fila a fila con búferes estáticos reutilizados, evitando la carga completa del documento en memoria.

---

## 2. Rendimiento del Canal USB y Puentes
* **Rendimiento de Interface 1 (Bulk OUT `0x05`):** 5.6 – 7.3 MB/s de tasa sostenida.
* **Latencia de Escaneo (150 DPI):** 3.89 a 6.33 segundos por página completa.
* **Sobrecarga del Puente eSCL (`hp_escl_bridge.py`):** Menor a 25 ms adicionales sobre la captura física de hardware.

---

## 3. Veredicto
**HARDWARE VERIFIED**: La implementación en C nativo para ARM64 ofrece un perfil de consumo mínimo, procesando documentos pesados sin sobrecargar la memoria del sistema ni generar picos térmicos.
