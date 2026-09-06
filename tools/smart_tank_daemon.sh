#!/bin/bash
# smart_tank_daemon.sh - Control del demonio AirScan / eSCL para HP Smart Tank 500

DIR="$(cd "$(dirname "$0")" && pwd)"
umask 077
STATE_DIR="${TMPDIR:-/tmp}/hp-smart-tank"
if [ -L "$STATE_DIR" ]; then
    echo "[smart_tank] ERROR: directorio de estado es un symlink; se aborta." >&2
    exit 1
fi
if [ ! -d "$STATE_DIR" ]; then
    mkdir -m 700 "$STATE_DIR"
fi
if [ "$(stat -f '%u' "$STATE_DIR" 2>/dev/null || echo -1)" != "$(id -u)" ]; then
    echo "[smart_tank] ERROR: directorio de estado no pertenece al usuario actual." >&2
    exit 1
fi
chmod 700 "$STATE_DIR"
PIDFILE="$STATE_DIR/bridge.pid"
LOGFILE="$STATE_DIR/bridge.log"
PORT=8089

start() {
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
            echo "[smart_tank] El servicio eSCL ya está corriendo (PID: $PID, Puerto: $PORT)"
            return 0
        else
            rm -f "$PIDFILE"
        fi
    fi

    echo "[smart_tank] Iniciando puente AirScan (eSCL) en puerto $PORT..."
    python3 "$DIR/hp_escl_bridge.py" --port "$PORT" > "$LOGFILE" 2>&1 &
    PID=$!
    echo "$PID" > "$PIDFILE"
    sleep 1

    if kill -0 "$PID" 2>/dev/null; then
        echo "[smart_tank] Servicio iniciado con éxito (PID: $PID)"
        echo "[smart_tank] Escáner anunciado en Bonjour: 'HP Smart Tank 500 (AirScan)'"
        echo "[smart_tank] Ya puedes abrir 'Captura de Imagen' o 'Vista Previa' para escanear."
    else
        echo "[smart_tank] ERROR al iniciar el servicio. Ver log en: $LOGFILE"
        cat "$LOGFILE"
        return 1
    fi
}

stop() {
    # Detener demonio principal
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if [[ "$PID" =~ ^[0-9]+$ ]]; then
            echo "[smart_tank] Deteniendo servicio (PID: $PID)..."
            kill "$PID" 2>/dev/null || true
        else
            echo "[smart_tank] PIDFILE inválido; no se ejecuta kill." >&2
        fi
        rm -f "$PIDFILE"
    fi
    # El bridge termina su propio proceso dns-sd en su bloque finally. No usar
    # pkill -f: podría terminar anuncios Bonjour de otros programas.
    echo "[smart_tank] Servicio detenido."
}

status() {
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        if [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
            echo "[smart_tank] Estado: ACTIVO (PID: $PID)"
            echo "[smart_tank] Puerto: $PORT"
            echo "[smart_tank] URL: http://127.0.0.1:$PORT/eSCL/"
            curl -s "http://127.0.0.1:$PORT/eSCL/ScannerStatus" | grep -o "<pwg:State>.*</pwg:State>" || true
            return 0
        fi
    fi
    echo "[smart_tank] Estado: INACTIVO"
    return 1
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 1
        start
        ;;
    status)
        status
        ;;
    *)
        echo "Uso: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
