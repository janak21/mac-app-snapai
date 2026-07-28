# SnapAI macOS app

This directory contains the first native SwiftUI macOS implementation. The app bundle now includes the compiled TypeScript core, production dependencies, and a Node runtime for local standalone development.

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

## Local transport decision

The native shell currently uses authenticated loopback HTTP rather than a Unix domain socket. This keeps the bundled Node runtime compatible with the app sandbox and the existing browser/dev surface while still binding only to `127.0.0.1` with a random per-launch bearer token. File previews are limited to paths recorded in local generation history; arbitrary filesystem paths are not served.
