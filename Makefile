# Define a directory for dependencies in the user's home folder
DEPS_DIR := $(HOME)/VoiceInk-Dependencies
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework

.PHONY: all clean whisper setup build check healthcheck help dev run local release archive export dmg notarize staple verify

# Default target
all: check build

# Development workflow
dev: build run

# Prerequisites
check:
	@echo "Checking prerequisites..."
	@command -v git >/dev/null 2>&1 || { echo "git is not installed"; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is not installed (need Xcode)"; exit 1; }
	@command -v swift >/dev/null 2>&1 || { echo "swift is not installed"; exit 1; }
	@echo "Prerequisites OK"

healthcheck: check

# Build process
whisper:
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(FRAMEWORK_PATH)" ]; then \
		echo "Building whisper.xcframework in $(DEPS_DIR)..."; \
		if [ ! -d "$(WHISPER_CPP_DIR)" ]; then \
			git clone https://github.com/ggerganov/whisper.cpp.git $(WHISPER_CPP_DIR); \
		else \
			(cd $(WHISPER_CPP_DIR) && git pull); \
		fi; \
		cd $(WHISPER_CPP_DIR) && ./build-xcframework.sh; \
	else \
		echo "whisper.xcframework already built in $(DEPS_DIR), skipping build"; \
	fi

setup: whisper
	@echo "Whisper framework is ready at $(FRAMEWORK_PATH)"
	@echo "Please ensure your Xcode project references the framework from this new location."

build: setup
	xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug CODE_SIGN_IDENTITY="" build

# Run application
run:
	@echo "Looking for VoiceInk.app..."
	@APP_PATH=$$(find "$$HOME/Library/Developer/Xcode/DerivedData" -name "VoiceInk.app" -type d | head -1) && \
	if [ -n "$$APP_PATH" ]; then \
		echo "Found app at: $$APP_PATH"; \
		open "$$APP_PATH"; \
	else \
		echo "VoiceInk.app not found. Please run 'make build' first."; \
		exit 1; \
	fi

# Local build (for personal use on your Mac)
local: setup
	@echo "Building for local use..."
	xcodebuild -project VoiceInk.xcodeproj \
		-scheme VoiceInk \
		-configuration Release \
		-derivedDataPath build \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM=3WPQAPHJFS \
		-allowProvisioningUpdates \
		build
	@echo ""
	@echo "Build complete! App located at:"
	@echo "  build/Build/Products/Release/VoiceInk.app"
	@echo ""
	@echo "To install, run:"
	@echo "  cp -R build/Build/Products/Release/VoiceInk.app /Applications/"

# Release build variables
ARCHIVE_PATH := $(HOME)/Desktop/VoiceInk.xcarchive
EXPORT_PATH := $(HOME)/Desktop/VoiceInk-Export
DMG_PATH := $(HOME)/Desktop/VoiceInk.dmg
APPLE_ID := natesena@icloud.com
TEAM_ID := 3WPQAPHJFS

# Release workflow: make release (runs archive -> export -> dmg -> notarize -> staple -> verify)
release: archive export dmg notarize staple verify
	@echo "Release build complete! DMG ready at $(DMG_PATH)"

# Build release archive
archive: setup
	@echo "Building release archive..."
	xcodebuild -project VoiceInk.xcodeproj \
		-scheme VoiceInk \
		-configuration Release \
		-archivePath $(ARCHIVE_PATH) \
		archive
	@echo "Archive created at $(ARCHIVE_PATH)"

# Export with Developer ID signing
export:
	@echo "Exporting with Developer ID signing..."
	@if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then \
		echo "ERROR: No Developer ID Application certificate found."; \
		echo "Please create one at https://developer.apple.com/account/resources/certificates/list"; \
		exit 1; \
	fi
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist ExportOptions.plist
	@echo "App exported to $(EXPORT_PATH)"

# Create DMG for distribution
dmg:
	@echo "Creating DMG..."
	@rm -f $(DMG_PATH)
	hdiutil create -volname "VoiceInk" \
		-srcfolder $(EXPORT_PATH)/VoiceInk.app \
		-ov -format UDZO $(DMG_PATH)
	@echo "DMG created at $(DMG_PATH)"

# Notarize the DMG (requires APP_PASSWORD environment variable)
notarize:
	@echo "Notarizing DMG..."
	@if [ -z "$$APP_PASSWORD" ]; then \
		echo "ERROR: APP_PASSWORD environment variable not set."; \
		echo "Create an app-specific password at https://appleid.apple.com"; \
		echo "Then run: APP_PASSWORD=xxxx-xxxx-xxxx-xxxx make notarize"; \
		exit 1; \
	fi
	xcrun notarytool submit $(DMG_PATH) \
		--apple-id "$(APPLE_ID)" \
		--password "$$APP_PASSWORD" \
		--team-id "$(TEAM_ID)" \
		--wait
	@echo "Notarization complete!"

# Staple the notarization ticket to the DMG
staple:
	@echo "Stapling notarization ticket..."
	xcrun stapler staple $(DMG_PATH)
	@echo "Stapling complete!"

# Verify the signed and notarized DMG
verify:
	@echo "Verifying DMG..."
	spctl -a -t open --context context:primary-signature -v $(DMG_PATH)
	@echo "Verification complete!"

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DEPS_DIR)
	@echo "Clean complete"

# Help
help:
	@echo "Available targets:"
	@echo ""
	@echo "  Development:"
	@echo "    check/healthcheck  Check if required CLI tools are installed"
	@echo "    whisper            Clone and build whisper.cpp XCFramework"
	@echo "    setup              Copy whisper XCFramework to VoiceInk project"
	@echo "    build              Build the VoiceInk Xcode project (Debug)"
	@echo "    run                Launch the built VoiceInk app"
	@echo "    dev                Build and run the app (for development)"
	@echo "    local              Build signed Release app for local use (free Apple ID)"
	@echo "    all                Run full build process (default)"
	@echo ""
	@echo "  Release (requires Developer ID certificate):"
	@echo "    release            Full release workflow (archive->export->dmg->notarize->staple->verify)"
	@echo "    archive            Build release archive"
	@echo "    export             Export with Developer ID signing"
	@echo "    dmg                Create DMG for distribution"
	@echo "    notarize           Notarize the DMG (requires APP_PASSWORD env var)"
	@echo "    staple             Staple notarization ticket to DMG"
	@echo "    verify             Verify the signed and notarized DMG"
	@echo ""
	@echo "  Other:"
	@echo "    clean              Remove build artifacts"
	@echo "    help               Show this help message"
	@echo ""
	@echo "  Release workflow example:"
	@echo "    APP_PASSWORD=xxxx-xxxx-xxxx-xxxx make release"