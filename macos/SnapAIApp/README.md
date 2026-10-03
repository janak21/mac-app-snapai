# SnapAI macOS app

This directory contains the native SwiftUI macOS app. The app bundle includes the compiled TypeScript core, production dependencies, and a Node runtime so it can run without a separate Node.js installation.

## Build and test

From the repository root:

```bash
pnpm run build
swift build --package-path macos/SnapAIApp
swift test --package-path macos/SnapAIApp
./macos/SnapAIApp/build-app.sh
```

The default developer bundle is ad-hoc signed without App Sandbox so it can launch the checkout’s Node runtime. To validate the release entitlement separately:

```bash
SNAPAI_ENABLE_SANDBOX=1 ./macos/SnapAIApp/build-app.sh
```

The sandboxed build launches the embedded core. Provider generation should still be validated with a user-selected output folder before distribution.

## Run the native app

```bash
open -n ./macos/SnapAIApp/SnapAI.app
```

The app prefers the embedded core. If the bundle is being used from an older build, run the executable directly against the checkout for diagnostics:

```bash
SNAPAI_CORE_ROOT="$PWD" \
  ./macos/SnapAIApp/SnapAI.app/Contents/MacOS/SnapAIApp
```

Alternatively, run the Swift executable directly from the package directory:

```bash
cd macos/SnapAIApp
swift run
```

On first launch, SnapAI guides you through provider Keychain setup, output-folder selection, and local-core readiness before opening the Create workspace. Existing state files remain compatible; onboarding is recorded without storing provider credentials.

The app stores provider credentials in macOS Keychain and local profiles/history under `~/Library/Application Support/SnapAI`. The bundle includes the local core runtime, so the normal launch path does not require the source checkout or a separately installed Node.js runtime.

## Create workspace

The Create workspace has one primary **Generate** action in the prompt composer. Select it after configuring the prompt and supported model options. During a request, the button shows an active generation state; the request status card provides **Cancel** and **Retry** when appropriate.

Generated files go to the selected output folder. Set the default folder in **Settings**, or choose a different folder for an individual run.

## Local transport decision

The native shell currently uses authenticated loopback HTTP rather than a Unix domain socket. This keeps the bundled Node runtime compatible with the app sandbox and the existing browser/dev surface while still binding only to `127.0.0.1` with a random per-launch bearer token. File previews are limited to paths recorded in local generation history; arbitrary filesystem paths are not served.

## Distribute as a DMG

`make-dmg.sh` builds a notarized, drag-to-install `SnapAI-<version>.dmg` for Apple Silicon (macOS 14+) distribution.

### One-time setup

You need a paid Apple Developer membership and a **Developer ID Application** certificate (created in your developer account under Certificates, IDs & Profiles -> Certificates -> "+" -> "Developer ID Application"). This is distinct from the "Apple Development" certificate used for local builds and is required for direct distribution outside the App Store.

Confirm it is installed:

```bash
security find-identity -v -p codesigning
# look for: "Developer ID Application: Your Name (TEAMID)"
```

Store notarization credentials once per machine. This uses an App Store Connect API key, not your Apple ID password. Create the key at App Store Connect -> Users and Access -> Integrations -> Team Keys with **App Manager** access, download the `.p8`, and copy the Key ID and Issuer ID:

```bash
cd macos/SnapAIApp
SNAPAI_NOTARY_KEY_ID=<Key ID> \
SNAPAI_NOTARY_ISSUER=<Issuer UUID> \
SNAPAI_NOTARY_KEY_PATH=./AuthKey_<KeyID>.p8 \
  ./setup-notary.sh
```

This saves a keychain profile named `snapai-notary` (override with `SNAPAI_NOTARY_PROFILE`).

### Build the DMG

```bash
cd macos/SnapAIApp
SNAPAI_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./make-dmg.sh
```

The script builds and Developer-ID signs `SnapAI.app` (hardened runtime + App Sandbox entitlements), notarizes and staples the app, assembles a `SnapAI-<version>.dmg` with an Applications symlink, notarizes and staples the DMG, and runs a Gatekeeper assessment. The final file is at `macos/SnapAIApp/SnapAI-<version>.dmg` and is ready to upload to GitHub Releases or any download host.

### Notes

- Apple Silicon only: the Swift binary and embedded Node runtime are `arm64`. Intel Macs cannot run this build.
- Validate the sandboxed release path with a user-selected output folder before publishing; `SNAPAI_ENABLE_SANDBOX=1` is set automatically by `make-dmg.sh`.
- If the DMG notarization step is unwanted (e.g. you only notarize the app), set `SNAPAI_SKIP_DMG_NOTARY=1`.
