import SwiftUI

public struct SettingsView: View {
    @ObservedObject var printer: PrinterManager
    @ObservedObject private var loc = LocalizationService.shared
    @State private var showingDeveloperModeConfirmation = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Cabecera
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("section_settings"))
                        .font(DesignTokens.Fonts.title)
                    Text(loc.t("settings_subtitle"))
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Grupo 0: Idioma de la Aplicación / Application Language
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(loc.t("settings_language_header"))
                        .font(DesignTokens.Fonts.sectionHeader)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.accentColor)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc.t("settings_language_header"))
                                    .font(DesignTokens.Fonts.bodyMedium)
                                Text(loc.t("settings_language_desc"))
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $loc.language) {
                                ForEach(AppLanguage.allCases) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // Grupo 1: Preferencias del Sistema
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(loc.t("settings_notifications_header"))
                        .font(DesignTokens.Fonts.sectionHeader)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundColor(.accentColor)
                            Text(loc.t("settings_notifications_title"))
                                .font(DesignTokens.Fonts.bodyMedium)
                            Spacer()
                            Text(loc.t("settings_notifications_active"))
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.green)
                        }
                        Text(loc.t("settings_notifications_desc"))
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // Grupo 2: Herramientas de Desarrollo
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(loc.t("settings_dev_header"))
                        .font(DesignTokens.Fonts.sectionHeader)

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(loc.t("settings_dev_toggle"), isOn: Binding(
                            get: { printer.developerMode },
                            set: { enabled in
                                if enabled { showingDeveloperModeConfirmation = true }
                                else { printer.developerMode = false }
                            }
                        ))
                        .font(DesignTokens.Fonts.bodyMedium)

                        Text(loc.t("settings_dev_desc"))
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // Grupo 3: Identidad y Versión
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TankControl")
                                .font(DesignTokens.Fonts.headline)
                            Text("Versión " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0-alpha") + " (Apple Silicon ARM64)")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(loc.t("settings_btn_about")) {
                            printer.selectedSection = .about
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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
            .padding(DesignTokens.Spacing.md)
        }
        .confirmationDialog(loc.t("settings_dialog_dev_title"), isPresented: $showingDeveloperModeConfirmation, titleVisibility: .visible) {
            Button(loc.t("settings_dialog_dev_confirm")) { printer.developerMode = true }
            Button(loc.t("settings_dialog_dev_cancel"), role: .cancel) {}
        } message: {
            Text(loc.t("settings_dialog_dev_message"))
        }
    }
}
