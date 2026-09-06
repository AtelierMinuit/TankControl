# Fuentes externas contrastadas

Fecha de consulta: 2026-09-04.

| fuente | versión/fecha observada | hallazgo aplicable | confianza |
|---|---|---|---|
| [CUPS backend(7)](https://www.cups.org/doc/man-backend.html) | documentación CUPS, rastreo 2022 | define discovery, URI, ABI, estados y códigos `CUPS_BACKEND_*`; `RETRY_CURRENT` no equivale a éxito | alta |
| [CUPS Filter and Backend Programming](https://www.cups.org/doc/api-filter.html) | documentación CUPS, rastreo 2022 | exige tratamiento de cancelación, temporales, side-channel y señales | alta |
| [PWG IPP Everywhere](https://www.pwg.org/ipp/everywhere.html) | v1.1; página actualizada recientemente | IPP/2.0, DNS-SD, PWG Raster/JPEG son requisitos del perfil; anunciar Bonjour no implementa el perfil | alta |
| [PWG IPP Guide](https://www.pwg.org/ipp/ippguide.html) | guía pública | lista atributos de impresora, formatos y resoluciones que deben consultarse | alta |
| [IPP Everywhere v1.1 PDF](https://ftp.pwg.org/pub/pwg/candidates/cs-ippeve11-20200515-5100.14.pdf) | 2020-05-15 | el cliente debe consultar atributos de medios antes de enviar PWG Raster | alta |
| [Apple AirPrint](https://developer.apple.com/airprint/) | documentación Apple | AirPrint es una capacidad completa de impresión, no sólo registro DNS-SD | alta |
| [Apple AirPrint Device Management](https://developer.apple.com/documentation/devicemanagement/airprint) | documentación Apple | las configuraciones AirPrint requieren IP/host y `ResourcePath`; no valida un servidor inexistente | alta |
| [CUPS IPP specification index](https://openprinting.github.io/cups/libcups/spec-ipp.html) | consulta 2026-09-04 | referencia vigente de IPP y enlaces a PWG 5100.14 (IPP Everywhere) y PWG 5102.4 (PWG Raster) | alta |
| [CUPS ipptransform](https://openprinting.github.io/cups/libcups/ipptransform.html) | consulta 2026-09-04 | enumera formatos driverless como PWG Raster, JPEG, PDF y URF; no demuestra que este equipo los acepte | alta |
| [CUPS IPP implementation](https://openprinting.github.io/cups/doc/spec-ipp.html) | consulta 2026-09-04 | documenta `Print-Job`, `Get-Printer-Attributes`, `Cancel-Job`, estados y atributos de impresora; un bridge AirPrint debe implementar una superficie IPP real | alta |
| [CUPS ippeveprinter](https://openprinting.github.io/cups/doc/man-ippeveprinter.html) | consulta 2026-09-04 | servidor de referencia conforme a IPP Everywhere; útil como criterio de integración, no presente en el paquete actual | alta |
| [PWG Published Standards](https://www.pwg.org/standards.html) | consulta 2026-09-04 | PWG 5102.4 define el formato PWG Raster y sus espacios de color/profundidades; no valida el codec PCL3GUI propietario | alta |
| [OpenPrinting HPLIP Printer Application](https://github.com/OpenPrinting/hplip-printer-app) | repositorio consultado 2026-09-04 | usa recursos HPLIP/PPD y una capa IPP/PAPPL; describe que la compatibilidad del modelo depende de los PPD y que USB puede usar IEEE-1284.4, pero no prueba Smart Tank 500 en este proyecto | alta |
| [HP Smart Tank 500 series specifications](https://support.hp.com/us-en/product/product-specs/hp-smart-tank-500-all-in-one-series/23394952) | ficha oficial consultada 2026-09-04 | indica `Wireless capability: No` y `Mobile printing capability: USB Only`; la misma ficha contiene una nota genérica sobre AirPrint que requiere conexión de red, por lo que no se afirma incompatibilidad absoluta sin evidencia específica de firmware | alta |

## Aplicación al proyecto

- La auditoría CUPS respalda revisar `DEVICE_URI`, discovery, códigos de salida, cancelación y side-channel del backend.
- La especificación PWG confirma que el bridge no debe anunciar `_ipp._tcp` sin implementar IPP y atributos reales; por eso el anuncio fue retirado.
- Las fuentes no demuestran capacidades específicas de Smart Tank 500, Mode10, P15_CISS, densidad o separación de tinta. Esas afirmaciones siguen requiriendo fuente HP/HPLIP específica o medición física.
- No se usaron foros como especificación.
- La fuente de OpenPrinting distingue explícitamente una Printer Application IPP de un backend/PPD clásico; sirve como contraste arquitectónico, no como prueba de que nuestro bridge eSCL sea AirPrint.
- La documentación actual de Apple describe AirPrint como un servicio de impresión completo y la documentación de OpenPrinting vincula IPP Everywhere con atributos y formatos concretos. Esto refuerza la clasificación `AIRPRINT: NO IMPLEMENTADO`, no la eleva a soporte parcial.
