#!/usr/bin/env python3
"""Comprehensive independent tests for the offline PCL3GUI Mode 10 decoder."""
from __future__ import annotations

import importlib.util
import math
from pathlib import Path
import re
import sys
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DECODER_PATH = PROJECT_ROOT / "tools" / "pcl3gui-decode.py"
SPEC = importlib.util.spec_from_file_location("pcl3gui_decode", DECODER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot import decoder from {DECODER_PATH}")
DECODER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = DECODER
SPEC.loader.exec_module(DECODER)


def raw_pixel(rgb: tuple[int, int, int]) -> bytes:
    packed = (rgb[0] << 16) | (rgb[1] << 8) | (rgb[2] & 0xFE)
    return (packed >> 1).to_bytes(3, "big")


def short_delta(delta: tuple[int, int, int]) -> bytes:
    dr, dg, db = delta
    packed = (
        0x8000
        | ((dr & 0x1F) << 10)
        | ((dg & 0x1F) << 5)
        | ((db // 2) & 0x1F)
    )
    return packed.to_bytes(2, "big")


class Mode10RowTests(unittest.TestCase):
    def test_raw_literal_preserves_rgb_except_blue_lsb(self) -> None:
        seed = bytes([255]) * 6
        row, stats = DECODER.decode_mode10_row(
            bytes([0x00]) + raw_pixel((10, 20, 31)), seed, 2
        )
        self.assertEqual(tuple(row[:3]), (10, 20, 30))
        self.assertEqual(tuple(row[3:]), (255, 255, 255))
        self.assertEqual(stats.raw_pixels, 1)

    def test_short_delta_uses_same_position_in_seed_row(self) -> None:
        seed = bytes((100, 100, 100))
        row, stats = DECODER.decode_mode10_row(
            bytes([0x00]) + short_delta((10, -10, 20)), seed, 1
        )
        self.assertEqual(tuple(row), (110, 90, 120))
        self.assertEqual(stats.short_delta_pixels, 1)

    def test_new_pixel_rle_and_extended_count(self) -> None:
        seed = bytes([255]) * (16 * 3)
        payload = bytes([0x97]) + raw_pixel((20, 40, 60)) + bytes([3])
        row, stats = DECODER.decode_mode10_row(payload, seed, 16)
        pixels = [tuple(row[x * 3 : x * 3 + 3]) for x in range(16)]
        self.assertEqual(pixels[:2], [(255, 255, 255)] * 2)
        self.assertEqual(pixels[2:14], [(20, 40, 60)] * 12)
        self.assertEqual(pixels[14:], [(255, 255, 255)] * 2)
        self.assertEqual(stats.rle, 1)

    def test_west_and_cached_sources(self) -> None:
        seed = bytes([255]) * (5 * 3)
        red = raw_pixel((200, 10, 20))
        payload = bytes([0x00]) + red + bytes([0xA0, 0x68])
        row, stats = DECODER.decode_mode10_row(payload, seed, 5)
        pixels = [tuple(row[x * 3 : x * 3 + 3]) for x in range(5)]
        self.assertEqual(pixels, [
            (200, 10, 20),
            (200, 10, 20),
            (200, 10, 20),
            (255, 255, 255),
            (200, 10, 20),
        ])
        self.assertEqual(stats.west, 1)
        self.assertEqual(stats.cached, 1)

    def test_north_east_source(self) -> None:
        seed = bytes((255, 255, 255, 4, 6, 8))
        row, stats = DECODER.decode_mode10_row(bytes([0x40]), seed, 2)
        self.assertEqual(tuple(row[:3]), (4, 6, 8))
        self.assertEqual(stats.north_east, 1)

    def test_literal_count_extension_is_interleaved_after_first_eight(self) -> None:
        seed = bytes([255]) * (9 * 3)
        expected = [(index * 2, index * 3, index * 4) for index in range(9)]
        payload = bytearray([0x07])
        for pixel in expected[:8]:
            payload.extend(raw_pixel(pixel))
        payload.append(1)
        payload.extend(raw_pixel(expected[8]))
        row, stats = DECODER.decode_mode10_row(bytes(payload), seed, 9)
        actual = [tuple(row[x * 3 : x * 3 + 3]) for x in range(9)]
        self.assertEqual(actual, expected)
        self.assertEqual(stats.literals, 1)


class ParserRobustnessTests(unittest.TestCase):
    def test_missing_raster_start_raises(self) -> None:
        with self.assertRaises(DECODER.DecodeError):
            DECODER.parse_raster_events(b"some random stream without start")

    def test_missing_raster_end_raises(self) -> None:
        with self.assertRaises(DECODER.DecodeError):
            DECODER.parse_raster_events(b"\x1b*r1A\x1b*b0W")

    def test_truncated_w_payload_raises(self) -> None:
        data = b"\x1b*r1A\x1b*b10Wabc\x1b*rC"
        with self.assertRaises(DECODER.DecodeError):
            DECODER.parse_raster_events(data)

    def test_unknown_raster_command_raises(self) -> None:
        data = b"\x1b*r1A\x1b*z99Z\x1b*rC"
        with self.assertRaises(DECODER.DecodeError):
            DECODER.parse_raster_events(data)


class CorpusIntegrationTests(unittest.TestCase):
    def decode(self, name: str):
        data = (PROJECT_ROOT / "research" / "corpus" / "streams" / name).read_bytes()
        raster_start, _, _ = DECODER.parse_raster_events(data)
        width = DECODER._last_int(DECODER.WIDTH_COMMAND, data, raster_start)
        self.assertIsNotNone(width)
        rows, counts, stats, ending_y = DECODER.decode_stream_mode10(data, width, None)
        bbox, colors = DECODER.content_summary(rows, width)
        return bbox, colors, stats, counts, width

    def test_white_page_has_no_content(self) -> None:
        bbox, colors, stats, counts, width = self.decode("01-white.pcl3gui")
        self.assertIsNone(bbox)
        self.assertEqual(colors, {})
        self.assertEqual(stats.commands, 0)

    def test_red_square_geometry_and_color(self) -> None:
        bbox, colors, stats, _, _ = self.decode("06-red-square.pcl3gui")
        self.assertEqual(bbox, (2300, 3050, 2800, 3550))
        self.assertEqual(colors, {(254, 0, 0): 250000})
        self.assertEqual(stats.rle, 1)

    def test_green_square_geometry_and_color(self) -> None:
        bbox, colors, stats, _, _ = self.decode("07-green-square.pcl3gui")
        self.assertEqual(bbox, (2300, 3050, 2800, 3550))
        self.assertEqual(colors, {(0, 255, 0): 250000})
        self.assertEqual(stats.rle, 1)

    def test_blue_square_geometry_and_color(self) -> None:
        bbox, colors, stats, _, _ = self.decode("08-blue-square.pcl3gui")
        self.assertEqual(bbox, (2300, 3050, 2800, 3550))
        self.assertEqual(colors, {(0, 0, 254): 250000})
        self.assertEqual(stats.rle, 1)

    def test_grayscale_geometry_and_color(self) -> None:
        bbox, colors, stats, _, _ = self.decode("09-grayscale.pcl3gui")
        self.assertEqual(bbox, (2300, 3050, 2800, 3550))
        self.assertEqual(colors, {(128, 128, 128): 250000})
        self.assertEqual(stats.rle, 1)

    def test_gradient_has_three_reconstructed_levels(self) -> None:
        bbox, colors, stats, _, _ = self.decode("10-gradient-steps.pcl3gui")
        self.assertEqual(bbox, (2466, 3050, 2966, 3550))
        self.assertEqual(sum(colors.values()), 250000)
        self.assertEqual(len(colors), 3)
        self.assertEqual(stats.rle, 3)

    def test_pure_black_square_is_absent_from_active_color_plane(self) -> None:
        bbox, colors, stats, _, _ = self.decode("05-black-square.pcl3gui")
        self.assertIsNone(bbox)
        self.assertEqual(colors, {})
        self.assertEqual(stats.commands, 0)


class ResolutionsAndMediaTests(unittest.TestCase):
    def test_resolution_scaling_600_vs_1200(self) -> None:
        data_600 = (PROJECT_ROOT / "research" / "corpus" / "streams" / "12-normal600.pcl3gui").read_bytes()
        data_1200 = (PROJECT_ROOT / "research" / "corpus" / "streams" / "12-photo1200.pcl3gui").read_bytes()

        r_start_600, _, _ = DECODER.parse_raster_events(data_600)
        r_start_1200, _, _ = DECODER.parse_raster_events(data_1200)

        w_600 = DECODER._last_int(DECODER.WIDTH_COMMAND, data_600, r_start_600)
        res_600 = DECODER._last_int(DECODER.RESOLUTION_COMMAND, data_600, r_start_600)

        w_1200 = DECODER._last_int(DECODER.WIDTH_COMMAND, data_1200, r_start_1200)
        res_1200 = DECODER._last_int(DECODER.RESOLUTION_COMMAND, data_1200, r_start_1200)

        self.assertEqual(res_600, 600)
        self.assertEqual(res_1200, 1200)
        self.assertEqual(w_600, 4960)
        self.assertEqual(w_1200, 9920)
        self.assertEqual(w_1200, w_600 * 2)

    def test_ppd_print_quality_options(self) -> None:
        ppd_text = (PROJECT_ROOT / "research" / "ppd" / "hp-smart_tank_500_series.ppd").read_text(encoding="latin1")
        output_modes = re.findall(r"\*OutputMode\s+([A-Za-z0-9]+)/", ppd_text)
        self.assertIn("Normal", output_modes)
        self.assertIn("Best", output_modes)
        self.assertIn("Photo", output_modes)
        self.assertNotIn("Draft", output_modes)

    def test_borderless_a4_dimensions_expansion(self) -> None:
        full_data = (PROJECT_ROOT / "research" / "corpus" / "streams" / "11-a4-full.pcl3gui").read_bytes()
        borderless_data = (PROJECT_ROOT / "research" / "corpus" / "streams" / "11-a4-borderless.pcl3gui").read_bytes()

        r_start_f, _, events_f = DECODER.parse_raster_events(full_data)
        r_start_b, _, events_b = DECODER.parse_raster_events(borderless_data)

        w_f = DECODER._last_int(DECODER.WIDTH_COMMAND, full_data, r_start_f)
        w_b = DECODER._last_int(DECODER.WIDTH_COMMAND, borderless_data, r_start_b)

        self.assertEqual(w_f, 4822)
        self.assertEqual(w_b, 4962)
        self.assertEqual(w_b - w_f, 140)
        self.assertEqual(len(events_b) - len(events_f), 140)


class InverseRasterValidationTests(unittest.TestCase):
    def check_inverse(self, name: str, expected_max_rmse: float) -> None:
        raster_path = PROJECT_ROOT / "research" / "corpus" / "raster" / f"{name}.raster"
        stream_path = PROJECT_ROOT / "research" / "corpus" / "streams" / f"{name}.pcl3gui"
        stream_data = stream_path.read_bytes()

        r_start, _, _ = DECODER.parse_raster_events(stream_data)
        width = DECODER._last_int(DECODER.WIDTH_COMMAND, stream_data, r_start)
        self.assertEqual(width, 5100)

        rows, _, _, _ = DECODER.decode_stream_mode10(stream_data, width, 6600)
        bbox, _ = DECODER.content_summary(rows, width)
        self.assertEqual(bbox, (2300, 3050, 2800, 3550))

        sq_err = 0.0
        total_pixels = 0
        with raster_path.open("rb") as rf:
            for y in range(3050, 3550, 25):  # Sample 20 rows across square
                rf.seek(4 + 1796 + y * width * 4)
                line = rf.read(width * 4)
                dec_row = rows[y]
                for x in range(2300, 2800, 10):  # Sample 50 cols across square
                    base = x * 4
                    r_in, g_in, b_in = line[base], line[base + 1], line[base + 2]
                    d_base = x * 3
                    r_out, g_out, b_out = dec_row[d_base], dec_row[d_base + 1], dec_row[d_base + 2]
                    sq_err += (r_in - r_out) ** 2 + (g_in - g_out) ** 2 + (b_in - b_out) ** 2
                    total_pixels += 1

        rmse = math.sqrt(sq_err / (total_pixels * 3))
        self.assertLessEqual(rmse, expected_max_rmse)

    def test_inverse_green_exact(self) -> None:
        self.check_inverse("07-green-square", 0.0)

    def test_inverse_grayscale_exact(self) -> None:
        self.check_inverse("09-grayscale", 0.0)

    def test_inverse_blue_lsb_bounded(self) -> None:
        self.check_inverse("08-blue-square", 0.6)

    def test_inverse_red_bounded(self) -> None:
        self.check_inverse("06-red-square", 0.6)


if __name__ == "__main__":
    unittest.main()
