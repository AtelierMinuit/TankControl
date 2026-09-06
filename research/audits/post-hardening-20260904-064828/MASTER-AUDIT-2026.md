# Auditoría maestra 2026

## ESTADO EJECUTIVO

Actualización 2026-09-04 06:17: la ejecución histórica terminó en **133/133 PASS**; quedó superada por la suite vigente de 134/134.

Actualización 2026-09-04 06:21: la suite vigente terminó en **134/134 PASS**. La revalidación física segura confirmó `info` y discovery `smarttank://`, pero `scan-caps` y `scan-status` devolvieron código 1 por timeout; no se creó trabajo ni se ejecutó mantenimiento.

Registro histórico 06:22: las notificaciones recibieron debounce por clave de estado/consumible. Ese artefacto intermedio (`HP_Smart_Tank_500_Native_Apple_Silicon-20260904-062257.pkg`, SHA-256 `05ed5e0dbdbc71aa84ec17afe52447e73965da10ed1dbe5dd37a925bd76400ab`) fue superado por la regeneración posterior del paquete indicada arriba.

Corrección PPD 06:30: se restauraron las 178 `UIConstraints` presentes en el PPD HPLIP Smart Tank 500 y se reemplazó el test heredado que exigía su ausencia. `cupstestppd -W all` y la suite **134/134 PASS**; paquete actualizado `HP_Smart_Tank_500_Native_Apple_Silicon-20260904-063030.pkg`, SHA-256 `d3cdd5c6f5ad55307b56bd3cc2bcd57d27d7c428957a1b59e8511b0687062aa1`.

Desinstalador del payload verificado 06:27: tras expandir el paquete vigente, su `uninstall.sh --dry-run` terminó con código 0 y confirmó que no modifica archivos ni colas. La prueba se limita a dry-run; no se ejecutó eliminación real.

Hardening SwiftUI 06:17: `toolBinaryPath()` ya no devuelve una ruta global como fallback; si no encuentra un helper regular, ejecutable y no symlink dentro del bundle, la app devuelve un error explícito y no inicia ningún proceso.

Hardening de instalador manual 06:20: `install_native.sh` exige `HP_AUDIT_BUILD_DIR`, valida filtro y backend de la misma build, evita sobrescribir destinos existentes e integra la cola mediante `smarttank://`. La suite vigente terminó en **134/134 PASS**.

La cobertura fase por fase está consolidada en `docs/PHASE-COVERAGE-2026.md`; esa matriz conserva explícitamente las fases no demostradas y no convierte `NOT TESTED` en `PASS`.

Verificación adicional 06:34: la build C limpia `research/builds/audit-clean/20260904-063443` compiló nuevamente `rastertopcl3gui`, `smarttank`, `hp_scan` y `hp-smart-tank-tool` como arm64. La suite ejecutada con `HP_AUDIT_BUILD_DIR` terminó en **134/134 PASS**; `clang --analyze` ejecutado por separado sobre los cuatro fuentes terminó sin diagnósticos. Esta build es evidencia de compilación, no reemplaza todavía el paquete auditado de 06:30.

Corrección adicional 06:36: `waste-ink` consultaba `ProductStatusDyn.xml` usando la interfaz LEDM del escáner (`ff/cc/00`) en vez del canal EWS de gestión (`ff/04/01`). Se corrigió la selección de interfaz, se añadió regresión específica y la build `research/builds/audit-clean/20260904-063617` compiló correctamente; la suite vigente terminó en **135/135 PASS**. No se ejecutó la consulta física de tinta residual.

Corrección adicional 06:37: la app SwiftUI aún contenía un fallback a `/usr/local/bin/hp-smart-tank-tool`, contradiciendo el aislamiento del bundle. Se eliminó, se añadió una regresión de ausencia de ruta global y la app recompiló arm64 con firma ad-hoc válida en `research/builds/audit-clean/20260904-063730/`. La suite vigente terminó en **135/135 PASS**.

Regeneración de paquete 06:38: se construyó el paquete desde la build combinada `research/builds/audit-clean/20260904-063900/`, que reúne los binarios C corregidos y la app SwiftUI corregida. El nuevo paquete `HP_Smart_Tank_500_Native_Apple_Silicon-20260904-063837.pkg` tiene SHA-256 `1684f96e99ee176cad92323e3bee31eaf7b090f7f0b200e67d4691bc8621f293`; la auditoría expandida pasa payload, firma ad-hoc y exclusiones de contenido. No se instaló.

