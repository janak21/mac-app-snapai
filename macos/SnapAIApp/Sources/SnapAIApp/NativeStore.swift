import Foundation

final class NativeStore {
    private let fileManager = FileManager.default
    private let stateURL: URL

    init() {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Library/Application Support")
        stateURL = applicationSupport
            .appendingPathComponent("SnapAI", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    func load() -> NativeStoreState {
        guard let data = try? Data(contentsOf: stateURL) else {
            return NativeStoreState()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(NativeStoreState.self, from: data)) ?? NativeStoreState()
    }

    @discardableResult
    func save(_ state: NativeStoreState) -> Bool {
        do {
            try fileManager.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(state).write(to: stateURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
