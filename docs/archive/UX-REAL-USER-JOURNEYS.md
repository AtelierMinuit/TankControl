# HP Smart Tank 500 — Flujos de Experiencia de Usuario en Hardware Real (UX Journeys)

**Versión de Referencia:** `0.1.0-alpha-pre-hardware`  
**Dispositivo Físico:** HP Smart Tank 500 (`0x03F0:0x2B54`), Serie `CN1924S1W7`  
**Entorno Operativo:** macOS 15+ Apple Silicon (ARM64), CUPS 2.3.4+, USB 2.0 High-Speed  

---

## Introducción y Filosofía de Diseño

A diferencia del software oficial de fabricante (HP Smart), el cual impone registro de cuenta obligatorio, conexión a internet, telemetría continua y tiempos de inicio lentos basados en frameworks web/Electron, **TankControl (HP Smart Tank Utility)** está diseñado con tres principios inviolables:

1. **Nativo y Transparente:** Aplicación Swift/SwiftUI compilada nativamente para Apple Silicon. Arranque en <300 ms, consumo de RAM <45 MB.
2. **Sin Servidumbre a la Nube:** Operación 100% local a través de la pila USB/CUPS/eSCL de macOS. Cero recolección de datos, cero cuentas, cero publicidad.
3. **Honestidad Técnica:** Jamás inventar niveles de tinta cuando no hay sensores físicos capacitivos. Explicar claramente al usuario la diferencia entre conteo algorítmico de gotas (`dropCount`) e inspección visual de las ventanas del tanque.

A continuación se detallan los 5 flujos canónicos de usuario basados en el comportamiento validado con hardware real.

---

## Flujo 1: Primera Conexión y Detección Automática (Plug & Play)

### Perfil de Usuario
Usuario que acaba de desempacar o conectar su HP Smart Tank 500 por cable USB a su Mac y necesita comenzar a trabajar de inmediato sin fricción.

### Secuencia de Pasos
1. **Conexión Física:** El usuario conecta el cable USB-B a USB-A/C en la Mac.
2. **Detección del Sistema:** macOS IOKit detecta el dispositivo:
   - Vendor ID: `0x03F0` (HP Inc.)
   - Product ID: `0x2B54` (Smart Tank 500 series)
   - Serial: `CN1924S1W7`
3. **Lanzamiento de TankControl:** El usuario abre la app (o el LaunchAgent opcional la activa).
4. **Verificación en Segundo Plano (0–1.5s):**
   - La app consulta la presencia de la cola CUPS (`lpstat -v`).
   - Se ejecuta en hilo desacoplado `hp-smart-tank-tool status` vía Interfaz USB 2 (`ff/04/01`, EP `0x86`).
   - La respuesta XML (`ProductStatusDyn.xml`) reporta: `<pscat:StatusCategory>genuineHP</pscat:StatusCategory>` y `<psdyn:LocString lang="es">Depós. llenos</psdyn:LocString>`.
5. **Respuesta Visual en UI:**
   - La tarjeta superior del Dashboard pasa instantáneamente de "Buscando impresora..." a:
     `HP Smart Tank 500 series` [Badge Verde: **EN LÍNEA (LIVE)**].
   - Mensaje de estado: *"Lista y en reposo (Depósitos llenos)"*.
   - Se habilitan inmediatamente los botones de acción rápida: `Escanear`, `Abrir Cola`, `Actualizar`.

### Criterios de Éxito de UX
- **Tiempo total hasta estado listo:** ≤ 2.0 segundos.
- **Acciones requeridas del usuario:** Cero clics de configuración si el driver está instalado.
- **Transparencia:** Si no existe la cola CUPS, la app ofrece un botón de 1 clic: *"Crear Cola de Impresión Nativa"* que invoca `lpadmin` sin abrir navegadores web.

---

## Flujo 2: Consulta Rápida de Tinta y Salud de Cabezales

