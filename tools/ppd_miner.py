#!/usr/bin/env python3
"""PPD Miner & Cross-Model Comparator for HP Smart Tank / Ink Tank families.

Analyzes official HPLIP PPDs, extracts media definitions, constraints, resolutions,
and compares them with our native macOS Apple Silicon PPD.
"""

from __future__ import annotations

import gzip
import json
from pathlib import Path
import re
import sys
from typing import Any, Dict, List, Set

ROOT = Path(__file__).resolve().parents[1]
HPLIP_PPD_DIR = ROOT / "research" / "hplip" / "hplip-3.26.4" / "ppd" / "hpcups"
MAC_PPD = ROOT / "research" / "builds" / "hp-smart_tank_500_series_mac.ppd"


def read_ppd_text(path: Path) -> str:
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8", errors="replace") as f:
            return f.read()
    else:
        return path.read_text(encoding="utf-8", errors="replace")


def parse_ppd_metadata(content: str) -> Dict[str, Any]:
    info: Dict[str, Any] = {
        "model_name": "",
        "nick_name": "",
        "product": "",
        "page_sizes": [],
        "media_types": [],
        "resolutions": [],
        "color_models": [],
        "ui_constraints": [],
        "cups_filter": [],
        "custom_page_size": None,
    }

    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith("%"):
            continue

        if line.startswith("*ModelName:"):
            info["model_name"] = line.split(":", 1)[1].strip().strip('"')
        elif line.startswith("*NickName:"):
            info["nick_name"] = line.split(":", 1)[1].strip().strip('"')
        elif line.startswith("*Product:"):
            info["product"] = line.split(":", 1)[1].strip().strip('"')
        elif line.startswith("*PageSize "):
            m = re.match(r"\*PageSize\s+([A-Za-z0-9_.-]+)", line)
            if m:
                info["page_sizes"].append(m.group(1))
        elif line.startswith("*MediaType ") or line.startswith("*HPColorMode "):
            m = re.match(r"\*(?:MediaType|HPColorMode)\s+([A-Za-z0-9_.-]+)", line)
            if m and m.group(1) not in info["media_types"]:
                info["media_types"].append(m.group(1))
        elif line.startswith("*Resolution "):
            m = re.match(r"\*Resolution\s+([A-Za-z0-9_.-]+)", line)
            if m and m.group(1) not in info["resolutions"]:
                info["resolutions"].append(m.group(1))
        elif line.startswith("*ColorModel "):
            m = re.match(r"\*ColorModel\s+([A-Za-z0-9_.-]+)", line)
            if m and m.group(1) not in info["color_models"]:
                info["color_models"].append(m.group(1))
        elif line.startswith("*UIConstraints:"):
            info["ui_constraints"].append(line.split(":", 1)[1].strip())
        elif line.startswith("*cupsFilter:"):
            info["cups_filter"].append(line.split(":", 1)[1].strip().strip('"'))
        elif line.startswith("*VariablePaperSize:"):
            info["variable_paper_size"] = "True" in line
        elif line.startswith("*ParamCustomPageSize Width:"):
            m = re.search(r"(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)", line)
            if m:
                info["custom_width_range"] = (float(m.group(1)), float(m.group(2)))
        elif line.startswith("*ParamCustomPageSize Height:"):
            m = re.search(r"(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)", line)
            if m:
                info["custom_height_range"] = (float(m.group(1)), float(m.group(2)))

    return info


def mine_all_ppds() -> Dict[str, Any]:
    results = {}
    if HPLIP_PPD_DIR.is_dir():
        for ppd_path in sorted(HPLIP_PPD_DIR.glob("hp-*smart_tank*.ppd*")) + sorted(HPLIP_PPD_DIR.glob("hp-*ink_tank*.ppd*")):
            if ppd_path.name.endswith(".ppd") or ppd_path.name.endswith(".ppd.gz"):
                try:
                    text = read_ppd_text(ppd_path)
                    meta = parse_ppd_metadata(text)
                    results[ppd_path.name] = meta
                except Exception as e:
                    results[ppd_path.name] = {"error": str(e)}

    if MAC_PPD.is_file():
        mac_text = read_ppd_text(MAC_PPD)
        results["mac_smart_tank_500"] = parse_ppd_metadata(mac_text)

    return results


def main() -> None:
    data = mine_all_ppds()
    print(f"[PPD-Miner] Processed {len(data)} PPD files.")

    # Compare HP Smart Tank 500 HPLIP vs macOS
    hplip_500 = data.get("hp-smart_tank_500_series.ppd")
    mac_500 = data.get("mac_smart_tank_500")

    if hplip_500 and mac_500:
        print("\n=== COMPARISON: HPLIP vs Native macOS Apple Silicon PPD ===")
        print(f"HPLIP NickName: {hplip_500.get('nick_name')}")
        print(f"macOS NickName: {mac_500.get('nick_name')}")
        print(f"HPLIP PageSizes ({len(hplip_500.get('page_sizes', []))}): {', '.join(hplip_500.get('page_sizes', [])[:8])}...")
        print(f"macOS PageSizes ({len(mac_500.get('page_sizes', []))}): {', '.join(mac_500.get('page_sizes', [])[:8])}...")
        print(f"HPLIP Filters: {hplip_500.get('cups_filter')}")
        print(f"macOS Filters: {mac_500.get('cups_filter')}")
        print(f"HPLIP Constraints ({len(hplip_500.get('ui_constraints', []))}): {len(hplip_500.get('ui_constraints', []))} constraints defined")
        print(f"macOS Constraints ({len(mac_500.get('ui_constraints', []))}): {len(mac_500.get('ui_constraints', []))} constraints defined")

    out_file = ROOT / "research" / "results" / "ppd_mined_comparison.json"
    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"\nSaved full mined dataset to: {out_file}")


if __name__ == "__main__":
    main()
