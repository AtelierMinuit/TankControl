# Guía de Identidad de Marca y Sistema de Diseño — TankControl

**Producto:** TankControl  
**Descriptor:** *Native printing, scanning & ink management for macOS*  
**Compatibilidad:** HP Smart Tank 500 Series (P15_CISS ASIC / USB)  
**Versión:** 0.1.0-alpha  
**Fecha:** 2026-09-05  

---

## 1. Fundamento de Naming y Propuestas de Identidad

Para asegurar una identidad moderna, profesional y legalmente inobjetable, se evaluaron tres conceptos de producto:

1. **`SmartTank Native`**:
   - *Ventajas:* Alta recordación y relación directa con la serie de impresoras.
   - *Desventajas:* Mantiene el término comercial "Smart Tank" como eje principal, lo que puede inducir a confusión con software oficial de HP Inc. y debilita la diferenciación.
2. **`InkBridge Native`**:
   - *Ventajas:* Describe con exactitud la naturaleza técnica del proyecto como puente entre protocolos USB, CUPS y eSCL.
   - *Desventajas:* Demasiado técnico para usuarios finales; sugiere un componente de infraestructura más que una aplicación completa de escritorio.
3. **`TankControl` (SELECCIONADO)**:
   - *Justificación:* Nombre limpio, rotundo y representativo del ecosistema macOS (análogo a utilidades de referencia como *AudioControl*, *FanControl*, *ColorSync*). Transmite precisión, control total sobre el sistema continuo de tinta (CISS) y prescinde de cualquier confusión con "HP Smart".
   - *Subtítulo Normativo:* *Compatible con HP Smart Tank 500 — Proyecto Independiente de Código Abierto*.

---

## 2. Personalidad del Producto

* **Técnica pero Accesible:** Proporciona datos reales y verificados (odómetro, gotas por color, cobertura TAC) sin abrumar al usuario cotidiano que sólo desea imprimir o escanear.
* **Hermética y Transparente:** Cero telemetría, cero recolección de datos, cero dependencia de la nube. Lo que la aplicación muestra refleja exactamente lo que ocurre en el puerto USB o en el spooler CUPS local.
* **Sobria y Nativa:** Utiliza materiales translúcidos de macOS, barras de herramientas estándar, tipografía de sistema y jerarquías claras, sin degradados estridentes ni emulaciones web.

---

## 3. Paleta Cromática Semántica

Para garantizar legibilidad total en **Light Mode**, **Dark Mode** y modos de **Alto Contraste**, no se hardcodean valores RGB absolutos para fondos o texto. Se emplean colores semánticos nativos de Apple:

### 3.1 Colores de Interfaz (macOS Semantic)
* **Fondo de Ventana:** `Color(NSColor.windowBackgroundColor)`
* **Fondo Secundario / Tarjetas:** `Color(NSColor.controlBackgroundColor)`
* **Borde / Separadores:** `Color(NSColor.separatorColor)`
* **Texto Primario:** `Color.primary`
* **Texto Secundario / Metadatos:** `Color.secondary`
* **Color de Acento:** `Color.accentColor` (azul nativo de macOS por defecto, adaptable a la preferencia del usuario en Ajustes del Sistema).

### 3.2 Paleta de Tanques de Tinta (CISS CMYK)
Los tanques de tinta poseen una formulación cromática calibrada para mantener contraste y brillo uniforme en fondos claros y oscuros:

| Canal | Nombre | Token SwiftUI | Valor Hex / Modo Claro | Modo Oscuro | Indicador Accesible |
| :---: | :---: | :--- | :--- | :--- | :---: |
| **K** | Negro | `DesignTokens.Ink.black` | `#1A1A1A` | `#2A2A2A` (con borde `#555555`) | **[K]** |
| **C** | Cian | `DesignTokens.Ink.cyan` | `#0099DD` | `#00A8F3` | **[C]** |
| **M** | Magenta | `DesignTokens.Ink.magenta` | `#E6007E` | `#F02693` | **[M]** |
| **Y** | Amarillo | `DesignTokens.Ink.yellow` | `#FFCC00` | `#FFD633` | **[Y]** |

> [!IMPORTANT]
> **Regla de Accesibilidad de Color:** Ninguna información crítica sobre el nivel de tinta debe depender únicamente del color. Cada tanque debe acompañarse de su letra identificadora, nombre completo y porcentaje numérico explícito (`Cian — 68%`).

---

## 4. Tipografía y Escala de Fuentes

Se utiliza exclusivamente la familia tipográfica del sistema **SF Pro**, garantizando compatibilidad con Dynamic Type y renderizado subpíxel perfecto en pantallas Retina.

* **Título Principal de Sección:** `.font(.system(size: 20, weight: .bold, design: .default))`
* **Encabezado de Tarjeta / Grupo:** `.font(.system(size: 14, weight: .semibold))`
* **Cuerpo de Texto Regular:** `.font(.system(size: 12, weight: .regular))`
* **Etiquetas de Estado / Badges:** `.font(.system(size: 11, weight: .medium))`
* **Datos Técnicos / Hex / Métricas:** `.font(.system(size: 10, weight: .medium, design: .monospaced))`

---

## 5. Iconografía del Sistema (SF Symbols)

Se emplean exclusivamente símbolos del catálogo de **SF Symbols** de Apple, garantizando alineación visual con el resto del sistema operativo:

* **Impresión / Cola:** `printer.fill`, `doc.text.fill`, `tray.and.arrow.down.fill`
* **Escáner:** `scanner.fill`, `doc.viewfinder.fill`, `camera.metering.center.weighted`
* **InkSaver:** `drop.triangle.fill`, `leaf.fill`, `slider.horizontal.2.square.badge.arrow.down`
* **Suministros / Tanques:** `drop.fill`, `gauge.medium`, `exclamationmark.triangle.fill`
* **Mantenimiento:** `sparkles`, `wrench.and.screwdriver.fill`, `arrow.triangle.2.circlepath`
* **Diagnóstico:** `stethoscope`, `checkmark.seal.fill`, `terminal.fill`
* **Ajustes:** `gearshape.fill`, `switch.2`, `lock.shield.fill`

---

## 6. Aviso Legal y Nominativo de Marca (Brand Disclaimer)

En la pantalla *Acerca de* y en los encabezados de la aplicación se incluye el texto normativo:

```text
TankControl es un proyecto de software libre independiente.
"HP" y "Smart Tank" son marcas comerciales registradas propiedad de HP Inc.
"macOS", "Apple Silicon", "AirPrint" y "ColorSync" son marcas registradas de Apple Inc.
Este software no ha sido creado, patrocinado, certificado ni respaldado por HP Inc. ni por Apple Inc.
Todas las marcas se utilizan exclusivamente para propósitos de identificación técnica de compatibilidad según la doctrina de uso leal nominativo (nominative fair use).
```
