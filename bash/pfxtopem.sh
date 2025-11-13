#!/usr/bin/env bash
set -euo pipefail

echo "=== PFX to PEM Converter ==="

# Ask for PFX file (with tab completion)
echo
read -e -p "Enter path to .pfx/.p12 file: " INPUT_PFX
if [[ ! -f "$INPUT_PFX" ]]; then
  echo "Error: file not found: $INPUT_PFX"
  exit 1
fi

# Ask for output directory (default: ./output), also with tab completion
read -e -p "Enter output directory [./output]: " OUT_DIR
OUT_DIR="${OUT_DIR:-./output}"
mkdir -p "$OUT_DIR"

# Ask for password (hidden)
read -s -p "Enter PFX password (leave blank if none): " PFX_PASS
echo

# Ask if the key should be encrypted
read -rp "Do you want to encrypt the exported private key? (y/N): " ENCRYPT_ANSWER
ENCRYPT_KEY=0
if [[ "$ENCRYPT_ANSWER" =~ ^[Yy]$ ]]; then
  ENCRYPT_KEY=1
fi

KEY_OUT="$OUT_DIR/key.pem"
CERT_OUT="$OUT_DIR/cert.pem"
CA_OUT="$OUT_DIR/ca.pem"

echo
echo "Converting '$INPUT_PFX'..."
echo "Output directory: $OUT_DIR"
echo

# Export certificate
if [[ -n "$PFX_PASS" ]]; then
  openssl pkcs12 -in "$INPUT_PFX" -clcerts -nokeys -out "$CERT_OUT" -passin "pass:${PFX_PASS}"
else
  openssl pkcs12 -in "$INPUT_PFX" -clcerts -nokeys -out "$CERT_OUT"
fi
echo "✅ Certificate exported to: $CERT_OUT"

# Export CA chain
if [[ -n "$PFX_PASS" ]]; then
  openssl pkcs12 -in "$INPUT_PFX" -cacerts -nokeys -out "$CA_OUT" -passin "pass:${PFX_PASS}" || true
else
  openssl pkcs12 -in "$INPUT_PFX" -cacerts -nokeys -out "$CA_OUT" || true
fi
if [[ ! -s "$CA_OUT" ]]; then
  rm -f "$CA_OUT"
  echo "ℹ️  No CA chain found."
else
  echo "✅ CA chain exported to: $CA_OUT"
fi

# Export private key
if [[ "$ENCRYPT_KEY" -eq 1 ]]; then
  echo "🔐 You will be asked to create a passphrase to encrypt the key."
  if [[ -n "$PFX_PASS" ]]; then
    openssl pkcs12 -in "$INPUT_PFX" -nocerts -out "$KEY_OUT" -passin "pass:${PFX_PASS}" -aes256
  else
    openssl pkcs12 -in "$INPUT_PFX" -nocerts -out "$KEY_OUT" -aes256
  fi
else
  echo "⚠️  Exporting unencrypted private key (insecure; readable by anyone with file access)."
  if [[ -n "$PFX_PASS" ]]; then
    openssl pkcs12 -in "$INPUT_PFX" -nocerts -nodes -out "$KEY_OUT" -passin "pass:${PFX_PASS}"
  else
    openssl pkcs12 -in "$INPUT_PFX" -nocerts -nodes -out "$KEY_OUT"
  fi
fi
chmod 600 "$KEY_OUT"

echo
echo "✅ Done!"
echo "  - Private key: $KEY_OUT"
echo "  - Certificate: $CERT_OUT"
[[ -f "$CA_OUT" ]] && echo "  - CA chain: $CA_OUT"
echo
