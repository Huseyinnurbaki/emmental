APP := build/Emmental.app

# Signs with this identity when it's in your keychain (create it once with
# scripts/create-signing-cert.sh), otherwise ad hoc. A stable identity keeps
# Input Monitoring granted across rebuilds.
SIGN_IDENTITY ?= Emmental Dev
SIGN := $(shell security find-identity -v -p codesigning | grep -q '"$(SIGN_IDENTITY)"' && echo '$(SIGN_IDENTITY)' || echo -)

.PHONY: app run install clean

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp .build/release/Emmental $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --sign "$(SIGN)" $(APP)
	@echo "Signed with: $(if $(filter -,$(SIGN)),ad hoc (run scripts/create-signing-cert.sh for a stable identity),$(SIGN))"

run: app
	open $(APP)

install: app
	rm -rf /Applications/Emmental.app
	cp -R $(APP) /Applications/

clean:
	rm -rf .build build
