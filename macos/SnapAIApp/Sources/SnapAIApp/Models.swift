import Foundation
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case create
    case library
    case history
    case profiles
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .create: "Create"
        case .library: "Results"
        case .history: "History"
        case .profiles: "Profiles"
        case .settings: "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .create: "wand.and.stars"
        case .library: "square.grid.2x2"
        case .history: "clock.arrow.circlepath"
        case .profiles: "person.2"
        case .settings: "gearshape"
        }
    }
}

enum GenerationPhase: Equatable {
    case idle
    case preparing
    case generating
    case saving
    case completed
    case cancelled
    case failed(String)

    var isActive: Bool {
        switch self {
        case .preparing, .generating, .saving:
            true
        default:
            false
        }
    }

    var shouldShowStatus: Bool {
        self != .idle && self != .completed
    }

    var title: String {
        switch self {
        case .idle:
            "Ready"
        case .preparing:
            "Preparing generation"
        case .generating:
            "Generating artwork"
        case .saving:
            "Saving results"
        case .completed:
            "Generation complete"
        case .cancelled:
            "Generation cancelled"
        case .failed:
            "Generation failed"
        }
    }

    var systemImage: String {
        switch self {
        case .idle, .preparing, .generating, .saving:
            "sparkles"
        case .completed:
            "checkmark.circle.fill"
        case .cancelled:
            "xmark.circle"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    var isFailure: Bool {
        if case .failed = self {
            return true
        }
        return false
    }

    var errorMessage: String? {
        if case .failed(let message) = self {
            return message
        }
        return nil
    }
}

enum Provider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case gemini = "Google Gemini"

    var id: String { rawValue }
}

enum ModelOption: String, CaseIterable, Identifiable {
    case gptImage2 = "gpt-image-2"
    case gpt15 = "gpt-1.5"
    case gpt1 = "gpt-1"
    case banana2 = "banana-2"
    case banana = "banana"
    case bananaPro = "banana-pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gptImage2: "GPT Image 2"
        case .gpt15: "GPT Image 1.5"
        case .gpt1: "GPT Image 1"
        case .banana2: "Nano Banana 2"
        case .banana: "Nano Banana"
        case .bananaPro: "Nano Banana Pro"
        }
    }

    var provider: Provider {
        switch self {
        case .gptImage2, .gpt15, .gpt1: .openAI
        case .banana2, .banana, .bananaPro: .gemini
        }
    }

    var detail: String {
        switch self {
        case .gptImage2: "Latest OpenAI image model"
        case .gpt15: "Balanced default for most generations"
        case .gpt1: "Previous OpenAI image model"
        case .banana2: "Fast Gemini model with thinking controls"
        case .banana: "Single-image Gemini generation"
        case .bananaPro: "Higher-quality Gemini variations"
        }
    }

    var supportsBatch: Bool {
        switch self {
        case .banana, .banana2: false
        default: true
        }
    }

    var supportsTransparency: Bool {
        self != .gptImage2 && provider == .openAI
    }

    var qualityOptions: [String] {
        switch self {
        case .gptImage2, .gpt15, .gpt1: ["Auto", "High", "Medium", "Low"]
        case .banana: ["1K"]
        case .banana2: ["1K"]
        case .bananaPro: ["1K", "2K", "4K"]
        }
    }
}

struct GenerationDraft {
    var prompt = ""
    var style = ""
    var model: ModelOption = .gptImage2
    var quality = "Auto"
    var count = 1
    var background = "Auto"
    var outputFormat = "PNG"
    var outputFolder: URL?
    var fileName = ""
    var rawPrompt = false
    var useIconWords = false
    var thinking = "Minimal"
}

struct PersistedDraft: Codable {
    var style: String
    var model: String
    var quality: String
    var count: Int
    var background: String
    var outputFormat: String
    var outputFolderPath: String?
    var fileName: String
    var rawPrompt: Bool
    var useIconWords: Bool
    var thinking: String
}

extension GenerationDraft {
    var persisted: PersistedDraft {
        PersistedDraft(
            style: style,
            model: model.rawValue,
            quality: quality,
            count: count,
            background: background,
            outputFormat: outputFormat,
            outputFolderPath: outputFolder?.path,
            fileName: fileName,
            rawPrompt: rawPrompt,
            useIconWords: useIconWords,
            thinking: thinking
        )
    }

    init(persisted: PersistedDraft, prompt: String = "") {
        self.prompt = prompt
        self.style = persisted.style
        self.model = ModelOption(rawValue: persisted.model) ?? .gptImage2
        self.quality = persisted.quality
        self.count = min(max(persisted.count, 1), 10)
        self.background = persisted.background
        self.outputFormat = persisted.outputFormat
        self.outputFolder = persisted.outputFolderPath.map { URL(fileURLWithPath: $0) }
        self.fileName = persisted.fileName
        self.rawPrompt = persisted.rawPrompt
        self.useIconWords = persisted.useIconWords
        self.thinking = persisted.thinking
    }
}

struct ResultItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let outputURL: URL?
}

struct StoredProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var prompt: String?
    var draft: PersistedDraft
    let createdAt: Date

    var detail: String {
        let style = draft.style.trimmingCharacters(in: .whitespacesAndNewlines)
        return style.isEmpty ? draft.model : "\(draft.model) · \(style)"
    }

    init(id: UUID, name: String, prompt: String? = nil, draft: PersistedDraft, createdAt: Date) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.draft = draft
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        draft = try container.decode(PersistedDraft.self, forKey: .draft)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct StoredHistoryEntry: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let prompt: String
    let finalPrompt: String
    let provider: String
    let model: String
    let draft: PersistedDraft
    let outputPaths: [String]

    var displayDate: String {
        createdAt.formatted(date: .abbreviated, time: .shortened)
    }
}

struct NativeStoreState: Codable {
    var schemaVersion: Int = 1
    var hasCompletedOnboarding: Bool = false
    var profiles: [StoredProfile] = []
    var history: [StoredHistoryEntry] = []

    init(
        schemaVersion: Int = 1,
        hasCompletedOnboarding: Bool = false,
        profiles: [StoredProfile] = [],
        history: [StoredHistoryEntry] = []
    ) {
        self.schemaVersion = schemaVersion
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.profiles = profiles
        self.history = history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        profiles = try container.decodeIfPresent([StoredProfile].self, forKey: .profiles) ?? []
        history = try container.decodeIfPresent([StoredHistoryEntry].self, forKey: .history) ?? []
    }
}
