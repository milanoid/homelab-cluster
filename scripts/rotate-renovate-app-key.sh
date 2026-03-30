#!/usr/bin/env bash
set -euo pipefail

# Rotate the Renovate GitHub App private key in the SOPS-encrypted secret.
# Usage:
#   export RENOVATE_GITHUB_APP_KEY_FILE="/path/to/private-key.pem"
#   ./scripts/rotate-renovate-app-key.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRET_FILE="${REPO_ROOT}/infrastructure/controllers/base/renovate/renovate-container-env.yaml"

# --- Pre-flight checks ---
if [[ -z "${RENOVATE_GITHUB_APP_KEY_FILE:-}" ]]; then
  echo "ERROR: RENOVATE_GITHUB_APP_KEY_FILE environment variable is not set." >&2
  echo "       Set it to the path of your GitHub App .pem private key file." >&2
  exit 1
fi

if [[ ! -f "${RENOVATE_GITHUB_APP_KEY_FILE}" ]]; then
  echo "ERROR: File not found: ${RENOVATE_GITHUB_APP_KEY_FILE}" >&2
  exit 1
fi

if ! command -v sops &>/dev/null; then
  echo "ERROR: 'sops' CLI is not installed. Install it from https://github.com/getsops/sops" >&2
  exit 1
fi

# --- Base64-encode the PEM key (avoids multiline YAML issues) ---
KEY_B64="$(base64 < "${RENOVATE_GITHUB_APP_KEY_FILE}" | tr -d '\n')"

# --- Write plaintext secret to the target file ---
cat > "${SECRET_FILE}" <<EOF
apiVersion: v1
kind: Secret
metadata:
  creationTimestamp: null
  name: renovate-container-env
stringData:
  GITHUB_APP_KEY: "${KEY_B64}"
EOF

# --- Encrypt in place using .sops.yaml rules ---
sops --encrypt --in-place "${SECRET_FILE}"

echo "✅ Secret encrypted and written to ${SECRET_FILE}"
echo "   Verify with: sops ${SECRET_FILE}"
