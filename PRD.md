# SnapAI macOS Product Requirements Document

**Status:** Draft for implementation
**Product:** SnapAI
**Primary platform:** macOS
**Existing surfaces:** CLI, local Web UI, terminal Studio
**Target experience:** A polished, local-first Mac app for generating, comparing, and saving app artwork.

## 1. Product Summary

SnapAI currently makes high-quality square app artwork through a command-line workflow. The CLI is powerful and scriptable, but repeated flags, model-specific constraints, API-key setup, output-folder selection, and result comparison create unnecessary friction.

SnapAI will evolve into a native macOS application that keeps the existing CLI engine and adds a calm, focused visual workflow. A user should be able to configure a provider, write a prompt, choose a model, generate several variations, compare them, and save the selected files to a chosen directory without repeating terminal commands.

The Mac app is local-first: generation requests go directly from the user’s machine to the selected provider, credentials are stored in the macOS Keychain, and generation history remains local unless the user explicitly exports or shares it.

## 2. Vision and Product Promise

**Promise:** Create and save a strong app-art concept in under 30 seconds after first-time setup.

SnapAI should feel like a focused creative utility rather than an administration console:

- Prompt first, controls second.
- Useful defaults, visible constraints, and fast iteration.
- Clear model differences without provider jargon.
- Native Mac interaction patterns and keyboard support.
- Secure by default, with no account or telemetry requirement.

## 3. Goals

1. Make first-run generation approachable for a developer who has never used the CLI.
2. Make repeat generation fast for experienced users.
3. Let users switch providers and models without losing their prompt or workflow settings.
4. Let users choose, remember, and override an output directory safely.
5. Make generated variations easy to compare, open, reveal in Finder, and reuse.
6. Store credentials securely and avoid exposing them to the UI, logs, history, or source-controlled files.
7. Preserve the existing `snapai icon` CLI for scripting and CI.

## 4. Non-Goals for the First Mac Release

1. Cloud accounts, synchronization, or team collaboration.
2. A hosted generation proxy or server-side storage.
3. Full image editing, masking, inpainting, or compositing.
4. Automatic App Store submission or Xcode project modification.
5. An iPhone or iPad client.
6. Building a general-purpose image library or asset manager.

## 5. Users and Jobs to Be Done

### 5.1 Mobile developer

Needs a recognizable icon concept quickly, with predictable square output and a known save location.

### 5.2 Indie maker or designer

Needs to explore several visual directions, compare variations, and keep useful prompts and settings for later.

### 5.3 Power user

Needs keyboard-first controls, exact model/quality options, repeatable profiles, and CLI compatibility.

## 6. Experience Principles

### Native Mac behavior

Use SwiftUI and standard macOS patterns: sidebar navigation, split views, sheets for focused tasks, native folder pickers, menus, keyboard commands, toolbars, and system share/reveal actions. Avoid hamburger navigation and web-style dashboards inside the desktop app.

### Progressive disclosure

The default Create screen exposes only the decisions most users need. Advanced provider options remain available without overwhelming first-time users.

### Explain constraints at the point of choice

If a model does not support transparency, multiple outputs, or a quality tier, show the reason next to the control and disable or adjust only the invalid option.

### Local-first privacy

No telemetry, analytics, remote history, or account requirement in the first release. Provider requests are direct and visible through clear status and error states.

### Accessible by construction

Support VoiceOver labels, keyboard navigation, Dynamic Type/text-size preferences, Dark Mode, increased contrast, reduced motion, and non-color status indicators. Use semantic system colors and accessible control labels.

## 7. Supported Platforms and Technologies

### 7.1 Desktop application

- SwiftUI-first macOS application.
- Target macOS 14 Sonoma or newer for the first release; revisit older versions after the MVP is stable.
- App sandbox enabled.
- Keychain Services for provider credentials.
- Security-scoped bookmarks for user-selected directories.
- Native `NSOpenPanel` folder selection and Finder reveal actions.

### 7.2 Existing generation core

The existing TypeScript generation engine remains the initial source of truth for provider behavior and prompt construction. The Mac app communicates with it through a versioned local boundary so CLI, Web UI, Studio, and the native app share validation and model constraints.

The desktop shell must own credential access. Credentials are read from Keychain and passed to the local generation process only in memory for a request; they are never written into the app UI state, generation history, request logs, or local JSON configuration.

## 8. Primary User Flows

### 8.1 First launch

1. App opens on a short setup state with a clear explanation of local storage and direct provider requests.
2. User selects OpenAI, Google Gemini, or both.
3. User enters a key into a secure field; the app validates it without displaying or persisting the raw value outside Keychain.
4. App performs a lightweight provider readiness check only after the user requests it.
5. User chooses a default output folder through a native folder picker.
6. App lands on Create with a useful starter prompt example.

### 8.2 Create and generate

1. User enters or pastes a prompt.
2. User selects a provider/model or accepts the recommended default.
3. User optionally chooses style, quality, number of variations, format, background, and output name.
4. App shows a compact summary of the resolved generation plan.
5. User previews the final prompt if desired.
6. User selects Generate.
7. App shows progress, elapsed time, cancellation state, and provider-aware errors.
8. Results appear in a comparison grid without navigating away from the Create context.