### Perfil de Usuario
Estudiante o profesional a punto de imprimir un reporte extenso de 50 páginas a color que necesita verificar si cuenta con suficiente tinta y si los cabezales están en condiciones óptimas.

### Secuencia de Pasos
1. **Acceso al Dashboard:** El usuario abre TankControl o hace clic en la sección **Tinta** de la barra lateral (1 clic desde cualquier vista).
2. **Visualización de Niveles (Gauges Físicos):**
   - Se presentan 4 columnas estilizadas que replican la disposición física del frontal de la HP Smart Tank 500:
     - **K (Negro - GT51):** Contenedor grande a la izquierda (135 ml).
     - **C (Cian - GT52):** Contenedor intermedio (70 ml).
     - **M (Magenta - GT52):** Contenedor intermedio (70 ml).
     - **Y (Amarillo - GT52):** Contenedor intermedio (70 ml).
3. **Mensaje de Honestidad Física (Crucial):**
   - Debajo de los indicadores se muestra una nota informativa con icono de ojo `eye`:
     > *"Aviso de Medición: La HP Smart Tank 500 utiliza conteo estimado de microgotas (dropCount). No posee flotadores eléctricos internos. Confirme siempre el nivel real observando las ventanas transparentes en el frontal de su equipo."*
4. **Estado de Cabezales (Printheads):**
   - Estado reportado por firmware: `newGenuineHP` (Cabezales originales HP detectados, sin errores de contacto ni circuitos abiertos).

### Criterios de Éxito de UX
- **Tiempo de lectura:** Menos de 5 segundos para comprender los niveles.
- **Claridad cognitiva:** El usuario nunca es engañado con un falso 100% si físicamente ha dejado vaciar el tanque. Se le enseña a mirar la ventana física.

---

## Flujo 3: Impresión Cotidiana, Monitoreo y Cancelación Segura

### Perfil de Usuario
Usuario que imprime un PDF o documento desde cualquier aplicación de macOS (Safari, Vista Previa, Pages, Word) y requiere supervisar el trabajo o cancelarlo de urgencia tras notar un error en la primera página.

### Secuencia de Pasos
1. **Envío desde la App del Sistema:**
   - El usuario pulsa `⌘P` en su aplicación.
   - En el diálogo de impresión de macOS selecciona la impresora `HP Smart Tank 500`.
   - Puede seleccionar opciones avanzadas provistas por el PPD: *InkSaver (Ahorro 30%)*, *Calidad Normal (600 DPI)* o *Borrador Rápido (300 DPI)*.
2. **Monitoreo en TankControl (Sección Impresión):**
   - La app detecta el trabajo entrante en el spooler CUPS.
   - Estado en tiempo real:
     - `En cola (Pending)` → `Procesando PCL3GUI (Filtering)` → `Transmitiendo USB (Sending)` → `Imprimiendo hoja 1/5`.
   - La interfaz no se congela en ningún momento gracias a la ejecución asíncrona en colas GCD secundarias.
3. **Cancelación de Emergencia (1 clic):**
   - El usuario pulsa el botón rojo *"Cancelar Trabajo"* en la fila del trabajo activo.
   - TankControl envía `cancel <job_id>` al subsistema CUPS.
   - El backend USB cierra limpiamente el stream PCL3GUI enviando la secuencia UEL (`\033%-12345X`) para forzar la expulsión de la página actual sin atascar el carro mecánico.
   - La cola vuelve al estado *"En reposo"* en < 3 segundos.

### Criterios de Éxito de UX
- **Velocidad de reacción:** Cancelación efectiva en < 3 segundos desde la pulsación.
- **Acceso rápido a cola:** Botón accesible desde el Dashboard principal o mediante el atajo estándar `⌘O`.

---

## Flujo 4: Escaneo Rápido vs. Avanzado de Documentos

### Perfil de Usuario
Usuario que necesita digitalizar un contrato firmado o una fotografía en color utilizando la platina plana A4 (CIS) de la Smart Tank 500.

