# Soporte de HP Smart Tank 500 en HPLIP y macOS

## Información General y Soporte en HPLIP
La serie **HP Smart Tank 500** cuenta con soporte oficial en Linux a través de **HPLIP (HP Linux Imaging and Printing)**, a partir de la versión **3.19.6**. 

### Detalles Técnicos (models.dat)
* **Entrada en `models.dat`:** `[hp_smart_tank_500_series]`
* **tech-class:** Pertenece a la clase de impresoras de inyección de tinta, utilizando habitualmente la clase técnica **PCL3GUI** (a veces referida bajo la arquitectura Pyramid).
* **PPD:** Utiliza el archivo PPD `hp-smart_tank_500_series.ppd.gz` para la configuración de CUPS.
* **Filtros de impresión (hpcups):** La impresión es gestionada por el filtro `hpcups`, que procesa los trabajos de impresión desde CUPS y los convierte en el formato ráster `PCL3GUI` que la impresora puede interpretar.
* **Escaneo (hpaio):** El escaneo está soportado mediante el backend de SANE `hpaio` (HP All-in-One), permitiendo la comunicación bidireccional para las funciones del escáner.
* **Conectividad:** Este modelo específico (500) es principalmente de conexión **USB**. Modelos superiores (como el 515 o 530) añaden conectividad de red.
* **Requisito de Plugin (`plugin=1`):** Dependiendo de la función específica y distribución, los modelos de HP a menudo requieren la instalación del plugin binario privativo de HP para tener capacidades completas (especialmente el escáner). En HPLIP, esto se indica con `plugin=1` en su entrada de configuración y requiere usar `hp-plugin` para descargarlo y aceptarlo.
* **Dependencias:** Requiere `hplip`, `hplip-data`, `hplip-gui` (opcional), CUPS y SANE (`libsane-hpaio`).
* **Capacidades declaradas por HPLIP:** La ficha expone color, tamaños/calidades y escaneo plano; esto acredita compatibilidad del backend HPLIP, no validación física de cada modo en este proyecto.
* **Límite de auditoría:** impresión sin bordes, separación K/CMY, calidades, consumibles y captura de escaneo deben permanecer como `NOT TESTED` o experimentales hasta probarlos en la unidad concreta.

## Comparación con macOS
* **AirPrint no demostrado:** la ficha oficial de HP para la serie indica `Wireless capability: No` y `Mobile printing capability: USB Only`, pero también incluye una nota genérica que describe AirPrint cuando una impresora está conectada a la misma red. La evidencia específica disponible no demuestra conectividad de red ni AirPrint en esta unidad; el proyecto no implementa servidor IPP y debe clasificar AirPrint como `NO IMPLEMENTADO`, sin afirmar imposibilidad absoluta del modelo.
* **Controladores en macOS:** Para utilizar esta impresora en macOS (a través de USB), es necesario instalar el paquete de controladores específicos proporcionado por HP, conocido como **"HP Smart Tank Driver Essentials"**. 
* **Experiencia de usuario:** Mientras que en Linux HPLIP proporciona un entorno centralizado (con `hp-setup` y `hp-toolbox`) que maneja de manera unificada la cola CUPS y el backend SANE, en macOS el usuario depende de que el paquete de controladores de HP se integre correctamente con el diálogo "Impresoras y Escáneres" del sistema. En versiones recientes de macOS (como macOS 15+), algunos usuarios han reportado que es necesario forzar controladores genéricos PCL si los oficiales fallan.

## Diferencia de protocolo reproducida en la auditoría 2026-09-04

La comparación con `research/hplip/hplip-3.26.4/scan/sane/bb_ledm.c` mostró que HPLIP envía cabeceras adicionales de sesión y el terminador `0\r\n\r\n`. Se corrigieron las solicitudes LEDM de estado, creación, polling y descarga en `tools/hp_scan.c` para aproximarlas al flujo HPLIP. La prueba física segura continúa devolviendo `LIBUSB_ERROR_TIMEOUT (-7)` al leer `/Scan/Status`; el escáner permanece `PARCIAL`.
