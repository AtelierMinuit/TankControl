# Investigación y Solución de Escaneo — HP Smart Tank 500 (macOS ARM64)

> Estado de auditoría: la enumeración USB funciona, pero las lecturas físicas actuales de capacidades/estado terminan en timeout USB (`-7`). Una captura física controlada tampoco está demostrada.

Fecha de actualización: 2026-09-02 / 2026-09-03.

Prueba offline adicional 2026-09-04: el bridge mock respondió `ScannerCapabilities`/`ScannerStatus` con 200, creó un job con 201 y entregó `NextDocument` con 200 y JPEG válido de 22 bytes. Esta prueba no acredita captura USB física ni integración completa con Captura de Imagen.

El parser HTTP nativo rechaza ahora respuestas sin `Content-Length`, longitudes inválidas y `Transfer-Encoding: chunked`; esto evita aceptar cuerpos incompletos como capturas válidas. La captura física sigue sin estar demostrada.

---

## 1. Naturaleza del Hardware y Corrección de Hipótesis

* **Hardware real:** La **HP Smart Tank 500 es un dispositivo estrictamente USB** (no posee tarjeta Wi-Fi ni puerto Ethernet). Los modelos con conectividad inalámbrica corresponden a las series Smart Tank 515, 530 o superiores.
* **Corrección de supuesto anterior:**
  - *Anterior:* Se sugería "conectar la impresora a Wi-Fi para que macOS la detecte por AirScan".
  - *Realidad demostrada:* Al carecer de Wi-Fi, la Smart Tank 500 nunca emitirá mDNS por red. Además, su interfaz USB de escáner no es IPP-over-USB (`07/01/04`), sino **Vendor-Specific `0xff/0xcc/0x00` (LEDM sobre USB Bulk)**.
  - *Conclusión:* macOS `Image Capture` no puede descubrirla nativamente por USB sin un puente o driver intermedio.

---

## 2. Protocolo Descubierto: LEDM / eSCL sobre USB Bulk

A partir del análisis de `scan/sane/bb_ledm.c` y el bundle original `/Library/Image Capture/Devices/HP Scanner 3.app/.../HPLEDMScan.bundle`:
- La interfaz 0 (`0xff/0xcc/0x00`) transporta solicitudes **HTTP/1.1 REST estándar** encapsuladas sobre endpoints USB Bulk IN y Bulk OUT.
- **Endpoints:**
  - `GET /Scan/ScanCaps`: Devuelve especificaciones ópticas de la cama plana (resoluciones 75 a 1200 dpi, formatos JPEG/Raw).
  - `GET /Scan/Status`: Informa estado de la unidad (`Idle`, `Processing`, tapa, ADF).
  - `POST /Scan/Jobs`: Inicia el trabajo con payload XML `<ScanSettings>`.
  - `GET /Jobs/ScanJobs/<id>/Pages/1`: Transfiere el flujo de bytes binario de la imagen escaneada.

---

## 3. Arquitectura del Puente Local `hp_escl_bridge`

Para permitir que aplicaciones nativas de macOS (**Captura de Imagen**, **Vista Previa**, **Preferencias del Sistema**) utilicen el escáner sin requerir HP Smart App ni software cerrado de terceros (VueScan):

```text
[ Aplicación macOS ] (Image Capture / Preview / ImageKit)
       │
       ▼ (HTTP eSCL / Bonjour AirScan)
[ hp_escl_bridge.py ] (daemon local en 127.0.0.1:8089)
       │
       ▼ (USB Bulk transfer vía libusb-1.0)
[ HP Smart Tank 500 ] (Interfaz 0: 0xff/0xcc/0x00)
```

### Componentes Implementados:
1. **`tools/hp_escl_bridge.py`**:
   - Servidor HTTP ligero local que expone endpoints eSCL para pruebas y para un cliente AirScan:
     - `/eSCL/ScannerCapabilities` $\longleftrightarrow$ `/Scan/ScanCaps`
     - `/eSCL/ScannerStatus` $\longleftrightarrow$ `/Scan/Status`
     - `/eSCL/ScanJobs` $\longleftrightarrow$ `/Scan/Jobs`
     - `/eSCL/ScanJobs/<id>/NextDocument` $\longleftrightarrow$ `/Jobs/ScanJobs/<id>/Pages/1`
   - Anuncio automático en mDNS local mediante `dns-sd -R "HP Smart Tank 500" _uscan._tcp ...`; esto no demuestra que Captura de Imagen acepte el dispositivo ni que el transporte físico esté integrado.
2. **`tools/hp-smart-tank-tool`**:
   - Binario compilado en C nativo para consulta por línea de comandos directa de capacidades y estado del escáner.
3. **`tests/test_escl_bridge.py`**:
   - Suite de pruebas automatizadas offline que valida la canalización HTTP eSCL mock y la entrega de imágenes JPEG con encabezados y marcadores de imagen conformes (`0xFFD8` / `0xFFD9`). La captura física y la integración completa con Captura de Imagen siguen `NOT TESTED`.
