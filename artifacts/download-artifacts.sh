#!/usr/bin/env bash
set -euo pipefail

# Default RKE2 version to download (override by passing RKE2_VERSION env var)
RKE2_VERSION="${RKE2_VERSION:-v1.36.2+rke2r1}"
ARCH="${ARCH:-amd64}"
DOWNLOAD_SELINUX_RPM="${DOWNLOAD_SELINUX_RPM:-true}"
DOWNLOAD_RKE2_RPMS="${DOWNLOAD_RKE2_RPMS:-true}"
DOWNLOAD_NVIDIA_RPMS="${DOWNLOAD_NVIDIA_RPMS:-true}"
RKE2_CHANNEL="${RKE2_CHANNEL:-stable}"
SELINUX_RPM_RELEASEVER="${SELINUX_RPM_RELEASEVER:-8}"
NVIDIA_DRIVER_STREAM="${NVIDIA_DRIVER_STREAM:-580}"
NVIDIA_RPM_RELEASEVER="${NVIDIA_RPM_RELEASEVER:-${SELINUX_RPM_RELEASEVER}}"
NVIDIA_DEPENDENCY_REPOS="${NVIDIA_DEPENDENCY_REPOS:-rhel*-base*,rhel*-appstream*,rhel*-codereadybuilder*}"
NVIDIA_DEVICE_PLUGIN_IMAGE="${NVIDIA_DEVICE_PLUGIN_IMAGE:-nvcr.io/nvidia/k8s-device-plugin:v0.20.2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENCODED_VERSION="${RKE2_VERSION//+/%2B}"
BASE_URL="https://github.com/rancher/rke2/releases/download/${ENCODED_VERSION}"
SELINUX_REPO_BASE_URL="https://rpm.rancher.io/rke2/${RKE2_CHANNEL}/common/centos/${SELINUX_RPM_RELEASEVER}/noarch"
RKE2_VERSION_MAJMIN="$(echo "${RKE2_VERSION}" | sed -E 's/^v?([0-9]+\.[0-9]+).*/\1/')"
RKE2_RPM_VERSION="${RKE2_VERSION#v}"
RKE2_RPM_VERSION="${RKE2_RPM_VERSION//+/\~}"
RPM_ARCH="${ARCH}"
if [[ "${ARCH}" == "amd64" ]]; then
  RPM_ARCH="x86_64"
elif [[ "${ARCH}" == "arm64" ]]; then
  RPM_ARCH="aarch64"
fi
RKE2_VERSIONED_REPO_BASE_URL="https://rpm.rancher.io/rke2/${RKE2_CHANNEL}/${RKE2_VERSION_MAJMIN}/centos/${SELINUX_RPM_RELEASEVER}/${RPM_ARCH}"
RPM_OUTPUT_DIR="${SCRIPT_DIR}/rpms"
NVIDIA_RPM_OUTPUT_DIR="${RPM_OUTPUT_DIR}/nvidia"
NVIDIA_CUDA_REPO_BASE_URL="https://developer.download.nvidia.com/compute/cuda/repos/rhel${NVIDIA_RPM_RELEASEVER}/${RPM_ARCH}"
NVIDIA_CONTAINER_REPO_BASE_URL="https://nvidia.github.io/libnvidia-container/stable/rpm/${RPM_ARCH}"
NVIDIA_DEVICE_PLUGIN_ARCHIVE="${SCRIPT_DIR}/nvidia-device-plugin.linux-${ARCH}.tar"

get_primary_path() {
  local repo_url="$1"
  curl -fsSL "${repo_url}/repodata/repomd.xml" \
    | sed -n '/<data type="primary">/,/<\/data>/s/.*location href="\([^"]*\)".*/\1/p' \
    | head -n 1
}

get_rpm_href() {
  local repo_url="$1"
  local package_name="$2"
  local package_version="$3"
  local primary_path
  primary_path="$(get_primary_path "${repo_url}")"
  if [[ -z "${primary_path}" ]]; then
    return 1
  fi
  curl -fsSL "${repo_url}/${primary_path}" \
    | gzip -dc \
    | awk -v name="${package_name}" -v version="${package_version}" '
      BEGIN { RS="</package>" }
      index($0, "<name>" name "</name>") && index($0, "ver=\"" version "\"") {
        if (match($0, /location href="([^"]+)"/, m)) {
          print m[1]
        }
      }
    ' \
    | head -n 1
}

require_dnf() {
  if ! command -v dnf >/dev/null 2>&1; then
    echo "Downloading NVIDIA RPMs requires dnf on the artifact download host." >&2
    exit 1
  fi
}

download_device_plugin_image() {
  if command -v skopeo >/dev/null 2>&1; then
    skopeo copy \
      --override-os linux \
      --override-arch "${ARCH}" \
      "docker://${NVIDIA_DEVICE_PLUGIN_IMAGE}" \
      "docker-archive:${NVIDIA_DEVICE_PLUGIN_ARCHIVE}:${NVIDIA_DEVICE_PLUGIN_IMAGE}"
  elif command -v ctr >/dev/null 2>&1; then
    ctr --namespace rke2-artifacts content fetch \
      --all-platforms \
      "${NVIDIA_DEVICE_PLUGIN_IMAGE}" \
      "${NVIDIA_DEVICE_PLUGIN_IMAGE}"
    ctr --namespace rke2-artifacts images export \
      --all-platforms \
      "${NVIDIA_DEVICE_PLUGIN_ARCHIVE}" \
      "${NVIDIA_DEVICE_PLUGIN_IMAGE}"
  else
    echo "Downloading the NVIDIA device plugin requires skopeo or ctr." >&2
    exit 1
  fi
}

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

