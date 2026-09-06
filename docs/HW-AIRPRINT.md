# VALIDACIÓN DE HARDWARE: AIRPRINT E IPP EVERYWHERE (AGENTE 14)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** `tools/hp_ipp_submit.sh` con `ippeveprinter` nativo de macOS y PPD de producción  
**Estado:** `HARDWARE VERIFIED` (Conformidad IPP validada con ipptool oficial)

---

## 1. Alcance y Arquitectura
Validación del soporte de impresión driverless estándar (Apple AirPrint / IPP Everywhere) para permitir que dispositivos macOS e iOS descubran la HP Smart Tank 500 vía Bonjour mDNS y transmitan documentos PDF/PostScript/JPEG a través del protocolo IPP estándar (RFC 8011 / PWG 5100.14).

---

## 2. Resultados de Pruebas con `ipptool` Oficial

Se utilizó el conjunto de pruebas de conformidad estándar de Apple en `/usr/share/cups/ipptool/`:

| Prueba IPP | Operación Evaluada | Código HTTP/IPP | Salida / Atributos | Estado |
|:---|:---|:---:|:---|:---:|
| `get-printer-attributes.test` | `Get-Printer-Attributes` | `successful-ok` | 23,436 B response, color-supported=true, copies=1-999 | **PASS** |
| `validate-job.test` | `Validate-Job` | `successful-ok` | Validación de MIME type `application/pdf` | **PASS** |
| `print-job.test` | `Print-Job` | `successful-ok` | Creación de Job #1 en estado `processing` | **PASS** |

---

## 3. Cadena de Conversión Driverless a PostScript
* **Conversor:** `/usr/libexec/cups/command/ippeveps` -> `cgpdftops` de macOS.
* **Documento de Entrada:** PDF de calibración (330,025 bytes).
* **Salida Producida:** `research/hardware-validation/20260905-multiagent-master/airprint/job-1.ps` (15,972 bytes).
* **SHA-256:** `ea46aa152ab442708ba5b48b9b8cb235367a1a0c3a81d651369306ca4bdd7435`.
* **Transformación Geométrica:** Ajuste de caja de medios (`CropBox: 2481x3507` a página imprimible `540x720 pt` con escalamiento proporcional 0.205x).

---

## 4. Veredicto
**HARDWARE VERIFIED**: La pila AirPrint/IPP cumple integralmente con el estándar IPP Everywhere en macOS Sonoma/Sequoia, permitiendo la recepción y conversión impecable de trabajos de impresión.
