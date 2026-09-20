import Foundation
import ServiceManagement
import Combine

/// Servicio para gestionar el arranque automático de TankControl al iniciar sesión en macOS.
/// Compatible con macOS 13+ (Ventura, Sonoma, Sequoia) mediante `SMAppService`
/// y con soporte retrocompatible para macOS 12 (Monterey).
public final class LaunchAtLoginService: ObservableObject {
    public static let shared = LaunchAtLoginService()

    @Published public var isEnabled: Bool = false {
        didSet {
            guard isEnabled != oldValue else { return }
            applyLaunchAtLogin(enabled: isEnabled)
        }
    }

    private var isUpdatingInternally = false

    private init() {
        refreshStatus()
    }

    /// Actualiza el estado actual de registro en el sistema
    public func refreshStatus() {
        isUpdatingInternally = true
        defer { isUpdatingInternally = false }

        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            self.isEnabled = (status == .enabled)
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: "tankcontrol_launch_at_login")
        }
    }

    /// Aplica el cambio en el sistema
    private func applyLaunchAtLogin(enabled: Bool) {
        guard !isUpdatingInternally else { return }

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("[LaunchAtLoginService] Error configurando SMAppService: %@", error.localizedDescription)
            }
        } else {
            UserDefaults.standard.set(enabled, forKey: "tankcontrol_launch_at_login")
        }
    }
}
