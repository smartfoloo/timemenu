#!/usr/bin/env bash
#
# Creates a one-time self-signed *code-signing* identity in your login Keychain
# so build-app.sh can produce a STABLE signature. A stable signature means the
# macOS Keychain "Always Allow" for the ODPT key sticks across rebuilds (ad-hoc
# signatures change every build, so they re-prompt).
#
#   Scripts/make-signing-cert.sh
#   export CODESIGN_IDENTITY="Timemenu Self-Signed"
#   Scripts/build-app.sh
#
# Note: self-signed (like ad-hoc) is NOT trusted by Gatekeeper — downloaders
# still clear quarantine once. This only stabilizes the signing identity.
#
# If this CLI path is finicky on your setup, the GUI equivalent is reliable:
#   Keychain Access → Certificate Assistant → Create a Certificate…
#   Name: "Timemenu Self-Signed", Identity Type: Self Signed Root,
#   Certificate Type: Code Signing → Create.
set -euo pipefail

CN="Timemenu Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CN"; then
  echo "✓ code-signing identity '$CN' already exists"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ generating self-signed code-signing certificate"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
  -subj "/CN=$CN" \
  -addext "basicConstraints=critical,CA:FALSE" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"

openssl pkcs12 -export -out "$TMP/cert.p12" -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -passout pass:

echo "→ importing into login keychain (allows codesign to use it without prompting)"
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "" -T /usr/bin/codesign

echo
echo "✓ created '$CN'."
echo "  Then:  export CODESIGN_IDENTITY=\"$CN\"  &&  Scripts/build-app.sh"
echo "  (If codesign later says the identity isn't found/trusted, use the"
echo "   Keychain Access GUI method described at the top of this script.)"
