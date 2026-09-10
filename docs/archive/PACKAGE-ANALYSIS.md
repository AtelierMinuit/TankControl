# Análisis histórico de Paquetes PKG/DMG

## Resumen de Ejecución
Este documento conserva el resultado de una búsqueda histórica anterior. No debe usarse como estado actual del proyecto.

## Resultados de Búsqueda
En aquella ejecución no se encontraron archivos con las extensiones `.pkg` o `.dmg`.

Los subdirectorios inspeccionados incluyen:
- `FUENTE_TECNICA – Macbook M4 – HP y paquetes – Codex`
- `HP - Instaladores Windows y soporte remoto`
- `HP Smart Tank 500 - Drivers macOS y solucion`
- `HP-SmartTank-Audit-20260806-112031`

## Conclusión
Ese resultado sólo describe el estado de esa fecha. En la auditoría actual sí se generó y auditó un paquete: `research/builds/HP_Smart_Tank_500_Native_Apple_Silicon-20260904-051128.pkg`. El análisis vigente está en `docs/PACKAGE-MANIFEST.md` y `docs/MASTER-AUDIT-2026.md`; el verificador `tools/audit_package.sh` confirmó payload, firma de la app y ausencia de rutas de desarrollo, sin instalarlo.

Si los archivos se encuentran en otra ubicación o bajo un formato distinto (como `.zip`), por favor proporcionar la ruta correcta o extraerlos previamente.