### 8.3 Compare and save

1. User selects one or more variations.
2. User can open a larger preview, copy the final prompt, regenerate, reveal the file in Finder, or share the file.
3. App saves files to the chosen folder using a predictable name and collision-safe behavior.
4. User can change the output folder for the current run or update the default in Settings.
5. Metadata is added to local history; the image file remains under the user-selected directory.

### 8.4 Reuse history

1. User opens History and searches or filters prior runs.
2. User can restore a prompt and its options into Create.
3. User can rerun a previous configuration, choose a different model, or delete the history record.
4. Deleting history never deletes image files unless the user explicitly chooses a separate file-deletion action.

## 9. Functional Requirements

### 9.1 Create screen

- Multiline prompt editor with character count and validation.
- Prompt preview action that does not call a provider.
- Recommended model selection with provider badge.
- Advanced options shown in a collapsible section.
- Generate button with keyboard shortcut and clear disabled states.
- Cost/rate-limit warning before large batches.
- Preserve prompt and options through errors, window resizing, and tab changes.

### 9.2 Model and provider selection

The first Mac release must expose the models already supported by the CLI:

| User-facing alias | Provider | Required behavior |
| --- | --- | --- |
| `gpt-1.5` | OpenAI | Current default OpenAI image model |
| `gpt-1` | OpenAI | Previous OpenAI image model |
| `gpt-image-2` | OpenAI | Latest OpenAI image model; reject unsupported transparency settings |
| `banana` | Google Gemini | Normal Nano Banana mode; one image and 1K quality |
| `banana-2` | Google Gemini | Nano Banana 2 with thinking-level controls |
| Banana Pro | Google Gemini | Optional multi-image generation with 1K/2K/4K quality |

The app must present capabilities as part of the model choice. It must not silently send an invalid combination to a provider.

### 9.3 Output management

- Native folder picker for the default output location.
- Per-run output-folder override.
- Persist folder access using security-scoped bookmarks.
- Request folder access only when the user chooses a folder.
- Remember the last successful output location when enabled.
- Support custom base filename with safe normalization.
- Avoid overwriting existing files by adding an index or timestamp.
- Offer “Reveal in Finder” and “Copy path.”
- Show the exact resolved path after saving.

### 9.4 Profiles and defaults

Profiles may contain:

- Provider/model.
- Style.
- Quality.
- Background and output format.
- Number of images.
- Output directory.
- Raw-prompt and icon-word behavior.

Users can create, rename, activate, edit, duplicate, and delete profiles. Deleting a profile does not delete images or history.

### 9.5 History

Each history entry stores only the information needed to reproduce a run:

- Timestamp.
- Prompt and final prompt.
- Provider/model.
- Resolved options.
- Output paths.
- Profile identifier, if used.
- Generation status and error summary, if applicable.

History must not store API keys, authorization headers, raw provider responses containing credentials, or unnecessary personal data.

### 9.6 CLI compatibility

- Existing `snapai icon` flags remain supported.
- Existing environment-variable configuration remains supported.
- Existing `~/.snapai/config.json` data is migrated without destructive changes.
- Shared validation and model capability rules are tested against both CLI and Mac app requests.

## 10. macOS App Information Architecture

Use a persistent sidebar with four primary sections and one utility section:

1. **Create** — prompt, controls, generation, and current results.
2. **History** — searchable prior runs and rerun actions.
3. **Profiles** — reusable workflows and defaults.
4. **Settings** — providers, credentials, output folder, privacy, and appearance.
5. **Help** — model capability explanations, keyboard shortcuts, diagnostics, and safe reset actions.

The Create view uses a focused split layout:

- Left: prompt and generation controls.
- Right: live prompt preview, generation status, and result comparison.
- Bottom toolbar: Generate, output location, and secondary actions.

The layout must reflow gracefully for smaller windows and larger text settings. No critical action may depend on hover alone.

## 11. Security and Privacy Requirements

### Credentials

- Store provider keys only in the macOS Keychain.
- Never put raw keys in `UserDefaults`, JSON files, logs, crash reports, analytics, URLs, or command-line arguments from the app.
- Mask keys in all UI and diagnostics.
- Provide explicit “Remove key” actions.
- Clear sensitive in-memory values as soon as practical after a request.

### Local transport

- Prefer a Unix domain socket or an authenticated loopback channel over an unauthenticated open port.
- If a loopback HTTP service is required for compatibility, bind to `127.0.0.1`, use a random per-launch bearer token, reject cross-origin requests, and never expose it on LAN interfaces.
- Validate request schemas at the boundary and cap prompt/body sizes.

### Filesystem

- Use App Sandbox entitlements.
- Request access only to user-selected folders.
- Do not scan arbitrary directories.
- Do not delete files as a side effect of deleting history.
- Treat output paths and provider-returned filenames as untrusted input.

### Network and telemetry

