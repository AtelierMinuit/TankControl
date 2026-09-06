# Árbol de Diagnóstico y Resolución de Problemas — TankControl

**Producto:** TankControl for macOS  
**Documento:** Guía de Soporte y Árbol de Decisión Offline (Troubleshooting Tree)  
**Fecha:** 2026-09-05  
**Estado:** GUÍA TÉCNICA Y DE ASISTENCIA  

---

## 1. Principio del Asistente de Diagnóstico

Este árbol de resolución de problemas funciona de manera **100% local, determinista y sin requerir conexión a Internet ni servicios externos**. Está diseñado para integrarse tanto en la vista de ayuda de la aplicación (`HelpView`) como en la documentación de soporte técnico.

---

## 2. Árbol de Decisión por Casos de Falla

```
                                 ¿Cuál es el síntoma observado?
                                               │
      ┌──────────────────┬─────────────────────┼─────────────────────┬──────────────────┐
      ▼                  ▼                     ▼                     ▼                  ▼
[1. No detecta USB] [2. Trabajo atascado] [3. Página en blanco] [4. Escáner falla] [5. AirPrint falta]
```

---

### Caso 1: La impresora no aparece o figura como "Desconectada"

```
[¿Está el cable USB conectado directamente a un puerto del Mac?]
  ├── NO ──► Conectar directamente a un puerto del Mac (evitar concentradores USB no energizados).
  └── SÍ
       ▼
[¿Aparece el dispositivo en el reporte de hardware de macOS?]
(Ejecutar en Terminal: system_profiler SPUSBDataType | grep -i "0x2b54")
  ├── NO ──► 1. Verificar si la pantalla LED de la impresora está encendida.
  │          2. Probar con otro cable USB Tipo B estándar.
  │          3. Comprobar que no haya un reinicio de ciclo de energía en curso.
  └── SÍ
       ▼
[¿Está cargado el backend en el spooler CUPS?]
(Ejecutar: lpstat -s | grep -i "smarttank")
  ├── NO ──► La cola CUPS no ha sido creada. Ejecutar el instalador PKG o crear cola con:
  │          lpadmin -p HP_Smart_Tank_500 -v smarttank://HP/Smart%20Tank%20500 -E
  └── SÍ ──► Comprobar permisos en `/usr/libexec/cups/backend/smarttank` (debe ser 0755 root:wheel).
```

---

### Caso 2: El trabajo de impresión se queda en cola ("Procesando..." o atascado)

```
[¿Indica la app una advertencia física (Cubierta abierta / Sin papel / Atasco)?]
  ├── SÍ ──► Corregir la condición física: cerrar cubierta frontal o recargar papel en bandeja.
  └── NO
       ▼
[¿Hay un error registrado en el log local de CUPS?]
(Consultar en Terminal: tail -n 50 /var/log/cups/error_log)
  ├── "Permission denied" ──► Reparar permisos de filtros: chmod 755 /usr/libexec/cups/filter/rastertopcl3gui
  ├── "Filter failed"      ──► El archivo enviado no es compatible con CUPS Raster (verificar formato).
  └── "Backend failed"     ──► Desconectar y reconectar el cable USB para restablecer el endpoint libusb.
```

---

### Caso 3: La hoja sale en blanco o falta el color negro

```
[¿Tienen los tanques frontales tinta visible sobre la línea mínima?]
  ├── NO ──► Recargar inmediatamente con tinta original HP GT51/GT53 (negro) o GT52 (color).
  └── SÍ
       ▼
[¿Hay burbujas continuas de aire en las mangueras transparentes del CISS?]
  ├── SÍ ──► Ir a Mantenimiento → Modo Técnico → "Cebado de Tubos CISS" (requiere confirmación).
  └── NO
       ▼
[¿Están tapados los inyectores del cabezal térmico?]
  ├── Ejecutar: Mantenimiento → "Patrón de Inyectores" (Nozzle Check).
  ├── Si faltan líneas: Ejecutar "Limpieza Básica de Cabezales".
  └── Si persiste tras 2 limpiezas: Esperar 30 min y ejecutar "Purga Profunda" (evitar repeticiones innecesarias).
```

---

### Caso 4: El escáner no responde o reporta "Error de comunicación"

```
[¿Está la aplicación de captura de imagen de Apple bloqueando la interfaz?]
  ├── SÍ ──► Cerrar Captura de Imagen u otras aplicaciones que usen la cámara/escáner.
  └── NO
       ▼
[¿Está corriendo el puente eSCL local?]
(Ejecutar: curl -s http://127.0.0.1:8089/eSCL/ScannerStatus)
  ├── Retorna XML ──► El puente eSCL está activo; reiniciar la app TankControl.
  └── Fallo de conexión
       ▼
  ├── Iniciar el servicio con: launchctl load ~/Library/LaunchAgents/com.hp.smarttank.airscan.plist
  └── O ejecutar escaneo nativo directo mediante CLI: hp_scan -o escaneo.jpg
```

---

### Caso 5: La impresora no aparece para AirPrint en iPhone o iPad

```
[¿Están el Mac y el dispositivo iOS conectados a la misma red Wi-Fi local?]
  ├── NO ──► Conectar ambos dispositivos a la misma subred (mismo SSID y sin aislamiento de clientes).
  └── SÍ
       ▼
[¿Está el Mac encendido con la sesión de usuario abierta?]
  ├── NO ──► TankControl funciona como servidor AirPrint puente; el Mac debe estar activo.
  └── SÍ
       ▼
[¿Está habilitada la compartición de impresoras en macOS?]
(Comprobar en Ajustes del Sistema → General → Compartir → Compartir Impresora)
  ├── Desactivado ──► Activar "Compartir impresora" y marcar la casilla de "HP_Smart_Tank_500".
  └── Activado   ──► Verificar emisión mDNS: dns-sd -B _ipp._tcp local.
```
