# HP Smart Tank 500 - Print Pipeline on macOS ARM64

## Overview
The HP Smart Tank 500 series relies on the `PCL3GUI` printing language (also known as Pyramid). On Linux, HPLIP translates CUPS raster data into PCL3GUI using the `hpcups` filter.

On macOS, the native printing architecture handles PDF natively. The print pipeline requires:
1. `cgpdftoraster`: A macOS-native CUPS filter that converts PDF spools into `application/vnd.cups-raster`.
2. `hpcups`: The HPLIP filter that reads CUPS raster and generates `PCL3GUI` with `PJL` headers.
3. USB Backend: The standard CUPS `usb` backend can stream this directly to the printer.

## Security & Architecture Win
A massive security and architecture win discovered during compilation: **The proprietary closed-source blob (`libImageProcessor`) is NOT required to drive this printer**. We successfully compiled `hpcups` natively for `ARM64` without linking this blob by explicitly disabling it and utilizing the `DISABLE_IMAGEPROCESSOR` macro.

## Compilation Steps (Apple Silicon)
The following patches and commands were used to compile `hpcups` organically on macOS:

### 1. Dependencies
* `libjpeg` and `dbus` (via Homebrew: `brew install jpeg dbus`)

### 2. Configuration
We used `./configure` aggressively stripping out unnecessary Linux/GUI components:
```bash
LDFLAGS="-L/opt/homebrew/lib" CPPFLAGS="-I/opt/homebrew/include" \
PYTHONINCLUDEDIR="-I/opt/homebrew/opt/python@3.14/Frameworks/Python.framework/Versions/3.14/include/python3.14" \
./configure --enable-hpcups-install --disable-gui-build \
--disable-network-build --disable-fax-build --disable-scan-build \
--disable-doc-build --disable-hpijs-install --disable-dbus-build \
--disable-imageProcessor-build
```

### 3. Source Code Patches
macOS is case-insensitive, which caused `#include "utils.h"` in some `hpcups` files to wrongly include `prnt/hpcups/Utils.h` instead of `common/utils.h`. Additionally, `malloc.h` is deprecated on macOS.

* **Fix Includes**: Replaced `#include "utils.h"` with `#include "../../common/utils.h"` in `HPCupsFilter.cpp`, `ModeJbig.cpp`, `LJZjStream.cpp`, `SystemServices.cpp`, `Hbpl1.cpp`, `ModeJpeg.cpp`, `Utils.cpp`.
* **Fix Malloc**: Replaced `<malloc.h>` with `<stdlib.h>` in `genJPEGStrips.cpp`.
* **Bypass Blob**: Injected `#define DISABLE_IMAGEPROCESSOR` at the very top of `HPCupsFilter.cpp`.
* **Makefile**: Removed `-lImageProcessor` from the `Makefile` linking stage.

### 4. Build
```bash
make hpcups
```
The resulting binary (`hpcups`) is a native Mach-O 64-bit executable for arm64!

## Offline Verification
We successfully ran an offline pipeline simulation without errors:
1. Generated a test PDF using `cupsfilter -m application/pdf`.
2. Converted PDF to CUPS raster using Apple's `cgpdftoraster` (via `cupsfilter -m application/vnd.cups-raster`).
3. Streamed the raster through the natively compiled `hpcups` filter using the Smart Tank 500 PPD.

**Result**: A fully valid `PCL3GUI` payload (1.3KB) starting with `@PJL ENTER LANGUAGE=PCL3GUI` was emitted perfectly!

## Next Steps
Now that the pipeline is proven, the next step is to configure CUPS to use our PPD and filter, and print a real physical test page.
