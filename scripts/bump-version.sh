#!/bin/bash
# Sets the version everywhere it's written, so the app, the website and the
# release all show the same number:
#
#   make bump VERSION=0.2.0
#
# Updates Resources/Info.plist (the app's version), landing/version.json (what
# Check for Updates will read) and landing/index.html (the page and its
# structured data). The release workflow refuses a tag that doesn't match
# Info.plist, so this runs before tagging.
set -euo pipefail
cd "$(dirname "$0")/.."

NEW="${1:-}"
if [[ ! "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: make bump VERSION=x.y.z   (for example VERSION=0.2.0)"
  exit 1
fi

OLD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
if [ "$NEW" = "$OLD" ]; then
  echo "Already at $NEW. Nothing to change."
  exit 0
fi

# Edit just that line; PlistBuddy would also reformat the rest of the file.
perl -0pi -e "s|(<key>CFBundleShortVersionString</key>\s*<string>)[^<]+|\${1}$NEW|" Resources/Info.plist
perl -pi -e "s/\"version\": \"[0-9.]+\"/\"version\": \"$NEW\"/; s|/releases/download/v[0-9.]+/|/releases/download/v$NEW/|" landing/version.json
# The structured data, and every "Version x.y.z" on the page, including the
# Settings window's "Version x.y.z (n)".
perl -pi -e "s/\"softwareVersion\": \"[0-9.]+\"/\"softwareVersion\": \"$NEW\"/; s/Version [0-9]+\.[0-9]+\.[0-9]+( \([0-9]+\))?/Version $NEW/g" landing/index.html

echo "Version $OLD → $NEW in Resources/Info.plist, landing/version.json and landing/index.html"
echo
echo "To release it:"
echo "  git commit -am \"Release $NEW\" && git push"
echo "  git tag -a v$NEW -m \"Emmental $NEW\" && git push origin v$NEW"
