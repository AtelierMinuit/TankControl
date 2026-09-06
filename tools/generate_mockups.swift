import Cocoa
import CoreGraphics
import Foundation

// MARK: - Generador Nativo de Mockups para TankControl (Apple Silicon / macOS HIG)

struct Theme {
    let isDark: Bool
    let windowBg: CGColor
    let titleBarBg: CGColor
    let sidebarBg: CGColor
    let cardBg: CGColor
    let cardBorder: CGColor
    let textPrimary: NSColor
    let textSecondary: NSColor
    let textTertiary: NSColor
    let accentColor: CGColor
    let dividerColor: CGColor

    static let dark = Theme(
        isDark: true,
        windowBg: CGColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1.0),
        titleBarBg: CGColor(red: 0.16, green: 0.17, blue: 0.19, alpha: 1.0),
        sidebarBg: CGColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 1.0),
        cardBg: CGColor(red: 0.18, green: 0.19, blue: 0.22, alpha: 0.7),
        cardBorder: CGColor(red: 0.26, green: 0.28, blue: 0.32, alpha: 0.6),
        textPrimary: NSColor(white: 0.92, alpha: 1.0),
        textSecondary: NSColor(white: 0.62, alpha: 1.0),
        textTertiary: NSColor(white: 0.42, alpha: 1.0),
        accentColor: CGColor(red: 0.0, green: 0.48, blue: 0.85, alpha: 1.0),
        dividerColor: CGColor(red: 0.24, green: 0.25, blue: 0.28, alpha: 1.0)
    )

    static let light = Theme(
        isDark: false,
        windowBg: CGColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0),
        titleBarBg: CGColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1.0),
        sidebarBg: CGColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 1.0),
        cardBg: CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85),
        cardBorder: CGColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 0.8),
        textPrimary: NSColor(white: 0.12, alpha: 1.0),
        textSecondary: NSColor(white: 0.45, alpha: 1.0),
        textTertiary: NSColor(white: 0.65, alpha: 1.0),
        accentColor: CGColor(red: 0.0, green: 0.45, blue: 0.82, alpha: 1.0),
        dividerColor: CGColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 1.0)
    )
}

func drawWindowFrame(ctx: CGContext, width: CGFloat, height: CGFloat, title: String, theme: Theme, selectedSection: String, isDevEnabled: Bool = false) {
    ctx.setFillColor(theme.windowBg)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let titleBarHeight: CGFloat = 38
    let titleBarRect = CGRect(x: 0, y: height - titleBarHeight, width: width, height: titleBarHeight)
    ctx.setFillColor(theme.titleBarBg)
    ctx.fill(titleBarRect)

    ctx.setStrokeColor(theme.dividerColor)
    ctx.setLineWidth(1)
    ctx.strokeLineSegments(between: [CGPoint(x: 0, y: height - titleBarHeight), CGPoint(x: width, y: height - titleBarHeight)])

    let buttons = [
        (CGColor(red: 1.0, green: 0.38, blue: 0.35, alpha: 1.0), CGFloat(18)),
        (CGColor(red: 1.0, green: 0.74, blue: 0.18, alpha: 1.0), CGFloat(36)),
        (CGColor(red: 0.16, green: 0.79, blue: 0.29, alpha: 1.0), CGFloat(54))
    ]
    for (color, x) in buttons {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: x, y: height - 25, width: 12, height: 12))
    }

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ]
    let titleStr = title as NSString
    let titleSize = titleStr.size(withAttributes: titleAttrs)
    titleStr.draw(at: NSPoint(x: (width - titleSize.width) / 2.0, y: height - 26), withAttributes: titleAttrs)

    let sidebarWidth: CGFloat = 200
    let sidebarRect = CGRect(x: 0, y: 0, width: sidebarWidth, height: height - titleBarHeight)
    ctx.setFillColor(theme.sidebarBg)
    ctx.fill(sidebarRect)
    ctx.strokeLineSegments(between: [CGPoint(x: sidebarWidth, y: 0), CGPoint(x: sidebarWidth, y: height - titleBarHeight)])

    var items = [
        ("General", "printer"),
        ("Impresión", "doc.text"),
        ("Escáner", "scanner"),
        ("Tinta", "drop"),
        ("Mantenimiento", "wrench.and.screwdriver"),
        ("Actividad", "chart.bar")
    ]
    if isDevEnabled {
        items.append(("Desarrollo", "hammer"))
    }

    var currentY: CGFloat = height - titleBarHeight - 34

    let hAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10, weight: .bold),
        .foregroundColor: theme.textTertiary
    ]
    ("HP SMART TANK 500" as NSString).draw(at: NSPoint(x: 18, y: currentY), withAttributes: hAttrs)
    currentY -= 22

    for (name, _) in items {
        let isSelected = (name == selectedSection)

        if isSelected {
            let selRect = CGRect(x: 10, y: currentY - 4, width: sidebarWidth - 20, height: 26)
            ctx.setFillColor(theme.accentColor.copy(alpha: theme.isDark ? 0.35 : 0.2)!)
            let path = CGPath(roundedRect: selRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
        }

        let itemAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: isSelected ? .semibold : .regular),
            .foregroundColor: isSelected ? (theme.isDark ? NSColor.white : NSColor(cgColor: theme.accentColor)!) : theme.textPrimary
        ]
        let bullet = isSelected ? "▸ " : "  "
        ((bullet + name) as NSString).draw(at: NSPoint(x: 16, y: currentY), withAttributes: itemAttrs)
        currentY -= 28
    }

    let vAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 9),
        .foregroundColor: theme.textTertiary
    ]
    ("v0.1.0-alpha-pre-hardware" as NSString).draw(at: NSPoint(x: 18, y: 14), withAttributes: vAttrs)

    let liveAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.16, green: 0.78, blue: 0.35, alpha: 1.0)
    ]
    ("● LIVE: USB (0x03F0:0x2B54)" as NSString).draw(at: NSPoint(x: width - 190, y: height - 25), withAttributes: liveAttrs)
}

