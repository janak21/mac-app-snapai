import XCTest
@testable import SnapAIApp

final class SnapAIAppTests: XCTestCase {
    func testModelCapabilitiesMatchProvider() {
        XCTAssertEqual(ModelOption.gptImage2.provider, .openAI)
        XCTAssertEqual(ModelOption.banana2.provider, .gemini)
        XCTAssertFalse(ModelOption.banana.supportsBatch)
        XCTAssertFalse(ModelOption.gptImage2.supportsTransparency)
    }

    func testQualityOptionsAreProviderAware() {
        XCTAssertEqual(ModelOption.gpt15.qualityOptions, ["Auto", "High", "Medium", "Low"])
        XCTAssertEqual(ModelOption.bananaPro.qualityOptions, ["1K", "2K", "4K"])
    }

    func testGenerationPhaseLifecycleMetadata() {
        XCTAssertTrue(GenerationPhase.generating.isActive)
        XCTAssertTrue(GenerationPhase.saving.isActive)
        XCTAssertTrue(GenerationPhase.failed("Provider unavailable").isFailure)
        XCTAssertFalse(GenerationPhase.cancelled.isActive)
        XCTAssertEqual(GenerationPhase.cancelled.title, "Generation cancelled")
    }

    func testStateDecodingKeepsOnboardingBackwardCompatible() throws {
        let legacy = #"{"schemaVersion":1,"profiles":[],"history":[]}"#.data(using: .utf8)!
        let state = try JSONDecoder().decode(NativeStoreState.self, from: legacy)
        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertTrue(state.profiles.isEmpty)
    }

    @MainActor
    func testNativeClientAcceptsGenerationEnvelope() throws {
        let response = #"{"ok":true,"result":{"provider":"openai","model":"gpt-1.5","finalPrompt":"resolved","outputPaths":["/tmp/icon.png"],"fileUrls":[]}}"#.data(using: .utf8)!
        let result = try LocalCoreClient.decodeGenerationResponse(response)
        XCTAssertEqual(result.model, "gpt-1.5")
        XCTAssertEqual(result.outputPaths, ["/tmp/icon.png"])
    }

    @MainActor
    func testNativeClientExplainsStructuredCoreErrors() throws {
        let response = #"{"error":{"message":"OpenAI API key not configured.","code":500,"status":"CONFIGURATION_ERROR"}}"#.data(using: .utf8)!
        XCTAssertEqual(LocalCoreClient.decodeErrorMessage(response), "OpenAI API key not configured.")
    }

    func testDraftPersistenceRoundTripDoesNotContainCredentials() throws {
        var draft = GenerationDraft()
        draft.prompt = "A secure finance symbol"
        draft.model = .banana2
        draft.quality = "1K"
        draft.thinking = "Max"
        draft.fileName = "finance-symbol"
        draft.outputFolder = URL(fileURLWithPath: "/tmp/snapai-output")

        let encoded = try JSONEncoder().encode(draft.persisted)
        let decoded = try JSONDecoder().decode(PersistedDraft.self, from: encoded)
        let restored = GenerationDraft(persisted: decoded, prompt: draft.prompt)

        XCTAssertEqual(restored.prompt, draft.prompt)
        XCTAssertEqual(restored.model, .banana2)
        XCTAssertEqual(restored.thinking, "Max")
        XCTAssertEqual(restored.fileName, "finance-symbol")
        XCTAssertEqual(restored.outputFolder?.path, "/tmp/snapai-output")
        XCTAssertFalse(String(data: encoded, encoding: .utf8)?.contains("api-key") == true)
    }

    func testLegacyProfileDecodingLeavesPromptOptional() throws {
        let legacy = #"{"id":"00000000-0000-0000-0000-000000000001","name":"Legacy","draft":{"style":"minimal","model":"gpt-1.5","quality":"auto","count":1,"background":"auto","outputFormat":"png","outputFolderPath":null,"fileName":"","rawPrompt":false,"useIconWords":true,"thinking":"Minimal"},"createdAt":"2026-01-01T00:00:00Z"}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(StoredProfile.self, from: legacy)
        XCTAssertNil(profile.prompt)
        XCTAssertEqual(profile.name, "Legacy")
    }
}