if [[ "${DOWNLOAD_SELINUX_RPM}" == "true" ]]; then
  mkdir -p "${RPM_OUTPUT_DIR}"
  echo "Resolving latest rke2-selinux RPM from ${SELINUX_REPO_BASE_URL}..."
  primary_path="$(get_primary_path "${SELINUX_REPO_BASE_URL}")"
  if [[ -z "${primary_path}" ]]; then
    echo "Failed to discover primary metadata path for rke2-selinux RPM." >&2
    exit 1
  fi

  selinux_rpm_name="$(
    curl -fsSL "${SELINUX_REPO_BASE_URL}/${primary_path}" \
      | gzip -dc \
      | awk 'BEGIN{RS="</package>"} /<name>rke2-selinux<\/name>/ { if (match($0,/location href="([^"]+)"/,m)) print m[1] }' \
      | sort -V \
      | tail -n 1
  )"
  if [[ -z "${selinux_rpm_name}" ]]; then
    echo "Failed to discover rke2-selinux RPM name in repository metadata." >&2
    exit 1
  fi

  curl -fL -o "${RPM_OUTPUT_DIR}/${selinux_rpm_name}" \
    "${SELINUX_REPO_BASE_URL}/${selinux_rpm_name}"
fi

if [[ "${DOWNLOAD_RKE2_RPMS}" == "true" ]]; then
  mkdir -p "${RPM_OUTPUT_DIR}"
  curl -fL -o "${RPM_OUTPUT_DIR}/rancher-rke2-public.key" \
    "https://rpm.rancher.io/public.key"
  for pkg in rke2-server rke2-agent rke2-common; do
    rpm_href="$(get_rpm_href "${RKE2_VERSIONED_REPO_BASE_URL}" "${pkg}" "${RKE2_RPM_VERSION}")"
    if [[ -z "${rpm_href:-}" ]]; then
      echo "Failed to find ${pkg} RPM for ${RKE2_VERSION} in ${RKE2_VERSIONED_REPO_BASE_URL}" >&2
      exit 1
    fi
    curl -fL -o "${RPM_OUTPUT_DIR}/$(basename "${rpm_href}")" \
      "${RKE2_VERSIONED_REPO_BASE_URL}/${rpm_href}"
  done
fi

if [[ "${DOWNLOAD_NVIDIA_RPMS}" == "true" ]]; then
  require_dnf

  mkdir -p "${NVIDIA_RPM_OUTPUT_DIR}"
  curl -fL -o "${NVIDIA_RPM_OUTPUT_DIR}/nvidia-cuda-public.key" \
    "${NVIDIA_CUDA_REPO_BASE_URL}/D42D0685.pub"
  curl -fL -o "${NVIDIA_RPM_OUTPUT_DIR}/nvidia-container-toolkit-public.key" \
    "https://nvidia.github.io/libnvidia-container/gpgkey"

  nvidia_download_root="$(mktemp -d)"
  trap 'rm -rf "${nvidia_download_root}"' EXIT

  dnf \
    --assumeyes \
    --installroot "${nvidia_download_root}/installroot" \
    --releasever "${NVIDIA_RPM_RELEASEVER}" \
    --setopt=module_platform_id=platform:el"${NVIDIA_RPM_RELEASEVER}" \
    --setopt=install_weak_deps=False \
    --setopt=best=True \
    --disablerepo='*' \
    --enablerepo="${NVIDIA_DEPENDENCY_REPOS}" \
    --repofrompath=rke2-artifacts-nvidia-cuda,"${NVIDIA_CUDA_REPO_BASE_URL}" \
    module enable "nvidia-driver:${NVIDIA_DRIVER_STREAM}"

  dnf \
    --assumeyes \
    --installroot "${nvidia_download_root}/installroot" \
    --releasever "${NVIDIA_RPM_RELEASEVER}" \
    --setopt=module_platform_id=platform:el"${NVIDIA_RPM_RELEASEVER}" \
    --setopt=install_weak_deps=False \
    --setopt=best=True \
    --disablerepo='*' \
    --enablerepo="${NVIDIA_DEPENDENCY_REPOS}" \
    --repofrompath=rke2-artifacts-nvidia-cuda,"${NVIDIA_CUDA_REPO_BASE_URL}" \
    --repofrompath=rke2-artifacts-nvidia-container,"${NVIDIA_CONTAINER_REPO_BASE_URL}" \
    --setopt=rke2-artifacts-nvidia-cuda.gpgcheck=True \
    --setopt=rke2-artifacts-nvidia-cuda.gpgkey="file://${NVIDIA_RPM_OUTPUT_DIR}/nvidia-cuda-public.key" \
    --setopt=rke2-artifacts-nvidia-container.gpgcheck=True \
    --setopt=rke2-artifacts-nvidia-container.gpgkey="file://${NVIDIA_RPM_OUTPUT_DIR}/nvidia-container-toolkit-public.key" \
    install \
    --downloadonly \
    --downloaddir "${NVIDIA_RPM_OUTPUT_DIR}" \
    nvidia-driver-cuda \
    nvidia-container-toolkit

  rm -rf "${nvidia_download_root}"
  trap - EXIT
  download_device_plugin_image
fi

echo "Done! Artifacts are ready in ${SCRIPT_DIR}."