Corrección de auditoría de paquete 06:40: la comprobación directa de `pkgutil --payload-files` reveló entradas AppleDouble `._*` que el auditor anterior no inspeccionaba. El paquete de 06:38 queda invalidado para distribución. `package_dist.sh` y `audit_package.sh` fueron endurecidos para limpiar/verificar atributos y rechazar esos BOM; la regeneración se detuvo porque `com.apple.provenance` reaparece en el staging del host. No se instaló ningún paquete.

Corrección de desinstalador: se detectó que una cola preexistente comparte el nombre `HP_Smart_Tank_500` pero usa URI `usb://`. El desinstalador ahora sólo elimina una cola cuya URI sea `smarttank://` y sólo elimina la app si existe el recibo del paquete propio. `uninstall.sh --dry-run`, ShellCheck y la suite terminaron correctamente; la cola y app preexistentes fueron preservadas.

Sanitizer adicional: `hp-smart-tank-tool.c` compiló con ASan/UBSan; `waste-ink --mock` terminó sin diagnósticos y `deep-clean` sin confirmación fue bloqueado con código 2 antes de abrir hardware. No se ejecutó ningún comando físico.

Estado: **PARCIAL / NO RELEASE CANDIDATE**. El backend actual compila; el error histórico de sintaxis no se reproduce. Hay builds ARM64 y pruebas offline útiles, pero no existe evidencia suficiente para afirmar controlador profesional: faltan pruebas físicas de impresión/escaneo, las funciones de tinta son heurísticas y el bridge eSCL es incompleto. El paquete distribuye `libusb` vendorizada mediante `@rpath`; el build de desarrollo aún usa Homebrew. El anuncio AirPrint incorrecto fue retirado.

## BASELINE REPRODUCIDA

Estado externo observado 2026-09-04: existe una cola CUPS `HP_Smart_Tank_500` con URI USB que incluye serial, y existe `/Applications/HP Smart Tank Utility.app`; no corresponden a una instalación del paquete nocturno de esta pasada porque sus componentes de proyecto no están presentes en `/Library` ni `/usr/local`. La app instalada tiene Mach-O arm64, pero `codesign --verify --deep --strict` falla porque la firma exige recursos ausentes. No se modificaron ni cola ni aplicación.

La cola existente no utiliza el backend auditado: `lpstat -v` muestra `usb://...`, mientras el binario auditado descubre `smarttank://...`; además faltan el filtro, backend y PPD del proyecto en las rutas del sistema. Por tanto, su estado inactivo no constituye una prueba de integración CUPS de este proyecto.

Snapshots posteriores de esta pasada: `research/audits/post-hardening-20260904-043945/`, `research/audits/post-hardening-20260904-045704/`, `research/audits/post-hardening-20260904-050015/`, `research/audits/post-hardening-20260904-050143/`, `research/audits/post-hardening-20260904-050731/`, `research/audits/post-hardening-20260904-051029/` y el más reciente posterior a la regeneración del paquete. El último conserva información del host, hashes actuales de fuentes/recursos y builds, el hash del paquete vigente y la build C limpia `20260904-051216`; el snapshot inicial permanece intacto en `research/audits/pre-hardening-20260904-014231/`.

Snapshot en `research/audits/pre-hardening-20260904-014231/`. macOS 26.6.2, Darwin ARM64, Apple Clang 21, CUPS 2.3.4, Homebrew `/opt/homebrew`. No hay Git en la raíz.

## ERRORES ENCONTRADOS

La comparación cruzada corrigió una afirmación anterior: el árbol local HPLIP 3.26.4 sí contiene `hp-smart_tank_500_series.ppd` y una entrada `smart_tank_500_series` para USB `03f0:2b54`/`P15_CISS`. Esto mejora la trazabilidad del modelo, pero no demuestra que nuestro filtro, backend o escáner funcionen físicamente.

La comparación de PPD produjo 508 líneas de diferencia: el proyecto conserva identificación, `pcl3gui2` y color, pero reemplaza `hpcups` por el filtro propio, añade ICC/icono y cambia restricciones de medios. Se clasifica como derivación parcial, no como equivalencia con HPLIP.

La revisión inicial detectó 178 `UIConstraints` en HPLIP y 0 en el PPD propio. Se corrigió restaurando las 178 restricciones y actualizando el test heredado que exigía su ausencia. El conteo actual coincide con HPLIP; las combinaciones siguen sin validación física y las opciones no probadas permanecen experimentales.

La comparación cruzada local exigida no tenía un informe consolidado; se creó `docs/HP-CROSS-MODEL-COMPARISON.md`. La inspección encontró HP Easy Scan instalado sólo como `x86_64`, sin evidencia binaria local de código compartido aplicable a Smart Tank 500.

La búsqueda de PPD instalados en `/Library/Printers/PPDs/Contents/Resources` tampoco encontró coincidencias identificables para Smart Tank, Ink Tank o ENVY 7100; no se usa un PPD ajeno como evidencia de capacidades.

