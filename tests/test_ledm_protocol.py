#!/usr/bin/env python3
"""Tests unitarios para el protocolo LEDM / EWS y el PPD corregido en RGB."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import re
import sys
import unittest
import xml.etree.ElementTree as ET

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DECODER_PATH = PROJECT_ROOT / "tools" / "pcl3gui-decode.py"
SPEC = importlib.util.spec_from_file_location("pcl3gui_decode", DECODER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot import decoder from {DECODER_PATH}")
DECODER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = DECODER
SPEC.loader.exec_module(DECODER)


MOCK_CONSUMABLES_XML = """<?xml version="1.0" encoding="UTF-8"?>
<ConsumableConfigDyn xmlns="http://www.hp.com/schemas/imaging/con/ledm/consumableconfigdyn/2007/11/05">
  <ConsumableInfo>
    <ConsumableLabelCode>K</ConsumableLabelCode>
    <ConsumableTypeEnum>inkTank</ConsumableTypeEnum>
    <ConsumablePercentageLevelRemaining>95</ConsumablePercentageLevelRemaining>
    <ConsumableLifeState>
      <ConsumableState>ok</ConsumableState>
    </ConsumableLifeState>
  </ConsumableInfo>
  <ConsumableInfo>
    <ConsumableLabelCode>C</ConsumableLabelCode>
    <ConsumableTypeEnum>inkTank</ConsumableTypeEnum>
    <ConsumablePercentageLevelRemaining>80</ConsumablePercentageLevelRemaining>
    <ConsumableLifeState>
      <ConsumableState>ok</ConsumableState>
    </ConsumableLifeState>
  </ConsumableInfo>
  <ConsumableInfo>
    <ConsumableLabelCode>M</ConsumableLabelCode>
    <ConsumableTypeEnum>inkTank</ConsumableTypeEnum>
    <ConsumablePercentageLevelRemaining>85</ConsumablePercentageLevelRemaining>
    <ConsumableLifeState>
      <ConsumableState>ok</ConsumableState>
    </ConsumableLifeState>
  </ConsumableInfo>
  <ConsumableInfo>
    <ConsumableLabelCode>Y</ConsumableLabelCode>
    <ConsumableTypeEnum>inkTank</ConsumableTypeEnum>
    <ConsumablePercentageLevelRemaining>75</ConsumablePercentageLevelRemaining>
    <ConsumableLifeState>
      <ConsumableState>ok</ConsumableState>
    </ConsumableLifeState>
  </ConsumableInfo>
</ConsumableConfigDyn>
"""

MOCK_PRODUCT_STATUS_XML = """<?xml version="1.0" encoding="UTF-8"?>
<ProductStatusDyn xmlns="http://www.hp.com/schemas/imaging/con/ledm/productstatusdyn/2007/10/31">
  <Status>
    <StatusCategory>ready</StatusCategory>
  </Status>
</ProductStatusDyn>
"""

MOCK_SCAN_CAPS_XML = """<?xml version="1.0" encoding="UTF-8"?>
<ScanCaps xmlns="http://www.hp.com/schemas/imaging/con/cnx/scan/2008/08/19">
  <Platen>
    <PlatenInputCaps>
      <MinWidth>0</MinWidth>
      <MaxWidth>2550</MaxWidth>
      <MinHeight>0</MinHeight>
      <MaxHeight>3508</MaxHeight>
      <SupportedResolutions>
        <Resolution>75</Resolution>
        <Resolution>150</Resolution>
        <Resolution>300</Resolution>
        <Resolution>600</Resolution>
        <Resolution>1200</Resolution>
      </SupportedResolutions>
      <SupportedFormats>
        <Format>Raw</Format>
        <Format>Jpeg</Format>
      </SupportedFormats>
    </PlatenInputCaps>
  </Platen>
