# Proveniencia y Trazabilidad de Características — HP Smart Tank 500 macOS

**Fecha:** 2026-09-04  
**Objetivo:** Establecer el origen técnico, base de estándares y trazabilidad de cada componente y funcionalidad implementada en la suite de controladores.

---

## 1. Matriz de Proveniencia Técnica

| Característica / Módulo | Fuente de Proveniencia | Estándar / Documentación Base | Nivel de Adaptación |
| :--- | :--- | :--- | :--- |
| **PCL3GUI Modo 10 Compresión** | HPLIP `bb_pcl3gui.c` y Guía de Desarrolladores HP PCL3 (1995) | HP PCL3 / PCL3GUI Specification | Reimplementación limpia en C99 (`rastertopcl3gui.c`) optimizada para ARM64. |
| **Backend USB Bidireccional** | CUPS Backend API Specification (Apple Open Source) + libusb-1.0 | CUPS 2.3 Backend Specification, USB CDC 1.1 / USB Printer Class 1.1 | Implementación propia en C99 (`cups_backend_smarttank.c`) con bloqueo global contra concurrencia de escáner. |
| **Protocolo LEDM de Diagnóstico** | Ingeniería inversa de `HPDM.framework` e inspección de esquemas XML de HP | HP Low End Device Management (LEDM) REST API sobre HTTP 1.1 / USB | Implementado en `hp-smart-tank-tool.c` para lectura de consumibles, odómetro y disparos de limpieza. |
| **Escáner USB / eSCL AirScan** | Ingeniería inversa de `HPLEDMScan.bundle` y especificación Mopria eSCL v2.6 | Mopria Alliance eSCL Specification, Apple AirScan Architecture | Servidor HTTP REST local (`hp_escl_bridge.py`) y cliente de captura USB C99 (`hp_scan.c`). |
| **AirPrint / IPP Everywhere** | Estándar IEEE-ISTO PWG 5100.14 e IETF RFC 8011 | Apple CUPS `ippeveprinter` y filtro `ippeveps` | Demonio ligero en bash (`hp_airprint_daemon.sh`) con ficha estricta RFC 8011 (`hp-smart-tank-500-airprint.conf`). |
| **Motor InkSaver / Eco-Print** | Algoritmos de filtrado espacial y atenuación de luminancia | Procesamiento de Señales Digitales (DSP) en espacio de color RGB | Implementado dentro de `rastertopcl3gui.c` como transformaciones deterministas de matrices de píxeles. |
| **Perfiles de Color ColorSync** | Especificación ICC.1:2010 (Profile version 4.3) | International Color Consortium (ICC) Specification | Generador experimental de bucle cerrado (`tools/calibrate_icc.py`) para calibración cromática escáner-impresora. |
| **Utilidad de Escritorio macOS** | Apple HIG (Human Interface Guidelines) para macOS | SwiftUI 4 / macOS 12+ App Lifecycle | Aplicación nativa en Swift 6 (`apps/HPSmartTankUtility/Sources/main.swift`). |

---

## 2. Declaración de Código Propio y Ausencia de Plagio

1. **Reescritura C99:** Ningún archivo de código C (`rastertopcl3gui.c`, `cups_backend_smarttank.c`, `hp_scan.c`, `hp-smart-tank-tool.c`) contiene copia textual o fragmentos desensamblados de los drivers de Linux o de Apple. Se diseñaron y codificaron desde cero siguiendo buenas prácticas de software embebido seguro (sin fugas de memoria, protección contra desbordamiento de búfer y validación estricta con sanitizers ASan/UBSan).
2. **Archivos PPD:** El PPD de referencia fue adaptado a partir del archivo libre GPL-2.0 de HPLIP 3.26.4, modificando la directiva `*cupsFilter` para apuntar a nuestro filtro nativo de alto rendimiento para macOS.
3. **Esquemas XML LEDM:** Los esquemas XML utilizados en las peticiones HTTP corresponden a las estructuras estandarizadas por HP para comunicación SOAP/REST en dispositivos de consumo y oficina.
