# Changelog

## 2026-09-04 — auditoría nocturna adicional

- El CLI de escaneo exige una ruta de salida explícita y abre entradas/salidas con `O_NOFOLLOW` y permisos restrictivos.
- `hp-smart-tank-tool` acepta `--help` y `-h` sin inicializar libusb.
- `package_dist.sh` y `build_app.sh` aceptan directorios de build auditados para mantener app, helpers y payload alineados.
- Retirado el fallback destructivo de `prime-tubes` ante respuestas HTTP insuficientes.
- Etiquetadas como sintéticas las salidas mock de cebado y salud de cabezales.

## 0.1.0-alpha — 2026-09-04

- Primera pasada de auditoría maestra reproducible.
- Confirmada compilación actual del backend; no reproducido el error histórico de llaves.
- Construcciones ARM64 limpias separadas en `research/builds/audit-clean/`.
- El bridge eSCL quedó limitado a localhost y dejó de anunciar AirPrint no implementado.
- Locks USB nuevos con permisos de creación 0600.
- Añadida protección explícita frente a fila nula en InkSaver.
- Documentadas dependencias, limitaciones y funciones experimentales.
- Añadido `uninstall --dry-run` sin mutaciones.
- Añadidas confirmaciones UI para purga profunda, alineación, RAW y cebado CISS.
- Eliminado el serial del URI generado por `postinstall`.
## 2026-09-04 — auditoría nocturna

- El parser de estado EWS reconoce etiquetas XML con prefijos de namespace.
- El bridge eSCL protege creación/lectura/eliminación de jobs bajo solicitudes concurrentes.
- El CLI bloquea operaciones físicas peligrosas sin `--confirm-hardware` fuera de `--mock`.
- Añadida matriz profesional de pruebas con separación explícita entre offline, integración y hardware.
- Endurecida la contabilidad CUPS contra symlinks y campos CSV/JSON con saltos de línea o comillas.
- Se documentó que las interfaces EWS duplicadas pueden devolver respuestas desfasadas; consumibles permanecen experimentales.
- Se corrigieron afirmaciones documentales sobre número de serie, mantenimiento, dependencias y warnings.
- El paquete distribuye `libusb` vendorizada con `@rpath`; helpers SwiftUI recompensados y firma ad-hoc revalidada después de modificar dependencias.
- Eliminados claims PPD/log de ahorro físico y banner continuo no demostrado.
- `hp_scan` rechaza respuestas HTTP sin longitud válida o incompletas y ofrece `--help`/`--version` sin abrir USB.
- El paquete se verifica expandido sin AppleDouble materializado, y el uninstall cubre todos los archivos propios y preserva enlaces CUPS ajenos.
- Suite de regresión histórica: 111/111 PASS; incluye 2.000 casos property-based Mode10 con seed reproducible; `clang --analyze` sin diagnósticos.
- Un paquete histórico `20260904-034311` incorporó el aislamiento privado del estado del daemon; el artefacto vigente y su hash se mantienen en `docs/PACKAGE-MANIFEST.md`.
## 0.1.0-alpha — Auditoría nocturna 2026-09-04

- Endurecidos los locks USB de backend, scanner y CLI con `O_NOFOLLOW` y permisos `0600`.
- Añadidas regresiones estáticas para impedir symlink attacks en locks y bind LAN accidental del bridge eSCL.
- Suite auditada actualizada a 115/115 PASS; continúan separadas las pruebas offline de las pruebas físicas.
- Añadida regresión automatizada para conservar el aislamiento de temporales eSCL.
- Añadido `tools/audit_package.sh` para auditar paquetes sin instalación.
- Endurecido el wrapper interactivo con `read -r`; `shellcheck` y `bash -n` quedan limpios en ese script.