- 21 warnings iniciales del filtro; tras hardening, filtro, `hp_scan`, `hp-smart-tank-tool` y backend compilan con 0 warnings bajo los flags estrictos. SwiftUI compila sin warnings en la última build auditada.
- El filtro rechazaba raster inválido con un mensaje `ERROR` pero código 0; se corrigió la propagación de error. La prueba actual devuelve código 1 para 32 bpp/colorspace 17 no soportado y código 0 para el raster RGB válido.
- `clang --analyze` señaló una ruta de posible fila nula en InkSaver; se añadió guardia defensiva.
- eSCL escuchaba en todas las interfaces y anunciaba `_ipp._tcp` sin servidor IPP.
- El cliente Python USB sufría un `SIGSEGV` en Apple Silicon por una firma ctypes ausente; se reprodujo, se corrigió declarando `argtypes/restype` y ahora termina controladamente con error de reclamación de interfaz.
- La ruta de descubrimiento Python libera ahora siempre el descriptor de configuración USB; una respuesta incompleta termina con error 1 y no se presenta como lectura válida.
- La suite no puede ejecutarse con pytest porque no está instalado.
- El paquete auditado no contiene rutas de desarrollo ni entradas AppleDouble `._*`; sigue sin firma/notarización.

## ERRORES CORREGIDOS

Se corrigió una apertura insegura del lock global USB: backend CUPS, scanner y CLI ahora usan `O_NOFOLLOW` al crear/abrir `/tmp/hp_smart_tank_usb.lock`, reduciendo el riesgo de redirección mediante symlink. La corrección recompiló los cuatro binarios y la suite vigente terminó con 117 tests ejecutados.

Además, `hp_scan` dejó de aceptar una salida implícita en `/tmp`: sin un archivo de salida explícito devuelve código 2. Esto evita truncar accidentalmente un nombre predecible y se verificó en la build `20260904-045141`.

- Guardias USB con modo de creación 0600.
- Bridge limitado a `127.0.0.1`; eliminado anuncio AirPrint no respaldado.
- Guardado de `CHANGELOG.md`, limitaciones, dependencias, build y validación profesional.

## AFIRMACIONES ANTERIORES NO DEMOSTRADAS

“OEM/Enterprise Grade”, “AirPrint completo”, “ICC calibrado”, “ahorro físico 25/50/75%”, “KGray físico”, “backend bidireccional funcional”, “100% verificado” y “opciones desbloqueadas” no quedan demostradas por código, mock o `sips`.

## DEUDA TÉCNICA

Parser HTTP frágil, build Swift/C aún separado y fuzzing nativo de parsers incompleto; `is_scanning` requiere validación bajo concurrencia física. El bridge ahora protege el diccionario/contador de jobs y sus transiciones, con 7/7 pruebas eSCL locales PASS; el harness Mode10 ejecutó 100.000 rondas ASan/UBSan. `tools/build_audit.sh` centraliza la build C y registra artefactos; libFuzzer no pudo enlazarse porque el runtime de Clang no está instalado en este host.

## BUILD

Nota de actualización: cualquier mención histórica a `131/131` o `133/133` en este documento queda superada por la ejecución vigente de **134/134 PASS** registrada en el estado ejecutivo y en la matriz de pruebas.

Validación nativa adicional 2026-09-04 06:16: `clang --analyze` no emitió diagnósticos para `rastertopcl3gui.c`, `cups_backend_smarttank.c`, `hp_scan.c` ni `hp-smart-tank-tool.c`. Builds ASan/UBSan del filtro y backend completaron el smoke offline sin reportes del sanitizer; el filtro rechazó stdin vacío con código 1. `detect_leaks=1` no está soportado por el runtime ASan de este macOS y no se considera prueba de fugas.

`smarttank`, `hp_scan`, `hp-smart-tank-tool`, `rastertopcl3gui` y app SwiftUI compilaron en `research/builds/audit-clean/night-20260904/`. Todos los binarios inspeccionados son arm64; la app SwiftUI incluida fue verificada con firma ad-hoc, mientras que los ejecutables C de desarrollo no se presentan como firmados. Las compilaciones C estrictas auditadas no emitieron warnings.

