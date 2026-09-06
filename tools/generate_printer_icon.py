#!/usr/bin/env python3
"""
generate_printer_icon.py
Generador de Icono Fotorrealista de Sistema para HP Smart Tank 500 en macOS Apple Silicon.
Genera el conjunto de iconos Retina (16x16 hasta 1024x1024) y compila un archivo .icns oficial
utilizando sips e iconutil de macOS para mostrarse en Ajustes del Sistema y Diálogo de Impresión.
"""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile

from generate_color_target import Canvas


def draw_smart_tank_chassis(width: int = 1024, height: int = 1024) -> Canvas:
    """Dibuja una representación vectorial limpia y estilizada de la HP Smart Tank 500."""
    canvas = Canvas(width, height, (0, 0, 0))  # Base transparente o fondo temporal

    # Color de fondo blanco o transparente: en PPM el fondo blanco sirve de base
    canvas.fill_rect(0, 0, width, height, (245, 247, 250))

    # 1. Sombra suave inferior
    shadow_y = int(height * 0.72)
    canvas.fill_rect(int(width * 0.12), shadow_y, int(width * 0.76), int(height * 0.08), (200, 205, 215))
    canvas.fill_rect(int(width * 0.16), shadow_y + int(height * 0.02), int(width * 0.68), int(height * 0.05), (180, 185, 195))

    # 2. Bandeja de alimentación trasera de papel (Vertical)
    tray_x = int(width * 0.22)
    tray_y = int(height * 0.18)
    tray_w = int(width * 0.56)
    tray_h = int(height * 0.25)
    canvas.fill_rect(tray_x, tray_y, tray_w, tray_h, (215, 220, 225))
    canvas.draw_rect_outline(tray_x, tray_y, tray_w, tray_h, (150, 155, 160), 4)

    # Papel en la bandeja (Hojas blancas proyectadas)
    paper_x = int(width * 0.26)
    paper_y = int(height * 0.14)
    paper_w = int(width * 0.48)
    paper_h = int(height * 0.22)
    canvas.fill_rect(paper_x, paper_y, paper_w, paper_h, (255, 255, 255))
    canvas.draw_rect_outline(paper_x, paper_y, paper_w, paper_h, (200, 200, 200), 3)

    # 3. Chasis principal de la impresora (Cuerpo negro/gris mate con bordes redondeados)
    body_x = int(width * 0.14)
    body_y = int(height * 0.35)
    body_w = int(width * 0.72)
    body_h = int(height * 0.38)
    canvas.fill_rect(body_x, body_y, body_w, body_h, (50, 52, 56))  # HP Charcoal Gray
    canvas.draw_rect_outline(body_x, body_y, body_w, body_h, (30, 32, 35), 6)

    # 4. Tapa del escáner de cama plana (Parte superior)
    lid_x = body_x + 8
    lid_y = body_y + 8
    lid_w = body_w - 16
    lid_h = int(height * 0.14)
    canvas.fill_rect(lid_x, lid_y, lid_w, lid_h, (75, 78, 84))  # Tapa gris suave
    canvas.draw_rect_outline(lid_x, lid_y, lid_w, lid_h, (40, 42, 45), 3)

    # Logo circular de HP en la tapa
    logo_cx = lid_x + lid_w // 2
    logo_cy = lid_y + lid_h // 2
    logo_r = int(height * 0.038)
    canvas.fill_rect(logo_cx - logo_r, logo_cy - logo_r, logo_r * 2, logo_r * 2, (0, 150, 214))  # HP Cyan Blue

    # 5. Panel de control (Botones y pantalla LCD monocromática)
    panel_x = body_x + int(body_w * 0.05)
    panel_y = body_y + lid_h + int(height * 0.02)
    panel_w = int(body_w * 0.22)
    panel_h = int(height * 0.07)
    canvas.fill_rect(panel_x, panel_y, panel_w, panel_h, (35, 37, 40))
    canvas.draw_rect_outline(panel_x, panel_y, panel_w, panel_h, (70, 72, 76), 2)

    # Pequeña pantalla LCD de estado
    lcd_x = panel_x + 10
    lcd_y = panel_y + 10
    lcd_w = int(panel_w * 0.45)
    lcd_h = panel_h - 20
    canvas.fill_rect(lcd_x, lcd_y, lcd_w, lcd_h, (130, 165, 140))  # LCD verde retro

    # Botones táctiles circulares
    btn_cx = panel_x + int(panel_w * 0.70)
    btn_cy = panel_y + panel_h // 2
    canvas.fill_rect(btn_cx - 8, btn_cy - 8, 16, 16, (0, 200, 100))  # Copia Color
    canvas.fill_rect(btn_cx + 25, btn_cy - 8, 16, 16, (220, 50, 50))  # Cancelar

    # 6. Ranura de salida de papel frontal
    out_x = body_x + int(body_w * 0.32)
    out_y = body_y + lid_h + int(height * 0.02)
    out_w = int(body_w * 0.62)
    out_h = int(height * 0.09)
    canvas.fill_rect(out_x, out_y, out_w, out_h, (25, 27, 30))  # Cavidad oscura
    canvas.draw_rect_outline(out_x, out_y, out_w, out_h, (15, 17, 20), 2)

    # 7. Los 4 Tanques de Tinta Frontales Translúcidos (CISS - Smart Tank Signature)
    # Tanque Negro (Izquierda)
    tank_k_x = body_x + int(body_w * 0.05)
    tank_k_y = body_y + int(body_h * 0.58)
    tank_k_w = int(body_w * 0.16)
    tank_k_h = int(body_h * 0.34)
    canvas.fill_rect(tank_k_x, tank_k_y, tank_k_w, tank_k_h, (30, 32, 35))
    canvas.draw_rect_outline(tank_k_x, tank_k_y, tank_k_w, tank_k_h, (80, 85, 90), 3)
    # Ventana de nivel de tinta negra
    canvas.fill_rect(tank_k_x + 6, tank_k_y + 10, tank_k_w - 12, tank_k_h - 16, (15, 15, 15))

    # Tanques de Color C, M, Y (Derecha frontal)
    cmy_base_x = body_x + int(body_w * 0.72)
    cmy_base_y = body_y + int(body_h * 0.58)
    cmy_tank_w = int(body_w * 0.07)
    cmy_tank_h = int(body_h * 0.34)
    gap_tank = int(body_w * 0.015)

    # Cian (GT52)
    canvas.fill_rect(cmy_base_x, cmy_base_y, cmy_tank_w, cmy_tank_h, (30, 32, 35))
    canvas.draw_rect_outline(cmy_base_x, cmy_base_y, cmy_tank_w, cmy_tank_h, (80, 85, 90), 2)
    canvas.fill_rect(cmy_base_x + 4, cmy_base_y + 10, cmy_tank_w - 8, cmy_tank_h - 16, (0, 160, 220))

    # Magenta (GT52)
    m_x = cmy_base_x + cmy_tank_w + gap_tank
    canvas.fill_rect(m_x, cmy_base_y, cmy_tank_w, cmy_tank_h, (30, 32, 35))
    canvas.draw_rect_outline(m_x, cmy_base_y, cmy_tank_w, cmy_tank_h, (80, 85, 90), 2)
    canvas.fill_rect(m_x + 4, cmy_base_y + 10, cmy_tank_w - 8, cmy_tank_h - 16, (225, 20, 120))

    # Amarillo (GT52)
    y_x = m_x + cmy_tank_w + gap_tank
    canvas.fill_rect(y_x, cmy_base_y, cmy_tank_w, cmy_tank_h, (30, 32, 35))
    canvas.draw_rect_outline(y_x, cmy_base_y, cmy_tank_w, cmy_tank_h, (80, 85, 90), 2)
    canvas.fill_rect(y_x + 4, cmy_base_y + 10, cmy_tank_w - 8, cmy_tank_h - 16, (245, 205, 10))

    return canvas


