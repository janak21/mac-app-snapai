import Foundation

enum LocalCoreProcessError: LocalizedError {
    case sourceRootNotFound
    case launchFailed(String)
    case didNotBecomeReady(String)

    var errorDescription: String? {
        switch self {
        case .sourceRootNotFound:
            "Could not find the SnapAI source root. Set SNAPAI_CORE_ROOT to the repository path."
        case .launchFailed(let message), .didNotBecomeReady(let message):
            message
        }
    }
}

private struct CoreRuntime {
    let root: URL
    let nodePath: String
    let entryPoint: String
}

@MainActor
final class LocalCoreProcess {
    private(set) var client: LocalCoreClient?
    private var process: Process?

    func start() async throws -> LocalCoreClient {
        if let client {
            return client
        }

        let runtime = try resolveRuntime()
        let port = Int.random(in: 4300...4399)
        let token = UUID().uuidString
        let process = Process()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: runtime.nodePath)
        process.arguments = [
            runtime.entryPoint,
            "ui",
            "--no-open",
            "--port",
            String(port),
            "--token",
            token
        ]
        process.currentDirectoryURL = runtime.root
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw LocalCoreProcessError.launchFailed(error.localizedDescription)
        }

        self.process = process
        let client = LocalCoreClient(
            baseURL: URL(string: "http://127.0.0.1:\(port)")!,
            authToken: token,
            rootDirectory: runtime.root
        )

        for _ in 0..<50 {
            if await client.health() {
                self.client = client
                return client
            }
            try? await Task.sleep(for: .milliseconds(120))
        }

        process.terminate()
        let diagnosticData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let diagnostic = String(data: diagnosticData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        throw LocalCoreProcessError.didNotBecomeReady(
            diagnostic?.isEmpty == false ? diagnostic! : "The local generation core did not become ready."
        )
    }

    func stop() {
        process?.terminate()
        process = nil
        client = nil
    }

    deinit {
        process?.terminate()
    }

    private func resolveRuntime() throws -> CoreRuntime {
        let fileManager = FileManager.default

        if let resourceRoot = Bundle.main.resourceURL?.appendingPathComponent("Core", isDirectory: true),
           fileManager.fileExists(atPath: resourceRoot.appendingPathComponent("dist/index.js").path) {
            let bundledNode = resourceRoot.appendingPathComponent("node", isDirectory: false)
            guard fileManager.isExecutableFile(atPath: bundledNode.path) else {
                throw LocalCoreProcessError.launchFailed("The bundled Node runtime is missing or not executable.")
            }
            return CoreRuntime(root: resourceRoot, nodePath: bundledNode.path, entryPoint: "dist/index.js")
        }

        let sourceRoot = try resolveSourceRoot()
        return CoreRuntime(root: sourceRoot, nodePath: try resolveNodePath(), entryPoint: "bin/dev.js")
    }

    private func resolveSourceRoot() throws -> URL {
        let fileManager = FileManager.default
        let current = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        let environmentRoot = ProcessInfo.processInfo.environment["SNAPAI_CORE_ROOT"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
        let candidates = [
            environmentRoot,
            current,
            current.deletingLastPathComponent(),
            current.deletingLastPathComponent().deletingLastPathComponent(),
            Bundle.main.bundleURL.deletingLastPathComponent(),
            Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent(),
            Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        ].compactMap { $0 }

        for candidate in candidates {
            let devEntry = candidate.appendingPathComponent("bin/dev.js")
            let builtEntry = candidate.appendingPathComponent("dist/index.js")
            if fileManager.fileExists(atPath: devEntry.path) && fileManager.fileExists(atPath: builtEntry.path) {
                return candidate
            }
        }

        throw LocalCoreProcessError.sourceRootNotFound
    }

    private func resolveNodePath() throws -> String {
        let fileManager = FileManager.default
        let environmentNode = ProcessInfo.processInfo.environment["SNAPAI_NODE_PATH"]
        let candidates = [
            environmentNode,
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node"
        ].compactMap { $0 }

        if let nodePath = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) {
            return nodePath
        }

        if let shellNodePath = resolveNodeFromLoginShell(),
           fileManager.isExecutableFile(atPath: shellNodePath) {
            return shellNodePath
        }

        throw LocalCoreProcessError.launchFailed(
            "Node.js was not found. Set SNAPAI_NODE_PATH to the Node executable used by this checkout."
        )
    }

    private func resolveNodeFromLoginShell() -> String? {
        let probe = Process()
        let output = Pipe()
        probe.executableURL = URL(fileURLWithPath: "/bin/zsh")
        probe.arguments = ["-lc", "command -v node"]
        probe.standardOutput = output
        probe.standardError = Pipe()

        do {
            try probe.run()
            probe.waitUntilExit()
        } catch {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.split(whereSeparator: \.isNewline).first.map(String.init)
    }
}
