from PIL import Image, ImageDraw
import datetime

# Crear imagen A4 a 300 DPI (2480 x 3508)
img = Image.new("RGB", (2480, 3508), "white")
draw = ImageDraw.Draw(img)

# Encabezado
draw.rectangle([(200, 200), (2280, 420)], fill=(240, 240, 248), outline=(0, 100, 200), width=4)
now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
draw.text((250, 230), "HP SMART TANK 500 — TEST DE IMPRESION NATIVO macOS", fill=(0, 0, 0))
draw.text((250, 290), f"Arquitectura: Apple Silicon (ARM64) | Fecha: {now_str}", fill=(60, 60, 60))
draw.text((250, 340), "Dispositivo: HP Smart Tank 500 series | Firmware: no leído | Identificador: no incluido", fill=(60, 60, 60))

# Bloques de Color (CMYK + RGB)
colors = [
    ("NEGRO PURO (K)", (0, 0, 0)),
    ("CIAN (C)", (0, 160, 230)),
    ("MAGENTA (M)", (230, 0, 120)),
    ("AMARILLO (Y)", (255, 210, 0)),
    ("ROJO (R)", (220, 30, 30)),
    ("VERDE (G)", (30, 160, 50)),
    ("AZUL (B)", (30, 70, 200)),
]

y_start = 500
for idx, (label, col) in enumerate(colors):
    y = y_start + idx * 160
    draw.rectangle([(250, y), (750, y + 110)], fill=col, outline=(0, 0, 0), width=2)
    draw.text((800, y + 35), label, fill=(0, 0, 0))

# Escala de grises
draw.text((250, 1680), "ESCALA DE GRISES (0% a 100%):", fill=(0, 0, 0))
for step in range(20):
    val = int(step * 255 / 19)
    x = 250 + step * 95
    draw.rectangle([(x, 1730), (x + 95, 1860)], fill=(val, val, val), outline=(120, 120, 120), width=1)

# Test de resolución y líneas finas
draw.text((250, 1950), "TEST DE RESOLUCION Y LINEAS FINAS (1px a 8px):", fill=(0, 0, 0))
for w in range(1, 9):
    y = 2010 + w * 25
    draw.line([(250, y), (2000, y)], fill=(0, 0, 0), width=w)

# Mensaje de verificación del pipeline
draw.rectangle([(200, 2300), (2280, 2600)], fill=(235, 248, 235), outline=(50, 150, 50), width=3)
draw.text((250, 2340), "ESTADO DEL PIPELINE: PRUEBA OFFLINE", fill=(20, 100, 20))
draw.text((250, 2400), "- Filtro PCL3GUI Mode 10: validado en corpus offline", fill=(0, 0, 0))
draw.text((250, 2450), "- Preservacion de Negro Puro: observada en raster offline", fill=(0, 0, 0))
draw.text((250, 2500), "- Integracion física CUPS/hardware: no demostrada en esta carta", fill=(0, 0, 0))

img.save("scratch/test_print_page.pdf", "PDF", resolution=300.0)
print("PDF generado con exito: scratch/test_print_page.pdf")
