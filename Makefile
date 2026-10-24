APP := build/Emmental.app

# Signs with this identity when it's in your keychain (create it once with
# scripts/create-signing-cert.sh), otherwise ad hoc. A stable identity keeps
# Input Monitoring granted across rebuilds.
SIGN_IDENTITY ?= Emmental Dev
SIGN := $(shell security find-identity -v -p codesigning | grep -q '"$(SIGN_IDENTITY)"' && echo '$(SIGN_IDENTITY)' || echo -)

.PHONY: app run install release bump icon og clean

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/release/Emmental $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/
	codesign --force --sign "$(SIGN)" $(APP)
	@echo "Signed with: $(if $(filter -,$(SIGN)),ad hoc (run scripts/create-signing-cert.sh for a stable identity),$(SIGN))"

run: app
	open $(APP)

install: app
	rm -rf /Applications/Emmental.app
	cp -R $(APP) /Applications/

# A universal (Intel + Apple silicon) build, signed and zipped for a GitHub
# release: build/release/Emmental.zip. CI passes SIGN, VERSION and BUILD_NUMBER;
# locally they default to the signing identity and Info.plist's values.
RELEASE := build/release
RELEASE_APP := $(RELEASE)/Emmental.app
release:
	swift build -c release --arch arm64 --arch x86_64
	rm -rf $(RELEASE)
	mkdir -p $(RELEASE_APP)/Contents/MacOS $(RELEASE_APP)/Contents/Resources
	cp .build/apple/Products/Release/Emmental $(RELEASE_APP)/Contents/MacOS/
	cp Resources/Info.plist $(RELEASE_APP)/Contents/
	cp Resources/AppIcon.icns $(RELEASE_APP)/Contents/Resources/
	$(if $(VERSION),/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(RELEASE_APP)/Contents/Info.plist)
	$(if $(BUILD_NUMBER),/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" $(RELEASE_APP)/Contents/Info.plist)
	codesign --force --sign "$(SIGN)" $(RELEASE_APP)
	ditto -c -k --keepParent $(RELEASE_APP) $(RELEASE)/Emmental.zip
	@lipo -archs $(RELEASE_APP)/Contents/MacOS/Emmental
	@echo "Built $(RELEASE)/Emmental.zip"

# Sets the version in the app, the website and its structured data at once.
#   make bump VERSION=0.2.0
bump:
	scripts/bump-version.sh "$(VERSION)"

# Regenerates Resources/AppIcon.icns from the wedge geometry in WedgeIcon.swift.
icon:
	mkdir -p build
	swiftc -O scripts/AppIcon/main.swift Sources/Emmental/WedgeIcon.swift -o build/AppIcon
	rm -rf build/AppIcon.iconset
	build/AppIcon build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

# Re-renders landing/og.png, the link preview card, from scripts/og-image.html.
og:
	"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu \
		--hide-scrollbars --force-device-scale-factor=1 --window-size=1200,630 \
		--screenshot="$(CURDIR)/landing/og.png" "file://$(CURDIR)/scripts/og-image.html"

clean:
	rm -rf .build build