La suite reproducida con `python3 -m unittest discover -s tests` terminó en **134/134 PASS**. Incluye 2.000 casos property-based Mode10 con seed reproducible `20260904`, el harness mutacional de 100.000 rondas sin diagnóstico ASan/UBSan, pruebas eSCL de solicitud fragmentada y rechazo de `chunked`, y regresiones de seguridad para locks USB, temporales privados, salida explícita del scanner, binding local, confirmación de hardware, propagación de errores LEDM, sanitización de logs, temporales ICC privados, rutas del wrapper empaquetado, generación segura del icono, escaneo temporal privado durante calibración, Content-Length malformado en el gemelo digital y límites del cliente HTTP USB. La build C limpia `research/builds/audit-clean/20260904-061000` compiló los cuatro binarios arm64 sin warnings; la app SwiftUI también compiló arm64 y su firma ad-hoc pasó verificación. La revalidación directa ejecutó Clang Static Analyzer sobre los cuatro fuentes C sin diagnósticos, `plutil -lint` sobre 5 plist sin fallos y `bash -n` sobre 10 scripts sin fallos. Esto incluye mocks, gemelo digital y pruebas offline, pero no convierte las pruebas físicas pendientes en PASS.

El PPD pasa `cupstestppd -W all` con código 0, pero no está libre de advertencias: el validador señala nombres de tamaños no estándar. La ejecución sin `-W all` devuelve código 4 porque el árbol de desarrollo no contiene todavía los recursos absolutos del destino de instalación; esto no debe confundirse con una prueba de instalación. Por tanto, “PPD aceptado en modo de advertencias” no equivale a “PPD sin warnings” ni a validación física.

Se corrigió `PCFileName` a `HPSMT500.PPD`; las advertencias restantes corresponden a nombres de tamaños y a recursos absolutos que sólo pueden resolverse en el sistema instalado.

Reproducción PPD 2026-09-04: `cupstestppd -W all research/builds/hp-smart_tank_500_series_mac.ppd` terminó con código 0. Persisten advertencias por recursos ausentes en el árbol de desarrollo (filtro, icono e ICC) y por nombres de tamaños no estándar; no se ocultaron ni se reclasificaron como errores de sintaxis.

## CUPS

Hardening adicional del backend: una lectura negativa del spool ahora devuelve `CUPS_BACKEND_FAILED`, y una transferencia USB con cero bytes escritos aborta para evitar un bucle infinito. El backend recompila sin warnings y `clang --analyze` no emite diagnósticos; no se ha probado la ruta físicamente durante esta auditoría.

La apertura de archivos de spool con ruta explícita usa `O_NOFOLLOW`; una prueba con symlink devolvió código 1 y no procesó el trabajo.

El discovery del backend se reprodujo el 2026-09-04 con el dispositivo conectado: devolvió una URI `smarttank://` y una entrada HP Smart Tank 500 series. Esto demuestra enumeración CUPS, no impresión física ni aceptación del trabajo por el firmware.

Backend: compila actualmente, con libusb y CUPS en runtime. La cola existente aceptó una página A4 normal como trabajo `HP_Smart_Tank_500-62` y CUPS la marcó completada; no se observó físicamente la hoja, por lo que esto es PASS de spool/integración, no PASS de hardware. No se probó desconexión/reconexión real. El filtro nativo genera PCL3GUI offline y sus claims físicos no están probados.

Las variantes JSON del CLI devuelven código 1 cuando no pueden leer status, consumibles u odómetro, conservando el JSON diagnóstico para consumidores automatizados; esta semántica se verificó con el hardware conectado y respuestas vacías.

## PCL3GUI

El decoder offline pasó 9/9 pruebas y los streams de corpus se decodifican. Mode10 es el camino activo observado; Mode9 no debe documentarse como activo.

El encoder/decoder además pasó 2.000 round-trips property-based con seed fija `20260904`; se tolera únicamente la cuantización protocolaria observada (diferencia máxima de un nivel por canal). Esto fortalece la validación offline, pero no demuestra aceptación del stream por firmware.

El PPD pasa `cupstestppd`, pero con advertencias por recursos aún no instalados y numerosos alias de tamaños; el límite de página custom fue reducido de 8000 a 1008 puntos para no exponer un banner de 2,8 m sin evidencia física.

## INKSAVER

Transformaciones de bytes RGB previas al firmware. Son heurísticas raster, no mediciones de tinta. La salida ahora se etiqueta como “reducción raster estimada (no tinta física)”; los campos contables siguen siendo un modelo teórico.

Benchmark offline del raster negro: `Off`/`Eco25`/`Eco50`/`Eco75` generaron 7.840 bytes; `EdgePreserve`, 1.057.455; `DotGainGrid`, 1.078.205. Este resultado mide tamaño de stream y transformación, no volumen de tinta ni calidad impresa.

## COLOR

El calibrador ICC ya no genera perfiles desde una carta sintética en modo real: sin `--scan` devuelve error. La ruta sintética exige `--mock`, y los perfiles siguen clasificados como experimentales hasta contar con medición física trazable.