### Secuencia de Pasos
1. **Colocación del Original:** El usuario levanta la tapa y alinea el documento con la esquina superior derecha de la platina de cristal.
2. **Navegación en TankControl:** Clic en la pestaña **Escáner** en la barra lateral.
3. **Selección de Parámetros:**
   - **Preajustes rápidos de 1 clic:**
     - *Documento Rápido:* 150 DPI, Blanco y Negro / Gris, Formato PDF.
     - *Documento Estándar:* 300 DPI, Color, Formato PDF con compresión.
     - *Fotografía Alta Calidad:* 600 DPI, Color 24 bits, Formato PNG/TIFF.
4. **Ejecución del Escaneo:**
   - Clic en *"Escanear"*.
   - La app despacha la petición al motor nativo `hp_scan` / bridge eSCL (`POST /Scan/Jobs` sobre interfaz USB `ff/cc/00` o `ff/04/01`).
   - La interfaz muestra una barra de progreso suave indicando: *"Moviendo cabezal óptico... Recibiendo datos JPEG (XX%)"*.
5. **Previsualización y Destino:**
   - Al terminar, se muestra la imagen completa en el visor interactivo.
   - Botones directos: *"Guardar en Descargas"*, *"Guardar en Documentos"*, *"Compartir..."* o *"Abrir en Vista Previa"*.

### Criterios de Éxito de UX
- **Cero bloqueos:** La barra de menús y demás secciones de la app permanecen responsivas mientras el motor del escáner está en movimiento.
- **Compatibilidad macOS:** Capacidad opcional de abrir el escáner directamente en *Captura de Imagen* de Apple vía el bridge eSCL local.

---

## Flujo 5: Diagnóstico, Recuperación de Errores y Mantenimiento Seguro

### Perfil de Usuario
Usuario que experimenta un problema mecánico (bandeja de entrada sin hojas, tapa levantada accidentalmente, atasco de papel o rayas blancas en la impresión).

### Secuencia de Pasos
1. **Detección Inmediata del Incidente:**
   - La impresora emite el estado de hardware en `ProductStatusDyn.xml`:
     - `<pscat:StatusCategory>mediaEmpty</pscat:StatusCategory>` o `closeDoorOrCover`.
2. **Notificación Amigable y Asistida:**
   - El badge del Dashboard cambia a color naranja o rojo: **ATENCIÓN REQUERIDA**.
   - Mensaje claro y humano:
     - *Sin papel:* *"La bandeja de alimentación trasera no tiene papel. Coloque hojas tamaño Carta o A4 y presione el botón Reanudar en la impresora."*
     - *Cubierta abierta:* *"La puerta de acceso a los cabezales está abierta. Ciérrela firmemente para continuar."*
3. **Mantenimiento Preventivo Guiado (Sección Mantenimiento):**
   - Si la impresión presenta rayas, el usuario va a **Mantenimiento**.
   - **Nivel 1 (Seguro - Diario):** *"Imprimir Patrón de Prueba de Inyectores"* (Gasta <0.02 ml de tinta).
   - **Nivel 2 (Limpieza Normal):** *"Limpiar Cabezales de Impresión (Ciclo Básico)"* (Gasta ~1.2 ml). Diálogo explicativo antes de iniciar.
   - **Nivel 3 (Peligroso / Alto Impacto - Deep Clean / Prime Tubes):**
     - Oculto bajo confirmación explícita con candado y aviso en rojo:
       > *"¡ADVERTENCIA DE ALTO CONSUMO! Este proceso bombea ~15 ml de tinta líquida directamente al depósito residual. Utilícelo ÚNICAMENTE si las mangueras de tinta contienen burbujas de aire vacías tras meses sin uso."*

### Criterios de Éxito de UX
- **Prevención de desastres:** Ningún usuario puede activar accidentalmente una purga profunda de tinta con un clic casual.
- **Claridad de resolución:** El usuario sabe exactamente qué acción física ejecutar sin necesidad de consultar el manual impreso.
