import AppKit
import Foundation

// MARK: - Generador de Icono Nativo TankControl para macOS
// Diseña e interactúa con CoreGraphics para renderizar el icono maestro de 1024x1024.

func renderMasterIcon() -> NSImage {
    let dim: CGFloat = 1024.0
    let size = NSSize(width: dim, height: dim)
    let image = NSImage(size: size)

    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // 1. Sombra suave general
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -30), blur: 50, color: CGColor(gray: 0.0, alpha: 0.45))

    // 2. Base Squircle Estilo macOS (Margen oficial: 824x824 centrado en 1024x1024)
    let squircleRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 185.0
    let squirclePath = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Gradiente de fondo: Titanio Espacial / Azul Profundo
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.12, green: 0.16, blue: 0.24, alpha: 1.0),
        CGColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1.0)
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.addPath(squirclePath.cgPath)
        ctx.clip()
        ctx.drawLinearGradient(bgGradient,
                               start: CGPoint(x: 512, y: 924),
                               end: CGPoint(x: 512, y: 100),
                               options: [])
    }
    ctx.restoreGState()

    // 3. Borde interno translúcido (Rim Light)
    ctx.saveGState()
    ctx.addPath(squirclePath.cgPath)
    ctx.setLineWidth(4.0)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.22))
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Silueta de la Impresora / Carro Estilizado (Vidrio Acrílico & Aluminio)
    let printerRect = CGRect(x: 230, y: 280, width: 564, height: 280)
    let printerPath = NSBezierPath(roundedRect: printerRect, xRadius: 40, yRadius: 40)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -15), blur: 30, color: CGColor(gray: 0.0, alpha: 0.5))
    ctx.addPath(printerPath.cgPath)
    let printerColors = [
        CGColor(red: 0.22, green: 0.27, blue: 0.36, alpha: 0.95),
        CGColor(red: 0.14, green: 0.18, blue: 0.25, alpha: 0.95)
    ] as CFArray
    if let printerGrad = CGGradient(colorsSpace: colorSpace, colors: printerColors, locations: [0.0, 1.0]) {
        ctx.clip()
        ctx.drawLinearGradient(printerGrad, start: CGPoint(x: 512, y: 560), end: CGPoint(x: 512, y: 280), options: [])
    }
    ctx.restoreGState()

    // Borde de la impresora
    ctx.saveGState()
    ctx.addPath(printerPath.cgPath)
    ctx.setLineWidth(3.0)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18))
    ctx.strokePath()
    ctx.restoreGState()

    // 5. Hoja de Papel Emergente con franjas de calibración CMYK
    let paperRect = CGRect(x: 310, y: 440, width: 404, height: 260)
    let paperPath = NSBezierPath(roundedRect: paperRect, xRadius: 16, yRadius: 16)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 20, color: CGColor(gray: 0.0, alpha: 0.35))
    ctx.addPath(paperPath.cgPath)
    ctx.setFillColor(CGColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0))
    ctx.fillPath()

    // Franjas de calibración en la hoja
    let stripeY: CGFloat = 630
    let stripeW: CGFloat = 70
    let stripeH: CGFloat = 8
    let gap: CGFloat = 16
    let startX: CGFloat = 346

    let cmykStripeColors = [
        CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0),   // K
        CGColor(red: 0.0, green: 0.65, blue: 0.95, alpha: 1.0), // C
        CGColor(red: 0.95, green: 0.1, blue: 0.58, alpha: 1.0), // M
        CGColor(red: 0.98, green: 0.82, blue: 0.12, alpha: 1.0) // Y
    ]

    for i in 0..<4 {
        let sRect = CGRect(x: startX + CGFloat(i) * (stripeW + gap), y: stripeY, width: stripeW, height: stripeH)
        let sPath = NSBezierPath(roundedRect: sRect, xRadius: 4, yRadius: 4)
        ctx.saveGState()
        ctx.addPath(sPath.cgPath)
        ctx.setFillColor(cmykStripeColors[i])
        ctx.fillPath()
        ctx.restoreGState()
    }

    // Líneas simuladas de texto
    for lineIdx in 0..<3 {
        let ly = 580 - CGFloat(lineIdx) * 22
        let lRect = CGRect(x: startX, y: ly, width: CGFloat(260 - lineIdx * 40), height: 6)
        let lPath = NSBezierPath(roundedRect: lRect, xRadius: 3, yRadius: 3)
        ctx.saveGState()
        ctx.addPath(lPath.cgPath)
        ctx.setFillColor(CGColor(red: 0.78, green: 0.80, blue: 0.84, alpha: 1.0))
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // 6. Ranura Frontal y Ventana de Tanques CISS
    let tankSlotRect = CGRect(x: 270, y: 310, width: 484, height: 90)
    let tankSlotPath = NSBezierPath(roundedRect: tankSlotRect, xRadius: 18, yRadius: 18)
    ctx.saveGState()
    ctx.addPath(tankSlotPath.cgPath)
    ctx.setFillColor(CGColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    // 4 Depósitos de Tinta CISS Iluminados
    let tankWidth: CGFloat = 85
    let tankHeight: CGFloat = 66
    let tankSpacing: CGFloat = 28
    let tankStartX: CGFloat = 295
    let tankY: CGFloat = 322

    let cissGradients: [(CGColor, CGColor)] = [
        (CGColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0), CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1.0)), // K
        (CGColor(red: 0.20, green: 0.85, blue: 1.00, alpha: 1.0), CGColor(red: 0.00, green: 0.50, blue: 0.85, alpha: 1.0)), // C
        (CGColor(red: 1.00, green: 0.30, blue: 0.75, alpha: 1.0), CGColor(red: 0.80, green: 0.00, blue: 0.50, alpha: 1.0)), // M
        (CGColor(red: 1.00, green: 0.92, blue: 0.35, alpha: 1.0), CGColor(red: 0.95, green: 0.70, blue: 0.00, alpha: 1.0))  // Y
    ]

    for idx in 0..<4 {
        let tRect = CGRect(x: tankStartX + CGFloat(idx) * (tankWidth + tankSpacing), y: tankY, width: tankWidth, height: tankHeight)
        let tPath = NSBezierPath(roundedRect: tRect, xRadius: 12, yRadius: 12)
        ctx.saveGState()
        ctx.addPath(tPath.cgPath)
        ctx.clip()

        let (cTop, cBottom) = cissGradients[idx]
        let tGrad = CGGradient(colorsSpace: colorSpace, colors: [cTop, cBottom] as CFArray, locations: [0.0, 1.0])!
        ctx.drawLinearGradient(tGrad, start: CGPoint(x: tRect.midX, y: tRect.maxY), end: CGPoint(x: tRect.midX, y: tRect.minY), options: [])

        // Menisco de nivel de tinta superior
        ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5))
        ctx.setLineWidth(2.0)
        ctx.move(to: CGPoint(x: tRect.minX + 4, y: tRect.maxY - 6))
        ctx.addLine(to: CGPoint(x: tRect.maxX - 4, y: tRect.maxY - 6))
        ctx.strokePath()

        ctx.restoreGState()
    }

    // 7. Gota de Tinta Central Emblema (Fusión de Precisión y Color)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 15), blur: 35, color: CGColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 0.45))

    let dropCenterX: CGFloat = 512
    let dropCenterY: CGFloat = 560
    let dropW: CGFloat = 90
    let dropH: CGFloat = 130

    let dropPath = CGMutablePath()
    dropPath.move(to: CGPoint(x: dropCenterX, y: dropCenterY + dropH / 2))
    dropPath.addCurve(to: CGPoint(x: dropCenterX + dropW / 2, y: dropCenterY - dropH / 6),
                      control1: CGPoint(x: dropCenterX + dropW / 8, y: dropCenterY + dropH / 4),
                      control2: CGPoint(x: dropCenterX + dropW / 2, y: dropCenterY + dropH / 8))
    dropPath.addArc(center: CGPoint(x: dropCenterX, y: dropCenterY - dropH / 4),
                    radius: dropW / 2,
                    startAngle: 0,
                    endAngle: CGFloat.pi,
                    clockwise: false)
    dropPath.addCurve(to: CGPoint(x: dropCenterX, y: dropCenterY + dropH / 2),
                      control1: CGPoint(x: dropCenterX - dropW / 2, y: dropCenterY + dropH / 8),
                      control2: CGPoint(x: dropCenterX - dropW / 8, y: dropCenterY + dropH / 4))
    dropPath.closeSubpath()

    ctx.addPath(dropPath)
    let dropColors = [
        CGColor(red: 0.10, green: 0.80, blue: 1.00, alpha: 1.0),
        CGColor(red: 0.00, green: 0.45, blue: 0.95, alpha: 1.0)
    ] as CFArray
    if let dropGrad = CGGradient(colorsSpace: colorSpace, colors: dropColors, locations: [0.0, 1.0]) {
        ctx.clip()
        ctx.drawLinearGradient(dropGrad,
                               start: CGPoint(x: dropCenterX, y: dropCenterY + dropH / 2),
                               end: CGPoint(x: dropCenterX, y: dropCenterY - dropH / 2),
                               options: [])
    }
    ctx.restoreGState()

    // Reflejo especular en la gota
    ctx.saveGState()
    let specRect = CGRect(x: dropCenterX - 24, y: dropCenterY - 10, width: 18, height: 32)
    let specPath = NSBezierPath(ovalIn: specRect)
    ctx.addPath(specPath.cgPath)
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.65))
    ctx.fillPath()
    ctx.restoreGState()

    // 8. Resplandor superior sutil (Luz cenital Apple)
    ctx.saveGState()
    let glowColors = [
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18),
        CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
    ] as CFArray
    if let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(glowGrad,
                               startCenter: CGPoint(x: 512, y: 924), startRadius: 0,
                               endCenter: CGPoint(x: 512, y: 924), endRadius: 500,
                               options: [])
    }
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

