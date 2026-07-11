# SnapAI Product Requirements Document (PRD)

## 1. Product Summary
SnapAI is currently a terminal-first utility that requires users to repeatedly run command-line prompts and options. This creates friction for both first-time and repeat usage. The product will evolve into a local-first experience with clean UX while preserving the existing CLI engine and backward compatibility.

This PRD defines a phased plan to deliver:
1. A local web app as the primary experience (`snapai ui`)
2. A terminal UI as a secondary experience (`snapai studio`)
3. A macOS desktop wrapper in a later phase (Tauri), reusing the same core.

## 2. Goals
1. Reduce time-to-first-icon to under 30 seconds after initial setup.
2. Remove repeated command/flag typing for regular usage.
3. Preserve full compatibility for current CLI users (`snapai icon ...`).
4. Establish one shared core logic layer across CLI, Web UI, and TUI.

## 3. Non-Goals (Phase 1)
1. Cloud-hosted multi-user backend.
2. Team collaboration features.
3. Mobile app clients.
4. Replacing the current generation pipeline.

## 4. User Personas
1. Mobile developer (React Native/Expo): wants icons fast without UI complexity.
2. Solo indie maker: wants visual controls and history.
3. Power terminal user: wants keyboard-driven repeat workflows.

## 5. User Problems
1. Must type a full command with prompt/options each run.
2. Current defaults are limited (API keys only) and not workflow-centric.
3. No visual browsing of results/history.
4. No low-friction iterative generation workflow.

## 6. Proposed Solution
### 6.1 Experience Tiers
1. **Web UI (Primary)**: Local app started with `snapai ui`, opened in browser.
2. **TUI (Secondary)**: Interactive terminal flow with `snapai studio`.
3. **CLI (Existing)**: `snapai icon` remains stable for scripting and advanced users.

### 6.2 Architecture
1. Extract shared core services for generation, validation, config resolution.
2. Add local storage layer for defaults, profiles, and history.
3. Add local API server for web app.
4. Add adapters for CLI, Web UI, and TUI.

## 7. Functional Requirements

### 7.1 Core Platform
1. Shared generation service used by all surfaces.
2. Shared validation rules across all surfaces.
3. Shared config/profile/history persistence.

### 7.2 Configuration
1. Persist API keys (existing behavior).
2. Persist workflow defaults:
   1. model
   2. style
   3. quality
   4. output path
   5. image count (`n`)
3. Support named profiles with active profile selection.
4. Optional remember-last-used toggle.

### 7.3 Web App (`snapai ui`)
1. Start local server from CLI command.
2. Optionally auto-open browser on launch.
3. Screens:
   1. Setup (keys/config readiness)
   2. Create (prompt + controls)
   3. Results (previews + actions)
   4. History (rerun/edit)
   5. Settings (defaults/profiles/keys)

### 7.4 TUI (`snapai studio`)
1. Guided flow for prompt and options.
2. Profile picker.
3. Rerun/edit prompt shortcuts.
4. Results summary and path actions.

### 7.5 Compatibility
1. Existing `snapai icon` flags continue to work.
2. Existing config data is migrated safely.
3. No breaking changes to provider selection and generation constraints.

## 8. UX Requirements

### 8.1 Web UI Main Flow
1. If keys are missing, user lands in Setup screen.
2. User enters prompt and selects options (or uses defaults).
3. User clicks Generate.
4. User views results and can regenerate quickly.
5. User can reuse prior runs from History.

### 8.2 UX Quality Bar
1. Clean two-column layout on Create screen.
2. Strong loading and error states.
3. Provider-aware guardrails for invalid combinations.
4. Keyboard shortcuts for speed (e.g., generate from prompt field).

## 9. API Contract (Local)
1. `GET /api/config` - return effective config.
2. `POST /api/config` - update config/defaults.
3. `GET /api/profiles` - list profiles.
4. `POST /api/profiles` - create profile.
5. `PATCH /api/profiles/:id` - update profile.
6. `DELETE /api/profiles/:id` - delete profile.
7. `POST /api/profiles/:id/use` - set active profile.
8. `POST /api/generate` - generate images.
9. `POST /api/prompt-preview` - return final prompt only.
10. `GET /api/history` - list runs.
11. `POST /api/history/:id/rerun` - rerun saved config.
12. `DELETE /api/history/:id` - remove run record.

## 10. Data Model (Local Files)
1. `config.json`
   1. API keys
   2. defaults
   3. active profile
   4. UX flags
2. `profiles.json`
   1. named profile objects
3. `history.json`
   1. append-only generation records

## 11. Validation Rules
1. Prompt required and max length enforced.
2. Banana normal mode allows only `n=1` and `quality=1k`.
3. OpenAI options must match model constraints.
4. Cost warnings for large batch generation (e.g., `n >= 5`).

## 12. Metrics
1. Time-to-first-icon (first-run path).
2. Average time per repeat generation.
3. Reduction in CLI support issues tied to flags/options.
4. Adoption split across `icon`, `ui`, and `studio`.

## 13. Milestones
1. **Milestone A**: Shared core + local API skeleton + `snapai ui` command.
2. **Milestone B**: Web MVP (Setup/Create/Results).
3. **Milestone C**: Profiles/history in UI.
4. **Milestone D**: `snapai studio` TUI.
5. **Milestone E**: Tauri desktop packaging spike.

## 14. Implementation Plan (Now)
1. Add `ui` command with local server bootstrap.
2. Introduce shared core entrypoint for generation/config validation.
3. Add minimal local API with health/config/generate stubs.
4. Add initial web client scaffold served locally.
5. Keep all existing CLI commands unchanged.

## 15. Risks and Mitigations
1. **Risk**: Logic drift between CLI and UI.
   1. **Mitigation**: Single shared core services.
2. **Risk**: Packaging complexity too early.
   1. **Mitigation**: defer desktop wrapper until web UX stabilizes.
3. **Risk**: Existing users impacted.
   1. **Mitigation**: strict backward compatibility tests.

## 16. Acceptance Criteria (Phase 1)
1. User can run `snapai ui` and load a local web interface.
2. User can complete setup and generate without typing repeated CLI flags.
3. Existing `snapai icon` usage remains functional.
4. Shared validation behavior is consistent across CLI and web entrypoints.
