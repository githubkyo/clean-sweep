APP_NAME = CleanSweep
BUNDLE_ID = com.cleansweep.app
VERSION = 1.0.0
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
DMG_NAME = $(APP_NAME)-$(VERSION).dmg

.PHONY: build test app dmg clean

# Build release binary
build:
	swift build -c release

# Run tests
test:
	swift test

# Create .app bundle
app: build
	@echo "Creating $(APP_NAME).app bundle..."
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	@cp Info.plist "$(APP_BUNDLE)/Contents/"
	@cp CleanSweep.entitlements "$(APP_BUNDLE)/Contents/"
	@echo "APPL????" > "$(APP_BUNDLE)/Contents/PkgInfo"
	@echo "$(APP_BUNDLE) created"

# Ad-hoc sign (no Apple Developer account needed)
sign: app
	@echo "Signing $(APP_NAME).app (ad-hoc)..."
	@codesign --force --deep --sign - \
		--entitlements CleanSweep.entitlements \
		"$(APP_BUNDLE)"
	@echo "Signed (ad-hoc)"

# Create DMG for distribution
dmg: sign
	@echo "Creating $(DMG_NAME)..."
	@rm -f "$(BUILD_DIR)/$(DMG_NAME)"
	@hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(APP_BUNDLE)" \
		-ov -format UDZO \
		"$(BUILD_DIR)/$(DMG_NAME)"
	@echo "$(BUILD_DIR)/$(DMG_NAME) created"

# Run the app
run: app
	@open "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)/$(APP_NAME).app"
	rm -f "$(BUILD_DIR)/$(DMG_NAME)"
