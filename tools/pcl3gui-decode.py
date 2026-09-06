#!/usr/bin/env python3
"""Parse PCL3GUI raster blocks and independently decode HP Mode 10 rows.

The decoder is intentionally read-only: it consumes a captured/generated stream
and can write a PPM reconstruction. It never opens a printer or a USB device.

Mode 10 stores 24-bit RGB pixels with the least-significant blue bit omitted.
Consequently the reconstructed blue channel is always even; that lossy bit
cannot be recovered from the stream alone.
"""
from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
import hashlib
from pathlib import Path
import re


RASTER_START = b"\x1b*r1A"
RASTER_END = b"\x1b*rC"
RASTER_EVENT = re.compile(rb"\x1b\*b([0-9]+)([WVY])")
WIDTH_COMMAND = re.compile(rb"\x1b\*r([0-9]+)S")
RESOLUTION_COMMAND = re.compile(rb"\x1b\*t([0-9]+)R")
POSITION_Y_COMMAND = re.compile(rb"\x1b\*p(-?[0-9]+)Y")


class DecodeError(ValueError):
    """Raised when a stream violates the Mode 10 structure."""


@dataclass(frozen=True)
class RasterEvent:
    offset: int
    end: int
    kind: str
    value: int
    payload: bytes = b""


@dataclass
class RowStats:
    commands: int = 0
    literals: int = 0
    rle: int = 0
    new_pixel: int = 0
    west: int = 0
    north_east: int = 0
    cached: int = 0
    short_delta_pixels: int = 0
    raw_pixels: int = 0

    def add(self, other: "RowStats") -> None:
        for name in self.__dataclass_fields__:
            setattr(self, name, getattr(self, name) + getattr(other, name))


class Reader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def read_u8(self, what: str) -> int:
        if self.pos >= len(self.data):
            raise DecodeError(f"payload ended while reading {what} at byte {self.pos}")
        value = self.data[self.pos]
        self.pos += 1
        return value

    def read_vli(self, what: str) -> int:
        """Decode HP's additive VLI: every 255 byte continues the value."""
        total = 0
        while True:
            value = self.read_u8(what)
            total += value
            if value != 255:
                return total


def _sign5(value: int) -> int:
    return value - 32 if value & 0x10 else value


def _pixel_at(row: bytes | bytearray, x: int) -> tuple[int, int, int]:
    base = x * 3
    return row[base], row[base + 1], row[base + 2]


def _put_pixel(row: bytearray, x: int, pixel: tuple[int, int, int]) -> None:
    base = x * 3
    row[base : base + 3] = bytes(pixel)


def _decode_pixel(
    reader: Reader, north: tuple[int, int, int], stats: RowStats
) -> tuple[int, int, int]:
    first = reader.read_u8("pixel")
    if first & 0x80:
        second = reader.read_u8("short-delta pixel")
        packed = (first << 8) | second
        dr = _sign5((packed >> 10) & 0x1F)
        dg = _sign5((packed >> 5) & 0x1F)
        db = _sign5(packed & 0x1F) * 2
        pixel = north[0] + dr, north[1] + dg, north[2] + db
        if any(channel < 0 or channel > 255 for channel in pixel):
            raise DecodeError(
                f"short delta produces invalid RGB {pixel} from north={north}"
            )
        stats.short_delta_pixels += 1
        return pixel

    second = reader.read_u8("raw pixel")
    third = reader.read_u8("raw pixel")
    packed = ((first << 16) | (second << 8) | third) << 1
    stats.raw_pixels += 1
    return (packed >> 16) & 0xFF, (packed >> 8) & 0xFF, packed & 0xFF


def _source_pixel(
    source: int,
    x: int,
    row: bytearray,
    seed: bytes,
    cache: tuple[int, int, int],
) -> tuple[int, int, int]:
    if source == 1:  # west
        if x == 0:
            raise DecodeError("west source requested for first pixel")
        return _pixel_at(row, x - 1)
    if source == 2:  # north-east
        if x + 1 >= len(seed) // 3:
            raise DecodeError("north-east source extends beyond row")
        return _pixel_at(seed, x + 1)
    if source == 3:  # cached color
        return cache
    raise DecodeError(f"invalid implicit pixel source {source}")


