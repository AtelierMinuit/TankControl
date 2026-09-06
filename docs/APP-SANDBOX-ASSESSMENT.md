# Evaluación de Seguridad y Factibilidad de App Sandbox — TankControl

**Producto:** TankControl for macOS  
**Documento:** Evaluación de Confinamiento de Aplicación (App Sandbox Assessment)  
**Fecha:** 2026-09-05  
**Estado:** INFORME TÉCNICO DE SEGURIDAD  

---

## 1. Objetivo del Análisis

Determinar si la aplicación de escritorio **TankControl** puede o debe ejecutarse con el atributo de seguridad **App Sandbox** (`com.apple.security.app-sandbox`) habilitado en macOS, identificando las restricciones impuestas por Apple, los requisitos de acceso a hardware y el impacto sobre la arquitectura del controlador.

---

## 2. Requisitos de Acceso del Sistema

Para proporcionar sus funciones sin degradación, TankControl interactúa con tres subsistemas clave de macOS:

| Subsistema | Recurso del Sistema | Permisos Requeridos | Compatibilidad con App Sandbox |
| :--- | :--- | :--- | :--- |
| **Acceso USB Físico** | `/dev/bus/usb` / `IOKit.framework` / `libusb-1.0` | Control de dispositivos USB específicos por VID/PID (`0x03f0:0x2b54`) | **Limitado:** App Sandbox ofrece `com.apple.security.device.usb`, pero restringe interfaces de clase específica (`0xff` vendor-specific) a menos que se implemente un DriverKit DEXT certificado. |
| **Spooler CUPS** | Socket Unix `/var/run/cupsd` y utilidades `/usr/bin/lp*` | Consulta de colas de impresión, estado de trabajos y cancelación | **Bloqueado:** El sandbox estándar de macOS prohíbe la comunicación IPC con demonios del sistema no confinados a través de sockets de dominio Unix locales. |
| **Binarios Auxiliares** | `/Contents/Helpers/hp-smart-tank-tool`, `/Contents/Helpers/hp_scan` | Ejecución de subprocesos locales mediante `Process()` | **Permitido:** Siempre que los binarios auxiliares se firmen con el mismo Team ID y residan estrictamente dentro de `Contents/Helpers/`. |
| **Red Local (eSCL)** | Loopback TCP `127.0.0.1:8089` | Comunicación con el puente HTTP eSCL local | **Permitido:** Con el derecho `com.apple.security.network.client`. |

---

## 3. Análisis de Privilegios y Separación de Root

Uno de los principios de diseño de TankControl es la **estricta segregación de privilegios**:

### 3.1 Operaciones Cotidianas (No Privilegiadas)
Ninguna de las siguientes operaciones requiere privilegios de superusuario (`root`) ni solicitud de contraseñas de administrador:
- Consulta de estado y telemetría de consumibles (K, C, M, Y).
- Captura de escaneo óptico por USB (ejecutado en espacio de usuario a través de `libusb`).
- Envío de trabajos de impresión a colas CUPS existentes.
- Cancelación o pausa de trabajos propios del usuario.
- Ajuste de perfiles locales de InkSaver.

### 3.2 Operaciones Administrativas (Instalación Inicial)
La configuración del sistema que requiere privilegios elevados comprende exclusivamente:
- Escritura en directorios protegidos del sistema (`/usr/libexec/cups/filter/` y `/Library/Printers/PPDs/`).
- Registro del servicio persistente en `/Library/LaunchAgents/com.hp.smarttank.airscan.plist`.
- Creación de colas de impresión compartidas con `lpadmin`.

> [!IMPORTANT]
> **Política de Privilegios:** Estas acciones administrativas se ejecutan **única y exclusivamente durante el proceso de instalación mediante el paquete oficial `.pkg`**, nunca desde la interfaz de usuario de la aplicación en tiempo de ejecución. La aplicación SwiftUI nunca invoca `sudo` ni solicita credenciales de administración.

---

## 4. Veredicto y Hoja de Ruta

### Veredicto Actual: App Sandbox NO Habilitado
Habilitar App Sandbox en esta fase rompería de inmediato la comunicación con el spooler local de CUPS (`/var/run/cupsd`) y bloquearía las transferencias de control USB de bajo nivel sobre las interfaces de gestión (`0xff/0x04/0x01`). Por tanto, la aplicación se distribuirá como aplicación nativa de macOS no confinada (firmada ad-hoc o con certificado Developer ID de Apple para Gatekeeper).

### Hoja de Ruta para Confinamiento Futuro (macOS 15+)
1. **Migración a DriverKit (USBDriverKit):** Reemplazar `libusb` por un DEXT de usuario firmado por Apple que gestione las interfaces `0x03f0:0x2b54` sin requerir acceso desprotegido a IOKit.
2. **Servicio Privilegiado con `SMAppService`:** Utilizar el framework moderno `ServiceManagement` para delegar operaciones de spooling a un demonio de fondo seguro.
3. **Sandbox Completo:** Habilitar el sandbox una vez que la arquitectura DriverKit esté consolidada.