func drawCard(ctx: CGContext, rect: CGRect, theme: Theme) {
    ctx.setFillColor(theme.cardBg)
    let path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
    ctx.addPath(path)
    ctx.fillPath()

    ctx.setStrokeColor(theme.cardBorder)
    ctx.setLineWidth(1)
    ctx.addPath(path)
    ctx.strokePath()
}

func createContext(width: CGFloat, height: CGFloat) -> (CGContext, NSGraphicsContext) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil,
        width: Int(width),
        height: Int(height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    return (ctx, nsCtx)
}

func saveContextToPNG(ctx: CGContext, path: String) {
    guard let img = ctx.makeImage() else {
        print("Error: No se pudo crear CGImage")
        return
    }
    let rep = NSBitmapImageRep(cgImage: img)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Error: No se pudo codificar a PNG")
        return
    }
    try? pngData.write(to: URL(fileURLWithPath: path))
    print("[+] Mockup generado: \(path)")
}

func generateDashboardMockup(outputPath: String, theme: Theme) {
    let width: CGFloat = 960
    let height: CGFloat = 620
    let (ctx, nsCtx) = createContext(width: width, height: height)
    NSGraphicsContext.current = nsCtx

    drawWindowFrame(ctx: ctx, width: width, height: height, title: "TankControl — General", theme: theme, selectedSection: "General")

    let contentX: CGFloat = 220
    let contentW = width - contentX - 20

    let heroRect = CGRect(x: contentX, y: height - 120, width: contentW, height: 70)
    drawCard(ctx: ctx, rect: heroRect, theme: theme)

    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 16, weight: .bold),
        .foregroundColor: theme.textPrimary
    ]
    ("HP Smart Tank 500 series" as NSString).draw(at: NSPoint(x: contentX + 20, y: height - 85), withAttributes: titleAttrs)

    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: theme.textSecondary
    ]
    ("ASIC P15_CISS • Controlador Nativo macOS ARM64 • CUPS / PCL3GUI" as NSString).draw(at: NSPoint(x: contentX + 20, y: height - 105), withAttributes: subAttrs)

    let badgeRect = CGRect(x: contentX + contentW - 140, y: height - 98, width: 120, height: 26)
    ctx.setFillColor(CGColor(red: 0.16, green: 0.75, blue: 0.32, alpha: 0.2))
    ctx.addPath(CGPath(roundedRect: badgeRect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.fillPath()
    let bAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.16, green: 0.75, blue: 0.32, alpha: 1.0)
    ]
    ("● Lista (En línea)" as NSString).draw(at: NSPoint(x: contentX + contentW - 126, y: height - 92), withAttributes: bAttrs)

    let tanksY = height - 290
    let tanksRect = CGRect(x: contentX, y: tanksY, width: contentW, height: 155)
    drawCard(ctx: ctx, rect: tanksRect, theme: theme)

    ("Niveles de Tinta (Depósitos CISS)" as NSString).draw(at: NSPoint(x: contentX + 20, y: tanksY + 128), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ])

    ("(Valores simulados en Digital Twin offline)" as NSString).draw(at: NSPoint(x: contentX + 240, y: tanksY + 129), withAttributes: [
        .font: NSFont.systemFont(ofSize: 10),
        .foregroundColor: theme.textTertiary
    ])

    let tanks = [
        ("K", "Negro", "■", 85, theme.isDark ? CGColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 1.0) : CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0), CGFloat(0)),
        ("C", "Cian", "▲", 70, CGColor(red: 0.0, green: 0.64, blue: 0.88, alpha: 1.0), CGFloat(1)),
        ("M", "Magenta", "●", 65, CGColor(red: 0.92, green: 0.0, blue: 0.55, alpha: 1.0), CGFloat(2)),
        ("Y", "Amarillo", "◆", 90, CGColor(red: 0.98, green: 0.80, blue: 0.05, alpha: 1.0), CGFloat(3))
    ]

    let tankColWidth = contentW / 4.0
    for (_, name, shape, level, color, idx) in tanks {
        let tx = contentX + (idx * tankColWidth) + (tankColWidth - 54) / 2.0
        let tankBox = CGRect(x: tx, y: tanksY + 28, width: 54, height: 75)

        ctx.setFillColor(theme.isDark ? CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0) : CGColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0))
        ctx.addPath(CGPath(roundedRect: tankBox, cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.fillPath()

        let fillH = CGFloat(level) * 0.68
        let fluidRect = CGRect(x: tx + 3, y: tanksY + 31, width: 48, height: fillH)
        ctx.setFillColor(color)
        ctx.addPath(CGPath(roundedRect: fluidRect, cornerWidth: 4, cornerHeight: 4, transform: nil))
        ctx.fillPath()

        let label = "\(shape) \(level)%"
        (label as NSString).draw(at: NSPoint(x: tx + 6, y: tanksY + 10), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: theme.textPrimary
        ])
        (name as NSString).draw(at: NSPoint(x: tx + 10, y: tanksY - 4), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textSecondary
        ])
    }

    let actionsY = height - 425
    let actionCards = [
        ("Alinear Cabezales", "Optimiza alineación de inyección", CGFloat(0)),
        ("Limpieza de Cabezal", "Ciclo estándar sin desperdicio", CGFloat(1)),
        ("Página de Diagnóstico", "Imprime reporte técnico interno", CGFloat(2))
    ]
    let cardW = (contentW - 20) / 3.0
    for (title, desc, i) in actionCards {
        let ax = contentX + i * (cardW + 10)
        let aRect = CGRect(x: ax, y: actionsY, width: cardW, height: 115)
        drawCard(ctx: ctx, rect: aRect, theme: theme)

        (title as NSString).draw(at: NSPoint(x: ax + 14, y: actionsY + 78), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: theme.textPrimary
        ])
        (desc as NSString).draw(at: NSPoint(x: ax + 14, y: actionsY + 58), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textSecondary
        ])

        let btnRect = CGRect(x: ax + 14, y: actionsY + 16, width: 80, height: 24)
        ctx.setFillColor(theme.accentColor.copy(alpha: theme.isDark ? 0.3 : 0.2)!)
        ctx.addPath(CGPath(roundedRect: btnRect, cornerWidth: 5, cornerHeight: 5, transform: nil))
        ctx.fillPath()
        ("Ejecutar" as NSString).draw(at: NSPoint(x: ax + 30, y: actionsY + 21), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: theme.isDark ? NSColor.white : NSColor(cgColor: theme.accentColor)!
        ])
    }

    let infoY = height - 570
    let infoRect = CGRect(x: contentX, y: infoY, width: contentW, height: 125)
    drawCard(ctx: ctx, rect: infoRect, theme: theme)

    ("Detalles de Configuración e Integridad" as NSString).draw(at: NSPoint(x: contentX + 16, y: infoY + 98), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ])

    let details = [
        ("Cola CUPS:", "HP_Smart_Tank_500 (Modo 10 PCL3GUI)"),
        ("Perfil ICC Activo:", "HP_Smart_Tank_Plain.icc (ColorSync sRGB D50)"),
        ("Conectividad USB:", "ID 03f0:2b54 • Interfaces 0 (Print), 1 (eSCL), 2 (Scan)"),
        ("Ahorro de Tinta:", "InkSaver Equilibrado (-25% raster, texto preservado)")
    ]

    var dy = infoY + 72
    for (k, v) in details {
        (k as NSString).draw(at: NSPoint(x: contentX + 16, y: dy), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: theme.textSecondary
        ])
        (v as NSString).draw(at: NSPoint(x: contentX + 160, y: dy), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textPrimary
        ])
        dy -= 18
    }

    saveContextToPNG(ctx: ctx, path: outputPath)
}

