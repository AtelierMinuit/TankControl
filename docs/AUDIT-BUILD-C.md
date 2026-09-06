# Auditoría de Build C y Análisis Estático — 2026

**Fecha:** 2026-09-04  
**Plataforma:** macOS 26.6.2 (Darwin 25.6.0) ARM64  
**Compilador:** Apple clang version 21.0.0 (clang-2100.1.1.101)  
**Entorno de build:** `research/builds/antigravity-offline-audit/`  
**Modo:** 100% OFFLINE (Sin hardware conectado)

---

## 1. Resumen Ejecutivo

| Métrica | Resultado |
| :--- | :--- |
| **Componentes C auditados** | 6 herramientas (`rastertopcl3gui`, `cups_backend_smarttank`, `hp_scan`, `hp-smart-tank-tool`, `ews-readonly-probe`, `usb-descriptor-inventory`) + 2 arneses de fuzzing |
| **Flags de compilación estrictos** | `-O2 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -Wundef` |
| **Errores de compilación** | **0** |
| **Warnings de compilación** | **0** (bajo flags estrictos en todos los fuentes) |
| **Diagnósticos `clang --analyze`** | **0** en todos los fuentes C del proyecto |
| **Sanitizers (ASan / UBSan)** | **PASS** (100.000 rondas de mutación Mode10; ejecución de rasters 5100×6600 y 4962×7014 sin fallos ni leaks) |
| **ThreadSanitizer (TSan)** | **PASS** (Compilación y discovery de backend sin data races) |

---

## 2. Matriz de Compilación Estricta (Flags Pedánticos)

Comando base:
```bash
clang -O2 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -Wundef \
  -I/opt/homebrew/include/libusb-1.0 -I/opt/homebrew/include \
  -L/opt/homebrew/lib <fuente.c> <libs> -o <binario>
```

| Componente | Líneas C | Dependencias de Linker | Warnings | Exit Code | Estado |
| :--- | :---: | :--- | :---: | :---: | :--- |
| `tools/rastertopcl3gui.c` | 837 | `-lcups -lm` | **0** | 0 | **VERIFICADO OFFLINE** |
| `tools/cups_backend_smarttank.c` | 557 | `-lusb-1.0 -lcups` | **0** | 0 | **VERIFICADO OFFLINE** |
| `tools/hp_scan.c` | 338 | `-lusb-1.0` | **0** | 0 | **VERIFICADO OFFLINE** |
| `tools/hp-smart-tank-tool.c` | 1344 | `-lusb-1.0` | **0** | 0 | **VERIFICADO OFFLINE** |
| `tools/ews-readonly-probe.c` | 84 | `-lusb-1.0` | **0** | 0 | **VERIFICADO OFFLINE** |
| `tools/usb-descriptor-inventory.c` | 179 | `-lusb-1.0` | **0** | 0 | **VERIFICADO OFFLINE** |
| `tools/fuzz_mode10_encoder.c` | 30 | `-lcups -lm` | **0** | 0 | **VERIFICADO OFFLINE** |
| `tools/fuzz_mode10_driver.c` | 27 | — | **0** | 0 | **VERIFICADO OFFLINE** |

---

## 3. Análisis Estático (`clang --analyze`)

Se ejecutó `clang --analyze` de forma exhaustiva sobre cada unidad de traducción con los paths de inclusión del sistema y Homebrew:

```bash
clang --analyze -I/opt/homebrew/include/libusb-1.0 -I/opt/homebrew/include tools/*.c
```

### Resultados Detallados:
1. `tools/rastertopcl3gui.c`: **0 diagnósticos**.
   - Guardias defensivas comprobadas contra punteros nulos en `apply_ink_saver_pro`.
   - Control de límites en `row_bytes`, `cupsWidth`, `cupsHeight` y buffers dinámicos `cur_row`, `seed_row`, `comp_buf`.
2. `tools/cups_backend_smarttank.c`: **0 diagnósticos**.
   - Gestión de descriptores `input_fd` y `lock_fd` con cierre seguro en todas las rutas de salida.
   - Cerrojo `pthread_mutex_t usb_mutex` liberado simétricamente en ramas de error.
3. `tools/hp_scan.c`: **0 diagnósticos**.
   - Validación de apertura `O_NOFOLLOW` con permisos restrictivos `0600`.
   - Manejo de buffers para Start-Of-Image (`0xFFD8`) y End-Of-Image (`0xFFD9`).
4. `tools/hp-smart-tank-tool.c`: **0 diagnósticos**.
   - Verificación de flujos `FILE *` y canales USB.
   - Bloqueo preventivo de operaciones de hardware destructivas (`--confirm-hardware`).
5. `tools/ews-readonly-probe.c`: **0 diagnósticos**.
6. `tools/usb-descriptor-inventory.c`: **0 diagnósticos**.
7. `tools/fuzz_mode10_encoder.c`: **0 diagnósticos** (tras inicialización determinista de buffers `{0}`).

---

## 4. Auditoría de Sanitizers

### A. AddressSanitizer (ASan) y UndefinedBehaviorSanitizer (UBSan)
Flags utilizados: `-O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer`.

1. **Arnés de Mutación Fuzz Mode 10 (`fuzz_mode10_asan`):**
   - **Rondas ejecutadas:** 100.000 rondas pseudo-aleatorias deterministas con saltos RLE, deltas y patrones periódicos.
   - **Resultado:** `MODE10_SANITIZER_MUTATION_ROUNDS=100000 PASS`.
   - **Diagnósticos:** 0 heap-buffer-overflow, 0 stack-buffer-overflow, 0 integer-overflows, 0 undefined behavior.

2. **Filtro RIP con Rasters de Gran Formato (`rastertopcl3gui_asan`):**
   - `scratch/05-black-square.rgb.raster` (5100×6600 px @ 600 DPI, ~101 MB sin comprimir): **Exit 0, 0 hallazgos**.
   - `scratch/test_page_hp500.raster` (4962×7014 px @ 600 DPI, ~104 MB sin comprimir): **Exit 0, 0 hallazgos**.

### B. ThreadSanitizer (TSan)
Flags utilizados: `-O1 -g -fsanitize=thread -fno-omit-frame-pointer`.

- Binario: `research/builds/antigravity-offline-audit/tsan/smarttank_tsan`.
- Prueba: Ejecución de modo descubrimiento CUPS en bucle.
- Resultado: **0 data races, 0 deadlocks detectados**.

---

## 5. Clasificación Epistémica del Componente

- **Compilación C:** `HECHO VERIFICADO` (0 errores, 0 warnings, reproducible).
- **Análisis Estático C:** `HECHO VERIFICADO` (0 issues).
- **Sanitizers C (ASan/UBSan/TSan):** `VERIFICADO OFFLINE` (100k rondas sin fallos de memoria).
- **Interacción Física USB:** `HARDWARE REQUIRED` (No demostrable sin dispositivo real).