- Connect only to the selected provider endpoint and explicitly requested update/help resources.
- No hidden telemetry or third-party analytics.
- Document provider data handling in Settings and the README.

## 12. Accessibility and Interaction Quality

- All controls have VoiceOver labels and meaningful value descriptions.
- Full keyboard navigation and command equivalents for Generate, Preview, Open, Reveal, Rerun, and Delete.
- Semantic text styles and support for larger system text sizes without truncation.
- Intentional Light and Dark Mode using semantic colors.
- Contrast is never conveyed by color alone.
- Respect reduced-motion settings and provide non-animated progress feedback.
- Primary actions remain discoverable at narrow window sizes.
- Destructive actions require confirmation and use the system destructive treatment.
- Empty, loading, success, partial-success, quota, authentication, and offline states are designed explicitly.

## 13. Data and Storage Model

### Keychain

- `openai-api-key`
- `google-api-key`

### Local app data

Use an app-owned versioned data directory for native app state. Migrate existing `~/.snapai` data on first launch only after showing the user what will be imported.

Suggested entities:

- `AppSettings`: defaults, active profile, output bookmark, privacy and appearance settings.
- `Profile`: named generation options.
- `GenerationRun`: prompt, resolved options, status, timestamps, and output paths.
- `OutputReference`: path, filename, provider/model, and optional thumbnail cache reference.

Thumbnails may be cached locally for performance, but cache deletion must never delete the original output file.

## 14. Architecture and Module Boundaries

### Native app layer

- `AppShell`: lifecycle, window, commands, navigation, and environment state.
- `CreateFeature`: prompt state, capability-aware controls, generation orchestration.
- `ResultsFeature`: comparison grid, preview, export, Finder/share actions.
- `HistoryFeature`: search, filtering, rerun, delete metadata.
- `ProfilesFeature`: profile CRUD and activation.
- `SettingsFeature`: Keychain, output folder, privacy, diagnostics.
- `SecurityLayer`: Keychain, scoped bookmarks, local transport token, redaction.

### Shared generation layer

- Provider/model capability registry.
- Prompt builder.
- Validation rules.
- Generation request/response contract.
- Config/profile/history migration.

The shared contract must be versioned and tested independently of the UI. The native layer should not duplicate provider-specific validation.

## 15. Release Milestones

### Milestone A — Foundation and design system

- Confirm macOS minimum version and SwiftUI architecture.
- Define visual language, spacing, typography, semantic colors, and component states.
- Add versioned generation contract and capability registry.
- Establish security threat model and redaction rules.

### Milestone B — Native shell and secure setup

- Create SwiftUI app shell with sidebar navigation.
- Implement Keychain-backed provider setup.
- Implement native output-folder picker and security-scoped bookmark storage.
- Add diagnostics that never print secrets.

### Milestone C — Generate and compare

- Implement Create screen and provider-aware controls.
- Connect to the shared generation service.
- Show progress, errors, partial results, and cancellation.
- Add result grid, preview, save, Reveal in Finder, and Copy path.

### Milestone D — History and profiles

- Add local history storage and search.
- Add profiles and active defaults.
- Add rerun/edit workflow.
- Migrate compatible existing `~/.snapai` data.

### Milestone E — Hardening and distribution

- App Sandbox review.
- Unit, integration, UI, accessibility, and security tests.
- Signed/notarized developer build.
- Upgrade and migration testing.
- README and privacy documentation update.

## 16. Success Metrics

1. Median time from first launch to first successful saved image: under 30 seconds after key entry.
2. Median time from an existing prompt to a second generation: under 10 seconds of user interaction.
3. At least 90% of first-run users complete setup without support documentation.
4. Zero raw API keys found in app data, logs, history, crash fixtures, or test artifacts.
5. Zero regressions in the existing CLI compatibility suite.
6. Users can identify the active provider/model and exact output directory at every generation.

## 17. Acceptance Criteria for the First Mac MVP

1. A user can install and launch a native macOS app without running a terminal command.
2. A user can securely configure at least one provider using Keychain storage.
3. A user can choose a model, enter a prompt, preview the resolved prompt, and generate one or more square images.
4. Invalid model/options combinations are prevented before the provider request.
5. A user can choose a directory, save output there, and reveal it in Finder.
6. A user can compare results and rerun or edit a previous generation.
7. A user can create and activate a profile.
8. The app supports Light Mode, Dark Mode, keyboard navigation, VoiceOver labels, and reduced motion.
9. History deletion does not delete image files by default.
10. Existing `snapai icon` commands continue to work.
11. No API key or sensitive local data is included in source control, logs, or exported diagnostics.

## 18. Open Decisions

1. Confirm whether the native app should remain SwiftUI-only or use a Tauri shell for faster reuse of the existing Web UI.
2. Decide whether the TypeScript generation service is bundled with a private Node runtime or gradually ported behind a native service boundary.
3. Confirm macOS minimum version and signing/notarization identity.
4. Define the visual direction and app icon for the Mac product.
5. Decide whether thumbnail caching is enabled in the first release.