ICC abre con `sips`, pero no hay carta medida ni perfil trazable. Clasificación: experimental.

## SCANNER

El código y HPLIP correlacionan LEDM en interfaz 0. Lecturas previas respondieron con HTTP/XML real y mostraron 75–1200 DPI/Idle; en la lectura física posterior, `scan-caps` y `scan-status` terminaron con timeout USB `-7`, mientras `info` enumeró correctamente las interfaces. Una captura física controlada a 75 DPI, región 100×100 en gris, falló por residuos XML/PCL; tras añadir un preflight seguro de `/Scan/Status`, la sesión falla antes del `POST` y no genera imagen. La comparación adicional con `bb_ledm.c` motivó cabeceras de sesión y el terminador HP `0\r\n\r\n` en `hp_scan.c`; recompilar pasó, pero el timeout físico persiste. Estado: PARCIAL/ROTO.

## AIRSCAN

El bridge responde mocks eSCL básicos. En modo hardware ya no presenta capacidades/estado mock como si fueran físicos: esos endpoints responden 503 hasta integrar una lectura segura. No equivale a soporte completo de Image Capture. Ahora sólo se enlaza localmente.

El manejo de `POST /ScanJobs` fue endurecido: requiere `Content-Length`, limita el body a 1 MiB y rechaza valores inválidos, incompletos o sobredimensionados. Las pruebas directas cubren solicitudes fragmentadas y confirman el rechazo de `Transfer-Encoding: chunked`; no se afirma soporte chunked.

## AIRPRINT

NO IMPLEMENTADO. No hay servidor IPP implementado; se eliminó el anuncio Bonjour `_ipp._tcp` para evitar falsa capacidad.

## USB

Lectura física segura final: el equipo continúa enumerando VID `0x03f0`/PID `0x2b54` con interfaz LEDM 0, impresora PCL3GUI 1 y dos interfaces EWS 2/3. La enumeración USB pasa; esto no demuestra que los canales de escaneo/estado respondan correctamente.

Descriptores pasivos VID/PID e interfaces están documentados. No se hicieron escrituras peligrosas. La duplicación de interfaz ff/04/01 y la concurrencia de subsistemas siguen sin validación física.

Evidencia actualizada (reproducción segura 2026-09-04): la enumeración y `info` vuelven a identificar el dispositivo y sus cuatro interfaces; discovery del backend devuelve `smarttank://`. Las lecturas `status`, `supplies` y `odometer` terminan con `LIBUSB_ERROR_TIMEOUT` y código 1, sin presentar datos sintéticos como reales. Las interfaces EWS 2/3 siguen sin demostrar independencia determinista; no se conserva el número de serie completo en informes.

## MANTENIMIENTO

Se retiró del flujo de `prime-tubes` el fallback histórico a `cleanHeadLevel2`: una respuesta HTTP insuficiente ya no puede disparar otra operación mecánica. Las salidas mock de cebado/salud de cabezales ahora se identifican explícitamente como sintéticas.

No ejecutado. `deep-clean`, `inject-raw`, waste-ink y alineación quedan fuera de pruebas automáticas por riesgo mecánico. El CLI ahora exige `--confirm-hardware` para operaciones físicas peligrosas; la barrera se verificó con `deep-clean` (código 2, sin apertura de operación). `waste-ink` ya no presenta valores sintéticos en modo real: sin contador físico devuelve JSON/error y código 1.

## APP SWIFTUI

La resolución de ejecutables auxiliares ahora exige archivo regular, ejecutable y no symlink antes de crear un `Process`; el bundle recompiló y pasó verificación de firma ad-hoc.

Compila arm64 sin warnings en la build auditada. La aplicación incluida en el paquete no conserva rutas del árbol de desarrollo; las acciones peligrosas requieren confirmación explícita. Persisten pruebas pendientes de accesibilidad, instalación y ejecución real.

## MENUBAR

El monitor ahora usa polling one-shot adaptativo: 15 s sin conexión y 4 s conectado, con guardia contra refreshes solapados. La lógica compila ARM64 y pasa la suite, pero consumo idle y reconexión real siguen sin prueba física.

## LAUNCHD

El plist del payload pasa `plutil -lint`, pero `launchctl print/blame gui/501/com.hp.smarttank.airscan` devuelve código 113 porque el servicio no está cargado. No se ha demostrado que `LaunchEvents` dispare como se documenta en esta versión de macOS; no se modificaron servicios instalados.

El test de LaunchEvents fue corregido para extraer y analizar el plist real del paquete más reciente; ya no valida un diccionario sintético en memoria.

## PKG

