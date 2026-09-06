import SwiftUI

/// Declaración explícita y verificable de privacidad y ausencia de telemetría.
public struct PrivacyView: View {
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Cabecera
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacidad y Transparencia")
                        .font(DesignTokens.Fonts.headline)
                    Text("Compromiso estricto de cero recolección de datos y cero telemetría remota.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("100% Local y Offline")
                                .font(DesignTokens.Fonts.bodyMedium)
                            Text("TankControl no requiere conexión a Internet para ninguna de sus funciones.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "icloud.slash.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sin Cuentas ni Servicios Cloud")
                                .font(DesignTokens.Fonts.bodyMedium)
                            Text("No se solicitan inicios de sesión, registros ni suscripciones.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contenidos Intactos y Privados")
                                .font(DesignTokens.Fonts.bodyMedium)
                            Text("Los documentos que imprimes o escaneas nunca se almacenan ni se transmiten fuera del subsistema CUPS de macOS.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Código Abierto y Auditable")
                                .font(DesignTokens.Fonts.bodyMedium)
                            Text("Todo el código fuente de los filtros, backends y utilidades está disponible para su auditoría y compilación independiente.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.cardBackground)
                .cornerRadius(DesignTokens.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}
