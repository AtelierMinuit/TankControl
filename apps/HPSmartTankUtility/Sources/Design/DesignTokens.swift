import SwiftUI

/// Tokens de diseño canónicos para TankControl / HP Smart Tank macOS Utility.
/// Basados en Apple Human Interface Guidelines (macOS 12 Monterey y superiores).
public enum DesignTokens {

    // MARK: - Espaciado Canónico macOS (Escala: 4, 8, 12, 16, 20, 24, 32)
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 24
        public static let xxl: CGFloat = 32
    }

    // MARK: - Radios de Curvatura Sobrios (6, 10, 12 pt)
    public enum Radii {
        public static let small: CGFloat = 6   // Badges, botones compactos
        public static let medium: CGFloat = 10  // Controles estándar, paneles
        public static let card: CGFloat = 12    // Tarjetas principales de estado
        public static let pill: CGFloat = 16    // Pastillas de estado
    }

    // MARK: - Tipografía Semántica del Sistema (Dynamic Type nativo)
    public enum Fonts {
        public static let title: Font = .title2.weight(.bold)
        public static let sectionHeader: Font = .headline
        public static let headline: Font = .headline
        public static let subheadline: Font = .subheadline
        public static let primaryValue: Font = .title3.weight(.semibold)
        public static let body: Font = .body
        public static let bodyMedium: Font = .body.weight(.medium)
        public static let callout: Font = .callout
        public static let caption: Font = .system(size: 12)
        public static let captionBold: Font = .system(size: 12, weight: .semibold)
        public static let mono: Font = .caption.monospaced()
        public static let metricNumber: Font = .system(.title, design: .rounded).weight(.bold)
        public static let metricSmall: Font = .system(.body, design: .rounded).weight(.semibold)
    }

    // MARK: - Colores Semánticos del Sistema
    public enum Colors {
        // Colores de acento e interfaz general
        public static let accent = Color.accentColor
        public static let brandTeal = Color.accentColor
        public static let primaryText = Color.primary
        public static let secondaryText = Color.secondary

        // Tintas CISS (Aplicadas con estricta finalidad informativa)
        public static let inkBlack = Color.black
        public static let inkCyan = Color(red: 0.0, green: 0.64, blue: 0.88)
        public static let inkMagenta = Color(red: 0.92, green: 0.0, blue: 0.55)
        public static let inkYellow = Color(red: 0.98, green: 0.80, blue: 0.05)

        // Estados Semánticos de Hardware (Verde = Normal, Amarillo = Atención, Rojo = Error, Gris = No Disponible)
        public static let statusNormal = Color.green
        public static let statusAttention = Color.orange
        public static let statusError = Color.red
        public static let statusUnavailable = Color.secondary
        public static let statusProcessing = Color.blue

        // Alias canónicos para compatibilidad con modelos de estado
        public static let statusReady = statusNormal
        public static let statusWarning = statusAttention
        public static let statusOffline = statusUnavailable

        // Superficies de Material Nativo macOS
        public static let surfaceGrouped = Color(NSColor.controlBackgroundColor)
        public static let surfaceSubtle = Color(NSColor.windowBackgroundColor)
        public static let cardBackground = Color(NSColor.controlBackgroundColor)
        public static let windowBackground = Color(NSColor.windowBackgroundColor)
        public static let border = Color(NSColor.separatorColor)
        public static let borderSubtle = Color(NSColor.separatorColor).opacity(0.6)
    }
}
