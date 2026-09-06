# Cobertura de fases de auditoría — 2026

Esta matriz conserva el alcance original y separa evidencia offline, integración y hardware. `PARCIAL` no significa aprobado para release.

| Fase | Alcance | Evidencia principal | Estado |
|---:|---|---|---|
| 0 | Snapshot | `research/audits/pre-hardening-20260904-014231/` | VERIFICADO |
| 1 | Backend CUPS | build estricta y `clang --analyze` | PARCIAL |
| 2 | Build reproducible | `docs/BUILD-REPRODUCIBILITY-AUDIT.md` | PARCIAL |
| 3 | Dependencias | `docs/DEPENDENCY-AUDIT.md` | VERIFICADO |
| 4 | Filtro raster | `tools/rastertopcl3gui.c`, fuzz y corpus offline | PARCIAL |
| 5 | Control de tinta | `docs/INK-CONTROL-AUDIT.md`; sin medición física | EXPERIMENTAL |
| 6 | InkSaver | corpus offline; sin medición de tinta | EXPERIMENTAL |
| 7 | Codec PCL3GUI | encode/decode Mode10 y corpus | VERIFICADO |
| 8 | Fuzzing | Mode10 100.000 rondas ASan/UBSan; análisis C sin diagnósticos; parsers nativos limitados | PARCIAL |
| 9 | Backend profesional | discovery físico; fallos USB sin prueba completa | PARCIAL |
| 10 | Arquitectura USB | inventario de 4 interfaces; EWS duplicado no concluyente | PARCIAL |
| 11 | Escáner/eSCL | bridge mock y parser; captura física no demostrada | PARCIAL |
| 12 | AirPrint | no existe servidor IPP; anuncio falso retirado | NO IMPLEMENTADO |
| 13 | ICC/ColorSync | ICC válido para `sips`; no calibración medida | EXPERIMENTAL |
| 14 | Funciones profesionales | matriz en `docs/PRO-FEATURE-VALIDATION.md` | EXPERIMENTAL |
| 15 | Servicio | comandos bloqueados sin confirmación; no ejecutados físicamente | PARCIAL |
| 16 | Drivers HP locales | inventario y comparación parcial | PARCIAL |
| 17 | Investigación externa | `docs/EXTERNAL-SOURCES-2026.md` | VERIFICADO |
| 18 | Ingeniería inversa | análisis documental/binario parcial; sin prueba de equivalencia | PARCIAL |
| 19 | SwiftUI | build ARM64, confirmaciones y helpers auditados | PARCIAL |
| 20 | Menubar | polling en app; integración persistente no demostrada | EXPERIMENTAL |
| 21 | launchd/hotplug | plist válido; `launchctl` no muestra servicio cargado | EXPERIMENTAL |
| 22 | PKG | expansión, payload y rutas auditados | PARCIAL |
| 23 | Root temporal | expansión sin instalación en `/` | PARCIAL |
| 24 | Uninstall | `--dry-run` verificado; instalación real ausente | PARCIAL |
| 25 | Test matrix | 133/133 offline; hardware incompleto | PARCIAL |
| 26 | Performance | mediciones offline puntuales | EXPERIMENTAL |
| 27 | Concurrencia | TSan arm64 enlazado; discovery backend sin diagnóstico; cargas simultáneas completas pendientes | PARCIAL |
| 28 | Seguridad | hardening y análisis estático; revisión dinámica parcial | PARCIAL |
| 29 | Privacidad | sin telemetría observada; instalación real no probada | PARCIAL |
| 30 | Refactor | duplicación aún existente; no refactorizar antes de cobertura | EXPERIMENTAL |
| 31 | Versionado | `0.1.0-alpha`, changelog y limitaciones | VERIFICADO |
| 32 | Release candidate | gates físicos y de firma/notarización pendientes | PARCIAL |

## Criterio de lectura

La suite verde demuestra comportamiento cubierto por tests, no compatibilidad física completa. Mientras existan fases con pruebas físicas ausentes, AirPrint no implementado, ICC experimental o paquete sin firma/notarización, el proyecto no debe declararse `RC1`.
