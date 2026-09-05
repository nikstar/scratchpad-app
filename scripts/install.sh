#!/bin/bash
# Build and install locally without requiring an Apple signing certificate.
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$project_dir/build/Install"
applications_dir="$HOME/Applications"
destination="$applications_dir/Scratchpad.app"
bundle_id="me.nikstar.Scratchpad"

if [[ -e "$destination" || -L "$destination" ]]; then
    installed_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$destination/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -L "$destination" || "$installed_id" != "$bundle_id" ]]; then
        echo "Refusing to replace an unrelated file or symlink at $destination" >&2
        exit 1
    fi
fi

echo "Building Scratchpad (Release)…"
xcodebuild -quiet \
    -project "$project_dir/Scratchpad.xcodeproj" \
    -scheme Scratchpad \
    -configuration Release \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$build_dir" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    build

mkdir -p "$applications_dir"
staging_dir="$(mktemp -d "$applications_dir/.Scratchpad-install.XXXXXX")"

cleanup() {
    local result=$?
    # If replacing the bundle fails, put the previous installation back.
    if [[ -d "$staging_dir/Previous.app" && ! -e "$destination" ]]; then
        if ! mv "$staging_dir/Previous.app" "$destination"; then
            echo "Previous installation preserved at $staging_dir/Previous.app" >&2
            return 1
        fi
    fi
    rm -rf "$staging_dir"
    return "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

ditto "$build_dir/Build/Products/Release/Scratchpad.app" "$staging_dir/Scratchpad.app"
codesign --verify --deep --strict "$staging_dir/Scratchpad.app"
# Keep the storage container identical to development builds. Disabling Xcode's
# base entitlements must never silently turn this into an unsandboxed app.
codesign -d --entitlements - --xml "$staging_dir/Scratchpad.app" > "$staging_dir/entitlements.plist" 2>/dev/null
sandbox_enabled="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$staging_dir/entitlements.plist" 2>/dev/null || true)"
if [[ "$sandbox_enabled" != true ]]; then
    echo "The release build is missing its sandbox entitlement. Installation stopped to preserve the notes location." >&2
    exit 1
fi

echo "Finishing any running Scratchpad session…"
# Request an ordinary quit so AppDelegate can flush notes. A cancelled or failed
# quit aborts installation; never force-kill an app that might have unwritten text.
xcrun swift - "$bundle_id" <<'SWIFT'
import AppKit
import Foundation
import Darwin

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let applications = NSRunningApplication.runningApplications(withBundleIdentifier: CommandLine.arguments[1])
for application in applications where !application.isTerminated {
    guard application.terminate() else {
        fail("Scratchpad couldn't quit. Quit it normally and run the installer again.")
    }
}
let deadline = Date().addingTimeInterval(20)
while applications.contains(where: { !$0.isTerminated }) {
    guard Date() < deadline else {
        fail("Scratchpad is still running. Resolve any backup error, quit normally, and run the installer again.")
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
SWIFT

if [[ -e "$destination" ]]; then
    mv "$destination" "$staging_dir/Previous.app"
fi
mv "$staging_dir/Scratchpad.app" "$destination"
echo "Installed $destination"
