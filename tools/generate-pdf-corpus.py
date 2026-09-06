#!/usr/bin/env python3
"""Genera PDFs vectoriales mínimos para alimentar cupsfilter offline."""
from pathlib import Path
import sys

def pdf(name, commands, media_box=(612, 792), label=True):
    width, height = media_box
    label_command = (
        f"BT /F1 12 Tf 36 {height - 36:g} Td ({name}) Tj ET\n" if label else ""
    )
    body = label_command + commands
    objs = [b"<< /Type /Catalog /Pages 2 0 R >>", b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            (f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {width:g} {height:g}] "
             "/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>").encode(),
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
            (f"<< /Length {len(body.encode())} >>\nstream\n{body}endstream").encode()]
    out = bytearray(b"%PDF-1.3\n")
    offs = [0]
    for i, obj in enumerate(objs, 1):
        offs.append(len(out)); out += f"{i} 0 obj\n".encode()+obj+b"\nendobj\n"
    xref = len(out); out += f"xref\n0 {len(objs)+1}\n0000000000 65535 f \n".encode()
    out += b"".join(f"{o:010d} 00000 n \n".encode() for o in offs[1:])
    out += f"trailer\n<< /Size {len(objs)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    return out

cases = {
 '01-white': ('', (612, 792), True),
 '02-black-pixel': ('0 0 0 rg 300 396 1 1 re f\n', (612, 792), True),
 '03-black-horizontal': ('0 0 0 rg 180 396 252 1 re f\n', (612, 792), True),
 '04-black-vertical': ('0 0 0 rg 306 300 1 192 re f\n', (612, 792), True),
 '05-black-square': ('0 0 0 rg 276 366 60 60 re f\n', (612, 792), True),
 '06-red-square': ('1 0 0 rg 276 366 60 60 re f\n', (612, 792), True),
 '07-green-square': ('0 1 0 rg 276 366 60 60 re f\n', (612, 792), True),
 '08-blue-square': ('0 0 1 rg 276 366 60 60 re f\n', (612, 792), True),
 '09-grayscale': ('0.5 g 276 366 60 60 re f\n', (612, 792), True),
 '10-gradient-steps': (
     '0 g 276 366 20 60 re f\n0.25 g 296 366 20 60 re f\n'
     '0.5 g 316 366 20 60 re f\n0.75 g 336 366 20 60 re f\n'
     '1 g 356 366 20 60 re f\n',
     (612, 792),
     True,
 ),
 '11-a4-full': (
     '0.90 0.95 1 rg 0 0 595.44 841.68 re f\n'
     '1 0 0 rg 0 0 18 841.68 re f\n'
     '0 1 0 rg 577.44 0 18 841.68 re f\n'
     '0 0 1 rg 0 0 595.44 18 re f\n'
     '1 0.5 0 rg 0 823.68 595.44 18 re f\n',
     (595.44, 841.68),
     False,
 ),
 '12-resolution-source': (
     '1 0 0 rg 72 600 468 2 re f\n'
     '0 1 0 rg 72 550 468 1 re f\n'
     '0 0 1 rg 72 500 468 0.5 re f\n'
     '0.2 0.4 0.8 rg 72 300 m 540 470 l 2 w S\n'
     '0.8 0.2 0.4 rg 72 470 m 540 300 l 1 w S\n',
     (612, 792),
     True,
 ),
 '13-quality-source': (
     '1 0 0 rg 156 330 100 140 re f\n'
     '0 1 0 rg 256 330 100 140 re f\n'
     '0 0 1 rg 356 330 100 140 re f\n'
     '0.25 g 156 300 300 12 re f\n'
     '0.5 g 156 280 300 8 re f\n'
     '0.75 g 156 264 300 4 re f\n',
     (612, 792),
     True,
 ),
}
root = Path(sys.argv[1] if len(sys.argv)>1 else 'research/corpus/pdf')
root.mkdir(parents=True, exist_ok=True)
for name, (commands, media_box, label) in cases.items():
    (root/(name+'.pdf')).write_bytes(pdf(name, commands, media_box, label))
print(f'generated={len(cases)} directory={root}')
