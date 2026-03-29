#!/usr/bin/env bash
set -euo pipefail

# Rotate the Renovate GitHub token in the SOPS-encrypted secret.
# Usage:
#   export RENOVATE_TOKEN="ghp_..."
#   ./scripts/rotate-renovate-token.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRET_FILE="${REPO_ROOT}/infrastructure/controllers/base/renovate/renovate-container-env.yaml"

# --- Pre-flight checks ---
if [[ -z "${RENOVATE_TOKEN:-}" ]]; then
  echo "ERROR: RENOVATE_TOKEN environment variable is not set." >&2
  exit 1
fi

if ! command -v sops &>/dev/null; then
  echo "ERROR: 'sops' CLI is not installed. Install it from https://github.com/getsops/sops" >&2
  exit 1
fi

# --- Build plaintext secret in a temp file ---
TMPFILE="$(mktemp).yaml"
trap 'rm -f "$TMPFILE"' EXIT

cat > "$TMPFILE" <<EOF
apiVersion: v1
kind: Secret
metadata:
  creationTimestamp: null
  name: renovate-container-env
stringData:
  RENOVATE_TOKEN: "${RENOVATE_TOKEN}"
EOF

# --- Encrypt using the age public key from .sops.yaml ---
AGE_KEY="age1jnfhet7cj900tg9f0dwgqktjwux4km4hen8gnevpujm5260sayesujm92y"

sops --encrypt \
  --age "$AGE_KEY" \
  --encrypted-regex '^(data|stringData)$' \
  --input-type yaml --output-type yaml \
  "$TMPFILE" > "${SECRET_FILE}"

echo "✅ Secret encrypted and written to ${SECRET_FILE}"
echo "   Verify with: sops ${SECRET_FILE}"
