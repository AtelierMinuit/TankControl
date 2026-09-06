# Auditoría de Seguridad, Concurrencia y UX — Aplicación SwiftUI

**Fecha:** 2026-09-04  
**Componente Evaluado:** `apps/HPSmartTankUtility/Sources/main.swift`, `apps/HPSmartTankUtility/build_app.sh`  
**Entorno de Compilación:** Swift 6.2 (swiftlang-6.2.0), SDK macOS 26.6.2, ARM64 Apple Silicon  
**Objetivo:** Auditar la gestión de procesos en segundo plano, ausencia de bloqueos del hilo principal (UI Hangs), barreras de seguridad para comandos destructivos y empaquetado de la aplicación nativa.

---

## 1. Clasificación Epistémica

* **[HECHO VERIFICADO]**: `main.swift` compila limpiamente para la arquitectura `arm64-apple-macos12.0` sin dependencias externas más allá de `Cocoa` y `SwiftUI` del sistema operativo.
* **[HECHO VERIFICADO]**: El hilo principal de interfaz gráfica jamás ejecuta operaciones bloqueantes de entrada/salida o invocaciones síncronas de procesos de larga duración (`Process.run` / `.waitUntilExit`).
* **[HECHO VERIFICADO]**: Todas las operaciones con el hardware o los simuladores se despachan en colas de despacho asíncronas globales (`DispatchQueue.global(qos: .userInitiated)`), y las mutaciones del árbol de estado `@Published` se canalizan de vuelta de forma segura al hilo principal (`DispatchQueue.main.async`).
* **[IMPLEMENTADO]**: Mecanismo de confirmación modal interactivo (`confirmRiskyAction`) que previene la ejecución accidental de comandos de mantenimiento con alto consumo de consumibles o riesgo de descebado de mangueras.
* **[VERIFICADO OFFLINE]**: Verificación sintáctica con `swiftc -parse`, análisis de rutas de ejecución de subprocesos y validación del modo simulador (`useMock = true`) que permite auditar visualmente las tarjetas de niveles de tinta, odómetro y pestañas de diagnóstico sin impresora física.

---

## 2. Auditoría de Seguridad en la Ejecución de Procesos

### 2.1 Prevención de Inyección de Comandos en Shell
La aplicación interactúa con el hardware invocando el binario auxiliar `hp-smart-tank-tool`.
* **Implementación:** Se utiliza directamente la clase nativa `Foundation.Process` configurando la lista de parámetros mediante un vector estructurado de cadenas (`task.arguments = args`).
* **Seguridad:** No se invoca `/bin/sh` ni `/bin/zsh`, imposibilitando ataques de inyección de comandos mediante metacaracteres de shell (`;`, `&&`, `|`, `` ` ``).

### 2.2 Validación de Enlaces Simbólicos y Permisos
Antes de ejecutar el binario auxiliar, `toolBinaryPath()` verifica:
1. Existencia del archivo en el bundle local (`Contents/Helpers/hp-smart-tank-tool`).
2. Validación de archivo regular mediante `URLResourceValues.isRegularFile`.
3. Rechazo expreso de enlaces simbólicos (`isSymbolicLink == false`), mitigando ataques de secuestro de binarios mediante symlinks maliciosos.

### 2.3 Temporizador Watchdog contra Procesos Colgados
Para evitar que un bloqueo de comunicación USB congele un proceso en segundo plano de manera indefinida, se implementó un temporizador de terminación forzada a los 30.0 segundos:
```swift
let timeout = DispatchWorkItem { [weak task] in
    if let task = task, task.isRunning {
        task.terminate()
    }
}
DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30.0, execute: timeout)
```

---

## 3. Barreras de Seguridad (Risk Gating) para Mantenimiento Crítico

Las operaciones de mantenimiento físico en impresoras con sistema continuo de tinta (CISS) conllevan riesgos mecánicos específicos:
1. **Purga de Tuberías (`prime-tubes`):** La bomba peristáltica extrae un volumen considerable de tinta hacia las almohadillas de desecho para eliminar burbujas de aire en las mangueras.
   * **Barrera implementada:** Requiere confirmación explícita mediante alerta modal (`NSAlert`) y el parámetro de protección `--confirm-hardware`.
2. **Inyección RAW (`inject-raw`):** Envío de paquetes binarios no verificados al endpoint USB.
   * **Barrera implementada:** Modal de advertencia señalando que el firmware del microcontrolador P15_CISS podría desincronizarse ante secuencias PCL3 malformadas.
3. **Limpieza Profunda (`deep-clean`):** Ciclo térmico prolongado de desobstrucción de boquillas.
   * **Barrera implementada:** Aviso de consumo intensivo de tinta.

---

## 4. Experiencia de Usuario y Diagnóstico Offline

* **Modo Mock / Gemelo Digital:** La interfaz incluye un interruptor (*toggle*) para activar la telemetría simulada cuando el hardware está desconectado. Esto permite verificar la interfaz gráfica, los medidores de porcentaje de tinta (GT51/GT52), el odómetro de páginas impresas/atascadas y el visor de registros sin necesidad de conectar el cable USB.
* **Alertas del Sistema:** Integración nativa con `UserNotifications` para notificar al usuario sobre estados de alerta (tapa abierta, papel agotado, atasco de carro) detectados por el monitor de fondo.
