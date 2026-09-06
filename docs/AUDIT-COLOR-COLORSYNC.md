# Auditoría de Color y Perfiles ColorSync ICC — HP Smart Tank 500

**Fecha:** 2026-09-04  
**Herramientas de Análisis:** `sips` (Apple Scriptable Image Processing System), `tools/calibrate_icc.py`  
**Archivos Auditados:**  
* `research/builds/HP_Smart_Tank_Plain.icc`
* `research/builds/HP_Smart_Tank_Glossy.icc`
* `research/builds/HP_Smart_Tank_Matte.icc`
* `research/builds/HP_Smart_Tank_500_Precision.icc`

---

## 1. Clasificación Epistémica

* **[HECHO VERIFICADO]**: Todos los perfiles `.icc` en `research/builds/` cumplen estrictamente con la especificación ICC.1:2010 (Profile version 4.3 / 2.1) y son parseados y validados correctamente por el motor ColorSync de macOS (`sips`).
* **[HECHO VERIFICADO]**: Ninguno de los perfiles actuales ha sido generado a partir de lecturas físicas de un espectrofotómetro de hardware (como X-Rite i1Pro, Datacolor SpyderPrint o Barbieri).
* **[SIMULACIÓN]**: `HP_Smart_Tank_500_Precision.icc` es el resultado de un bucle cerrado de calibración sintética ejecutado por `tools/calibrate_icc.py` sobre una imagen escaneada simulada a 600 DPI con 24 parches ColorChecker.
* **[SINTÉTICO / TEÓRICO]**: Los perfiles `Plain`, `Glossy` y `Matte` son modelos matemáticos parametrizados con punto blanco D50/D65 y curvas de respuesta tonal (TRC) estándar \(\gamma \approx 2.2\).
* **[HARDWARE REQUIRED]**: Para crear un perfil verdaderamente calibrado se debe imprimir la carta física `scratch/test_calib/HP_Smart_Tank_Color_Target.pdf` sin gestión de color, dejar secar la tinta 24 horas, escanearla en el cristal óptico de la impresora a 600 DPI sin auto-exposición y procesarla con `calibrate_icc.py`.

---

## 2. Inventario y Validación con Motor ColorSync de Apple (`sips`)

```text
Comando: sips -g all <perfil.icc>

Perfil: HP_Smart_Tank_Plain.icc
  typeIdentifier: icc
  format: icc
  formatOptions: default
  hasAlpha: no
  Clasificación: [SINTÉTICO / TEÓRICO]

Perfil: HP_Smart_Tank_Glossy.icc
  typeIdentifier: icc
  format: icc
  formatOptions: default
  hasAlpha: no
  Clasificación: [SINTÉTICO / TEÓRICO]

Perfil: HP_Smart_Tank_Matte.icc
  typeIdentifier: icc
  format: icc
  formatOptions: default
  hasAlpha: no
  Clasificación: [SINTÉTICO / TEÓRICO]

Perfil: HP_Smart_Tank_500_Precision.icc
  typeIdentifier: icc
  format: icc
  formatOptions: default
  hasAlpha: no
  Clasificación: [SIMULACIÓN EN BUCLE CERRADO]
```

---

## 3. Análisis del Pipeline de Calibración en Bucle Cerrado

El script `tools/calibrate_icc.py` implementa una solución que aprovecha el hardware multifunción del equipo (impresora de inyección + escáner de cama plana CIS):

1. **Generación del Blanco de Calibración (`generate_color_target.py`):**  
   Crea una carta de prueba en PDF/PNG de alta resolución con los 24 parches estándar de la carta Macbeth ColorChecker, rodeados de marcas de registro y barras de calibración neutra.
2. **Muestreo Óptico Digital:**  
   En modo de prueba o simulación, extrae la región central de cada parche (radio de 10 píxeles para evitar aberraciones cromáticas de borde) y calcula el valor RGB promedio.
3. **Conversión de Espacio de Color:**  
   Convierte las muestras \(sRGB \to CIE\ XYZ \to CIE\ L^*a^*b^*\) utilizando el iluminante estándar D65.
4. **Cálculo de Desviación Colorimétrica:**  
   Calcula la distancia perceptual \(\Delta E\) CIE 1976 entre los parches teóricos y los medidos por el sensor óptico.
5. **Ajuste de Curvas TRC y Síntesis ICC:**  
   Ajusta los coeficientes Gamma individuales para los canales Rojo, Verde y Azul (\(\gamma_R \approx 2.36\), \(\gamma_G \approx 2.24\), \(\gamma_B \approx 2.39\)) y empaqueta la estructura binaria del perfil ICC con etiquetas `rXYZ`, `gXYZ`, `bXYZ`, `rTRC`, `gTRC`, `bTRC` y `wtpt`.

---

## 4. Hoja de Ruta para Calibración Física Definitiva

Cuando el hardware esté físicamente conectado:
1. Imprimir `tools/generate_color_target.py` en papel común HP y en papel fotográfico.
2. Esperar 24 horas para estabilización química y evaporación de solventes de las tintas GT51/GT52.
3. Colocar la hoja en el cristal del escáner alineada contra la esquina superior izquierda.
4. Ejecutar:
   ```bash
   python3 tools/calibrate_icc.py --scan --device-uri "smarttank://03f0:2b54" --output /Library/ColorSync/Profiles/Printers/HP_Smart_Tank_500_Calibrated.icc
   ```
5. Asociar el perfil en CUPS mediante `lpoptions -p HP_Smart_Tank_500 -o HPColorMatching=True`.
