# Feature Implementation & Option Mapping Matrix (HP Smart Tank 500)

**Project:** HP Smart Tank 500 macOS Native Driver (`0x03f0:0x2b54`)  
**Status:** CANONICAL AUDIT DOCUMENT  
**Version:** 0.1.0-alpha  
**Date:** 2026-09-04  

---

## 1. Overview & Pipeline Traceability

Every print setting configured in the macOS Print Dialog or passed via `lp -o` traverses multiple subsystems before reaching the physical HP Smart Tank 500:

1. **User Interface (UI):** macOS Print Dialog / CUPS Web Interface (`http://localhost:631`).
2. **PPD Specification:** Options, choices, PostScript `setpagedevice` dictionaries, and constraints in `hp-smart_tank_500_series_mac.ppd`.
3. **CUPS Filter Input:** Option passed either through `cups_page_header2_t` struct fields or raw command-line string in `argv[5]`.
4. **Raster Filter (`tools/rastertopcl3gui`):** Software raster manipulation (LUT, thinning, watermarking) or PCL3GUI command emission.
5. **CUPS Backend (`tools/cups_backend_smarttank`):** USB Bulk transport and status monitoring.
6. **Physical Device (P15_CISS ASIC):** Firmware ingestion, drop firing, and carriage movement.

---

## 2. Complete Option Mapping Table

