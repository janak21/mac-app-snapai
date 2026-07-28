#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="$SCRIPT_DIR/SnapAI.app"

swift build --package-path "$SCRIPT_DIR" --configuration release
BIN_PATH="$(swift build --package-path "$SCRIPT_DIR" --configuration release --show-bin-path)"
EXECUTABLE="$BIN_PATH/SnapAIApp"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "Release executable was not produced at $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

CORE_DIR="$APP_DIR/Contents/Resources/Core"
mkdir -p "$CORE_DIR"
cp -R "$PROJECT_ROOT/dist" "$PROJECT_ROOT/package.json" "$CORE_DIR/"
if [[ -d "$PROJECT_ROOT/node_modules" ]]; then
  cp -R "$PROJECT_ROOT/node_modules" "$CORE_DIR/"
fi

NODE_SOURCE="${SNAPAI_NODE_PATH:-$(command -v node || true)}"
if [[ -z "$NODE_SOURCE" || ! -x "$NODE_SOURCE" ]]; then
  echo "Node.js was not found. Set SNAPAI_NODE_PATH before building the app." >&2
  exit 1
fi
cp -L "$NODE_SOURCE" "$CORE_DIR/node"

cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/SnapAIApp"
cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$SCRIPT_DIR/SnapAIApp.entitlements" "$APP_DIR/Contents/Resources/SnapAIApp.entitlements"

if [[ "${SNAPAI_ENABLE_SANDBOX:-0}" == "1" ]]; then
	cp "$SCRIPT_DIR/SnapAINode.entitlements" "$APP_DIR/Contents/Resources/SnapAINode.entitlements"
	codesign \
		--force \
		--sign - \
		--entitlements "$SCRIPT_DIR/SnapAINode.entitlements" \
		"$CORE_DIR/node"
  codesign \
    --force \
    --deep \
    --sign - \
    --entitlements "$SCRIPT_DIR/SnapAIApp.entitlements" \
    "$APP_DIR"
  echo "Built and ad-hoc signed $APP_DIR with App Sandbox enabled"
else
  codesign --force --deep --sign - "$APP_DIR"
  echo "Built and ad-hoc signed $APP_DIR for source-checkout development"
fi

echo "Set SNAPAI_ENABLE_SANDBOX=1 only when validating the sandboxed release path."
