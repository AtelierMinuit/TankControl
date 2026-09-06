import Foundation

/// Perfiles de impresión locales (Presets) para TankControl.
public struct PrintPreset: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var description: String
    public var colorModel: String         // "RGB", "CMYK", "KGray"
    public var resolution: String         // "300dpi", "600dpi", "1200dpi"
    public var mediaType: String          // "Plain", "Glossy", "Matte"
    public var inkSaverLevel: String      // "None", "Eco25", "Eco50", "EcoMax", "EdgePreserve"
    public var pureBlack: Bool            // True = Forzar K puro en texto
    public var borderless: Bool           // True = Margen cero en 10x15 o A4
    public var isBuiltIn: Bool

    public init(
        id: String,
        name: String,
        description: String,
        colorModel: String = "RGB",
        resolution: String = "600dpi",
        mediaType: String = "Plain",
        inkSaverLevel: String = "None",
        pureBlack: Bool = true,
        borderless: Bool = false,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.colorModel = colorModel
        self.resolution = resolution
        self.mediaType = mediaType
        self.inkSaverLevel = inkSaverLevel
        self.pureBlack = pureBlack
        self.borderless = borderless
        self.isBuiltIn = isBuiltIn
    }

    /// Presets predeterminados integrados en la aplicación
    public static let builtInPresets: [PrintPreset] = [
        PrintPreset(
            id: "doc-standard",
            name: "Documento Estándar",
            description: "Texto nítido y gráficos cotidianos en papel común (600 DPI, RGB).",
            colorModel: "RGB",
            resolution: "600dpi",
            mediaType: "Plain",
            inkSaverLevel: "None",
            pureBlack: true,
            borderless: false,
            isBuiltIn: true
        ),
        PrintPreset(
            id: "doc-eco",
            name: "Documento Eco Ahorro",
            description: "Ahorro moderado (-25% raster) manteniendo alta legibilidad.",
            colorModel: "RGB",
            resolution: "600dpi",
            mediaType: "Plain",
            inkSaverLevel: "Eco25",
            pureBlack: true,
            borderless: false,
            isBuiltIn: true
        ),
        PrintPreset(
            id: "photo-glossy",
            name: "Fotografía Premium",
            description: "Máxima fidelidad cromática sin bordes en papel fotográfico brillante.",
            colorModel: "RGB",
            resolution: "1200dpi",
            mediaType: "Glossy",
            inkSaverLevel: "None",
            pureBlack: false,
            borderless: true,
            isBuiltIn: true
        ),
        PrintPreset(
            id: "text-mono-pure",
            name: "Solo Texto B/N Puro",
            description: "Canal negro exclusivo (K). Cero consumo de tintas de color C, M, Y.",
            colorModel: "KGray",
            resolution: "600dpi",
            mediaType: "Plain",
            inkSaverLevel: "None",
            pureBlack: true,
            borderless: false,
            isBuiltIn: true
        ),
        PrintPreset(
            id: "draft-fast",
            name: "Borrador Rápido",
            description: "Impresión de alta velocidad con ahorro agresivo de cobertura (-50%).",
            colorModel: "RGB",
            resolution: "300dpi",
            mediaType: "Plain",
            inkSaverLevel: "Eco50",
            pureBlack: false,
            borderless: false,
            isBuiltIn: true
        )
    ]
}
