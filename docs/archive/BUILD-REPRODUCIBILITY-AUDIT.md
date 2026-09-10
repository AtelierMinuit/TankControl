# Auditoría de build reproducible

Fecha: 2026-09-04. Snapshot: `/Users/jorge/Downloads/Instaladores/hp/research/audits/pre-hardening-20260904-014231/`.

Se construyeron desde source en `research/builds/audit-clean/night-20260904/` `smarttank`, `hp_scan`, `hp-smart-tank-tool` y `rastertopcl3gui`, todos Mach-O arm64. La app SwiftUI también compiló como arm64 sin warnings en la última build auditada. Los artefactos de build usan Homebrew para compilar; el paquete final reescribe los binarios a `@rpath` e incluye `libusb-1.0.0.dylib` en `/usr/local/lib`, por lo que no depende de una ruta Homebrew en runtime.

El build reproducible queda condicionado por versión exacta de Xcode/SDK, Homebrew/libusb y ausencia de un sistema de build único. `pytest` no está instalado; la suite se ejecutó mediante `python3 -m unittest discover`.

Se añadió `tools/build_audit.sh` como punto único de compilación de los cuatro componentes C. Cada ejecución crea un directorio timestamped nuevo y registra `file`, SHA-256 y `otool -L`; no reutiliza binarios antiguos ni instala archivos.

Se añadió `tools/audit_package.sh` como verificador reproducible de paquetes: expande sólo en un temporal, valida la firma ad-hoc de la app, cuenta el payload y rechaza rutas de desarrollo o anuncios AirPrint. No instala ni modifica el sistema.

Build C limpia reproducida el 2026-09-04 06:53: `research/builds/audit-clean/20260904-065355`. Los cuatro ejecutables (`rastertopcl3gui`, `smarttank`, `hp_scan`, `hp-smart-tank-tool`) son arm64 y compilaron con código 0. La compilación de desarrollo de los componentes que usan USB enlaza contra Homebrew; el paquete distribuido usa la copia vendorizada documentada en la auditoría de dependencias. La suite contra el estado actual terminó 140/140 y el análisis estático por fuente no emitió diagnósticos.

Revalidación posterior 2026-09-04 07:12: `research/builds/audit-clean/20260904-071243`. Los cuatro binarios se recompilaron desde source como Mach-O arm64, sin coincidencias `warning:`/`error:` en el log, y `codesign --verify` pasó individualmente. SHA-256: `rastertopcl3gui` `3829dcf14073efbf007d90a8571d480a1ad1e515b0936549ff2a3961d38e6f47`; `smarttank` `8af80a4496178f3699048cc24b49958f9e22e2b2daeb6c29f8b2c39a0cf3bf85`; `hp_scan` `45338fe8ffd167dbb981a1f2ea1761f0e9ac1b76a35217d012794dedad92ed2c`; `hp-smart-tank-tool` `b464cadea43a36b0e7fb2086008fd36384cdbff9213fb796948b20e54ec34395`.

Revalidación SwiftUI 2026-09-04 07:15: `research/builds/audit-clean/20260904-0715/HP Smart Tank Utility.app`. `swiftc` generó la aplicación arm64 desde `apps/HPSmartTankUtility/Sources/main.swift`; helpers `hp_scan` y `hp-smart-tank-tool` también son arm64. `plutil -lint` pasó y `codesign --verify --deep --strict` pasó para el bundle. La firma es ad-hoc, sin identidad de distribución ni notarización.

`apps/HPSmartTankUtility/build_app.sh` acepta ahora `HP_AUDIT_BUILD_DIR` y `HP_APP_OUTPUT_DIR`, lo que permite construir la app en un directorio limpio con los binarios C de una ejecución concreta, sin depender del staging nocturno fijo.

Evidencia histórica: la ejecución reproducida `research/builds/audit-clean/20260904-042401` compiló los cuatro binarios como Mach-O arm64, sin warnings ni errores. La build C más reciente es `research/builds/audit-clean/20260904-044542`; el paquete auditado vigente se identifica en `docs/PACKAGE-MANIFEST.md`.

Revalidación posterior: `research/builds/audit-clean/20260904-041156` volvió a compilar los cuatro binarios C como Mach-O arm64, sin warnings ni errores. El harness mutacional Mode10 registró `MODE10_SANITIZER_MUTATION_ROUNDS=100000 PASS` sin diagnóstico ASan/UBSan.

La regeneración más reciente del paquete utilizó los cuatro binarios C y la app SwiftUI de `research/builds/audit-clean/20260904-044542/`; la expansión y firma ad-hoc del bundle pasaron, y el artefacto está identificado en `docs/PACKAGE-MANIFEST.md`.

Auditoría del payload vigente: todos los ejecutables Mach-O incluidos (filtro, backend, CLI, helpers y app) son `arm64`; los enlaces externos apuntan a frameworks/librerías del sistema o a `@rpath/libusb-1.0.0.dylib`, y la app pasa `codesign --verify --deep --strict`.

La suite puede ejecutarse contra una build concreta con `HP_AUDIT_BUILD_DIR=/ruta/audit-clean/<timestamp> python3 -m unittest discover -s tests`; la ejecución contra la build fresca `20260904-044542` terminó con 111 tests ejecutados sin `FAILED`. Los cuatro binarios de esa build son Mach-O arm64; sus SHA-256 quedaron registrados en la carpeta de build.

Análisis estático adicional sobre esa misma build: `clang --analyze` terminó sin diagnósticos en `rastertopcl3gui.c`, `cups_backend_smarttank.c`, `hp_scan.c` y `hp-smart-tank-tool.c`. Los binarios de desarrollo enlazan `libusb` desde Homebrew; esto es build/runtime de desarrollo y no contradice que el paquete reubique la biblioteca vendorizada mediante `@rpath`.

El probe de lectura EWS (`tools/ews-readonly-probe.c`) también compiló como Mach-O arm64 con las mismas reglas estrictas y `clang --analyze` terminó sin diagnósticos. SHA-256 del ejecutable de esta comprobación: `bc3f166c3b853c0cbddeb03b2d33ce9929ad85997c0e6d3ffa9c0467a45d6529`. No se ejecutó contra USB.

La aplicación SwiftUI fue recompilada desde `apps/HPSmartTankUtility/Sources/main.swift` dentro de `research/builds/audit-clean/20260904-044542/`; el bundle y sus helpers son arm64, `codesign --verify --deep --strict` pasó y la firma es ad-hoc sin Team ID. Esa app y los cuatro binarios C fueron usados para generar el paquete vigente `20260904-044619`, identificado en `docs/PACKAGE-MANIFEST.md`.

El generador auxiliar `tools/generate_test_page.py` no pudo ejecutarse en este entorno porque el Python activo no tiene `Pillow` (`ModuleNotFoundError: PIL`). No forma parte del payload del paquete ni se usa como evidencia de hardware.