func generateInkStatusMockup(outputPath: String, theme: Theme) {
    let width: CGFloat = 960
    let height: CGFloat = 620
    let (ctx, nsCtx) = createContext(width: width, height: height)
    NSGraphicsContext.current = nsCtx

    drawWindowFrame(ctx: ctx, width: width, height: height, title: "TankControl — Tinta", theme: theme, selectedSection: "Tinta")

    let contentX: CGFloat = 220
    let contentW = width - contentX - 20

    let bannerRect = CGRect(x: contentX, y: height - 100, width: contentW, height: 50)
    ctx.setFillColor(CGColor(red: 0.95, green: 0.65, blue: 0.1, alpha: 0.15))
    let bPath = CGPath(roundedRect: bannerRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
    ctx.addPath(bPath)
    ctx.fillPath()
    ctx.setStrokeColor(CGColor(red: 0.95, green: 0.65, blue: 0.1, alpha: 0.4))
    ctx.addPath(bPath)
    ctx.strokePath()

    ("⚠ Verificación Física Requerida: HP Smart Tank 500 no posee flotadores electrónicos." as NSString).draw(
        at: NSPoint(x: contentX + 16, y: height - 76),
        withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: theme.isDark ? NSColor(calibratedRed: 1.0, green: 0.8, blue: 0.2, alpha: 1.0) : NSColor.brown]
    )
    ("Los niveles mostrados son estimaciones basadas en conteo de gotas. Inspeccione siempre las ventanas transparentes frontales." as NSString).draw(
        at: NSPoint(x: contentX + 16, y: height - 92),
        withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: theme.textSecondary]
    )

    let cissRect = CGRect(x: contentX, y: height - 310, width: contentW, height: 195)
    drawCard(ctx: ctx, rect: cissRect, theme: theme)

    ("Depósitos CISS Integrados" as NSString).draw(at: NSPoint(x: contentX + 20, y: height - 135), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ])

    let tanks = [
        ("K", "Negro GT53", 85, "135 ml", "Pigmentada"),
        ("C", "Cian GT52", 70, "70 ml", "Colorante"),
        ("M", "Magenta GT52", 65, "70 ml", "Colorante"),
        ("Y", "Amarillo GT52", 90, "70 ml", "Colorante")
    ]
    let colors = [
        theme.isDark ? CGColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 1.0) : CGColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0),
        CGColor(red: 0.0, green: 0.64, blue: 0.88, alpha: 1.0),
        CGColor(red: 0.92, green: 0.0, blue: 0.55, alpha: 1.0),
        CGColor(red: 0.98, green: 0.80, blue: 0.05, alpha: 1.0)
    ]

    let colW = contentW / 4.0
    for (i, t) in tanks.enumerated() {
        let tx = contentX + CGFloat(i) * colW + (colW - 60) / 2.0
        let tankBox = CGRect(x: tx, y: height - 255, width: 60, height: 95)
        ctx.setFillColor(theme.isDark ? CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0) : CGColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0))
        ctx.addPath(CGPath(roundedRect: tankBox, cornerWidth: 6, cornerHeight: 6, transform: nil))
        ctx.fillPath()

        let fluidH = CGFloat(t.2) * 0.85
        let fRect = CGRect(x: tx + 3, y: height - 252, width: 54, height: fluidH)
        ctx.setFillColor(colors[i])
        ctx.addPath(CGPath(roundedRect: fRect, cornerWidth: 4, cornerHeight: 4, transform: nil))
        ctx.fillPath()

        ("\(t.2)%" as NSString).draw(at: NSPoint(x: tx + 14, y: height - 275), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: theme.textPrimary
        ])
        (t.1 as NSString).draw(at: NSPoint(x: tx + 2, y: height - 290), withAttributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: theme.textSecondary
        ])
        ("\(t.3) • \(t.4)" as NSString).draw(at: NSPoint(x: tx - 4, y: height - 304), withAttributes: [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: theme.textTertiary
        ])
    }

    let sensRect = CGRect(x: contentX, y: height - 570, width: contentW, height: 245)
    drawCard(ctx: ctx, rect: sensRect, theme: theme)

    ("Sensores de Cabezales y Chasis" as NSString).draw(at: NSPoint(x: contentX + 20, y: height - 340), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ])

    let sensorRows = [
        ("Cabezal Negro (M0H50A):", "OK • Temp: 32°C • Voltaje: Nominal"),
        ("Cabezal Color (M0H51A):", "OK • Temp: 34°C • Voltaje: Nominal"),
        ("Sensor de Tapa / Puerta Frontal:", "Cerrada (Normal)"),
        ("Sensor de Presencia de Papel:", "Bandeja cargada (Papel detectado)"),
        ("Sensor Óptico de Carro:", "Calibrado • Sin atasco"),
        ("Nivel Acumulado de Almohadilla:", "Estimado 18% (Seguro)")
    ]

    var sy = height - 370
    for r in sensorRows {
        (r.0 as NSString).draw(at: NSPoint(x: contentX + 20, y: sy), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: theme.textSecondary
        ])
        (r.1 as NSString).draw(at: NSPoint(x: contentX + 250, y: sy), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textPrimary
        ])
        sy -= 26
    }

    saveContextToPNG(ctx: ctx, path: outputPath)
}