| Option Name | PPD Option Keyword | Mechanism / Passing Channel | Action in `rastertopcl3gui` | PCL3GUI / USB Emission | Physical Effect / Verification State |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Page Size** | `*PageSize` | `header.PageSize`, `header.cupsPageSizeName` | Calculates width, height, DPI, and media ID (A4=26, Letter=2, Legal=3, 4x6=74, etc.) | `\033&l<id>A\033*t<dpi>R\033*r<width>S` | Paper feed indexing and carriage scan width (`UNIT/INTEGRATION VERIFIED`) |
| **Borderless** | `*PageSize *.FB` | `header.cupsImagingBBox`, `.FB` suffix | Disables margins; sets `is_borderless = 1` | `\033&l0U` / zero top margin alignment | Full-bleed carriage traversal (`UNIT/INTEGRATION VERIFIED`) |
| **Print Quality** | `*OutputMode` | `header.OutputType[0]` | Sets quality mode: Draft (1), Normal (2), Best (3), Photo (4) | `\033*o<qual>M` | Firmware printhead pass count / speed (`UNIT/INTEGRATION VERIFIED`) |
| **Media Type** | `*MediaType` | `header.cupsMediaType`, `header.cupsInteger[5]` | Sets media type (0=Plain, 5=Photo, 8=Matte) and subtype | `\033&l<type>M\033*o5W 0D 03 00 [hi] [lo]` | Droplet volume / drying curve table in firmware (`UNIT/INTEGRATION VERIFIED`) |
| **Color Model** | `*ColorModel` | `header.cupsColorSpace`, `header.cupsBitsPerPixel` | Dispatches decoder: sRGB (24bpp), Gray (8bpp), RGBA (32bpp), RGBW (32bpp), CMYK (32bpp) | `crd_color_mode10` (`\033*o3W 02 01 02`) | Selects color plane vs mono plane (`UNIT/INTEGRATION VERIFIED`) |
| **Ink Density** | `*HPDensity` | `<</cupsReal0 0.80..1.30>>` or `argv[5] (density=...)` | Multiplies pixel channels via `build_advanced_lut` (0.80x to 1.30x transfer curve) | Pixel values darkened or lightened in raster data before Mode 10 | Raster pixel transformation (`UNIT/INTEGRATION VERIFIED`; physical droplet change `HARDWARE REQUIRED`) |
| **Dry Time** | `*HPDryTime` | `<</cupsInteger7 0..40>>` or `argv[5] (HPDryTime=...)` | Extracts delay seconds (5, 10, 20, 40) | Emits PML command: `\033&b16WPML ... [sec]` | Carriage pause after page ejection (`UNIT/INTEGRATION VERIFIED`; physical pause `HARDWARE REQUIRED`) |
| **Pure Black** | `*HPPureBlack` | `argv[5]` (`HPPureBlack=TextOnly / AggressiveK`) | In `process_pixel_pro`, sets `R=G=B=0` if near-black (`R,G,B < 30`) or UCR reduction | Mode 10 stream has pure 0x00 bytes for black areas | Raster pixel transformation (`UNIT/INTEGRATION VERIFIED`; pigment vs dye pen separation `HARDWARE REQUIRED`) |
| **TAC Limit** | `*HPTACLimit` | `argv[5]` (`HPTACLimit=TAC240 / 280 / 300`) | In `process_pixel_pro`, clamps total simulated CMY coverage | Mode 10 stream reflects desaturated dark pixels | Raster pixel transformation (`UNIT/INTEGRATION VERIFIED`) |
| **Gamma Curve** | `*HPGammaCurve` | `argv[5]` (`HPGammaCurve=ShadowBoost / HighContrast / VividLandscape`) | Applies non-linear gamma / S-curve / vivid saturation via LUT | Mode 10 stream reflects remapped tonality | Raster pixel transformation (`UNIT/INTEGRATION VERIFIED`) |
| **Watermark** | `*HPWatermark` | `argv[5]` (`HPWatermark=Draft / Confidential / Copy / Sample`) | Procedurally blends 5x7 bitmap diagonal font into raster image | Watermark text rendered directly into raster data | Raster pixel transformation (`UNIT/INTEGRATION VERIFIED`) |
| **InkSaver** | `*HPInkSaver` | `argv[5]` (`HPInkSaver=Eco25 / Eco50 / Eco75 / EdgePreserve / DotGainGrid`) | Micro-perforation, edge preservation, or selective pixel dropping via `apply_ink_saver_pro` | Mode 10 stream contains thinned pixel patterns | Software raster reduction (`UNIT/INTEGRATION VERIFIED`; physical ink savings claim `THEORETICAL / UNVERIFIED`) |
| **Eco Color Drop** | `*HPEcoColorDrop`| `argv[5]` (`HPEcoColorDrop=DropColorBg / EcoGrayscale`) | Lightens high-luminance colored background pixels or forces desaturation | Mode 10 stream contains lightened background pixels | Software raster reduction (`UNIT/INTEGRATION VERIFIED`) |
| **KGray / CMYGray** | `*ColorModel KGray / CMYGray` | `header.cupsRowStep` (1=CMYGray, 2=KGray) | Sets `gray_mode = 0x01` or `0x02` in Grayscale sequence | `\033*o4W 0C 02 00 <mode>` | Sends PCL header sequence (`UNIT/INTEGRATION VERIFIED`; physical nozzle exclusivity `HARDWARE REQUIRED`) |

---

## 3. UI-Only vs Physical Action Classification

To prevent misleading claims of "hardware control":

1. **Active Filter Modifications:**
   - `HPDensity`, `HPPureBlack`, `HPTACLimit`, `HPGammaCurve`, `HPWatermark`, `HPInkSaver`, `HPEcoColorDrop`.
   - These options **genuinely alter the binary PCL3GUI stream** emitted by `rastertopcl3gui`. The resulting file sizes, hash values, and decoded raster patterns differ deterministically.
   - However, they act at the software raster level before compression. They do **not** reprogram hardware ASIC voltage or droplet mass.

2. **Active Hardware PCL/PML Sequences:**
   - `HPDryTime`: Generates genuine PML device delay sequence (`Esc&b16WPML...`).
   - `PageSize`, `MediaType`, `OutputMode`: Generates genuine PCL3GUI configure commands (`Esc&l...`, `Esc*o...`).
   - `KGray / CMYGray`: Generates genuine Grayscale sequence (`Esc*o4W 0C 02 00 01/02`).
   - Physical execution on hardware requires `--live` verification when device is physically connected (`HARDWARE REQUIRED`).

3. **UI-Only / Mock Elements:**
   - Any hardware telemetry readings (`levels`, `odometer`, `head-health`) without real USB connection operate strictly in `--mock` mode.
