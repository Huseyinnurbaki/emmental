APP := build/Emmental.app

# Signs with this identity when it's in your keychain (create it once with
# scripts/create-signing-cert.sh), otherwise ad hoc. A stable identity keeps
# Input Monitoring granted across rebuilds.
SIGN_IDENTITY ?= Emmental Dev
SIGN := $(shell security find-identity -v -p codesigning | grep -q '"$(SIGN_IDENTITY)"' && echo '$(SIGN_IDENTITY)' || echo -)

.PHONY: app run install icon og clean

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