func generatePrintCenterMockup(outputPath: String, theme: Theme) {
    let width: CGFloat = 960
    let height: CGFloat = 620
    let (ctx, nsCtx) = createContext(width: width, height: height)
    NSGraphicsContext.current = nsCtx

    drawWindowFrame(ctx: ctx, width: width, height: height, title: "TankControl — Impresión", theme: theme, selectedSection: "Impresión")

    let contentX: CGFloat = 220
    let contentW = width - contentX - 20

    let groups = [
        ("▾ Calidad de Impresión", ["Resolución: 600x600 dpi (Óptima)", "Tipo de Soporte: Papel común / Bond"]),
        ("▾ Color y Reproducción", ["Espacio de Color: sRGB (Estándar fotográfico)", "ColorSync ICC: HP_Smart_Tank_Plain.icc", "Negro Puro: Activado (Preserva K al 100%)"]),
        ("▾ Papel y Alimentación", ["Tamaño de Página: Carta (8.5 x 11 in)", "Orientación: Vertical", "Borde a Borde (Borderless): Desactivado"]),
        ("▾ Ahorro de Tinta (InkSaver)", ["Nivel Activo: Equilibrado (-25% raster)", "Preservar Bordes: Activado", "Límite TAC (Total Area Coverage): 260%"]),
        ("▸ Opciones Avanzadas del Controlador", ["Modo de Compresión: PCL3GUI Mode 10", "Drying Time: 0s", "Densidad de Inyección: Normal"])
    ]

    var gy = height - 80
    for (header, lines) in groups {
        let gHeight: CGFloat = CGFloat(lines.count * 22 + 36)
        let gRect = CGRect(x: contentX, y: gy - gHeight, width: contentW, height: gHeight)
        drawCard(ctx: ctx, rect: gRect, theme: theme)

        (header as NSString).draw(at: NSPoint(x: contentX + 16, y: gy - 26), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: theme.textPrimary
        ])

        var ly = gy - 48
        for line in lines {
            (line as NSString).draw(at: NSPoint(x: contentX + 32, y: ly), withAttributes: [
                .font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: theme.textSecondary
            ])
            ly -= 22
        }

        gy -= (gHeight + 10)
    }

    let printBtnRect = CGRect(x: contentX + contentW - 140, y: 15, width: 140, height: 28)
    ctx.setFillColor(theme.accentColor)
    ctx.addPath(CGPath(roundedRect: printBtnRect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.fillPath()
    let pAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: NSColor.white
    ]
    ("Imprimir Documento" as NSString).draw(at: NSPoint(x: contentX + contentW - 130, y: 22), withAttributes: pAttrs)

    saveContextToPNG(ctx: ctx, path: outputPath)
}

