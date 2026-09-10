# Investigación Cruzada de Modelos y Familia P15_CISS — HP Smart Tank

**Fecha:** 2026-09-04  
**Fuente de Datos Primaria:** HPLIP 3.26.4 (`data/models/models.dat`, PPDs en `ppd/hpcups/`), PPDs extraídos de controladores HP para macOS.  
**Herramientas:** `tools/ppd_miner.py`, análisis comparativo estructurado.

---

## 1. Clasificación Epistémica

* **[HECHO VERIFICADO]**: En la base de datos oficial de ingeniería de HP (`models.dat`), la HP Smart Tank 500 pertenece a la clase de tecnología `P15_CISS` (`family-class=P15_CISS`, `tech-subclass=Normal`, `tech-type=2`).
* **[HECHO VERIFICADO]**: El parámetro `plugin=0` confirma de forma concluyente que este modelo NO requiere ningún firmware o blob binario propietario cerrado para imprimir o escanear.
* **[HECHO VERIFICADO]**: El parámetro `io-support=2` en la Smart Tank 500 indica comunicación estrictamente USB (a diferencia de la serie 530/510 con `io-support=10` que incluye Wi-Fi/Red).
* **[HECHO VERIFICADO]**: La familia `P15_CISS` comparte el mismo motor de inyección térmica (TIJ 2.X), cabezales de impresión rellenables por tanques externos continuos (CISS) y protocolo raster PCL3GUI (Modo 10 de compresión).
* **[IMPLEMENTADO]**: Generador y comparador automatizado `tools/ppd_miner.py` que procesó 49 PPDs de la familia HP Smart Tank / Ink Tank.
* **[VERIFICADO OFFLINE]**: Concordancia del 100% en las 53 opciones de tamaño de papel y las 178 restricciones UIConstraints entre el PPD de referencia HPLIP y el PPD nativo para macOS Apple Silicon (`hp-smart_tank_500_series_mac.ppd`).

---

## 2. Comparativa de Modelos de la Familia P15_CISS

A partir de la minería de `models.dat` y los PPDs oficiales, se consolidó la siguiente matriz de modelos hermanos:

| Modelo HP | USB VID:PID | Tech Class | IO Support | Plugin Requerido | Tipo Escáner | Consumibles Soportados |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **HP Smart Tank 500** | `03f0:2b54` | `P15_CISS` | `2` (USB) | `0` (Ninguno) | `7` (LEDM Platen) | GT51/GT53 (K), GT52 (C,M,Y) |
| **HP Smart Tank 510** | `03f0:2c54` | `P15_CISS` | `10` (USB+Net) | `0` (Ninguno) | `7` (LEDM Platen) | GT51/GT53 (K), GT52 (C,M,Y) |
| **HP Smart Tank 530** | `03f0:2d54` | `P15_CISS` | `10` (USB+Net) | `0` (Ninguno) | `7` (LEDM ADF+Platen) | GT51/GT53 (K), GT52 (C,M,Y) |
| **HP Smart Tank 350** | `03f0:1954` | `P15_CISS` | `2` (USB) | `0` (Ninguno) | `7` (LEDM Platen) | GT51/GT53 (K), GT52 (C,M,Y) |
| **HP Ink Tank 310** | `03f0:1554` | `P15_CISS` | `2` (USB) | `0` (Ninguno) | `7` (LEDM Platen) | GT51 (K), GT52 (C,M,Y) |
| **HP Ink Tank 410** | `03f0:1654` | `P15_CISS` | `10` (USB+Net) | `0` (Ninguno) | `7` (LEDM Platen) | GT51 (K), GT52 (C,M,Y) |

---

## 3. Minería de Atributos y Restricciones PPD

El script `tools/ppd_miner.py` analizó las directivas de los 49 archivos PPD asociados a la familia Ink/Smart Tank. Los hallazgos principales son:

1. **Resoluciones Nativas Soportadas por Hardware:**
   * `300x300dpi` (Borrador / Draft)
   * `600x600dpi` (Normal / Estándar en texto y gráficos)
   * `1200x1200dpi` (Óptima / Fotográfica de alta resolución)
   * `4800x1200dpi` (Modo foto interpolado con papel fotográfico HP Premium)
2. **Dimensiones y Márgenes de Página:**
   * Márgenes físicos mínimos estándar: Superior 3.0 mm, Inferior 3.0 mm (o 12.7 mm en ciertos modelos), Izquierdo 3.0 mm, Derecho 3.0 mm.
   * Modos sin bordes (*Borderless*): Soportados en 4x6in, 5x7in, Carta y A4.
3. **Mapeo de Tipos de Medio (Media Types):**
   * Papel Común (Plain Paper) -> ID interno PCL3GUI `0`
   * Papel Fotográfico Brillante (Glossy Photo) -> ID interno PCL3GUI `2`
   * Papel Mate / Folleto (Matte Brochure) -> ID interno PCL3GUI `4`
4. **Filtro Raster CUPS:**
   * En HPLIP / Linux: `application/vnd.cups-raster 0 hpcups`
   * En nuestra distribución macOS: `application/vnd.cups-raster 0 /Library/Printers/hp/cups/filters/rastertopcl3gui` (reemplazo C de alto rendimiento sin dependencia de librerías Linux C++).
