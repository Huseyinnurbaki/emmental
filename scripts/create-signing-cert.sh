#!/bin/bash
# Creates a self-signed code signing identity in your login keychain, so macOS
# keeps Emmental's Input Monitoring permission across rebuilds. Ad-hoc signed
# builds look like a different app every time. Run once; `make` picks it up.
#
#   scripts/create-signing-cert.sh            # creates "Emmental Dev"
#   scripts/create-signing-cert.sh "My Cert"  # or any name you like
set -euo pipefail

NAME="${1:-Emmental Dev}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning "$KEYCHAIN" | grep -q "\"$NAME\""; then
  echo "\"$NAME\" already exists in your login keychain. Nothing to do."
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.conf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no

[dn]
CN = $NAME

[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

echo "Creating certificate \"$NAME\"..."
# The system LibreSSL writes a PKCS#12 file that `security import` accepts;
# Homebrew's OpenSSL 3 defaults to an encryption it doesn't.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.conf" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
PASSWORD=$(uuidgen)
/usr/bin/openssl pkcs12 -export -name "$NAME" -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -passout "pass:$PASSWORD" -out "$TMP/identity.p12"

echo "Importing into your login keychain..."
# -T lets codesign use the key without prompting on every build.
security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign >/dev/null

echo "Trusting it for code signing. macOS will ask for your password..."
if ! security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"; then
  echo "Couldn't set trust automatically. In Keychain Access, open \"$NAME\" under"
  echo "login › My Certificates, expand Trust, and set Code Signing to Always Trust."
  exit 1
fi

echo
security find-identity -v -p codesigning | grep "\"$NAME\""
echo "Done. Run 'make install' to build a signed Emmental, then grant Input Monitoring one last time."