func generateScannerMockup(outputPath: String, theme: Theme) {
    let width: CGFloat = 960
    let height: CGFloat = 620
    let (ctx, nsCtx) = createContext(width: width, height: height)
    NSGraphicsContext.current = nsCtx

    drawWindowFrame(ctx: ctx, width: width, height: height, title: "TankControl — Escáner", theme: theme, selectedSection: "Escáner")

    let contentX: CGFloat = 220
    let contentW = width - contentX - 20

    let leftColW: CGFloat = 310
    let rightColX = contentX + leftColW + 16
    let rightColW = contentW - leftColW - 16

    let settingsRect = CGRect(x: contentX, y: 20, width: leftColW, height: height - 70)
    drawCard(ctx: ctx, rect: settingsRect, theme: theme)

    ("Ajustes de Escaneo" as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 85), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ])

    let scanControls = [
        ("Modo de Color:", "Color (24 bits)"),
        ("Resolución:", "300 ppi (Recomendada)"),
        ("Tamaño de Cama:", "Plano A4 / Carta (8.5 x 11.7 in)"),
        ("Formato de Salida:", "PDF con soporte de texto"),
        ("Destino:", "~/Documents/Scans"),
        ("Mejoras:", "Corrección óptica de contraste"),
        ("Conexión:", "eSCL / AirScan nativo")
    ]

    var cy = height - 120
    for c in scanControls {
        (c.0 as NSString).draw(at: NSPoint(x: contentX + 16, y: cy), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: theme.textSecondary
        ])
        (c.1 as NSString).draw(at: NSPoint(x: contentX + 16, y: cy - 16), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textPrimary
        ])
        cy -= 44
    }

    let scanBtnRect = CGRect(x: contentX + 16, y: 35, width: leftColW - 32, height: 32)
    ctx.setFillColor(theme.accentColor)
    ctx.addPath(CGPath(roundedRect: scanBtnRect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.fillPath()
    ("Escanear Página" as NSString).draw(at: NSPoint(x: contentX + 115, y: 43), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: NSColor.white
    ])

    let previewRect = CGRect(x: rightColX, y: 20, width: rightColW, height: height - 70)
    drawCard(ctx: ctx, rect: previewRect, theme: theme)

    ("Vista Previa Óptica" as NSString).draw(at: NSPoint(x: rightColX + 16, y: height - 85), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ])

    let paperRect = CGRect(x: rightColX + 30, y: 40, width: rightColW - 60, height: height - 150)
    ctx.setFillColor(theme.isDark ? CGColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) : CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    ctx.addPath(CGPath(roundedRect: paperRect, cornerWidth: 4, cornerHeight: 4, transform: nil))
    ctx.fillPath()

    let docColor = CGColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.8)
    ctx.setFillColor(docColor)
    ctx.fill(CGRect(x: rightColX + 50, y: height - 160, width: 140, height: 16))
    for i in 0..<10 {
        ctx.fill(CGRect(x: rightColX + 50, y: height - 195 - CGFloat(i * 22), width: rightColW - 100, height: 8))
    }

    saveContextToPNG(ctx: ctx, path: outputPath)
}

func generateMaintenanceMockup(outputPath: String, theme: Theme) {
    let width: CGFloat = 960
    let height: CGFloat = 620
    let (ctx, nsCtx) = createContext(width: width, height: height)
    NSGraphicsContext.current = nsCtx

    drawWindowFrame(ctx: ctx, width: width, height: height, title: "TankControl — Mantenimiento", theme: theme, selectedSection: "Mantenimiento")

    let contentX: CGFloat = 220
    let contentW = width - contentX - 20

    let normalRect = CGRect(x: contentX, y: height - 260, width: contentW, height: 210)
    drawCard(ctx: ctx, rect: normalRect, theme: theme)

    ("Mantenimiento Habitual" as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 80), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ])

    let normalCards = [
        ("Alinear Cabezal", "Alinea inyectores térmicos para eliminar efecto banding o desfases.", "Bajo", CGFloat(0)),
        ("Limpieza Estándar", "Ciclo ligero de purga de boquillas para recuperar líneas perdidas.", "Medio (~1.2 ml)", CGFloat(1))
    ]
    let cW = (contentW - 44) / 2.0
    for (t, d, ink, i) in normalCards {
        let cx = contentX + 16 + i * (cW + 12)
        let cardR = CGRect(x: cx, y: height - 245, width: cW, height: 145)
        ctx.setFillColor(theme.cardBg)
        let p = CGPath(roundedRect: cardR, cornerWidth: 8, cornerHeight: 8, transform: nil)
        ctx.addPath(p)
        ctx.fillPath()
        ctx.setStrokeColor(theme.cardBorder)
        ctx.strokePath()

        (t as NSString).draw(at: NSPoint(x: cx + 12, y: height - 125), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: theme.textPrimary
        ])
        (d as NSString).draw(at: NSPoint(x: cx + 12, y: height - 150), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textSecondary
        ])
        ("Consumo de Tinta: \(ink)" as NSString).draw(at: NSPoint(x: cx + 12, y: height - 195), withAttributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: theme.textTertiary
        ])

        let bR = CGRect(x: cx + 12, y: height - 235, width: 90, height: 24)
        ctx.setFillColor(theme.accentColor.copy(alpha: theme.isDark ? 0.3 : 0.2)!)
        ctx.addPath(CGPath(roundedRect: bR, cornerWidth: 5, cornerHeight: 5, transform: nil))
        ctx.fillPath()
        ("Ejecutar" as NSString).draw(at: NSPoint(x: cx + 36, y: height - 230), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: theme.isDark ? NSColor.white : NSColor(cgColor: theme.accentColor)!
        ])
    }

    let advRect = CGRect(x: contentX, y: 20, width: contentW, height: height - 295)
    drawCard(ctx: ctx, rect: advRect, theme: theme)

    ("Mantenimiento Avanzado (Requiere Confirmación Explícita)" as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 310), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ])

    let advCards = [
        ("Limpieza Profunda (Deep Clean)", "Purgado intensivo del sistema hidráulico. Utilizar solo si persisten inyectores tapados.", "Alto (~5.5 ml)", CGFloat(0)),
        ("Limpieza de Rodillos", "Ciclo mecánico de rotación de rodillos de arrastre sin inyección de tinta.", "0 ml", CGFloat(1))
    ]
    for (t, d, ink, i) in advCards {
        let cx = contentX + 16 + i * (cW + 12)
        let cardR = CGRect(x: cx, y: 35, width: cW, height: 230)
        ctx.setFillColor(theme.cardBg)
        let p = CGPath(roundedRect: cardR, cornerWidth: 8, cornerHeight: 8, transform: nil)
        ctx.addPath(p)
        ctx.fillPath()
        ctx.setStrokeColor(theme.cardBorder)
        ctx.strokePath()

        (t as NSString).draw(at: NSPoint(x: cx + 12, y: 235), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: theme.textPrimary
        ])
        (d as NSString).draw(at: NSPoint(x: cx + 12, y: 205), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textSecondary
        ])
        ("Consumo de Tinta: \(ink)" as NSString).draw(at: NSPoint(x: cx + 12, y: 155), withAttributes: [
            .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: NSColor.orange
        ])

        let bR = CGRect(x: cx + 12, y: 55, width: 150, height: 24)
        ctx.setFillColor(CGColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 0.2))
        ctx.addPath(CGPath(roundedRect: bR, cornerWidth: 5, cornerHeight: 5, transform: nil))
        ctx.fillPath()
        ("Solicitar Confirmación…" as NSString).draw(at: NSPoint(x: cx + 18, y: 60), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.orange
        ])
    }

    saveContextToPNG(ctx: ctx, path: outputPath)
}

