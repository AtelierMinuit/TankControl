#!/usr/bin/env python3
"""Inspección conservadora de comandos ASCII PCL/PJL y bloques binarios."""
from __future__ import annotations
import argparse, re
from pathlib import Path

ESC = 0x1b
def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('stream', type=Path)
    args = ap.parse_args(); data = args.stream.read_bytes()
    print(f'file={args.stream} length={len(data)}')
    print('PJL lines:')
    for line in data.split(b'\n'):
        if b'@PJL' in line:
            print('  ' + line.decode('ascii', 'replace'))
    print('ESC command candidates:')
    # PCL command strings ending in a final ASCII letter, plus binary *o5W/*g12W.
    pat = re.compile(rb'\x1b(?:%[-0-9A-Z]+X|[&*][^\x1b\r\n]{0,24}?[A-Za-z])')
    seen = {}
    for m in pat.finditer(data):
        raw = m.group(); off = m.start()
        # Do not claim binary fields after a W command are commands.
        key = raw
        seen.setdefault(key, []).append(off)
    for raw, offsets in seen.items():
        printable = raw[1:].decode('ascii', 'replace')
        print(f'  offsets={[f"0x{x:04x}" for x in offsets]} count={len(offsets)} bytes={raw.hex(" ")} text=ESC{printable!r}')
    return 0
if __name__ == '__main__': raise SystemExit(main())