// MARK: - Exportación y Generación de Conjunto de Iconos

func exportIconAssets() {
    let fileManager = FileManager.default
    let rootPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let brandDir = rootPath.appendingPathComponent("Brand")
    let appIconDir = brandDir.appendingPathComponent("AppIcon")
    let iconsetDir = appIconDir.appendingPathComponent("AppIcon.iconset")
    let appiconsetDir = appIconDir.appendingPathComponent("AppIcon.appiconset")

    for dir in [brandDir, appIconDir, iconsetDir, appiconsetDir] {
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
    }

    print("[*] Renderizando icono maestro 1024x1024...")
    let master = renderMasterIcon()

    guard let tiffData = master.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let masterPng = bitmap.representation(using: .png, properties: [:]) else {
        print("[ERROR] No se pudo codificar el PNG maestro")
        exit(1)
    }

    let masterPath = appIconDir.appendingPathComponent("AppIcon_1024x1024.png")
    try? masterPng.write(to: masterPath)
    print("  [+] Guardado icono maestro: \(masterPath.path)")

    // Tamaños oficiales de icono para macOS según Apple HIG
    let iconSizes: [(name: String, px: Int)] = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]

    print("[*] Generando resoluciones para iconset y appiconset...")
    for item in iconSizes {
        let resized = NSImage(size: NSSize(width: item.px, height: item.px))
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        master.draw(in: NSRect(x: 0, y: 0, width: item.px, height: item.px),
                    from: NSRect(origin: .zero, size: master.size),
                    operation: .copy,
                    fraction: 1.0)
        resized.unlockFocus()

        if let resTiff = resized.tiffRepresentation,
           let resRep = NSBitmapImageRep(data: resTiff),
           let resPng = resRep.representation(using: .png, properties: [:]) {
            let pathInIconset = iconsetDir.appendingPathComponent(item.name)
            let pathInAppiconset = appiconsetDir.appendingPathComponent(item.name)
            try? resPng.write(to: pathInIconset)
            try? resPng.write(to: pathInAppiconset)
        }
    }

    // Contents.json para Asset Catalog
    let contentsJson = """
    {
      "images" : [
        { "size" : "16x16", "idiom" : "mac", "filename" : "icon_16x16.png", "scale" : "1x" },
        { "size" : "16x16", "idiom" : "mac", "filename" : "icon_16x16@2x.png", "scale" : "2x" },
        { "size" : "32x32", "idiom" : "mac", "filename" : "icon_32x32.png", "scale" : "1x" },
        { "size" : "32x32", "idiom" : "mac", "filename" : "icon_32x32@2x.png", "scale" : "2x" },
        { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128.png", "scale" : "1x" },
        { "size" : "128x128", "idiom" : "mac", "filename" : "icon_128x128@2x.png", "scale" : "2x" },
        { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256.png", "scale" : "1x" },
        { "size" : "256x256", "idiom" : "mac", "filename" : "icon_256x256@2x.png", "scale" : "2x" },
        { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512.png", "scale" : "1x" },
        { "size" : "512x512", "idiom" : "mac", "filename" : "icon_512x512@2x.png", "scale" : "2x" }
      ],
      "info" : {
        "version" : 1,
        "author" : "xcode"
      }
    }
    """
    let jsonPath = appiconsetDir.appendingPathComponent("Contents.json")
    try? contentsJson.write(to: jsonPath, atomically: true, encoding: .utf8)
    print("  [+] Generado Contents.json en: \(jsonPath.path)")

    // Compilar a formato binario multipágina Apple ICNS
    let icnsPath = appIconDir.appendingPathComponent("AppIcon.icns")
    let iconutilProc = Process()
    iconutilProc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutilProc.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]

    do {
        try iconutilProc.run()
        iconutilProc.waitUntilExit()
        if iconutilProc.terminationStatus == 0 {
            print("  [+] ¡Archivo binario macOS .icns compilado con éxito: \(icnsPath.path)!")
        } else {
            print("[WARN] iconutil terminó con código \(iconutilProc.terminationStatus)")
        }
    } catch {
        print("[WARN] No se pudo invocar iconutil: \(error.localizedDescription)")
    }
}

exportIconAssets()