func generateActivityMockup(outputPath: String, theme: Theme) {
    let width: CGFloat = 960
    let height: CGFloat = 620
    let (ctx, nsCtx) = createContext(width: width, height: height)
    NSGraphicsContext.current = nsCtx

    drawWindowFrame(ctx: ctx, width: width, height: height, title: "TankControl — Actividad", theme: theme, selectedSection: "Actividad")

    let contentX: CGFloat = 220
    let contentW = width - contentX - 20

    // Tarjeta Heroica de Odometría
    let heroRect = CGRect(x: contentX, y: height - 120, width: contentW, height: 70)
    drawCard(ctx: ctx, rect: heroRect, theme: theme)

    ("Odómetro de Hardware y Salud Mecánica" as NSString).draw(at: NSPoint(x: contentX + 20, y: height - 85), withAttributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    ("Telemetría directa del firmware EWS • Conexión USB High-Speed activa" as NSString).draw(at: NSPoint(x: contentX + 20, y: height - 105), withAttributes: [
        .font: NSFont.systemFont(ofSize: 11),
        .foregroundColor: theme.textSecondary
    ])

    // Grid de Métricas de Odómetro Real (9.721 páginas)
    let gridY = height - 290
    let cardW = (contentW - 20) / 3.0
    let cardH: CGFloat = 72

    let stats = [
        ("Total Páginas Impresas", "9.721", "3.077 B/N • 6.644 Color", theme.accentColor),
        ("Monocromáticas (K)", "3.077", "Canal de texto negro GT51", theme.accentColor),
        ("Color (CMY)", "6.644", "Canales de color GT52", theme.accentColor),
        ("Digitalizaciones", "0", "Ciclos de escáner óptico", theme.accentColor),
        ("Atascos de Papel", "0", "Saludable • Cero atascos", CGColor(red: 0.16, green: 0.75, blue: 0.32, alpha: 1.0)),
        ("Reintentos de Arrastre", "0", "Rodillos en estado óptimo", CGColor(red: 0.16, green: 0.75, blue: 0.32, alpha: 1.0))
    ]

    for (idx, (title, val, sub, col)) in stats.enumerated() {
        let colIdx = CGFloat(idx % 3)
        let rowIdx = CGFloat(idx / 3)
        let cx = contentX + colIdx * (cardW + 10)
        let cy = gridY + (1 - rowIdx) * (cardH + 10)

        let r = CGRect(x: cx, y: cy, width: cardW, height: cardH)
        drawCard(ctx: ctx, rect: r, theme: theme)

        (title as NSString).draw(at: NSPoint(x: cx + 12, y: cy + cardH - 22), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: theme.textSecondary
        ])
        (val as NSString).draw(at: NSPoint(x: cx + 12, y: cy + cardH - 46), withAttributes: [
            .font: NSFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: NSColor(cgColor: col)!
        ])
        (sub as NSString).draw(at: NSPoint(x: cx + 12, y: cy + cardH - 62), withAttributes: [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: theme.textTertiary
        ])
    }

    // Historial de Trabajos Locales
    let histY: CGFloat = 20
    let histH = gridY - histY - 15
    let histRect = CGRect(x: contentX, y: histY, width: contentW, height: histH)
    drawCard(ctx: ctx, rect: histRect, theme: theme)

    ("Historial Local de Trabajos (Privacidad Garantizada)" as NSString).draw(at: NSPoint(x: contentX + 16, y: histY + histH - 30), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    let jobs = [
        ("Reporte_Trimestral_Q3.pdf", "14 páginas • 850 KB", "Completado"),
        ("Factura_Servicios_0826.pdf", "2 páginas • 120 KB", "Completado"),
        ("Fotografia_Paisaje_A4.jpg", "1 página • 4.2 MB", "Completado"),
        ("Esquema_Circuito_PCB.pdf", "4 páginas • 340 KB", "Completado")
    ]

    var jy = histY + histH - 60
    for (name, meta, status) in jobs {
        (name as NSString).draw(at: NSPoint(x: contentX + 16, y: jy), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: theme.textPrimary
        ])
        (meta as NSString).draw(at: NSPoint(x: contentX + 260, y: jy), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textSecondary
        ])
        (status as NSString).draw(at: NSPoint(x: contentX + contentW - 100, y: jy), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.16, green: 0.75, blue: 0.32, alpha: 1.0)
        ])
        jy -= 26
    }

    saveContextToPNG(ctx: ctx, path: outputPath)
}

