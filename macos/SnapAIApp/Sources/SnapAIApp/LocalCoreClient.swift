import Foundation

struct CoreCredentials: Encodable {
    let openai: String?
    let google: String?
}

private struct PromptPreviewPayload: Encodable {
    let prompt: String
    let rawPrompt: Bool
    let style: String
    let useIconWords: Bool
}

private struct GenerationOptionsPayload: Encodable {
    let output: String?
    let fileName: String?
    let model: String
    let quality: String
    let background: String
    let outputFormat: String
    let rawPrompt: Bool
    let style: String
    let useIconWords: Bool
    let pro: Bool
    let n: Int
    let thinking: String?
}

private struct GenerationPayload: Encodable {
    let prompt: String
    let options: GenerationOptionsPayload
    let credentials: CoreCredentials?
}

struct CoreFileURL: Decodable {
    let path: String
    let url: String
}

struct CoreGenerationResult: Decodable {
    let provider: String
    let model: String
    let finalPrompt: String
    let outputPaths: [String]
    let fileUrls: [CoreFileURL]?
}

private struct CoreGenerationEnvelope: Decodable {
    let ok: Bool
    let result: CoreGenerationResult
}

private struct CorePromptPreviewResponse: Decodable {
    let finalPrompt: String
}

private struct CoreHealthResponse: Decodable {
    let ok: Bool
}

private struct CoreErrorResponse: Decodable {
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case error
    }

    private struct ErrorPayload: Decodable {
        let message: String?
        let status: String?
        let code: Int?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let message = try? container.decode(String.self, forKey: .error) {
            error = message
            return
        }

        if let payload = try? container.decode(ErrorPayload.self, forKey: .error) {
            error = payload.message ?? payload.status ?? payload.code.map(String.init)
            return
        }

        error = nil
    }
}

enum LocalCoreError: LocalizedError {
    case invalidResponse
    case requestFailed(String)
    case providerFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The local SnapAI core returned an invalid response."
        case .requestFailed(let message), .providerFailed(let message):
            message
        }
    }
}

@MainActor
final class LocalCoreClient {
    let baseURL: URL
    let authToken: String
    let rootDirectory: URL

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL, authToken: String, rootDirectory: URL) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.rootDirectory = rootDirectory
    }

    func health() async -> Bool {
        do {
            let (data, response) = try await send(path: "/api/health", method: "GET", body: nil)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            let payload = try decoder.decode(CoreHealthResponse.self, from: data)
            return payload.ok
        } catch {
            return false
        }
    }

    func preview(prompt: String, draft: GenerationDraft) async throws -> String {
        let payload = PromptPreviewPayload(
            prompt: prompt,
            rawPrompt: draft.rawPrompt,
            style: draft.style,
            useIconWords: draft.useIconWords
        )
        let data = try encoder.encode(payload)
        let response: CorePromptPreviewResponse = try await request(
            path: "/api/prompt-preview",
            method: "POST",
            body: data
        )
        return response.finalPrompt
    }

    func generate(prompt: String, draft: GenerationDraft, credentials: CoreCredentials) async throws -> CoreGenerationResult {
        let payload = GenerationPayload(
            prompt: prompt,
            options: GenerationOptionsPayload(
                output: draft.outputFolder?.path,
                fileName: draft.fileName.isEmpty ? nil : draft.fileName,
                model: draft.model.rawValue,
                quality: draft.quality.lowercased(),
                background: draft.background.lowercased(),
                outputFormat: draft.outputFormat.lowercased(),
                rawPrompt: draft.rawPrompt,
                style: draft.style,
                useIconWords: draft.useIconWords,
                pro: draft.model == .bananaPro,
                n: draft.model.supportsBatch ? draft.count : 1,
                thinking: draft.model == .banana2 ? draft.thinking.lowercased() : nil
            ),
            credentials: credentials
        )
        let data = try encoder.encode(payload)
        let responseData = try await requestData(path: "/api/generate", method: "POST", body: data)
        return try Self.decodeGenerationResponse(responseData)
    }

    static func decodeGenerationResponse(_ data: Data) throws -> CoreGenerationResult {
        let envelope = try JSONDecoder().decode(CoreGenerationEnvelope.self, from: data)
        guard envelope.ok else {
            throw LocalCoreError.invalidResponse
        }
        return envelope.result
    }

    static func decodeErrorMessage(_ data: Data) -> String? {
        (try? JSONDecoder().decode(CoreErrorResponse.self, from: data))?.error
    }

    private func request<T: Decodable>(path: String, method: String, body: Data) async throws -> T {
        let data = try await requestData(path: path, method: method, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw LocalCoreError.invalidResponse
        }
    }

    private func requestData(path: String, method: String, body: Data) async throws -> Data {
        let (data, response) = try await send(path: path, method: method, body: body)
        guard let http = response as? HTTPURLResponse else {
            throw LocalCoreError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let message = Self.decodeErrorMessage(data) {
                throw LocalCoreError.providerFailed(message)
            }
            throw LocalCoreError.requestFailed("Local core request failed with HTTP \(http.statusCode).")
        }
        return data
    }

    private func send(path: String, method: String, body: Data?) async throws -> (Data, URLResponse) {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body
        return try await URLSession.shared.data(for: request)
    }
}