Verificación nocturna adicional: todos los scripts auditables pasan `bash -n`, los plist pasan `plutil -lint`, la app expandida pasa `codesign --verify --deep --strict` y el paquete vigente `20260904-055057` no contiene rutas de desarrollo, `/opt/homebrew`, `_ipp._tcp` ni `0.0.0.0`. El `postinstall` extraído pasa `bash -n` y ShellCheck, y rechaza destinos ausentes o symlinks antes de cambiar permisos.

El instalador heredado `install.sh` fue deshabilitado tras reproducir que apuntaba a `research/builds/hpcups_arm64` y ejecutaba cambios privilegiados sin confirmación; devuelve código 2 sin modificar el sistema.

El `postinstall` ahora diferencia archivos configurados de servicios activos: si `launchctl` falla, emite una advertencia explícita y no afirma instalación completa.

Además, el `postinstall` ya no ejecuta `chown -R` sobre el directorio de iconos: sólo ajusta el icono propio `HP_Smart_Tank_500.icns`, preservando archivos HP ajenos.

La revisión posterior eliminó también el `chmod` del directorio de iconos; el instalador sólo cambia permisos/propiedad de archivos propios.

El `postinstall` extraído del paquete vigente pasa `shellcheck -x` y `bash -n`; la app expandida conserva firma ad-hoc verificable.

La expansión del paquete `20260904-035538` detectó y permitió corregir referencias `research/` y `scratch/` que permanecían en los scripts de generación/calibración ICC. Ahora las salidas por defecto usan directorios temporales seguros; el paquete fue regenerado y el payload expandido ya no contiene esas rutas.

Nota de vigencia: los párrafos históricos de esta sección conservan trazabilidad de builds intermedias; el artefacto autoritativo actual es `20260904-055057`, con SHA-256 y contenido descritos en `docs/PACKAGE-MANIFEST.md`.

Evidencia histórica de paquete verificado: `research/builds/HP_Smart_Tank_500_Native_Apple_Silicon-20260904-032026.pkg`, SHA-256 `6cdff6a8bc16a94c9fcab3c4b094794f10b98ae0375b20e55f79ad9da7e74f75`. Sus binarios C y helpers de la app usan `@rpath/libusb-1.0.0.dylib` y el payload incluye `/usr/local/lib/libusb-1.0.0.dylib`; no conservan la ruta Homebrew.

Evidencia histórica de expansión (`20260904-034311`, SHA-256 `2b6f1eb3144bff2117dc8efcecf7e0412ff4b60f4a46234057285fff25e69d8a`) confirmó 0 entradas AppleDouble `._*`, firma ad-hoc válida y 0 referencias a rutas de desarrollo, Homebrew o anuncios AirPrint. También contiene el hardening de PID/log del daemon con directorio privado 700.

Evidencia histórica: la firma ad-hoc del bundle fue revalidada sobre el payload del paquete `20260904-032516`.

La regeneración más reciente, tras retirar porcentajes no medidos de las etiquetas PPD de `HPDensity`/`HPInkSaver`, produjo el paquete documentado en `docs/PACKAGE-MANIFEST.md`; `cupstestppd -W all` y la suite vigente siguen pasando. El paquete canónico no incorpora cambios de código posteriores en wrappers/scripts y debe regenerarse antes de distribuir esta iteración.

Evidencia histórica: la regeneración posterior incorporó ayuda/versionado seguro en `hp_scan` (no abre USB ante `--help`) y produjo `research/builds/HP_Smart_Tank_500_Native_Apple_Silicon-20260904-032238.pkg`, SHA-256 `8049adf46dd33c7d0df8e1c8d2c0ec0ae5c71d213d0527f2e38ed0d0a28b6dcf`.

La verificación física repetida de esta pasada ejecutó `status`, `supplies` y `odometer`: los tres devolvieron código 1 y “No se recibieron datos”. Se conserva como evidencia negativa y no se extrapola a funcionamiento del hardware.

Evidencia histórica: el paquete `research/builds/HP_Smart_Tank_500_Native_Apple_Silicon-20260904-031724.pkg` expandía correctamente, declara versión `0.1.0-alpha`, contiene app arm64 con firma ad-hoc verificable y no contiene referencias a `/Users/jorge`, `/opt/homebrew`, `research/`, `scratch/` ni `Downloads/`; incluye el módulo Python requerido por el bridge con resolución dinámica de libusb. La importación offline desde el payload expandido de `hp_escl_bridge` y `hp_smart_tank` pasó, y el daemon resuelve el bridge vecino del payload sin ruta de desarrollo. El LaunchAgent incluido pasa `plutil -lint` y ya no fija logs previsibles en `/tmp`. El postinstalador preserva enlaces/backend y colas CUPS existentes. El daemon ya no usa `pkill -f` amplio para detener Bonjour y valida su PID bajo `umask 077`. El bridge eSCL aplica timeout de 15 segundos por conexión cliente, rechaza capacidades/estado falsamente simulados en modo hardware y los clientes C rechazan explícitamente respuestas chunked no implementadas. `hp_scan` abre el archivo de salida con `O_NOFOLLOW` y modo 0600. La app ya no muestra niveles de tinta sintéticos, limpia la lectura ante desconexión y la herramienta de escaneo no inventa rutas de trabajo cuando falta `Location`; el temporal RAW usa nombre único y se elimina tras el intento. La inspección XAR/expansión del paquete actual no encontró entradas `._*`. El contenedor `.pkg` no está firmado/notarizado y no se instaló en `/`.

