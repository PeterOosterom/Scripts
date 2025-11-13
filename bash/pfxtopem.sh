#!/usr/bin/env bash
set -euo pipefail

echo "=== PFX to PEM Converter ==="

# --- Ask for input file (tab completion) ---
echo
read -e -p "Enter path to .pfx/.p12 file: " INPUT_PFX
if [[ ! -f "$INPUT_PFX" ]]; then
  echo "❌ Error: file not found: $INPUT_PFX"
  exit 1
fi

# --- Default name based on PFX file ---
DEFAULT_NAME="$(basename "$INPUT_PFX")"
DEFAULT_NAME="${DEFAULT_NAME%.*}"

# --- Ask for custom name (optional) ---
read -p "Enter name for output folder and files [$DEFAULT_NAME]: " BASE_NAME
BASE_NAME="${BASE_NAME:-$DEFAULT_NAME}"

# --- Output folder structure ---
OUT_DIR="./output/${BASE_NAME}"
mkdir -p "$OUT_DIR"

KEY_OUT="$OUT_DIR/${BASE_NAME}.key.pem"
CERT_OUT="$OUT_DIR/${BASE_NAME}.crt.pem"
CA_OUT="$OUT_DIR/${BASE_NAME}.ca.pem"

# --- Ask for password (hidden) ---
read -s -p "Enter PFX password (leave blank if none): " PFX_PASS
echo

# --- Ask if key should be encrypted ---
read -rp "Do you want to encrypt the exported private key? (y/N): " ENCRYPT_ANSWER
ENCRYPT_KEY=0
if [[ "$ENCRYPT_ANSWER" =~ ^[Yy]$ ]]; then
  ENCRYPT_KEY=1
fi

echo
echo "Converting '$INPUT_PFX'..."
echo "Output folder: $OUT_DIR"
echo "Base name:     $BASE_NAME"
echo

# --- Export certificate ---
if [[ -n "$PFX_PASS" ]]; then
  openssl pkcs12 -in "$INPUT_PFX" -clcerts -nokeys -out "$CERT_OUT" -passin "pass:${PFX_PASS}"
else
  openssl pkcs12 -in "$INPUT_PFX" -clcerts -nokeys -out "$CERT_OUT"
fi
echo "✅ Certificate exported: $CERT_OUT"

# --- Export CA chain (if present) ---
if [[ -n "$PFX_PASS" ]]; then
  openssl pkcs12 -in "$INPUT_PFX" -cacerts -nokeys -out "$CA_OUT" -passin "pass:${PFX_PASS}" || true
else
  openssl pkcs12 -in "$INPUT_PFX" -cacerts -nokeys -out "$CA_OUT" || true
fi
if [[ ! -s "$CA_OUT" ]]; then
  rm -f "$CA_OUT"
  echo "ℹ️  No CA chain found."
else
  echo "✅ CA chain exported: $CA_OUT"
fi

# --- Export private key ---
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

# --- Extract CN from certificate for summary ---
CN=$(openssl x509 -in "$CERT_OUT" -noout -subject 2>/dev/null | sed -n 's/.*CN=//p' | head -n 1 || true)
CN=${CN:-"(unknown)"}

echo
echo "========================================="
echo "✅ Conversion complete!"
echo "📁 Output directory: $OUT_DIR"
echo "🔑 Private key:      $(basename "$KEY_OUT")"
echo "📜 Certificate:      $(basename "$CERT_OUT")"
[[ -f "$CA_OUT" ]] && echo "🧾 CA chain:          $(basename "$CA_OUT")"
echo "📛 Common Name (CN): $CN"
echo "========================================="
echo