def decode_mode10_row(payload: bytes, seed: bytes, width: int) -> tuple[bytes, RowStats]:
    """Decode one Mode 10 payload against its previous (seed) RGB row."""
    if len(seed) != width * 3:
        raise DecodeError(f"seed length {len(seed)} does not match width {width}")
    if not payload:
        return seed, RowStats()

    reader = Reader(payload)
    row = bytearray(seed)
    cache = (255, 255, 255)
    x = 0
    stats = RowStats()

    def emit_encoded_pixel() -> tuple[int, int, int]:
        if x >= width:
            raise DecodeError(f"encoded pixel begins beyond width {width}")
        return _decode_pixel(reader, _pixel_at(seed, x), stats)

    def emit_literal_pixels(count: int, source: int, first_group: bool) -> None:
        nonlocal x, cache
        for index in range(count):
            if x >= width:
                raise DecodeError(f"literal run extends beyond width {width}")
            if first_group and index == 0 and source != 0:
                pixel = _source_pixel(source, x, row, seed, cache)
            else:
                pixel = emit_encoded_pixel()
                if first_group and index == 0 and source == 0:
                    cache = pixel
            _put_pixel(row, x, pixel)
            x += 1

    while reader.pos < len(payload):
        command_offset = reader.pos
        command = reader.read_u8("command")
        is_rle = bool(command & 0x80)
        source = (command >> 5) & 0x03
        offset = (command >> 3) & 0x03
        count_code = command & 0x07

        stats.commands += 1
        if is_rle:
            stats.rle += 1
        else:
            stats.literals += 1
        source_counter = ("new_pixel", "west", "north_east", "cached")[source]
        setattr(stats, source_counter, getattr(stats, source_counter) + 1)

        if offset == 3:
            offset += reader.read_vli("seed-row offset")
        x += offset
        if x >= width:
            raise DecodeError(
                f"command at payload byte {command_offset} skips to x={x}, width={width}"
            )

        if is_rle:
            if source == 0:
                pixel = emit_encoded_pixel()
                cache = pixel
            else:
                pixel = _source_pixel(source, x, row, seed, cache)

            count = count_code + 2
            if count_code == 7:
                count += reader.read_vli("RLE replacement count")
            if x + count > width:
                raise DecodeError(
                    f"RLE at payload byte {command_offset} ends at {x + count}, width={width}"
                )
            for _ in range(count):
                _put_pixel(row, x, pixel)
                x += 1
            continue

        if count_code < 7:
            emit_literal_pixels(count_code + 1, source, True)
            continue

        # A literal count of eight is followed *after those eight pixels* by
        # an additive continuation byte. Groups of 255 pixels are followed
        # by another continuation byte.
        emit_literal_pixels(8, source, True)
        while True:
            extension = reader.read_u8("literal replacement count")
            emit_literal_pixels(extension, source, False)
            if extension != 255:
                break

    return bytes(row), stats


def parse_raster_events(data: bytes) -> tuple[int, int, list[RasterEvent]]:
    start = data.find(RASTER_START)
    if start < 0:
        raise DecodeError("ESC*r1A raster start not found")
    raster_data_start = start + len(RASTER_START)
    pos = raster_data_start
    events: list[RasterEvent] = []
    while pos < len(data):
        if data.startswith(RASTER_END, pos):
            return raster_data_start, pos, events
        position_match = POSITION_Y_COMMAND.match(data, pos)
        if position_match:
            events.append(
                RasterEvent(
                    pos,
                    position_match.end(),
                    "P",
                    int(position_match.group(1)),
                )
            )
            pos = position_match.end()
            continue
        match = RASTER_EVENT.match(data, pos)
        if not match:
            preview = data[pos : pos + 16].hex(" ")
            raise DecodeError(f"unknown raster bytes at stream offset 0x{pos:x}: {preview}")
        value = int(match.group(1))
        kind = match.group(2).decode("ascii")
        end = match.end()
        payload = b""
        if kind in ("W", "V"):
            payload_end = end + value
            if payload_end > len(data):
                raise DecodeError(
                    f"{kind} payload at 0x{pos:x} is truncated: "
                    f"available={len(data) - end}, expected={value}"
                )
            payload = data[end:payload_end]
            end = payload_end
        events.append(RasterEvent(pos, end, kind, value, payload))
        pos = end
    raise DecodeError("ESC*rC raster end not found")


def _last_int(pattern: re.Pattern[bytes], data: bytes, limit: int) -> int | None:
    matches = list(pattern.finditer(data, 0, limit))
    return int(matches[-1].group(1)) if matches else None


def decode_stream_mode10(
    data: bytes, width: int, page_height: int | None
) -> tuple[dict[int, bytes], dict[str, int], RowStats, int]:
    raster_start, raster_end, events = parse_raster_events(data)
    initial_y = _last_int(POSITION_Y_COMMAND, data, raster_start) or 0
    y = initial_y
    white = bytes([255]) * (width * 3)
    seed = white
    rows: dict[int, bytes] = {}
    totals = RowStats()
    counts = Counter(event.kind for event in events)
    counts["zero_W"] = sum(e.kind == "W" and e.value == 0 for e in events)
    counts["payload_bytes"] = sum(
        e.value for e in events if e.kind in ("W", "V")
    )

    for event in events:
        if event.kind == "P":
            y = event.value
            seed = white
            continue
        if event.kind == "Y":
            y += event.value
            seed = white
            continue
        if event.kind == "V":
            raise DecodeError(
                "Mode 9 black-plane V blocks are present; this decoder currently "
                "implements the Mode 10 color W plane only"
            )
        if page_height is not None and y >= page_height:
            raise DecodeError(f"decoded row y={y} exceeds page height {page_height}")
        row, row_stats = decode_mode10_row(event.payload, seed, width)
        rows[y] = row
        totals.add(row_stats)
        seed = row
        y += 1

    counts["raster_start"] = raster_start
    counts["raster_end"] = raster_end
    counts["initial_y"] = initial_y
    return rows, dict(counts), totals, y


