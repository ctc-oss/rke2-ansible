#!/usr/bin/env bash
set -euo pipefail

# Default RKE2 version to download (override by passing RKE2_VERSION env var)
RKE2_VERSION="${RKE2_VERSION:-v1.36.6+rke2r1}"
ARCH="${ARCH:-amd64}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENCODED_VERSION="${RKE2_VERSION//+/%2B}"
BASE_URL="https://github.com/rancher/rke2/releases/download/${ENCODED_VERSION}"

echo "Downloading RKE2 ${RKE2_VERSION} (${ARCH}) artifacts into ${SCRIPT_DIR}..."

curl -fL -o "${SCRIPT_DIR}/rke2.linux-${ARCH}.tar.gz" \
  "${BASE_URL}/rke2.linux-${ARCH}.tar.gz"

curl -fL -o "${SCRIPT_DIR}/rke2-images.linux-${ARCH}.tar.zst" \
  "${BASE_URL}/rke2-images.linux-${ARCH}.tar.zst"

curl -fsSL "${BASE_URL}/sha256sum-${ARCH}.txt" \
  | grep -E " (rke2\.linux-${ARCH}\.tar\.gz|rke2-images\.linux-${ARCH}\.tar\.zst)$" \
  > "${SCRIPT_DIR}/sha256sum-${ARCH}.txt"

echo "Verifying checksums..."
(
  cd "${SCRIPT_DIR}"
  sha256sum -c "sha256sum-${ARCH}.txt"
)

echo "Done! Artifacts are ready in ${SCRIPT_DIR}."