## SECURITY

## PRIVACIDAD

La revisión de logging no encontró volcado de documentos impresos, imágenes escaneadas ni cuerpos binarios en los componentes operativos. Se corrigió el bridge eSCL: ya no registra el XML completo de `ScanSettings`; sólo deja un evento resumido. El gemelo digital puede escribir PPM de diagnóstico por diseño de prueba offline, no como almacenamiento del controlador distribuido. La salida XML de la CLI `hp_smart_tank.py` corresponde explícitamente a la respuesta solicitada por el usuario y no es un log del daemon.

La contabilidad CLI ahora abre sus archivos con `O_NOFOLLOW` y, si no existe un registro local, devuelve error en modo real en vez de inventar métricas; los datos sintéticos quedan restringidos a `--mock`.

Los scripts shell pasan `bash -n` y `shellcheck -x`; se eliminó una variable no utilizada de `install_native.sh` que generaba `SC2034`.

Se corrigió exposición LAN del bridge, permisos nuevos del lock, logs predecibles del LaunchAgent, escritura insegura de contabilidad y carrera de temporales eSCL: archivos con `O_NOFOLLOW`, modo 0600, directorios privados por job y campos de usuario/título sanitizados. Persisten riesgos de `inject-raw`, parser HTTP/XML, rutas fijas y postinstall.

`clang --analyze` volvió a completar sin diagnósticos en `rastertopcl3gui.c`, `cups_backend_smarttank.c`, `hp_scan.c`, `hp-smart-tank-tool.c` y `ews-readonly-probe.c`; además, el probe EWS compiló arm64 en la comprobación posterior y su SHA quedó registrado en `docs/BUILD-REPRODUCIBILITY-AUDIT.md`. Esto no sustituye ASan/UBSan, fuzzing de parsers ni pruebas de concurrencia física.

## PERFORMANCE

Una ejecución offline con un corpus CUPS Raster sintético de 100 páginas terminó correctamente con `100 paginas procesadas`, sin crecimiento observable de memoria: tiempo real ~0,00 s y memoria residente máxima ~5,8 MiB. Es una validación de límites y reutilización de buffers del filtro, no throughput físico ni tiempo de impresión.

Medición offline puntual del raster RGB válido: 0,04 s de tiempo real, 5,9 MB de memoria máxima y 7.840 bytes de stream PCL3GUI. No constituye una medición completa de throughput por página, daemon idle o hardware.

Medición reproducida 2026-09-04 06:24 sobre `scratch/test_page_hp500.raster` (4962×7014, 600 DPI): 0,03 s real, 0,02 s CPU de usuario, 5.865.472 bytes de RSS máxima y 131.307 bytes de salida PCL3GUI; código 0. Es una muestra offline de una página, no una garantía de throughput físico.

Medición nocturna reproducida 06:46 sobre la build `research/builds/audit-clean/20260904-064340`: dos raster sintéticos (`scratch/*.raster`) terminaron con código 0. La muestra 5100×6600 tardó 0,32 s reales, 0,03 s de usuario y alcanzó 5.865.472 bytes de RSS máxima, con 7.840 bytes de PCL3GUI; la muestra 4962×7014 tardó 0,04 s reales. Son mediciones offline del filtro y no representan throughput del dispositivo ni del transporte USB.

## FUZZING Y SANITIZERS

La build ASan/UBSan de `smarttank`, `hp_scan` y `hp-smart-tank-tool` compiló en ARM64 sin warnings tras corregir una conversión de tamaño en `hp_scan`; las rutas seguras de ayuda/validación no reportaron diagnósticos. Esto no sustituye fuzzing de transporte USB ni pruebas físicas.

`tools/fuzz_mode10_encoder.c` + `tools/fuzz_mode10_driver.c` compilaron sin warnings con ASan/UBSan y completaron `MODE10_SANITIZER_MUTATION_ROUNDS=100000 PASS`. El intento de libFuzzer quedó `NOT AVAILABLE`: falta `libclang_rt.fuzzer_osx.a`. No se declara fuzzing completo del proyecto.