func generateSettingsMockup(outputPath: String, theme: Theme) {
    let width: CGFloat = 960
    let height: CGFloat = 620
    let (ctx, nsCtx) = createContext(width: width, height: height)
    NSGraphicsContext.current = nsCtx

    drawWindowFrame(ctx: ctx, width: width, height: height, title: "TankControl — Configuración", theme: theme, selectedSection: "Configuración")

    let contentX: CGFloat = 220
    let contentW = width - contentX - 20

    let s1Rect = CGRect(x: contentX, y: height - 165, width: contentW, height: 115)
    drawCard(ctx: ctx, rect: s1Rect, theme: theme)

    ("General y Arranque" as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 80), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    let gRows = [
        ("Iniciar TankControl al iniciar sesión de macOS", "ON"),
        ("Mostrar indicador de estado en la Barra de Menús", "ON")
    ]
    var y = height - 110
    for r in gRows {
        (r.0 as NSString).draw(at: NSPoint(x: contentX + 16, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textSecondary
        ])
        (r.1 as NSString).draw(at: NSPoint(x: contentX + contentW - 50, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor(cgColor: theme.accentColor)!
        ])
        y -= 26
    }

    let s2Rect = CGRect(x: contentX, y: height - 325, width: contentW, height: 145)
    drawCard(ctx: ctx, rect: s2Rect, theme: theme)

    ("Gestión de Color ColorSync" as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 200), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    let cRows = [
        ("Perfil Activo:", "HP_Smart_Tank_Plain.icc"),
        ("Espacio Cromático de Trabajo:", "sRGB IEC61966-2.1"),
        ("Intención de Representación:", "Perceptual (Fotografía / Gráficos)")
    ]
    y = height - 230
    for r in cRows {
        (r.0 as NSString).draw(at: NSPoint(x: contentX + 16, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textSecondary
        ])
        (r.1 as NSString).draw(at: NSPoint(x: contentX + 220, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: theme.textPrimary
        ])
        y -= 26
    }

    let s3Rect = CGRect(x: contentX, y: height - 510, width: contentW, height: 170)
    drawCard(ctx: ctx, rect: s3Rect, theme: theme)

    ("Herramientas Avanzadas y Diagnóstico" as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 360), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    ("Activar Modo Desarrollador" as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 395), withAttributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
        .foregroundColor: theme.textPrimary
    ])
    ("OFF" as NSString).draw(at: NSPoint(x: contentX + contentW - 50, y: height - 395), withAttributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .bold),
        .foregroundColor: theme.textTertiary
    ])

    let devWarning = "El Modo Desarrollador habilita inspectores USB de bajo nivel, visores de árboles XML LEDM en bruto y comandos de inyección de paquetes de desarrollo. No es necesario para uso diario."
    (devWarning as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 440), withAttributes: [
        .font: NSFont.systemFont(ofSize: 9),
        .foregroundColor: theme.textSecondary
    ])

    saveContextToPNG(ctx: ctx, path: outputPath)
}

func generateDeveloperModeMockup(outputPath: String, theme: Theme) {
    let width: CGFloat = 960
    let height: CGFloat = 620
    let (ctx, nsCtx) = createContext(width: width, height: height)
    NSGraphicsContext.current = nsCtx

    drawWindowFrame(ctx: ctx, width: width, height: height, title: "TankControl — Desarrollo", theme: theme, selectedSection: "Desarrollo", isDevEnabled: true)

    let contentX: CGFloat = 220
    let contentW = width - contentX - 20

    let warnRect = CGRect(x: contentX, y: height - 85, width: contentW, height: 35)
    ctx.setFillColor(CGColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 0.15))
    ctx.addPath(CGPath(roundedRect: warnRect, cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.fillPath()
    ("Modo Desarrollador Activo • Telemetría USB y LEDM sin filtrar" as NSString).draw(at: NSPoint(x: contentX + 14, y: height - 72), withAttributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .bold),
        .foregroundColor: NSColor.red
    ])

    let usbRect = CGRect(x: contentX, y: height - 250, width: contentW, height: 155)
    drawCard(ctx: ctx, rect: usbRect, theme: theme)

    ("Descriptores USB de Hardware (ID 03f0:2b54)" as NSString).draw(at: NSPoint(x: contentX + 14, y: height - 115), withAttributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    let usbText = """
    Interface 0 (ff/cc/00): Endpoints [OUT: 0x02 (Bulk), IN: 0x81 (Bulk)] -> CUPS Backend PCL3GUI
    Interface 1 (07/01/02): Endpoints [OUT: 0x02 (Bulk), IN: 0x82 (Bulk)] -> eSCL / IPP-USB Bridge
    Interface 2 (ff/04/01): Endpoints [OUT: 0x02 (Bulk), IN: 0x82 (Bulk)] -> SANE / SCL Scanner
    Device Descriptor: bcdUSB: 0x0200, bMaxPacketSize0: 64, idVendor: 0x03F0, idProduct: 0x2B54
    """
    (usbText as NSString).draw(at: NSPoint(x: contentX + 14, y: height - 235), withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
        .foregroundColor: theme.textSecondary
    ])

    let ledmRect = CGRect(x: contentX, y: 55, width: contentW, height: height - 315)
    drawCard(ctx: ctx, rect: ledmRect, theme: theme)

    ("Árbol LEDM / DevMgmt ProductStatusDyn.xml" as NSString).draw(at: NSPoint(x: contentX + 14, y: height - 280), withAttributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    let xmlSnippet = """
    <pstat:ProductStatusDyn xmlns:pstat="http://www.hp.com/schemas/imaging/con/ledm/productstatusdyn/2007/10/31">
      <pstat:Status>
        <pstat:StatusCategory>ready</pstat:StatusCategory>
        <pstat:StatusReason>none</pstat:StatusReason>
      </pstat:Status>
      <pstat:ConsumableConfigDyn>
        <pstat:Consumable>
          <pstat:ConsumableTypeEnum>ink</pstat:ConsumableTypeEnum>
          <pstat:ConsumableColorCode>black</pstat:ConsumableColorCode>
          <pstat:ConsumableRawPercentage>85</pstat:ConsumableRawPercentage>
        </pstat:Consumable>
      </pstat:ConsumableConfigDyn>
    </pstat:ProductStatusDyn>
    """
    (xmlSnippet as NSString).draw(at: NSPoint(x: contentX + 14, y: height - 480), withAttributes: [
        .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
        .foregroundColor: theme.textSecondary
    ])

    let copyBtnRect = CGRect(x: contentX + contentW - 170, y: 15, width: 170, height: 26)
    ctx.setFillColor(theme.accentColor.copy(alpha: theme.isDark ? 0.3 : 0.2)!)
    ctx.addPath(CGPath(roundedRect: copyBtnRect, cornerWidth: 5, cornerHeight: 5, transform: nil))
    ctx.fillPath()
    ("Copiar Diagnóstico Completo" as NSString).draw(at: NSPoint(x: contentX + contentW - 160, y: 21), withAttributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .medium),
        .foregroundColor: theme.isDark ? NSColor.white : NSColor(cgColor: theme.accentColor)!
    ])

    saveContextToPNG(ctx: ctx, path: outputPath)
}

