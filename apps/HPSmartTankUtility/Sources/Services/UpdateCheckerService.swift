import Foundation
import AppKit

/// Estructura para decodificar la respuesta de GitHub Releases API
public struct GitHubReleaseResponse: Codable {
    public let tag_name: String
    public let name: String?
    public let html_url: String
    public let body: String?
    public let published_at: String?
}

/// Servicio para comprobar de forma asíncrona actualizaciones en GitHub Releases
public final class UpdateCheckerService: ObservableObject {
    public static let shared = UpdateCheckerService()

    @Published public var isChecking: Bool = false
    @Published public var updateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var releaseTitle: String = ""
    @Published public var releaseNotes: String = ""
    @Published public var releaseURL: URL? = nil
    @Published public var statusMessage: String = ""

    private let repoApiURL = "https://api.github.com/repos/AtelierMinuit/TankControl/releases/latest"

    private init() {}

    /// Obtiene la versión actual de la aplicación desde Info.plist
    public var currentVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"
    }

    /// Comprueba si existe una versión más reciente en GitHub Releases
    public func checkForUpdates(manual: Bool = false) {
        guard let url = URL(string: repoApiURL) else { return }

        isChecking = true
        statusMessage = "Comprobando actualizaciones en GitHub..."

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("TankControl-macOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isChecking = false

                if let error = error {
                    self.statusMessage = manual ? "No se pudo comprobar: \(error.localizedDescription)" : ""
                    return
                }

                guard let data = data,
                      let release = try? JSONDecoder().decode(GitHubReleaseResponse.self, from: data) else {
                    self.statusMessage = manual ? "Respuesta de versión no disponible." : ""
                    return
                }

                let remoteTag = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                let current = self.currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))

                self.latestVersion = release.tag_name
                self.releaseTitle = release.name ?? release.tag_name
                self.releaseNotes = release.body ?? ""
                self.releaseURL = URL(string: release.html_url)

                if self.isVersion(remoteTag, greaterThan: current) {
                    self.updateAvailable = true
                    self.statusMessage = "¡Nueva versión disponible: \(release.tag_name)!"
                } else {
                    self.updateAvailable = false
                    self.statusMessage = manual ? "Tienes la última versión instalada (\(self.currentVersion))." : ""
                }
            }
        }.resume()
    }

    /// Compara dos cadenas de versión semántica (ej: "1.3.0" vs "1.2.0")
    public func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }

        let count = max(p1.count, p2.count)
        for i in 0..<count {
            let num1 = i < p1.count ? p1[i] : 0
            let num2 = i < p2.count ? p2[i] : 0
            if num1 > num2 { return true }
            if num1 < num2 { return false }
        }
        return false
    }

    /// Abre la página oficial del Release en el navegador por defecto
    public func openLatestRelease() {
        if let url = releaseURL {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "https://github.com/AtelierMinuit/TankControl/releases") {
            NSWorkspace.shared.open(fallback)
        }
    }
}
