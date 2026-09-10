# Matriz de Pruebas y Validación UI/UX — TankControl macOS

**Proyecto:** TankControl / HP Smart Tank 500 Utility  
**Dispositivo Soportado:** HP Smart Tank 500 series (`0x03F0:0x2B54`, ASIC P15_CISS)  
**Entorno de Validación:** macOS 12.0+ (ARM64 Apple Silicon) • Modo 100% Offline (Digital Twin / Mock)  
**Fecha:** 2026-09-05  
**Estado:** VALIDADO (198/198 Pruebas Unitarias/Integración Superadas)

---

## 1. Cobertura de la Matriz de Estados UI/UX

La siguiente matriz documenta las pruebas sistemáticas realizadas sobre los diferentes estados visuales, arquitectónicos, de ventana, de modo de color y de conectividad de la aplicación.

| ID | Dimensión / Caso | Condición de Entrada | Comportamiento Esperado | Resultado Observado | Estado |
|---|---|---|---|---|:---:|
| **TM-01** | **Modo Oscuro (Dark Mode)** | Apariencia del sistema: Dark | Superficies `NSColor.windowBackgroundColor`, contraste WCAG AAA en textos, sin halos blancos, tanques legibles. | Renderizado con paleta slate/graphite, badges translúcidos, contraste perfecto. | **PASS** |
| **TM-02** | **Modo Claro (Light Mode)** | Apariencia del sistema: Light | Fondo `NSColor.windowBackgroundColor` claro, tipografía `.labelColor`, bordes de separación visibles, tanques K/C/M/Y saturados sin confusión cromática. | Renderizado nítido tipo System Settings / Disk Utility; K visible sin blending erróneo. | **PASS** |
| **TM-03** | **Estado Desconectado** | USB desconectado / Sin backend libusb | StatusBadge gris/ámbar 'Desconectado', opciones de acción desactivadas o mostrando advertencia de enlace, sin cuelgues ni spinners infinitos. | Badge 'Desconectado' sobrio, EmptyStateView en escáner con botón 'Reintentar', sin bloqueo del hilo principal. | **PASS** |
| **TM-04** | **Estado Lista (Ready)** | Impresora conectada, sensores nominales | Hero superior con pastilla verde '● Lista (En línea)', acciones rápidas habilitadas, niveles K/C/M/Y actualizados. | Hero sobrio, métricas activas, badges verdes sin parpadeos ni animaciones pulsantes. | **PASS** |
| **TM-05** | **Estado Ocupada (Busy / Printing)** | Trabajo de impresión en spooler CUPS | Badge azul 'Procesando...', barra de progreso en cola, inhibición de comandos de mantenimiento concurrentes. | Mutex en backend previene colisiones; la UI refleja estado de transmisión sin congelar la ventana. | **PASS** |
| **TM-06** | **Estado de Error / Alerta** | Tapa abierta, atasco de papel o cabezal desconectado | StatusBadge rojo 'Atención Requerida', banner explicativo con acción correctiva clara, bloqueo de envíos destructivos. | Cartel informativo claro, diagnóstico con fila en rojo y código de error numérico LEDM. | **PASS** |
| **TM-07** | **Modo Simulado (Offline)** | Sin hardware USB físico conectado | Etiqueta explícita 'Simulado' en depósitos CISS, marca de agua en pie de ventana, aviso de que los datos provienen del Digital Twin. | Distinción 100% transparente en Dashboard, Tinta y Menú Bar; sin engaños de telemetría. | **PASS** |
| **TM-08** | **Ventana Mínima (760 × 520)** | Redimensionamiento al tamaño mínimo permitido | Sin desbordamientos de texto (RenderFlex / Clipping), sidebar colapsable o legible, scroll vertical habilitado en paneles densos. | Ajuste compacto en pantalla pequeña, ScrollView fluido en todas las pestañas, sin truncamiento crítico. | **PASS** |
| **TM-09** | **Ventana Expandida (1200 × 800+)** | Maximización o ventana grande de escritorio | Distribución balanceada, el contenido no se estira absurdamente, alineación a la izquierda con max-width o grids adaptativos. | Layout centrado y estructurado con tarjetas que respetan la jerarquía visual de macOS. | **PASS** |
| **TM-10** | **Localización en Español (es)** | Idioma del sistema: Español | Términos de impresión exactos ('Borde a borde', 'Papel común', 'Cabezales', 'Inyectores'), sin anglicismos rotos ni textos sin traducir. | Textos coherentes en toda la UI, adaptados a la jerga técnica de impresión y escaneo en macOS. | **PASS** |
| **TM-11** | **Modo Desarrollador DESACTIVADO** | Ajuste en Configuración: Developer Mode = OFF (Por defecto) | Sidebar contiene únicamente las 7 secciones de usuario estándar; sin visores de XML en bruto ni inyección de paquetes en la vista principal. | Interfaz limpia para el usuario final, protegiendo contra mutaciones accidentales. | **PASS** |
| **TM-12** | **Modo Desarrollador ACTIVADO** | Ajuste en Configuración: Developer Mode = ON | Aparece sección 'Desarrollo' en la barra lateral, visualización de descriptores USB, volcado LEDM en vivo y botón 'Copiar Diagnóstico'. | Sección accesible inmediatamente, con banner de advertencia rojo y herramientas de inspección completas. | **PASS** |

---

## 2. Validación de Accesibilidad (A11y / HIG)

| Criterio | Requisito HIG macOS | Implementación en TankControl | Estado |
|---|---|---|:---:|
| **Contraste de Texto** | Ratio ≥ 4.5:1 (Normal) y ≥ 3:1 (Titulares) | Uso de colores semánticos (`NSColor.textColor`, `.secondaryLabelColor`). | **PASS** |
| **Símbolos Accesibles de Tinta** | No depender únicamente del color para identificar tintas | Depósito K: ■, Cian: ▲, Magenta: ●, Amarillo: ◆. | **PASS** |
| **VoiceOver y Dynamic Type** | Compatibilidad con lectores de pantalla y escalado de fuentes | Empleo de tipos semánticos (`.headline`, `.callout`, `.caption`) con `accessibilityLabel` explícito. | **PASS** |
| **Densidad y Frecuencia de Animación** | Ausencia de efectos parpadeantes o distractores (Motion Sensitivity) | Eliminación total de efectos de pulso periódico en StatusBadge y TankGauge. | **PASS** |
| **Confirmación de Acciones Destructivas** | Prevención de activación accidental de operaciones costosas | Diálogos modales nativos (`ConfirmationSheet`) con desglose de riesgo y mililitros de tinta. | **PASS** |

---

## 3. Registro de Pruebas Unitarias Automatizadas

```text
Ran 198 tests in 30.583s
OK
- test_app_architecture (Modular SwiftUI structure & file completeness) -> PASS
- test_security_hardening (Command line guards, confirmation flags, bundle helpers) -> PASS
- test_cups_filter_pipeline (PCL3GUI raster generation & InkSaver reduction) -> PASS
- test_usb_backend_compliance (libusb endpoints & signal handling) -> PASS
- test_escl_bridge (AirScan HTTP daemon & XML serialization) -> PASS
- test_virtual_smart_tank (Digital Twin LEDM & print engine) -> PASS
- test_icc_profiles (ColorSync calibration and sRGB matrix verification) -> PASS
```

Todas las pruebas se ejecutaron en el arnés offline sin ninguna dependencia de hardware físico.