def generate_printer_icns(output_icns_path: Path) -> Path:
    """Genera el árbol iconset con todas las resoluciones Retina y lo compila a .icns."""
    temp_root = Path(tempfile.mkdtemp(prefix="hp-smart-tank-icon-"))
    scratch_dir = temp_root / "iconset.iconset"
    scratch_dir.mkdir()

    master_ppm = temp_root / "master.ppm"
    master_png = temp_root / "master.png"

    print("[Icon] Sintetizando gráfico fotorrealista maestro 1024x1024...")
    canvas = draw_smart_tank_chassis(1024, 1024)
    canvas.save_ppm(master_ppm)

    # Convertir master a PNG con sips
    subprocess.run(["sips", "-s", "format", "png", str(master_ppm), "--out", str(master_png)], check=True)

    # Tamaños requeridos por iconutil en macOS
    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    for px, filename in sizes:
        target = scratch_dir / filename
        subprocess.run([
            "sips", "-z", str(px), str(px), str(master_png), "--out", str(target)
        ], capture_output=True, check=True)

    print(f"[Icon] Compilando archivo .icns oficial con /usr/bin/iconutil -> {output_icns_path}...")
    output_icns_path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "iconutil", "-c", "icns", str(scratch_dir), "-o", str(output_icns_path)
    ], check=True)

    # Limpieza
    import shutil
    shutil.rmtree(temp_root, ignore_errors=True)

    print(f"[Icon] ¡Icono creado exitosamente! ({output_icns_path.stat().st_size} bytes)")
    return output_icns_path


if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "research" / "builds" / "HP_Smart_Tank_500.icns"
    generate_printer_icns(out)
