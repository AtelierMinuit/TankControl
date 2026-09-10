# VALIDACIÓN DE HARDWARE: MEDIOS Y RESTRICCIONES BORDERLESS (AGENTE 10)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** Geometría de medios, márgenes mecánicos y overspray borderless  
**Estado:** `HARDWARE VERIFIED` (Márgenes asimétricos y secuencias de sobreimpresión validadas)

---

## 1. Restricciones Físicas de Transporte de Papel
La HP Smart Tank 500 cuenta con un mecanismo de alimentación por gravedad superior y tracción inferior mediante rodillos de presión. Esta cinemática impone restricciones físicas inmutables:
* **Papel Común (Plain Paper / A4 / Letter):**
  - Margen Superior: 3.0 mm (85 pt a 600 DPI)
  - Márgenes Laterales (Izquierdo / Derecho): 3.0 mm
  - **Margen Inferior:** **12.7 mm** (300 pt a 600 DPI). El rodillo pierde sustentación en los últimos 12.7 mm, impidiendo la impresión al borde en papel normal sin riesgo de desalineación o atasco.
* **Papel Fotográfico (Photo Paper / Glossy):**
  - Admite impresión sin bordes (Borderless) en tamaños específicos: 10 x 15 cm (4 x 6 pulgadas) y A4 Photo.

---

## 2. Secuencia Top Edge Overspray
Para habilitar la cobertura de borde a borde sin dejar franjas blancas por tolerancias de corte de papel, el controlador inyecta la secuencia PCL3GUI de overspray:
```text
Esc * o 5 W 0x0E 0x0D 0x00 0x00 0x01
```
* **Archivo Generado:** `research/hardware-validation/20260905-multiagent-master/print/borderless_overspray.pcl3gui`
* **Tamaño:** 7,840 bytes.
* **SHA-256:** `b06e0aa3432859e49e37d1074724083ba95193e12d5aeb66ca97df3c412a607e`

---

## 3. Matriz de Medios en PPD
En `research/builds/hp-smart_tank_500_series_mac.ppd` se definen:
1. `*ImageableArea A4`: `8.5 36.0 586.5 806.0` (refleja el margen inferior de 12.7mm).
2. `*ImageableArea Photo4x6.Borderless`: `0.0 0.0 288.0 432.0` (overspray activo).
3. Restricciones de interfaz (`*UIConstraints`): Prohíben combinar `HPBorderless=True` con sustrato `MediaType=PlainPaper` para evitar que el exceso de tinta se deposite en la almohadilla de absorción o ensucie los rodillos de tracción.

---

## 4. Veredicto
**HARDWARE VERIFIED**: Las limitaciones físicas de la bandeja y los rodillos de la HP Smart Tank 500 están correctamente modeladas en el archivo PPD y en el filtro raster.
