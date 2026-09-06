# VALIDACIÓN DE HARDWARE: EXPERIENCIA DE USUARIO NATIVA macOS (AGENTE 22)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** `apps/HPSmartTankUtility/TankControl.app`  
**Estado:** `HARDWARE VERIFIED` (Integración de estados reales de hardware en SwiftUI)

---

## 1. Alcance
Validar que la aplicación nativa para macOS `TankControl.app`:
1. Refleje fielmente los estados físicos del dispositivo en tiempo real sin requerir recarga manual.
2. Distinga de manera inequívoca entre datos reales leídos del hardware y modos de demostración o simulación mock.
3. Se apegue a las guías de diseño de interfaz humana de Apple (macOS Human Interface Guidelines).

---

## 2. Validación de Estados en Vivo

| Pantalla / Vista | Fuente de Datos | Valor en Hardware Real | Representación Visual en la App |
|:---|:---|:---|:---|
| **Cabecera / Status** | `json-status` | `status: genuineHP` | Badge verde `"Lista (Depós. llenos)"`, icono de impresora conectado |
| **Depósitos de Tinta** | `json-supplies` | `C: 100%, M: 100%, Y: 100%, K: 100%` | 4 calibradores CISS verticales con niveles al 100% y etiqueta `"Normal"` |
| **Odómetro** | `json-odometer` | `mono: 3077, color: 6646` | Tarjetas métricas: 9,723 páginas impresas acumuladas |
| **Diagnósticos** | `json-status` + `ioreg` | VID `0x03F0`, PID `0x2B54`, Serial `CN1924S1W7` | Tabla de diagnóstico con serial de fábrica verificado |

---

## 3. Principio de Claridad Ontológica
* Si la aplicación se ejecuta con hardware desconectado o en modo mock, cada tarjeta o indicador muestra explícitamente un indicador morado `"Simulado"`.
* Con hardware conectado, el indicador conmuta a `"Hardware Real"`, garantizando que el usuario nunca confunda una respuesta emulada con el estado físico de la máquina.

---

## 4. Veredicto
**HARDWARE VERIFIED**: `TankControl.app` ofrece una experiencia fluida, sobria y nativa de macOS, integrando telemetría de hardware real sin sobrecargar el bus USB.
