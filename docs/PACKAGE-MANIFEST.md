# Manifiesto de paquete

Paquete auditado vigente (construcción 2026-09-04 08:41):

`research/builds/HP_Smart_Tank_500_Native_Apple_Silicon-20260904-084131.pkg`

SHA-256: `452542bc2f986a2f38394e7d3180ee095af16f714e720b46e84e822cb7ee001a`

El auditor `tools/audit_package.sh` confirmó que el paquete no materializa ningún archivo AppleDouble `._*` en disco al ser expandido (`materialized_dots=0`), contiene firma ad-hoc válida de la app (`app_signature=PASS`), cero referencias a rutas de desarrollo (`content_exclusions=PASS`), y 113 archivos en payload.

Contenido: app, filtro y backend CUPS, PPD, cuatro ICC, LaunchAgent eSCL, CLI y scripts bajo las rutas estándar de macOS y `/usr/local`; incluye el módulo Python `hp_smart_tank.py` requerido por el bridge.

La lista de propiedad de `uninstall.sh` incluye ahora la biblioteca `libusb` vendorizada, todos los scripts Python y el propio desinstalador distribuido en `/usr/local/share/hp-smart-tank/uninstall.sh`; conserva software HP ajeno, ofrece `--dry-run` y exige `--confirm` para cambios. El `postinstall` rechaza destinos ausentes o symlinks antes de aplicar permisos. La secuencia dry-run→confirmación queda como procedimiento operativo y no se presenta como estado persistente verificable.

`pkgutil --expand-full` terminó correctamente. El escaneo del payload no encontró rutas de desarrollo, seriales, `scratch/`, `Downloads/`, `/opt/homebrew`, `_ipp._tcp` ni `0.0.0.0`.

La inspección directa del XAR no basta para esta condición: la fuente autoritativa es también `pkgutil --payload-files`, que sí expuso las entradas AppleDouble del artefacto invalidado.

La app incluida tiene firma ad-hoc verificable (`codesign --verify --deep --strict`). El contenedor `.pkg` sigue sin firma según `pkgutil --check-signature`; no es release final hasta firmar, notarizar y probar instalación en root temporal y máquina de prueba.

La versión del paquete y de la aplicación es `0.1.0-alpha`. La expansión final confirmó payload/BOM/scripts válidos y `PackageInfo` declara 105 archivos de payload; los ejecutables son arm64 y no contienen rutas del árbol de desarrollo ni rutas Homebrew codificadas. El paquete se generó con `HP_AUDIT_BUILD_DIR` apuntando a la build combinada `research/builds/audit-clean/20260904-063900/`, que contiene los cuatro binarios C de `063617` y la app SwiftUI de `063730`; los scripts Python del payload y los wrappers pasan sus comprobaciones de sintaxis. El bridge eSCL usa directorios temporales privados por job.

Verificación de runtime offline desde el payload expandido: los cuatro módulos Python compilan con `py_compile`/`compileall`, `hp_escl_bridge` expone `ESCLBridge`, `hp_smart_tank` carga su binding libusb, y `smart_tank_daemon.sh` resuelve sus archivos vecinos correctamente. No se instaló el paquete ni se ejecutaron operaciones de hardware.