No hay medición completa reproducida de throughput, memoria, CPU, idle o latencia.

ASan/UBSan smoke offline del filtro corregido: 16 raster del corpus, 0 fallos y 0 hallazgos. LeakSanitizer no está soportado por esta plataforma, por lo que fugas no quedan verificadas.

Los clientes nativos `hp_scan` y `hp-smart-tank-tool` recompilan en ARM64 con flags estrictos y 0 warnings.

## PRUEBAS FÍSICAS

No probadas con éxito en esta pasada: observación física de impresión, captura física de escaneo, supplies, fallos USB, reconexión, papel, tapa, cancelación y concurrencia. CUPS completó un trabajo A4, pero no se verificó la salida física. Capacidades/estado del escáner sí fueron leídos físicamente; la captura controlada falló por respuesta desincronizada.

La matriz detallada está en `docs/TEST-MATRIX-2026.md`.

## FUNCIONES EXPERIMENTALES

InkSaver, TAC, PureBlack/KGray/CMYGray, Dry time, borderless, banner, ICC, AirScan bridge y mantenimiento.

## LIMITACIONES CONOCIDAS

Ver `docs/KNOWN-LIMITATIONS.md`.

## RELEASE READINESS

No cumple criterios RC1: faltan hardware tests completos, fuzzing de parsers CUPS/HTTP/XML, cancelación/reconexión y firma/notarización del paquete. La hermeticidad de runtime del payload fue verificada con `libusb` vendorizada y `@rpath`.

## PRÓXIMOS 10 CAMBIOS PRIORIZADOS

1. Corregir la sincronización LEDM/USB y obtener una captura física JPEG válida.
2. Ejecutar matriz física de impresión: A4 negro, A4 color, foto y reconexión.
3. Ejecutar matriz física de scanner: preview, crop, color/gris y 75–1200 DPI.
4. Probar cancelación CUPS, cable desconectado y recuperación de endpoint.
5. Validar concurrencia real impresión/status/escaneo con locks por subsistema.
6. Completar fuzzing ASan/UBSan de entradas CUPS, HTTP y XML.
7. Validar eSCL con Image Capture real y declarar sólo endpoints soportados.
8. Completar pruebas de accesibilidad, errores de procesos y notificaciones de la app.
9. Firmar, notarizar y probar instalación/uninstall en root temporal y máquina limpia.
10. Medir ICC y transformaciones de tinta con cartas y hojas físicas trazables.

## MATRIZ FINAL

| Característica | Código | Compila | Unit test | Integration test | Hardware test | Estado |
|---|---:|---:|---:|---:|---:|---|
| rastertopcl3gui | sí | sí, 0 warnings | parcial | offline + sanitizer | no | PARCIAL |
| smarttank backend | sí | sí, 0 warnings | parcial | CUPS job 62 completado; hardware visual no | no | PARCIAL |
| CLI mantenimiento seguro | sí | sí, 0 warnings | 20 tests | bloqueo sin confirmación verificado | no | VERIFICADO |
| PCL3GUI Mode10 | sí | sí | 9/9 decoder + 2.000 property-based | offline | no | VERIFICADO |
| hp_scan LEDM | sí | sí, 0 warnings | parcial | caps/status físicos; captura FALLA | no | ROTO |
| eSCL bridge | sí | Python válido | pasa unittest | mock | no | PARCIAL |
| AirPrint IPP | no | n/a | no | no | no | NO IMPLEMENTADO |
| ICC | sí | n/a | sintaxis/sips | offline | no | EXPERIMENTAL |
| SwiftUI app | sí | arm64, 0 warnings | no | no | no | PARCIAL |
| LaunchEvents | plist | lint | no | no | no | EXPERIMENTAL |
| PKG/uninstall | scripts | pkg construido arm64 | no | expansión/manifiesto | dry-run, no instalación root | EXPERIMENTAL |

Estados usados: VERIFICADO, PARCIAL, EXPERIMENTAL, ROTO, NO IMPLEMENTADO.
## CONCURRENCIA

En el host auditado, ThreadSanitizer pudo enlazar builds arm64 de `cups_backend_smarttank.c` y `rastertopcl3gui.c`. El backend ejecutó discovery con código 0 y sin diagnósticos TSan. El filtro TSan no pudo iniciar sin un flujo CUPS Raster por stdin y terminó con su error de inicialización; esto no constituye una prueba de concurrencia del filtro. No se declara ausencia general de races hasta ejecutar cargas simultáneas de impresión, estado y escaneo con hardware o gemelo digital instrumentado.
