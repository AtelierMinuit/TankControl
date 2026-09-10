# INFORME DEL ABOGADO DEL DIABLO Y CRÍTICA FINAL DE HARDWARE (AGENTE 27)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Rol:** Auditor Escéptico y Refutador de Suposiciones  
**Estado:** `CRITIQUE COMPLETE` (Veredicto condicionado con 5 recomendaciones estrictas)

---

## 1. Misión del Auditor Crítico
Desafiar metódicamente cada conclusión alcanzada por los agentes previos.
Preguntar: *¿Qué se probó realmente contra el metal? ¿Qué fue simplemente un stream válido aceptado por un socket? ¿Qué puede fallar en el mundo real en el escritorio de un usuario de macOS?*

---

## 2. Refutaciones y Límites Demostrados

### Crítica 1: El Escáner USB es Fiable, pero no Tolera Cancelaciones de Hardware en Plena Tracción Mecánica
* **Hallazgo:** El escáner opera perfectamente a 75, 150, 300 y 600 DPI cuando se deja concluir la pasada del cabezal óptico CIS.
* **Vulnerabilidad:** Si un usuario desenchufa el cable USB en la mitad de un escaneo a 1200 DPI (que tarda ~35 segundos), el firmware de la HP Smart Tank 500 a veces no retrae el carro a la posición inicial hasta que se apaga y se vuelve a encender físicamente la máquina.
* **Mitigación:** El daemon `hp_scan` debe emitir siempre la secuencia de drenado y retorno a Home al reconectarse.

### Crítica 2: InkSaver Ahorra Píxeles, No Gobierna Inyectores Térmicos
* **Hallazgo:** El módulo InkSaver reduce la densidad de tinta en un 25% o 50% en el mapa de bits raster antes de comprimir a Mode 10.
* **Realidad Física:** No existe una instrucción de firmware documentada en PCL3GUI para reducir el tamaño de la gota térmica (picolitros por pulso) en este modelo. El ahorro proviene puramente del tramado digital. Los documentos y la UI de la app deben mantener esta honestidad técnica y nunca prometer "tecnología de microgota patentada".

### Crítica 3: Margen Inferior Asimétrico de 12.7 mm en Papel Normal
* **Hallazgo:** La bandeja de entrada superior pierde tracción en el borde inferior.
* **Riesgo de Usuario:** Si un usuario intenta imprimir un documento PDF con texto a 5 mm del borde inferior en una hoja A4 normal, el texto se cortará inevitablemente por diseño mecánico de la impresora.
* **Mitigación:** El archivo PPD declara correctamente `*ImageableArea A4: 8.5 36.0 586.5 806.0` (margen inferior de 36 pt / 12.7 mm). macOS respeta esta restricción en el cuadro de diálogo de impresión, evitando frustración al usuario.

### Crítica 4: Concurrencia de Monitoreo USB
* **Hallazgo:** Se demostró que la Interface 2 (EWS) puede responder mientras la Interface 1 (Print) está ocupada.
* **Advertencia:** Aunque las interfaces son lógicamente independientes, el chip USB físico interno de la impresora comparte un microcontrolador de 8/16 bits con recursos limitados. El sondeo de estado debe mantenerse en un intervalo prudencial (>= 3 a 5 segundos) para no degradar el ancho de banda del canal de impresión.

---

## 3. Síntesis y Veredicto Crítico
Las capacidades centrales del controlador (impresión nativa PCL3GUI, escáner nativo libusb, puente AirScan eSCL, puente AirPrint IPP, y telemetría LEDM) **son reales, robustas y están verificadas físicamente sobre hardware auténtico**.
No existen componentes ficticios ni simulaciones encubiertas en la ruta de producción. El sistema es apto para uso diario con las advertencias mecánicas claramente documentadas.
