# Plan de mejora HP Smart Tank 500 para macOS Apple Silicon

Fecha: 2026-09-04  
Base: `docs/MASTER-AUDIT-2026.md` y snapshot `research/audits/pre-hardening-20260904-014231/`.

## Objetivo

Convertir el prototipo actual en un controlador reproducible, seguro y técnicamente defendible, sin confundir simulación, pruebas offline e integración física.

## Prioridad 0 — Seguridad y control de alcance

1. Retirar o proteger `inject-raw`, `deep-clean`, `prime-tubes`, waste-ink y alineación detrás de confirmación explícita, modo diagnóstico y registro de autorización.
2. Eliminar toda exposición LAN no necesaria; mantener eSCL en localhost hasta disponer de implementación completa y pruebas de aislamiento.
3. Auditar `postinstall`, `uninstall` y symlinks CUPS para que sólo actúen sobre archivos propiedad del paquete y dispongan de dry-run.
4. Sustituir rutas de desarrollo, seriales y credenciales potenciales por configuración instalada o detección segura.
5. Redactar logs: nunca guardar documentos completos, imágenes escaneadas ni datos identificables innecesarios.

**Criterio de salida:** revisión estática sin comandos peligrosos accesibles por defecto; instalación y desinstalación reversibles en root temporal.

## Prioridad 1 — Build reproducible

1. Crear un único script de build sin `rm -rf` sobre artefactos de referencia.
2. Separar explícitamente `build/`, `audit-clean/`, `package-root/` y `release/`.
3. Registrar versión de Xcode, SDK, clang, CUPS, libusb y Python.
4. Decidir entre libusb vendorizada firmada o dependencia documentada; no mantener rutas Homebrew en runtime de distribución.
5. Añadir verificación automática: `file`, `otool -L`, `codesign`, SHA-256, arquitectura y ausencia de rutas de desarrollo.

**Criterio de salida:** dos builds desde checkout limpio producen artefactos equivalentes o diferencias explicadas y manifestadas.

## Prioridad 2 — Corrección del filtro y backend

1. Resolver los warnings de conversiones con tipos `size_t`/`uint32_t` y validaciones explícitas.
2. Corregir límites antes de multiplicar `width × channels`, `width × 5` y tamaños recibidos de CUPS.
3. Tratar short read, EOF, short write, `SIGPIPE`, cancelación y cleanup como estados explícitos.
4. Añadir tests multi-página, raster corrupto, dimensiones máximas y memoria insuficiente.
5. Auditar la recuperación de USB: timeout, `LIBUSB_ERROR_PIPE`, unplug/reconnect y `CUPS_BACKEND_RETRY_CURRENT`.
6. Sustituir el lock global por locks por subsistema sólo después de probar exclusión segura por interfaz.

**Criterio de salida:** cero warnings críticos, sanitizer sin errores y matriz de errores CUPS reproducible mediante gemelo digital.

## Prioridad 3 — Codec y calidad raster

1. Consolidar `encode → decode → compare` con miles de seeds persistentes.
2. Añadir property-based testing para Mode10 y parser de streams truncados/malformados.
3. Medir InkSaver offline por corpus: píxeles modificados, histogramas, luminancia, SSIM y tamaño PCL3GUI.
4. Renombrar “ahorro de tinta” como “reducción raster estimada” hasta medir consumo físico.
5. Documentar que RGB, TAC y PureBlack no demuestran separación real de tinta en firmware.

**Criterio de salida:** resultados reproducibles, sin claims físicos no sustentados y sin regresión visual aceptable en el corpus.

## Prioridad 4 — Scanner y eSCL

1. Implementar y probar explícitamente `ScannerCapabilities`, `ScannerStatus`, creación de jobs, `NextDocument`, `DELETE`, preview y crop.
2. Validar Content-Length, chunked encoding, límites de body y XML malformado sin excepciones ni asignaciones ilimitadas.
3. Probar 75/150/300/600/1200 DPI sólo como capacidades reales cuando exista respuesta del equipo.
4. Ejecutar pruebas con cliente Image Capture; un mock HTTP no cuenta como integración macOS.
5. Separar el bridge local del eventual servicio LAN y documentar el modelo de amenaza.

**Criterio de salida:** captura real, preview y crop verificados o declarados `NOT TESTED`.

## Prioridad 5 — AirPrint

No anunciar AirPrint hasta implementar un servidor IPP real con `Get-Printer-Attributes`, `Print-Job`, formatos, estados, spool y errores. Comparar contra CUPS/IPPEverywhere/PWG Raster. Si no se implementa, mantenerlo documentado como `NO IMPLEMENTADO`.

## Prioridad 6 — App SwiftUI y monitor

1. Reemplazar `NSUserNotification` por `UserNotifications`.
2. Centralizar ejecución de procesos con allowlist de comandos, argumentos tipados, timeout y captura segura de errores.
3. Añadir confirmaciones separadas para mantenimiento intensivo y nunca ejecutar acciones peligrosas desde un clic ambiguo.
4. Verificar accesibilidad, estados bloqueados, cancelación y ausencia de UI que presente mocks como hardware.
5. Si existe menubar monitor, probar polling adaptativo, reconexión, debounce y consumo idle.

## Prioridad 7 — Color y funciones pro

1. Marcar los ICC actuales como experimentales.
2. Definir procedimiento de calibración con carta, instrumento, condiciones, papel, tinta y archivo de mediciones.
3. Validar físicamente por combinación de medio, calidad, borderless y resolución.
4. Retirar del PPD opciones cuyo efecto físico no pueda demostrarse; conservarlas sólo en modo experimental claramente rotulado.

## Prioridad 8 — Paquete y ciclo de release

1. Auditar payload, BOM, scripts, ownership y permisos sin instalar en `/`.
2. Crear `uninstall --dry-run` y manifiesto de propiedad por archivo.
3. Probar instalación en root temporal y luego en una máquina de prueba.
4. Añadir matriz PASS/FAIL/NOT TESTED/BLOCKED.
5. Usar versionado `0.x-alpha/beta` hasta cerrar hardware tests.

## Secuencia recomendada de ejecución

| sprint | alcance | salida |
|---|---|---|
| 1 | seguridad, rutas, mantenimiento | superficie segura y reversible |
| 2 | build y dependencias | build limpio verificable |
| 3 | filtro/backend | sanitizer y errores CUPS controlados |
| 4 | Mode10/InkSaver | corpus cuantificado |
| 5 | scanner/eSCL | integración local y hardware delimitada |
| 6 | app/packaging | instalación y uninstall auditables |
| 7 | hardware | matriz física mínima |
| 8 | release review | decisión alpha/beta/RC basada en evidencia |

## Gate de decisión

- **Alpha:** builds limpios y pruebas offline; hardware aún parcial.
- **Beta:** scanner/impresión básicos y recuperación USB probados físicamente; funciones avanzadas experimentales.
- **RC1:** sólo cuando build, sanitizer, CUPS, scanner, paquete y hardware mínimo cumplan la matriz final sin `NOT TESTED` en funciones anunciadas como estables.

## Próxima acción concreta

Sprint 1 ejecutado parcialmente: `uninstall --dry-run`, confirmaciones SwiftUI para operaciones intensivas/RAW, URI de instalación sin serial, bridge sólo localhost y locks USB 0600. Pendiente: manifiesto exhaustivo de archivos propiedad del proyecto y reemplazo de `NSUserNotification`.

La siguiente acción es completar el manifiesto y luego iniciar el sprint 2 de build hermético.
