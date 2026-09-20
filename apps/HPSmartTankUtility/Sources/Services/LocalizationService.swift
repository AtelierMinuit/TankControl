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
        "section_calibration": [
            .spanish: "Calibración ICC", .english: "ICC Calibration", .portuguese: "Calibração ICC", .french: "Étalonnage ICC", .german: "ICC-Farbkalibrierung"
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
        "settings_subtitle": [
            .spanish: "Preferencias generales y opciones de desarrollo de TankControl.",
            .english: "General preferences and development options for TankControl.",
            .portuguese: "Preferências gerais e opções de desenvolvimento do TankControl.",
            .french: "Préférences générales et options de développement de TankControl.",
            .german: "Allgemeine Einstellungen und Entwickleroptionen für TankControl."
        ],
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
        ],
        "settings_notifications_title": [
            .spanish: "Avisos de Hardware y Tinta Baja",
            .english: "Hardware and Low Ink Alerts",
            .portuguese: "Alertas de Hardware e Tinta Baixa",
            .french: "Alertes Matériel et Encre Faible",
            .german: "Hardware- und Tintenstandswarnungen"
        ],
        "settings_notifications_active": [
            .spanish: "Activas", .english: "Active", .portuguese: "Ativas", .french: "Actives", .german: "Aktiv"
        ],
        "settings_notifications_desc": [
            .spanish: "Notifica automáticamente si algún depósito CISS cae por debajo del 12% o si la impresora reporta un atasco.",
            .english: "Automatically notifies if any CISS tank drops below 12% or if the printer reports a paper jam.",
            .portuguese: "Notifica automaticamente se algum tanque CISS cair abaixo de 12% ou se a impressora relatar atolamento de papel.",
            .french: "Notifie automatiquement si un réservoir CISS passe sous 12% ou si l'imprimante signale un bourrage papier.",
            .german: "Benachrichtigt automatisch, wenn ein CISS-Tank unter 12 % fällt oder der Drucker einen Papierstau meldet."
        ],
        "settings_dev_header": [
            .spanish: "Opciones de Desarrollo", .english: "Developer Options", .portuguese: "Opções de Desenvolvedor", .french: "Options Développeur", .german: "Entwickleroptionen"
        ],
        "settings_dev_toggle": [
            .spanish: "Mostrar sección de Desarrollo en la barra lateral",
            .english: "Show Developer section in sidebar",
            .portuguese: "Mostrar seção de Desenvolvimento na barra lateral",
            .french: "Afficher la section Développeur dans la barre latérale",
            .german: "Entwicklerbereich in der Seitenleiste anzeigen"
        ],
        "settings_dev_desc": [
            .spanish: "Habilita el visor de descriptores USB, volcados XML de firmware y diagnósticos de subsistemas.",
            .english: "Enables USB descriptor viewer, firmware XML dumps, and subsystem diagnostics.",
            .portuguese: "Habilita o visualizador de descritores USB, despejos XML de firmware e diagnósticos de subsistemas.",
            .french: "Active le visualiseur de descripteurs USB, les vidages XML du micrologiciel et les diagnostics de sous-systèmes.",
            .german: "Aktiviert den USB-Deskriptor-Viewer, Firmware-XML-Dumps und Subsystem-Diagnosen."
        ],
        "settings_btn_about": [
            .spanish: "Acerca de…", .english: "About…", .portuguese: "Sobre…", .french: "À propos…", .german: "Über…"
        ],
        "settings_dialog_dev_title": [
            .spanish: "¿Mostrar herramientas de desarrollo?",
            .english: "Show developer tools?",
            .portuguese: "Mostrar ferramentas de desenvolvedor?",
            .french: "Afficher les outils de développement ?",
            .german: "Entwicklertools anzeigen?"
        ],
        "settings_dialog_dev_confirm": [
            .spanish: "Mostrar herramientas", .english: "Show tools", .portuguese: "Mostrar ferramentas", .french: "Afficher les outils", .german: "Tools anzeigen"
        ],
        "settings_dialog_dev_cancel": [
            .spanish: "Cancelar", .english: "Cancel", .portuguese: "Cancelar", .french: "Annuler", .german: "Abbrechen"
        ],
        "settings_dialog_dev_message": [
            .spanish: "Incluye operaciones que consumen tinta o envían comandos directos al equipo. Activar esta sección no ejecuta ninguna operación sin confirmación adicional.",
            .english: "Includes operations that consume ink or send raw commands to the hardware. Enabling this section does not execute any operation without explicit confirmation.",
            .portuguese: "Inclui operações que consomem tinta ou enviam comandos diretos ao dispositivo. Ativar esta seção não executa nenhuma operação sem confirmação adicional.",
            .french: "Comprend des opérations consommant de l'encre ou envoyant des commandes directes. L'activation de cette section n'exécute aucune opération sans confirmation.",
            .german: "Enthält Operationen, die Tinte verbrauchen oder direkte Befehle an das Gerät senden. Die Aktivierung führt keine Aktionen ohne Bestätigung aus."
        ],
        "settings_airprint_header": [
            .spanish: "Puente AirPrint para iOS y Red Local",
            .english: "AirPrint Bridge for iOS & Local Network",
            .portuguese: "Ponte AirPrint para iOS e Rede Local",
            .french: "Pont AirPrint pour iOS et Réseau Local",
            .german: "AirPrint-Bridge für iOS und lokales Netzwerk"
        ],
        "settings_airprint_desc": [
            .spanish: "Anuncia la HP Smart Tank 500 mediante Bonjour/mDNS en la red local para imprimir sin cables ni controladores desde iPhone, iPad y Mac.",
            .english: "Advertises the HP Smart Tank 500 via Bonjour/mDNS on the local network for wireless, driverless printing from iPhone, iPad, and Mac.",
            .portuguese: "Anuncia a HP Smart Tank 500 via Bonjour/mDNS na rede local para impressão sem fio e sem drivers a partir do iPhone, iPad e Mac.",
            .french: "Diffuse l'imprimante HP Smart Tank 500 via Bonjour/mDNS sur le réseau local pour imprimer sans fil et sans pilote depuis iPhone, iPad et Mac.",
            .german: "Gibt den HP Smart Tank 500 über Bonjour/mDNS im lokalen Netzwerk frei für kabelloses Drucken ohne Treiber von iPhone, iPad und Mac."
        ],
        "settings_airprint_active": [
            .spanish: "Activo (Transmitiendo en red local)",
            .english: "Active (Broadcasting on local network)",
            .portuguese: "Ativo (Transmitindo na rede local)",
            .french: "Actif (Diffusion sur le réseau local)",
            .german: "Aktiv (Im lokalen Netzwerk sichtbar)"
        ],
        "settings_airprint_inactive": [
            .spanish: "Inactivo (Compartición pausada)",
            .english: "Inactive (Sharing paused)",
            .portuguese: "Inativo (Compartilhamento pausado)",
            .french: "Inactif (Partage en pause)",
            .german: "Inaktiv (Freigabe angehalten)"
        ],
        "paper_guide_title": [
            .spanish: "Guía y Comparador de Formatos de Papel",
            .english: "Paper Formats Guide & Comparator",
            .portuguese: "Guia e Comparador de Formatos de Papel",
            .french: "Guide et Comparateur de Formats de Papier",
            .german: "Papierformate Leitfaden & Komparator"
        ],
        "paper_guide_subtitle": [
            .spanish: "Diferenciación exacta entre Carta, Oficio Chile/LATAM (13''), Legal (14'') y A4",
            .english: "Exact dimensions and tray alignment for Letter, Oficio, Legal, and A4",
            .portuguese: "Diferenciação exata entre Carta, Ofício Chile/LATAM (13''), Legal (14'') e A4",
            .french: "Différenciation exacte entre Lettre, Oficio Chili/LATAM (13''), Légal (14'') et A4",
            .german: "Exakte Maße und Ausrichtung für US-Letter, Oficio, US-Legal und A4"
        ]
    ]
}