</ScanCaps>
"""


def parse_supplies(xml_str: str) -> dict[str, dict]:
    root = ET.fromstring(xml_str)
    # Remove namespaces for easy parsing
    for elem in root.iter():
        if "}" in elem.tag:
            elem.tag = elem.tag.split("}", 1)[1]
    supplies = {}
    for item in root.findall(".//ConsumableInfo"):
        code = item.findtext("ConsumableLabelCode")
        level_str = item.findtext("ConsumablePercentageLevelRemaining")
        state = item.findtext(".//ConsumableState")
        if code and level_str:
            supplies[code] = {
                "level": int(level_str),
                "state": state or "unknown",
            }
    return supplies


def parse_status_category(xml_str: str) -> str:
    root = ET.fromstring(xml_str)
    for elem in root.iter():
        if "}" in elem.tag:
            elem.tag = elem.tag.split("}", 1)[1]
    return root.findtext(".//StatusCategory") or "unknown"


def parse_scan_resolutions(xml_str: str) -> list[int]:
    root = ET.fromstring(xml_str)
    for elem in root.iter():
        if "}" in elem.tag:
            elem.tag = elem.tag.split("}", 1)[1]
    return [int(r.text) for r in root.findall(".//SupportedResolutions/Resolution") if r.text]


class LedmProtocolTests(unittest.TestCase):
    def test_parse_consumables(self) -> None:
        supplies = parse_supplies(MOCK_CONSUMABLES_XML)
        self.assertIn("K", supplies)
        self.assertIn("C", supplies)
        self.assertIn("M", supplies)
        self.assertIn("Y", supplies)
        self.assertEqual(supplies["K"]["level"], 95)
        self.assertEqual(supplies["C"]["level"], 80)
        self.assertEqual(supplies["M"]["level"], 85)
        self.assertEqual(supplies["Y"]["level"], 75)
        self.assertEqual(supplies["K"]["state"], "ok")

    def test_parse_status_ready(self) -> None:
        cat = parse_status_category(MOCK_PRODUCT_STATUS_XML)
        self.assertEqual(cat, "ready")

    def test_parse_scan_caps(self) -> None:
        res_list = parse_scan_resolutions(MOCK_SCAN_CAPS_XML)
        self.assertEqual(res_list, [75, 150, 300, 600, 1200])


class MacPpdRgbCorrectionTests(unittest.TestCase):
    def test_ppd_has_standard_rgb_colorspace(self) -> None:
        ppd_path = PROJECT_ROOT / "research" / "builds" / "hp-smart_tank_500_series_mac.ppd"
        ppd_content = ppd_path.read_text(encoding="latin1")
        # Ensure RGB ColorModel specifies cupsColorSpace 1, NOT 17
        match = re.search(r'\*ColorModel RGB/Color:.*cupsColorSpace\s+(\d+)', ppd_content)
        self.assertIsNotNone(match)
        self.assertEqual(int(match.group(1)), 1, "ColorModel RGB must use cupsColorSpace 1 to avoid black drop")

    def test_black_square_decoded_from_rgb_stream(self) -> None:
        rgb_stream_path = PROJECT_ROOT / "scratch" / "05-black-square.rgb.pcl3gui"
        if not rgb_stream_path.exists():
            self.skipTest("scratch/05-black-square.rgb.pcl3gui not found")
        data = rgb_stream_path.read_bytes()
        r_start, _, _ = DECODER.parse_raster_events(data)
        width = DECODER._last_int(DECODER.WIDTH_COMMAND, data, r_start)
        self.assertEqual(width, 5100)
        rows, _, _, _ = DECODER.decode_stream_mode10(data, width, None)

        black_pixels = 0
        for y in range(3050, 3550):
            row = rows.get(y)
            self.assertIsNotNone(row)
            for x in range(2300, 2800):
                px = (row[x * 3], row[x * 3 + 1], row[x * 3 + 2])
                if px == (0, 0, 0):
                    black_pixels += 1
        self.assertEqual(black_pixels, 250000, "All 250000 pixels of the 500x500 black square must be pure black (0,0,0)")


if __name__ == "__main__":
    unittest.main()
