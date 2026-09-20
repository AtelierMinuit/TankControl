import SwiftUI

/// Formato de papel con especificaciones dimensionales y notas regionales.
public struct PaperFormatItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let widthMm: Double
    public let heightMm: Double
    public let widthInches: Double
    public let heightInches: Double
    public let postScriptWidth: Int
    public let postScriptHeight: Int
    public let pclMediaId: Int
    public let badgeText: String
    public let badgeColor: Color
    public let guidance: String

    public static func == (lhs: PaperFormatItem, rhs: PaperFormatItem) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Asistente Visual y Comparador de Formatos de Papel Regionales para TankControl.
public struct PaperGuideView: View {
    @ObservedObject var printer: PrinterManager
    @ObservedObject private var loc = LocalizationService.shared
    @State private var selectedFormatId: String = "oficio"

    public static let formats: [PaperFormatItem] = [
        PaperFormatItem(
            id: "carta",
            name: "Carta (US Letter)",
            subtitle: "Estándar escolar y comercial universal",
            widthMm: 215.9,
            heightMm: 279.4,
            widthInches: 8.5,
            heightInches: 11.0,
            postScriptWidth: 612,
            postScriptHeight: 792,
            pclMediaId: 2,
            badgeText: "Universal",
            badgeColor: .blue,
            guidance: "Alinear la guía lateral izquierda de la bandeja en la marca 'LTR'."
        ),
        PaperFormatItem(
            id: "oficio",
            name: "Oficio (Chile / LATAM)",
            subtitle: "Formato legal, judicial y notarial en Chile y Latinoamérica",
            widthMm: 215.9,
            heightMm: 330.2,
            widthInches: 8.5,
            heightInches: 13.0,
            postScriptWidth: 612,
            postScriptHeight: 936,
            pclMediaId: 10,
            badgeText: "Chile / LATAM",
            badgeColor: .indigo,
            guidance: "51 mm (2'') más largo que Carta. No seleccionar 'Legal' en la app de impresión para evitar desbordes y atascos."
        ),
        PaperFormatItem(
            id: "legal",
            name: "Legal (Oficio Americano)",
            subtitle: "Estándar legal exclusivo de Estados Unidos y Canadá",
            widthMm: 215.9,
            heightMm: 355.6,
            widthInches: 8.5,
            heightInches: 14.0,
            postScriptWidth: 612,
            postScriptHeight: 1008,
            pclMediaId: 3,
            badgeText: "EE.UU.",
            badgeColor: .orange,
            guidance: "25 mm (1'') más largo que Oficio Chile. Extender completamente la bandeja de salida para sostener la hoja."
        ),
        PaperFormatItem(
            id: "a4",
            name: "A4 (Estándar ISO)",
            subtitle: "Norma internacional predominante en Europa y documentos técnicos",
            widthMm: 210.0,
            heightMm: 297.0,
            widthInches: 8.27,
            heightInches: 11.69,
            postScriptWidth: 595,
            postScriptHeight: 842,
            pclMediaId: 26,
            badgeText: "ISO 216",
            badgeColor: .teal,
            guidance: "6 mm más estrecho y 18 mm más largo que Carta. Deslizar la guía lateral hasta la marca 'A4'."
        ),
        PaperFormatItem(
            id: "a5",
            name: "A5 (Media Cuartilla)",
            subtitle: "Cuadernos, folletos, libretas y recetarios médicos",
            widthMm: 148.0,
            heightMm: 210.0,
            widthInches: 5.83,
            heightInches: 8.27,
            postScriptWidth: 420,
            postScriptHeight: 595,
            pclMediaId: 25,
            badgeText: "Folleto",
            badgeColor: .purple,
            guidance: "Ajustar la guía lateral centrada en la marca 'A5' para asegurar tracción recta del rodillo."
        )
    ]

    private var currentFormat: PaperFormatItem {
        Self.formats.first { $0.id == selectedFormatId } ?? Self.formats[1]
    }