def content_summary(
    rows: dict[int, bytes], width: int
) -> tuple[tuple[int, int, int, int] | None, Counter[tuple[int, int, int]]]:
    min_x = width
    max_x = -1
    min_y: int | None = None
    max_y: int | None = None
    colors: Counter[tuple[int, int, int]] = Counter()
    for y, row in rows.items():
        row_changed = False
        for x in range(width):
            pixel = _pixel_at(row, x)
            if pixel == (255, 255, 255):
                continue
            row_changed = True
            min_x = min(min_x, x)
            max_x = max(max_x, x)
            colors[pixel] += 1
        if row_changed:
            min_y = y if min_y is None else min(min_y, y)
            max_y = y if max_y is None else max(max_y, y)
    if min_y is None or max_y is None:
        return None, colors
    return (min_x, min_y, max_x + 1, max_y + 1), colors


def write_ppm(path: Path, rows: dict[int, bytes], width: int, height: int) -> None:
    white = bytes([255]) * (width * 3)
    with path.open("wb") as output:
        output.write(f"P6\n{width} {height}\n255\n".encode("ascii"))
        for y in range(height):
            output.write(rows.get(y, white))


def _print_block(event: RasterEvent, index: int) -> None:
    payload_hash = hashlib.sha256(event.payload).hexdigest() if event.payload else "-"
    print(
        f"event={index} offset=0x{event.offset:08x} kind={event.kind} "
        f"value={event.value} end=0x{event.end:08x} "
        f"payload_sha256={payload_hash} payload_prefix={event.payload[:16].hex(' ')}"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stream", type=Path)
    parser.add_argument("--width", type=int, help="override ESC*r<n>S width")
    parser.add_argument("--height", type=int, help="full output page height in pixels")
    parser.add_argument("--decode-mode10", action="store_true")
    parser.add_argument("--ppm", type=Path, help="write decoded full-page RGB PPM")
    parser.add_argument("--list-blocks", action="store_true")
    args = parser.parse_args()

    data = args.stream.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    raster_start, raster_end, events = parse_raster_events(data)
    width = args.width or _last_int(WIDTH_COMMAND, data, raster_start)
    resolution = _last_int(RESOLUTION_COMMAND, data, raster_start)
    print(f"stream={args.stream} bytes={len(data)} sha256={digest}")
    print(
        f"raster_data=[0x{raster_start:08x},0x{raster_end:08x}) "
        f"events={len(events)} width={width or 'unknown'} "
        f"vertical_resolution={resolution or 'unknown'}"
    )
    kinds = Counter(event.kind for event in events)
    zero_w = sum(event.kind == "W" and event.value == 0 for event in events)
    payload_bytes = sum(event.value for event in events if event.kind in ("W", "V"))
    print(
        f"event_counts W={kinds['W']} V={kinds['V']} Y={kinds['Y']} "
        f"position_Y={kinds['P']} "
        f"zero_W={zero_w} payload_bytes={payload_bytes}"
    )
    if args.list_blocks:
        for index, event in enumerate(events):
            _print_block(event, index)

    if not args.decode_mode10 and args.ppm is None:
        return 0
    if width is None:
        raise DecodeError("cannot decode Mode 10 without --width or ESC*r<n>S")

    rows, counts, stats, ending_y = decode_stream_mode10(data, width, args.height)
    bbox, colors = content_summary(rows, width)
    print(
        f"mode10_decoded_rows={len(rows)} initial_y={counts['initial_y']} "
        f"ending_y={ending_y} blue_lsb=reconstructed_as_zero"
    )
    print(
        f"mode10_commands={stats.commands} literal={stats.literals} rle={stats.rle} "
        f"sources=new:{stats.new_pixel},west:{stats.west},"
        f"north_east:{stats.north_east},cached:{stats.cached} "
        f"pixels=short_delta:{stats.short_delta_pixels},raw:{stats.raw_pixels}"
    )
    if bbox is None:
        print("nonwhite_bbox=none")
    else:
        print(f"nonwhite_bbox=x[{bbox[0]},{bbox[2]}) y[{bbox[1]},{bbox[3]})")
    common = ", ".join(f"{rgb}:{count}" for rgb, count in colors.most_common(12))
    print(f"nonwhite_colors={len(colors)} most_common=[{common}]")

    if args.ppm is not None:
        height = args.height if args.height is not None else max(ending_y, 1)
        args.ppm.parent.mkdir(parents=True, exist_ok=True)
        write_ppm(args.ppm, rows, width, height)
        print(
            f"ppm={args.ppm} width={width} height={height} "
            f"bytes={args.ppm.stat().st_size}"
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except DecodeError as error:
        raise SystemExit(f"decode error: {error}")
