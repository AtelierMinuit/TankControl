# Auditoría de dependencias

| componente | dependencia | origen | runtime | incluida en pkg | riesgo |
|---|---|---|---:|---:|---|
| rastertopcl3gui | libcups | macOS | sí | no | bajo, API del sistema |
| smarttank/hp_scan/hp-smart-tank-tool | libusb-1.0 | vendorizada en `/usr/local/lib` (build desde Homebrew) | sí | sí | medio: debe mantenerse y actualizarse con el paquete |
| mismos binarios | libSystem | macOS | sí | no | bajo |
| app | Cocoa/SwiftUI/Swift runtime | Apple SDK/macOS | sí | parcialmente | medio: deployment/SDK |
| bridge | Python 3 (`/usr/bin/python3`) | macOS system | sí | no | medio; ruta fija en plist y versión provista por el sistema |
| bridge | Bonjour `dns-sd` | macOS | sí | no | bajo si sólo localhost |
| ICC | ColorSync/sips | macOS | herramienta de validación | no | perfiles no calibrados |

Conclusión: los ejecutables libusb ya no dependen de una ruta Homebrew en el paquete; requieren la `libusb` vendorizada. La afirmación estricta “cero dependencias externas” sigue siendo incorrecta porque libusb no es parte del sistema base.

Verificación del host actual: `/usr/bin/python3` existe y ejecuta Python 3.9.6 arm64; `/usr/bin/dns-sd` y `/usr/bin/codesign` existen; `cupsfilter` existe en `/usr/sbin/cupsfilter` y no es invocado directamente por el payload. Los módulos `hp_escl_bridge` y `hp_smart_tank` importan correctamente desde el payload expandido usando sólo sus dependencias declaradas.