func generateInkSaverMockup(outputPath: String, theme: Theme) {
    let width: CGFloat = 960
    let height: CGFloat = 620
    let (ctx, nsCtx) = createContext(width: width, height: height)
    NSGraphicsContext.current = nsCtx

    drawWindowFrame(ctx: ctx, width: width, height: height, title: "TankControl — InkSaver Center", theme: theme, selectedSection: "Impresión")

    let contentX: CGFloat = 220
    let contentW = width - contentX - 20

    let compRect = CGRect(x: contentX, y: height - 280, width: contentW, height: 230)
    drawCard(ctx: ctx, rect: compRect, theme: theme)

    ("Comparador Raster Antes / Después" as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 75), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    let splitX = contentX + contentW / 2.0
    let imageRect = CGRect(x: contentX + 16, y: height - 265, width: contentW - 32, height: 170)
    ctx.setFillColor(theme.isDark ? CGColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1.0) : CGColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0))
    ctx.fill(imageRect)

    ctx.setStrokeColor(theme.accentColor)
    ctx.setLineWidth(2)
    ctx.strokeLineSegments(between: [CGPoint(x: splitX, y: height - 265), CGPoint(x: splitX, y: height - 95)])

    let tagAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 9),
        .foregroundColor: theme.textPrimary
    ]
    ("CON INKSAVER (-25% RASTER)" as NSString).draw(at: NSPoint(x: contentX + 24, y: height - 115), withAttributes: tagAttrs)
    ("ORIGINAL SIN MODIFICAR" as NSString).draw(at: NSPoint(x: splitX + 20, y: height - 115), withAttributes: tagAttrs)

    let metrics = [
        ("Reducción Raster:", "-25% en cobertura de píxeles"),
        ("Texto / Bordes:", "100% nitidez (K Puro protegido)"),
        ("Ahorro Estimado:", "~0.5 ml por cada 100 páginas")
    ]
    let mRect = CGRect(x: contentX, y: height - 420, width: contentW, height: 125)
    drawCard(ctx: ctx, rect: mRect, theme: theme)

    ("Impacto Técnico del Ahorro" as NSString).draw(at: NSPoint(x: contentX + 16, y: height - 320), withAttributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    var my = height - 345
    for m in metrics {
        (m.0 as NSString).draw(at: NSPoint(x: contentX + 16, y: my), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: theme.textSecondary
        ])
        (m.1 as NSString).draw(at: NSPoint(x: contentX + 160, y: my), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: theme.textPrimary
        ])
        my -= 24
    }

    let noticeRect = CGRect(x: contentX, y: 20, width: contentW, height: 155)
    drawCard(ctx: ctx, rect: noticeRect, theme: theme)

    ("Transparencia Técnica Obligatoria" as NSString).draw(at: NSPoint(x: contentX + 16, y: 145), withAttributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .bold),
        .foregroundColor: theme.textPrimary
    ])

    let noticeText = """
    La reducción es una estimación de cobertura de píxeles generada por software en el buffer     raster RGB previo a la compresión PCL3GUI Mode 10 del spooler CUPS. No representa una medición     de flujo por sensor piezométrico de hardware. La nitidez tipográfica se mantiene intacta     mediante el algoritmo EdgePreserve de canal K aislado.
    """
    (noticeText as NSString).draw(at: NSPoint(x: contentX + 16, y: 55), withAttributes: [
        .font: NSFont.systemFont(ofSize: 9),
        .foregroundColor: theme.textSecondary
    ])

    saveContextToPNG(ctx: ctx, path: outputPath)
}

let screenshotsDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Brand/screenshots"
try? FileManager.default.createDirectory(atPath: screenshotsDir, withIntermediateDirectories: true)

print("[*] Generando suite completa de mockups nativos macOS para TankControl...")

generateDashboardMockup(outputPath: "\(screenshotsDir)/dashboard_mockup.png", theme: .dark)
generateDashboardMockup(outputPath: "\(screenshotsDir)/dashboard_light_mockup.png", theme: .light)
generateInkStatusMockup(outputPath: "\(screenshotsDir)/ink_status_mockup.png", theme: .dark)
generatePrintCenterMockup(outputPath: "\(screenshotsDir)/print_center_mockup.png", theme: .dark)
generateScannerMockup(outputPath: "\(screenshotsDir)/scanner_mockup.png", theme: .dark)
generateMaintenanceMockup(outputPath: "\(screenshotsDir)/maintenance_mockup.png", theme: .dark)
generateActivityMockup(outputPath: "\(screenshotsDir)/activity_mockup.png", theme: .dark)
generateActivityMockup(outputPath: "\(screenshotsDir)/activity_light_mockup.png", theme: .light)
generateSettingsMockup(outputPath: "\(screenshotsDir)/settings_mockup.png", theme: .dark)
generateDeveloperModeMockup(outputPath: "\(screenshotsDir)/developer_mode_mockup.png", theme: .dark)
generateInkSaverMockup(outputPath: "\(screenshotsDir)/inksaver_mockup.png", theme: .dark)

print("[+] ¡Todos los mockups fueron generados con éxito!")