    public init(printer: PrinterManager) {
        self.printer = printer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Cabecera de la sección
            HStack {
                Image(systemName: "ruler.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(DesignTokens.Radii.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("paper_guide_title"))
                        .font(DesignTokens.Fonts.headline)
                    Text(loc.t("paper_guide_subtitle"))
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Selector horizontal de formatos
            HStack(spacing: 8) {
                ForEach(Self.formats) { format in
                    Button(action: { selectedFormatId = format.id }) {
                        VStack(spacing: 4) {
                            Text(format.name.components(separatedBy: " ").first ?? format.name)
                                .font(DesignTokens.Fonts.bodyMedium)
                            Text("\(format.widthInches, specifier: "%.1f")x\(format.heightInches, specifier: "%.0f")''")
                                .font(DesignTokens.Fonts.mono)
                                .foregroundColor(selectedFormatId == format.id ? .white : .secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedFormatId == format.id
                                ? Color.accentColor
                                : DesignTokens.Colors.surfaceGrouped
                        )
                        .foregroundColor(selectedFormatId == format.id ? .white : .primary)
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(selectedFormatId == format.id ? Color.accentColor : DesignTokens.Colors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Comparador visual interactivo
            HStack(alignment: .bottom, spacing: 24) {
                // Siluetas a escala proporcional
                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(Self.formats) { fmt in
                            VStack(spacing: 4) {
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            fmt.id == selectedFormatId
                                                ? fmt.badgeColor.opacity(0.85)
                                                : Color.secondary.opacity(0.18)
                                        )
                                        .frame(
                                            width: CGFloat(fmt.widthMm) * 0.35,
                                            height: CGFloat(fmt.heightMm) * 0.35
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(fmt.id == selectedFormatId ? fmt.badgeColor : Color.secondary.opacity(0.3), lineWidth: 1.5)
                                        )

                                    if fmt.id == selectedFormatId {
                                        Text("\(Int(fmt.heightMm)) mm")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.bottom, 4)
                                    }
                                }

                                Text(fmt.name.components(separatedBy: " ").first ?? "")
                                    .font(.system(size: 10, weight: fmt.id == selectedFormatId ? .bold : .regular))
                                    .foregroundColor(fmt.id == selectedFormatId ? fmt.badgeColor : .secondary)
                            }
                        }
                    }
                    .frame(height: 140, alignment: .bottom)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(DesignTokens.Radii.small)

                    Text("Siluetas a escala proporcional (mm)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Ficha técnica del formato seleccionado
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(currentFormat.name)
                            .font(DesignTokens.Fonts.headline)
                        Text(currentFormat.badgeText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(currentFormat.badgeColor)
                            .cornerRadius(4)
                    }

                    Text(currentFormat.subtitle)
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Dimensiones:")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)
                            Text("\(currentFormat.widthMm, specifier: "%.1f") × \(currentFormat.heightMm, specifier: "%.1f") mm  (\(currentFormat.widthInches, specifier: "%.2f") × \(currentFormat.heightInches, specifier: "%.2f")'')")
                                .font(DesignTokens.Fonts.captionBold)
                        }
                        HStack {
                            Text("Puntos PostScript:")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)
                            Text("\(currentFormat.postScriptWidth) × \(currentFormat.postScriptHeight) pt")
                                .font(DesignTokens.Fonts.mono)
                        }
                        HStack {
                            Text("ID PCL3GUI:")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)
                            Text("media_id \(currentFormat.pclMediaId)")
                                .font(DesignTokens.Fonts.mono)
                                .foregroundColor(.accentColor)
                        }
                    }

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "hand.point.right.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                            .padding(.top, 2)
                        Text(currentFormat.guidance)
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.primary)
                    }
                    .padding(8)
                    .background(currentFormat.badgeColor.opacity(0.1))
                    .cornerRadius(DesignTokens.Radii.small)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.surfaceGrouped)
            .cornerRadius(DesignTokens.Radii.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
            )
        }
    }
}
