# Auditoría de AirPrint e IPP Everywhere — HP Smart Tank 500 macOS

**Fecha:** 2026-09-04  
**Entorno:** macOS 26.6.2 (Darwin 25.6.0 ARM64 Apple Silicon), CUPS 2.3.4, `/usr/bin/ippeveprinter`, `/usr/bin/ipptool`  
**Objetivo:** Evaluar la arquitectura, conformidad de protocolo RFC 8011 / PWG 5100, interoperabilidad y límites de la emulación AirPrint/IPP Everywhere local para la HP Smart Tank 500.

---

## 1. Clasificación Epistémica

* **[HECHO VERIFICADO]**: macOS provee el binario `/usr/bin/ippeveprinter` (servidor IPP de emulación de Apple) y el conversor raster `/usr/libexec/cups/command/ippeveps`.
* **[HECHO VERIFICADO]**: En `ippeveprinter`, el parámetro `-a <archivo.conf>` y la opción de línea de comandos `-f <formatos>` son mutuamente excluyentes; intentar combinarlos provoca terminación con código 1 y despliegue del mensaje de uso.
* **[HECHO VERIFICADO]**: `ippeveprinter` inicializa internamente los atributos `document-format-default` y `document-format-supported` (`application/octet-stream`, `image/pwg-raster`, `image/urf`). Si se redeclaran con `ATTR` en el archivo `.conf`, `ippeveprinter` duplica la clave en el grupo de atributos, violando la sección 5.1.10 de RFC 8011 (detectado por `ipptool`).
* **[IMPLEMENTADO]**: Demonio local `tools/hp_airprint_daemon.sh`, configuración de atributos estáticos `tools/hp-smart-tank-500-airprint.conf`, y filtro de entrega `tools/hp_ipp_submit.sh`.
* **[VERIFICADO OFFLINE]**: Ejecución del conjunto de pruebas oficial de Apple/CUPS (`/usr/share/cups/ipptool/get-printer-attributes.test`, `/usr/share/cups/ipptool/validate-job.test`, `/usr/share/cups/ipptool/print-job.test`) contra el demonio en puerto efímero.
* **[VERIFICADO EN MOCK]**: Recepción de trabajo PWG Raster (`onepage-letter-300-black-1.pwg`, 300 DPI) y conversión mediante `ippeveps` a PostScript nivel 2 (`job-*.ps`, 561.933 bytes) formateado según el PPD de la HP Smart Tank 500.
* **[HARDWARE REQUIRED]**: Descubrimiento mDNS/DNS-SD por Bonjour en clientes iOS/iPadOS reales en la red de área local y expulsión física de tinta mediante backend USB.

---

## 2. Arquitectura de la Solución AirPrint

La HP Smart Tank 500 es una impresora multifunción estrictamente USB y sin placa de red nativa (no posee Ethernet ni Wi-Fi). Para permitir que dispositivos en la red local (o en la misma máquina Mac) impriman vía AirPrint / IPP Everywhere sin drivers propietarios, el sistema implementa un puente de reenvío:

```
+-------------------------------------------------------------+
| Dispositivo Cliente (iOS / iPadOS / macOS AirPrint)        |
+-------------------------------------------------------------+
                              |
                     IPP / HTTP (puerto 8631)
                     (image/urf o image/pwg-raster)
                              v
+-------------------------------------------------------------+
| /usr/bin/ippeveprinter (Demonio IPP Everywhere en macOS)    |
| Configuración: tools/hp-smart-tank-500-airprint.conf        |
+-------------------------------------------------------------+
                              |
               Invoca comando: tools/hp_ipp_submit.sh
                              |
                              v
+-------------------------------------------------------------+
| /usr/libexec/cups/command/ippeveps                          |
| Conversor de PWG/URF a PostScript con PPD de destino        |
+-------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------+
| Cola local CUPS (lp -d HP_Smart_Tank_500)                   |
| -> cups_backend_smarttank -> Dispositivo USB                |
+-------------------------------------------------------------+
```

---

## 3. Resultados de Pruebas con `/usr/bin/ipptool`

Se ejecutaron pruebas automatizadas integradas en `tests/test_airprint_ipptool_suite.py` utilizando los archivos de prueba estándar de CUPS:

### 3.1 `get-printer-attributes.test`
* **Comando:** `/usr/bin/ipptool -t ipp://localhost:<port>/ipp/print /usr/share/cups/ipptool/get-printer-attributes.test`
* **Resultado:** `[PASS]` (Código de salida: 0).
* **Atributos validados:**
  * `color-supported = true`
  * `copies-supported = 1-1`
  * `media-supported`: Carta (Letter), A4, Legal, 4x6, 5x7.
  * `printer-resolution-supported = 600dpi`
  * `sides-supported = one-sided`
  * `printer-supply`: Reportado con `level=-2` (nivel desconocido, conforme a RFC 3805 / PWG para evitar falsas lecturas sintéticas).

### 3.2 `validate-job.test`
* **Comando:** `/usr/bin/ipptool -t -d filetype=<formato> ipp://localhost:<port>/ipp/print /usr/share/cups/ipptool/validate-job.test`
* **Formatos verificados:**
  * `image/pwg-raster`: `successful-ok` `[PASS]`
  * `image/urf`: `successful-ok` `[PASS]`
  * `application/octet-stream`: `successful-ok` `[PASS]`

### 3.3 `print-job.test`
* **Comando:** `/usr/bin/ipptool -t -d filetype=image/pwg-raster -d filename=onepage-letter-300-black-1.pwg ipp://localhost:<port>/ipp/print /usr/share/cups/ipptool/print-job.test`
* **Resultado:** `[PASS]` (Código de salida: 0).
* **Salida generada:** Archivo PostScript en `HP_IPP_TEST_OUTPUT_DIR` con cabecera `%!PS-Adobe-3.0`, `LanguageLevel: 2`, tamaño 561.933 bytes, listo para ser consumido por el spooler CUPS.

---

## 4. Análisis de Seguridad y Robustez

1. **Aislamiento de puertos:** El demonio permite configurar puertos arbitrarios no privilegiados (`1024` a `65535`). En pruebas automatizadas y entornos de laboratorio offline se ejecuta con `--no-advertise` (`-r off`) para no contaminar la red local vía Bonjour/mDNS.
2. **Sanitización de argumentos en `hp_ipp_submit.sh`:**
   * Restricción estricta de nombres de cola (`^[A-Za-z0-9_.-]{1,127}$`).
   * Validación de que el archivo recibido sea regular y no un enlace simbólico (`! -L`).
   * Límite superior estricto de tamaño de archivo (1 GiB) para prevenir ataques de agotamiento de disco/memoria.
   * Supresión y reemplazo de saltos de línea y tabuladores en `IPP_JOB_NAME` para prevenir inyección de comandos en `lp`.
3. **Spool Seguro:** Se utiliza un directorio dedicado con permisos estrictos `0700` (`chmod 700`) perteneciente exclusivamente al UID ejecutor.
