import Foundation
import SwiftUI

/// Idiomas soportados por TankControl
public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case spanish = "es"
    case english = "en"
    case portuguese = "pt"
    case french = "fr"
    case german = "de"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "🌐 Automático (Sistema)"
        case .spanish: return "🇪🇸 Español"
        case .english: return "🇺🇸 English"
        case .portuguese: return "🇧🇷 Português"
        case .french: return "🇫🇷 Français"
        case .german: return "🇩🇪 Deutsch"
        }
    }

    public var localeIdentifier: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "es"
            if preferred.hasPrefix("en") { return "en" }
            if preferred.hasPrefix("pt") { return "pt" }
            if preferred.hasPrefix("fr") { return "fr" }
            if preferred.hasPrefix("de") { return "de" }
            return "es"
        case .spanish: return "es"
        case .english: return "en"
        case .portuguese: return "pt"
        case .french: return "fr"
        case .german: return "de"
        }
    }
}

/// Servicio centralizado de localización dinámica de TankControl
public final class LocalizationService: ObservableObject {
    public static let shared = LocalizationService()

    @Published public var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "tankcontrol_language")
            activeLocale = language.localeIdentifier
        }
    }

    @Published public private(set) var activeLocale: String

    private init() {
        let saved = UserDefaults.standard.string(forKey: "tankcontrol_language") ?? AppLanguage.system.rawValue
        let resolved = AppLanguage(rawValue: saved) ?? .system
        self.language = resolved
        self.activeLocale = resolved.localeIdentifier
    }

    /// Obtiene la traducción de una clave en el idioma activo
    public func t(_ key: String) -> String {
        guard let entry = translations[key] else { return key }
        let langKey = AppLanguage(rawValue: activeLocale) ?? .spanish
        return entry[langKey] ?? entry[.spanish] ?? entry[.english] ?? key
    }

    // MARK: - Catálogo de Traducciones
    private let translations: [String: [AppLanguage: String]] = [
        // Secciones de la barra lateral
        "section_general": [
            .spanish: "General", .english: "General", .portuguese: "Geral", .french: "Général", .german: "Allgemein"
        ],
        "section_print": [
            .spanish: "Impresión", .english: "Print", .portuguese: "Impressão", .french: "Impression", .german: "Drucken"
        ],
        "section_scan": [
            .spanish: "Escáner", .english: "Scanner", .portuguese: "Scanner", .french: "Numériseur", .german: "Scanner"
        ],
        "section_ink": [
            .spanish: "Tinta", .english: "Ink", .portuguese: "Tinta", .french: "Encre", .german: "Tinte"
        ],
        "section_inksaver": [
            .spanish: "InkSaver", .english: "InkSaver", .portuguese: "InkSaver", .french: "InkSaver", .german: "InkSaver"
        ],
        "section_maintenance": [
            .spanish: "Mantenimiento", .english: "Maintenance", .portuguese: "Manutenção", .french: "Maintenance", .german: "Wartung"
        ],
        "section_activity": [
            .spanish: "Actividad", .english: "Activity", .portuguese: "Atividade", .french: "Activité", .german: "Aktivität"
        ],
        "section_developer": [
            .spanish: "Desarrollo", .english: "Developer", .portuguese: "Desenvolvimento", .french: "Développement", .german: "Entwickler"
        ],
        "section_settings": [
            .spanish: "Configuración", .english: "Settings", .portuguese: "Configurações", .french: "Réglages", .german: "Einstellungen"
        ],
        "section_about": [
            .spanish: "Acerca de", .english: "About", .portuguese: "Sobre", .french: "À propos", .german: "Über"
        ],

        // Grupos de la barra lateral
        "group_printer": [
            .spanish: "Impresora", .english: "Printer", .portuguese: "Impressora", .french: "Imprimante", .german: "Drucker"
        ],
        "group_maintenance_usage": [
            .spanish: "Mantenimiento y Uso", .english: "Maintenance & Usage", .portuguese: "Manutenção e Uso", .french: "Maintenance et Utilisation", .german: "Wartung & Nutzung"
        ],

        // Estados y Acciones Comunes
        "status_ready": [
            .spanish: "Lista para usar", .english: "Ready to use", .portuguese: "Pronta para uso", .french: "Prête à l'emploi", .german: "Bereit"
        ],
        "status_connected_usb": [
            .spanish: "Conectada por USB", .english: "Connected via USB", .portuguese: "Conectada via USB", .french: "Connectée via USB", .german: "Über USB verbunden"
        ],
        "status_waiting_usb": [
            .spanish: "En espera de conexión USB", .english: "Waiting for USB connection", .portuguese: "Aguardando conexão USB", .french: "En attente de connexion USB", .german: "Warte auf USB-Verbindung"
        ],
        "btn_scan": [
            .spanish: "Escanear", .english: "Scan", .portuguese: "Digitalizar", .french: "Numériser", .german: "Scannen"
        ],
        "btn_open_queue": [
            .spanish: "Abrir Cola", .english: "Open Queue", .portuguese: "Abrir Fila", .french: "Ouvrir la file", .german: "Warteschlange"
        ],
        "btn_save_cups": [
            .spanish: "Guardar en CUPS", .english: "Save to CUPS", .portuguese: "Salvar no CUPS", .french: "Enregistrer dans CUPS", .german: "In CUPS speichern"
        ],

        // Modo Rápido Borrador
        "fast_draft_title": [
            .spanish: "Modo Rápido Borrador", .english: "Fast Draft Mode", .portuguese: "Modo Rascunho Rápido", .french: "Mode Brouillon Rapide", .german: "Schnell-Entwurf-Modus"
        ],
        "fast_draft_badge_active": [
            .spanish: "● BORRADOR ACTIVO", .english: "● DRAFT ACTIVE", .portuguese: "● RASCUNHO ATIVO", .french: "● BROUILLON ACTIF", .german: "● ENTWURF AKTIV"
        ],
        "fast_draft_badge_normal": [
            .spanish: "○ MODO NORMAL", .english: "○ NORMAL MODE", .portuguese: "○ MODO NORMAL", .french: "○ MODE NORMAL", .german: "○ NORMALMODUS"
        ],
        "fast_draft_btn_activate": [
            .spanish: "Activar Modo Rápido Borrador", .english: "Activate Fast Draft Mode", .portuguese: "Ativar Modo Rascunho Rápido", .french: "Activer le Mode Brouillon Rapide", .german: "Schnell-Entwurf aktivieren"
        ],
        "fast_draft_btn_revert": [
            .spanish: "Volver a Calidad Normal", .english: "Return to Normal Quality", .portuguese: "Voltar para Qualidade Normal", .french: "Revenir en Qualité Normale", .german: "Zurück zu Normalqualität"
        ],

        // Configuración y Selector de Idioma
        "settings_language_header": [
            .spanish: "Idioma de la Aplicación", .english: "Application Language", .portuguese: "Idioma do Aplicativo", .french: "Langue de l'application", .german: "Anwendungssprache"
        ],
        "settings_language_desc": [
            .spanish: "Selecciona el idioma de la interfaz o sincroniza automáticamente con el sistema macOS.",
            .english: "Select the interface language or synchronize automatically with macOS.",
            .portuguese: "Selecione o idioma da interface ou sincronize automaticamente com o macOS.",
            .french: "Sélectionnez la langue de l'interface ou synchronisez automatiquement avec macOS.",
            .german: "Wählen Sie die Sprache der Benutzeroberfläche oder synchronisieren Sie mit macOS."
        ],
        "settings_notifications_header": [
            .spanish: "Notificaciones y Sistema", .english: "Notifications & System", .portuguese: "Notificações e Sistema", .french: "Notifications et Système", .german: "Benachrichtigungen & System"
        ]
    ]
}
