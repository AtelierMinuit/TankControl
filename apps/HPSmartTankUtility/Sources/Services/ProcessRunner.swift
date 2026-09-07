import Foundation

/// Resultado estructurado de ejecución de un subproceso.
public struct ProcessResult {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var isSuccess: Bool { exitCode == 0 }
    public var combinedOutput: String {
        if stderr.isEmpty { return stdout }
        if stdout.isEmpty { return stderr }
        return "\(stdout)\n\(stderr)"
    }
}

/// Ejecutor seguro de subprocesos sin invocación de shell (no `sh -c`).
/// Diseñado para ejecutar helpers auxiliares de forma no bloqueante y controlada.
public final class ProcessRunner {

    public static let shared = ProcessRunner()

    private init() {}

    /// Ejecuta un binario ejecutable con argumentos seguros y timeout cooperativo.
    /// - Parameters:
    ///   - executableURL: URL absoluta al binario.
    ///   - arguments: Argumentos de línea de comandos tipados.
    ///   - timeoutSeconds: Tiempo máximo antes de terminar el proceso (por defecto 30.0s).
    /// - Returns: ProcessResult con código de salida, stdout y stderr.
    public func run(
        executableURL: URL,
        arguments: [String] = [],
        timeoutSeconds: TimeInterval = 30.0
    ) -> ProcessResult {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            return ProcessResult(
                exitCode: -1,
                stdout: "",
                stderr: "[ERROR] El archivo no es ejecutable: \(executableURL.path)"
            )
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()

            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + timeoutSeconds)
            timer.setEventHandler {
                if process.isRunning {
                    process.terminate()
                }
            }
            timer.resume()

            let group = DispatchGroup()
            var stdoutData = Data()
            var stderrData = Data()

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            process.waitUntilExit()
            group.wait()
            timer.cancel()

            let stdoutStr = String(data: stdoutData, encoding: .utf8) ?? ""
            let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""

            return ProcessResult(
                exitCode: process.terminationStatus,
                stdout: stdoutStr.trimmingCharacters(in: .whitespacesAndNewlines),
                stderr: stderrStr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            return ProcessResult(
                exitCode: -2,
                stdout: "",
                stderr: "[ERROR] Error al iniciar subproceso: \(error.localizedDescription)"
            )
        }
    }

    /// Localiza de forma segura un helper dentro del bundle de la aplicación.
    public func resolveHelperPath(named name: String) -> URL? {
        let bundle = Bundle.main
        var candidates: [URL] = []

        if let helperURL = bundle.url(forAuxiliaryExecutable: name) {
            candidates.append(helperURL)
        }

        let bundleHelpersURL = bundle.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")
            .appendingPathComponent(name)
        candidates.append(bundleHelpersURL)

        if let resURL = bundle.url(forResource: name, withExtension: nil) {
            candidates.append(resURL)
        }

        for url in candidates {
            let path = url.path
            if FileManager.default.isExecutableFile(atPath: path),
               let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
               values.isRegularFile == true,
               values.isSymbolicLink != true {
                return url.standardizedFileURL
            }
        }
        return nil
    }
}
